// POST /api/git/push - Push changes to remote

import { NextRequest, NextResponse } from 'next/server';
import { pushChanges } from '@/lib/git';

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { branch } = body;

    await pushChanges(branch);

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('Error pushing changes:', error);
    return NextResponse.json(
      { success: false, error: 'Failed to push changes' },
      { status: 500 }
    );
  }
}
