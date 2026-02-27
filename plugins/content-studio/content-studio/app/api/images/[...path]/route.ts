import { NextRequest, NextResponse } from 'next/server';
import { readFile } from 'fs/promises';
import path from 'path';

const CONTENT_DIR = path.join(process.cwd(), '..', 'content');

const MIME_TYPES: Record<string, string> = {
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'gif': 'image/gif',
  'webp': 'image/webp',
  'svg': 'image/svg+xml'
};

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ path: string[] }> }
) {
  try {
    const { path: pathParts } = await params;
    const imagePath = path.join(CONTENT_DIR, ...pathParts);

    // Security: ensure path is within content directory
    const resolvedPath = path.resolve(imagePath);
    if (!resolvedPath.startsWith(path.resolve(CONTENT_DIR))) {
      return NextResponse.json(
        { error: 'Access denied' },
        { status: 403 }
      );
    }

    const ext = path.extname(imagePath).slice(1).toLowerCase();
    const mimeType = MIME_TYPES[ext];

    if (!mimeType) {
      return NextResponse.json(
        { error: 'Unsupported file type' },
        { status: 400 }
      );
    }

    const buffer = await readFile(imagePath);

    return new NextResponse(buffer, {
      headers: {
        'Content-Type': mimeType,
        'Cache-Control': 'public, max-age=31536000, immutable'
      }
    });
  } catch (error) {
    console.error('Error serving image:', error);
    return NextResponse.json(
      { error: 'Image not found' },
      { status: 404 }
    );
  }
}
