// GET /api/content/[type]/[slug] - Get specific content
// PUT /api/content/[type]/[slug] - Update content

import { NextRequest, NextResponse } from 'next/server';
import { getContentByType, saveContent, getSuggestions, isValidContentType } from '@/lib/content';
import { ContentType, ContentMetadata } from '@/types/content';

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

    // Also fetch suggestions if they exist
    const suggestions = await getSuggestions(type as ContentType, slug);

    return NextResponse.json({
      success: true,
      data: { ...content, suggestions }
    });
  } catch (error) {
    console.error('Error fetching content:', error);
    return NextResponse.json(
      { success: false, error: 'Failed to fetch content' },
      { status: 500 }
    );
  }
}

export async function PUT(
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

    const body = await request.json();
    const { metadata, content } = body;

    const existing = await getContentByType(type as ContentType, slug);

    if (!existing) {
      return NextResponse.json(
        { success: false, error: 'Content not found' },
        { status: 404 }
      );
    }

    const result = await saveContent(
      type as ContentType,
      slug,
      metadata as ContentMetadata,
      content,
      existing.path
    );

    return NextResponse.json({
      success: true,
      lastUpdated: result.lastUpdated,
      newPath: result.newPath
    });
  } catch (error) {
    console.error('Error updating content:', error);
    return NextResponse.json(
      { success: false, error: 'Failed to update content' },
      { status: 500 }
    );
  }
}
