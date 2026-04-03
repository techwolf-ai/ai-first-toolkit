// POST /api/content/[type]/[slug]/move - Move content to a different stage

import { NextRequest, NextResponse } from 'next/server';
import { getContentByType, moveContent, isValidContentType } from '@/lib/content';
import { ContentStage, ContentType } from '@/types/content';

const VALID_STAGES: ContentStage[] = ['01-ideas', '02-drafts', '03-published'];

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ type: string; slug: string }> }
) {
  try {
    const { type, slug } = await params;
    const body = await request.json();
    const { targetStage } = body;

    if (!isValidContentType(type)) {
      return NextResponse.json(
        { success: false, error: `Invalid content type: ${type}` },
        { status: 400 }
      );
    }

    // Validate target stage
    if (!targetStage || !VALID_STAGES.includes(targetStage as ContentStage)) {
      return NextResponse.json(
        { success: false, error: 'Invalid target stage' },
        { status: 400 }
      );
    }

    // Get the content to verify it exists and get current stage
    const content = await getContentByType(type as ContentType, slug);

    if (!content) {
      return NextResponse.json(
        { success: false, error: 'Content not found' },
        { status: 404 }
      );
    }

    // Don't allow moving to the same stage
    if (content.metadata.stage === targetStage) {
      return NextResponse.json(
        { success: false, error: 'Content is already in this stage' },
        { status: 400 }
      );
    }

    const previousStage = content.metadata.stage;

    // Move the content to the new stage
    await moveContent(type as ContentType, slug, targetStage as ContentStage);

    return NextResponse.json({
      success: true,
      data: {
        slug,
        previousStage,
        newStage: targetStage
      }
    });
  } catch (error) {
    console.error('Error moving content:', error);
    return NextResponse.json(
      { success: false, error: 'Failed to move content' },
      { status: 500 }
    );
  }
}
