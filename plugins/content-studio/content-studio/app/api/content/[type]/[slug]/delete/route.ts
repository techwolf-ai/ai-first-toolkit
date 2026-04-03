// DELETE /api/content/[type]/[slug]/delete - Delete content and its images

import { NextRequest, NextResponse } from 'next/server';
import { deleteContent, isValidContentType } from '@/lib/content';
import { ContentType } from '@/types/content';

export async function DELETE(
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

    await deleteContent(type as ContentType, slug);

    return NextResponse.json({
      success: true,
      data: {
        slug,
        deleted: true
      }
    });
  } catch (error) {
    console.error('Error deleting content:', error);
    return NextResponse.json(
      { success: false, error: 'Failed to delete content' },
      { status: 500 }
    );
  }
}
