// GET /api/content - Get all content across stages
// POST /api/content - Create new content

import { NextRequest, NextResponse } from 'next/server';
import { getAllContent, createContent, isValidContentType } from '@/lib/content';
import { ContentMetadata, ContentType } from '@/types/content';
import { generateTimestampSlug } from '@/lib/slug';

export async function GET() {
  try {
    const content = await getAllContent();
    return NextResponse.json({ success: true, data: content });
  } catch (error) {
    console.error('Error fetching content:', error);
    return NextResponse.json(
      { success: false, error: 'Failed to fetch content' },
      { status: 500 }
    );
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { stage, metadata, content } = body;

    const now = new Date().toISOString();

    // Ensure slug and timestamps are set server-side if not provided
    const fullMetadata: ContentMetadata = {
      ...metadata,
      slug: metadata.slug || generateTimestampSlug(),
      created: metadata.created || now,
      lastUpdated: now
    };

    // Validate content type
    if (!isValidContentType(fullMetadata.type)) {
      return NextResponse.json(
        { success: false, error: `Invalid content type: ${fullMetadata.type}` },
        { status: 400 }
      );
    }

    const filename = await createContent(fullMetadata.type as ContentType, fullMetadata, content || '');

    return NextResponse.json({
      success: true,
      data: { filename, stage, slug: fullMetadata.slug, type: fullMetadata.type }
    });
  } catch (error) {
    console.error('Error creating content:', error);
    return NextResponse.json(
      { success: false, error: 'Failed to create content' },
      { status: 500 }
    );
  }
}
