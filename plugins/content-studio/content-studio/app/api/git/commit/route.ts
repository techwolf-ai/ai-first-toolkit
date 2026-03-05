// POST /api/git/commit - Commit changes

import { NextRequest, NextResponse } from 'next/server';
import { stageFiles, commitChanges } from '@/lib/git';

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { files, message } = body;

    if (!message || typeof message !== 'string' || message.trim().length === 0) {
      return NextResponse.json(
        { success: false, error: 'Commit message is required' },
        { status: 400 }
      );
    }

    if (message.length > 5000) {
      return NextResponse.json(
        { success: false, error: 'Commit message too long (max 5000 characters)' },
        { status: 400 }
      );
    }

    // Stage files if provided, otherwise commit all staged files
    if (files && Array.isArray(files) && files.length > 0) {
      await stageFiles(files);
    }

    const commit = await commitChanges(message);

    return NextResponse.json({ success: true, data: commit });
  } catch (error) {
    console.error('Error committing changes:', error);
    return NextResponse.json(
      { success: false, error: 'Failed to commit changes' },
      { status: 500 }
    );
  }
}
