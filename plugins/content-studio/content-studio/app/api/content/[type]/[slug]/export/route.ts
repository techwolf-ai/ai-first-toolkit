import { NextRequest, NextResponse } from 'next/server';
import { getContentByType, isValidContentType } from '@/lib/content';
import { ContentType } from '@/types/content';
import puppeteer from 'puppeteer';
import { readFile } from 'fs/promises';
import path from 'path';
import { marked } from 'marked';
import { CONTENT_DIR, isPathWithin } from '@/lib/paths';

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ type: string; slug: string }> }
) {
  try {
    const { type, slug } = await params;

    if (!isValidContentType(type)) {
      return NextResponse.json(
        { success: false, error: `Invalid content type: ${type}` },
        { status: 400 }
      );
    }

    const content = await getContentByType(type as ContentType, slug);

    if (!content) {
      return NextResponse.json(
        { success: false, error: 'Content not found' },
        { status: 404 }
      );
    }

    // Convert images to base64
    const imageData: Record<string, string> = {};
    if (content.metadata.images) {
      for (const img of content.metadata.images) {
        try {
          const imgPath = path.join(CONTENT_DIR, img.path);
          if (!isPathWithin(imgPath, CONTENT_DIR)) continue;
          const buffer = await readFile(imgPath);
          const ext = path.extname(img.filename).slice(1).toLowerCase();
          const mimeType = ext === 'png' ? 'image/png' : ext === 'gif' ? 'image/gif' : 'image/jpeg';
          imageData[img.filename] = `data:${mimeType};base64,${buffer.toString('base64')}`;
        } catch {
          // Skip missing images
        }
      }
    }

    // Parse markdown to HTML
    const contentHtml = await marked(content.content || '');

    // Build HTML document
    const html = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>${content.metadata.title || 'Untitled'}</title>
  <style>
    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
    }

    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      font-size: 14px;
      line-height: 1.6;
      color: #1a1a1a;
      padding: 40px;
      max-width: 800px;
      margin: 0 auto;
    }

    .header {
      border-bottom: 2px solid #e5e5e5;
      padding-bottom: 20px;
      margin-bottom: 30px;
    }

    .stage-badge {
      display: inline-block;
      font-size: 11px;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      padding: 4px 10px;
      border-radius: 4px;
      background: ${content.metadata.stage === '03-published' ? '#dcfce7' : content.metadata.stage === '02-drafts' ? '#fef3c7' : '#ede9fe'};
      color: ${content.metadata.stage === '03-published' ? '#166534' : content.metadata.stage === '02-drafts' ? '#92400e' : '#5b21b6'};
      margin-bottom: 12px;
    }

    .title {
      font-family: Georgia, 'Times New Roman', serif;
      font-size: 28px;
      font-weight: 600;
      line-height: 1.3;
      margin-bottom: 16px;
    }

    .core-insight {
      font-size: 16px;
      color: #4a4a4a;
      font-style: italic;
      padding: 16px;
      background: #f9f9f9;
      border-left: 3px solid #0066cc;
      margin-bottom: 16px;
    }

    .meta {
      font-size: 12px;
      color: #666;
    }

    .meta span {
      margin-right: 16px;
    }

    .tags {
      margin-top: 8px;
    }

    .tag {
      display: inline-block;
      font-size: 11px;
      padding: 2px 8px;
      background: #f0f0f0;
      border-radius: 3px;
      margin-right: 6px;
      color: #555;
    }

    .content {
      margin-top: 30px;
    }

    .content p {
      margin-bottom: 16px;
    }

    .content h1, .content h2, .content h3 {
      font-family: Georgia, 'Times New Roman', serif;
      margin-top: 24px;
      margin-bottom: 12px;
    }

    .content h1 { font-size: 24px; }
    .content h2 { font-size: 20px; }
    .content h3 { font-size: 16px; }

    .content ul, .content ol {
      margin-bottom: 16px;
      padding-left: 24px;
    }

    .content li {
      margin-bottom: 8px;
    }

    .content strong {
      font-weight: 600;
    }

    .content blockquote {
      margin: 16px 0;
      padding: 12px 20px;
      border-left: 3px solid #ddd;
      color: #555;
      font-style: italic;
    }

    .content code {
      font-family: 'SF Mono', Monaco, monospace;
      font-size: 13px;
      background: #f5f5f5;
      padding: 2px 6px;
      border-radius: 3px;
    }

    .images {
      margin-top: 30px;
      border-top: 1px solid #e5e5e5;
      padding-top: 20px;
    }

    .images-title {
      font-size: 12px;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      color: #666;
      margin-bottom: 16px;
    }

    .image-grid {
      display: grid;
      grid-template-columns: repeat(2, 1fr);
      gap: 16px;
    }

    .image-item img {
      width: 100%;
      height: auto;
      border-radius: 4px;
      border: 1px solid #e5e5e5;
    }

    .footer {
      margin-top: 40px;
      padding-top: 20px;
      border-top: 1px solid #e5e5e5;
      font-size: 11px;
      color: #999;
      text-align: center;
    }
  </style>
</head>
<body>
  <div class="header">
    <div class="stage-badge">${content.metadata.stage.replace(/^\d+-/, '')}</div>
    <h1 class="title">${content.metadata.title || 'Untitled'}</h1>
    ${content.metadata.coreInsight ? `<div class="core-insight">${content.metadata.coreInsight}</div>` : ''}
    <div class="meta">
      <span><strong>Type:</strong> ${content.metadata.type}</span>
      <span><strong>Created:</strong> ${new Date(content.metadata.created).toLocaleDateString()}</span>
      <span><strong>Updated:</strong> ${new Date(content.metadata.lastUpdated).toLocaleDateString()}</span>
    </div>
    ${content.metadata.tags && content.metadata.tags.length > 0 ? `
    <div class="tags">
      ${content.metadata.tags.map(tag => `<span class="tag">${tag}</span>`).join('')}
    </div>
    ` : ''}
  </div>

  <div class="content">
    ${contentHtml}
  </div>

  ${content.metadata.images && content.metadata.images.length > 0 ? `
  <div class="images">
    <div class="images-title">Attached Images</div>
    <div class="image-grid">
      ${content.metadata.images.map(img => `
        <div class="image-item">
          <img src="${imageData[img.filename] || ''}" alt="${img.alt || img.filename}" />
        </div>
      `).join('')}
    </div>
  </div>
  ` : ''}

  <div class="footer">
    Exported from Content Studio on ${new Date().toLocaleDateString()} at ${new Date().toLocaleTimeString()}
  </div>
</body>
</html>
    `;

    // Launch Puppeteer and generate PDF
    const browser = await puppeteer.launch({
      headless: true,
      args: ['--no-sandbox', '--disable-setuid-sandbox']
    });

    const page = await browser.newPage();
    await page.setContent(html, { waitUntil: 'networkidle0' });

    const pdf = await page.pdf({
      format: 'A4',
      printBackground: true,
      margin: {
        top: '20mm',
        right: '20mm',
        bottom: '20mm',
        left: '20mm'
      }
    });

    await browser.close();

    // Return PDF
    const filename = `${slug}-${content.metadata.stage.replace(/^\d+-/, '')}.pdf`;

    return new NextResponse(Buffer.from(pdf), {
      headers: {
        'Content-Type': 'application/pdf',
        'Content-Disposition': `attachment; filename="${filename}"`
      }
    });

  } catch (error) {
    console.error('Error exporting PDF:', error);
    return NextResponse.json(
      { success: false, error: 'Failed to export PDF' },
      { status: 500 }
    );
  }
}
