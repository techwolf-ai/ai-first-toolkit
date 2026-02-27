import { NextRequest, NextResponse } from 'next/server';
import { writeFile, mkdir } from 'fs/promises';
import path from 'path';

const CONTENT_DIR = path.join(process.cwd(), '..', 'content');

export async function POST(request: NextRequest) {
  try {
    const formData = await request.formData();
    const file = formData.get('file') as File;
    const type = formData.get('type') as string;
    const slug = formData.get('slug') as string;

    if (!file) {
      return NextResponse.json(
        { success: false, error: 'No file provided' },
        { status: 400 }
      );
    }

    if (!type || !slug) {
      return NextResponse.json(
        { success: false, error: 'Type and slug are required' },
        { status: 400 }
      );
    }

    // Validate file type
    const validTypes = ['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/svg+xml'];
    if (!validTypes.includes(file.type)) {
      return NextResponse.json(
        { success: false, error: 'Invalid file type. Only images are allowed.' },
        { status: 400 }
      );
    }

    // Create images directory for this content (in central images folder)
    const imagesDir = path.join(CONTENT_DIR, 'images', slug);
    await mkdir(imagesDir, { recursive: true });

    // Generate unique filename
    const ext = file.name.split('.').pop();
    const timestamp = Date.now();
    const safeName = file.name
      .replace(/\.[^/.]+$/, '')
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .substring(0, 50);
    const filename = `${safeName}-${timestamp}.${ext}`;

    // Write file
    const filePath = path.join(imagesDir, filename);
    const bytes = await file.arrayBuffer();
    const buffer = Buffer.from(bytes);
    await writeFile(filePath, buffer);

    // Return relative path for markdown
    const relativePath = `images/${slug}/${filename}`;

    return NextResponse.json({
      success: true,
      data: {
        filename,
        path: relativePath,
        markdown: `![${file.name}](${relativePath})`,
        fullPath: filePath
      }
    });
  } catch (error) {
    console.error('Error uploading file:', error);
    return NextResponse.json(
      { success: false, error: 'Failed to upload file' },
      { status: 500 }
    );
  }
}
