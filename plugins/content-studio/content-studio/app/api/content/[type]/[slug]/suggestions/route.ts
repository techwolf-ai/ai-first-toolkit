// GET /api/content/[type]/[slug]/suggestions - Get suggestions
// PUT /api/content/[type]/[slug]/suggestions - Update suggestions

import { NextRequest, NextResponse } from 'next/server';
import { getSuggestions, saveSuggestions, isValidContentType } from '@/lib/content';
import { ContentType, SuggestionFile } from '@/types/content';

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

    const suggestions = await getSuggestions(type as ContentType, slug);

    if (!suggestions) {
      return NextResponse.json(
        { success: false, error: 'No suggestions found' },
        { status: 404 }
      );
    }

    return NextResponse.json({ success: true, data: suggestions });
  } catch (error) {
    console.error('Error fetching suggestions:', error);
    return NextResponse.json(
      { success: false, error: 'Failed to fetch suggestions' },
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

    await saveSuggestions(type as ContentType, slug, body as SuggestionFile);

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('Error updating suggestions:', error);
    return NextResponse.json(
      { success: false, error: 'Failed to update suggestions' },
      { status: 500 }
    );
  }
}
