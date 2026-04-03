// POST /api/content/[type]/[slug]/duplicate - Duplicate content

import { NextRequest, NextResponse } from 'next/server';
import { getContentByType, createContent, isValidContentType } from '@/lib/content';
import { ContentType, ContentMetadata, ContentImage } from '@/types/content';
import { generateTimestampSlug } from '@/lib/slug';
import fs from 'fs/promises';
import path from 'path';
import { CONTENT_DIR } from '@/lib/paths';

export async function POST(
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

    // Get the original content
    const original = await getContentByType(type as ContentType, slug);

    if (!original) {
      return NextResponse.json(
        { success: false, error: 'Content not found' },
        { status: 404 }
      );
    }

    // Generate new timestamp-based slug
    const now = new Date();
    const newSlug = generateTimestampSlug(now);

    // Copy images if they exist
    let newImages: ContentImage[] | undefined = undefined;
    if (original.metadata.images && original.metadata.images.length > 0) {
      const oldImagesDir = path.join(CONTENT_DIR, 'images', slug);
      const newImagesDir = path.join(CONTENT_DIR, 'images', newSlug);

      try {
        // Check if source images folder exists
        await fs.access(oldImagesDir);

        // Create new images directory
        await fs.mkdir(newImagesDir, { recursive: true });

        // Copy each image file
        newImages = [];
        for (const image of original.metadata.images) {
          const srcPath = path.join(oldImagesDir, image.filename);
          const destPath = path.join(newImagesDir, image.filename);

          try {
            await fs.copyFile(srcPath, destPath);
            newImages.push({
              ...image,
              path: `images/${newSlug}/${image.filename}`
            });
          } catch (copyError) {
            console.error(`Failed to copy image ${image.filename}:`, copyError);
          }
        }
      } catch {
        // Images directory doesn't exist, skip copying
        console.log('No images directory found for original content');
      }
    }

    // Create new metadata with modifications (use full ISO timestamps)
    const nowISO = now.toISOString();
    const newMetadata: ContentMetadata = {
      ...original.metadata,
      title: `Copy of ${original.metadata.title}`,
      slug: newSlug,
      stage: '01-ideas',
      status: 'concept',
      created: nowISO,
      lastUpdated: nowISO,
      feedbackLog: [], // Reset feedback log for the copy
      images: newImages, // Use copied images with new paths
      // Clear published-specific fields
      publishedDate: undefined,
      finalVersion: undefined,
      channel: undefined,
      url: undefined,
      engagement: undefined,
      notes: undefined
    };

    // Create the duplicate content (keep same type)
    const filename = await createContent(type as ContentType, newMetadata, original.content);

    return NextResponse.json({
      success: true,
      data: {
        filename,
        stage: '01-ideas',
        slug: newSlug,
        type
      }
    });
  } catch (error) {
    console.error('Error duplicating content:', error);
    return NextResponse.json(
      { success: false, error: 'Failed to duplicate content' },
      { status: 500 }
    );
  }
}
