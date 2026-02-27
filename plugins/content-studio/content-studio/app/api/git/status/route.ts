// GET /api/git/status - Get current git status

import { NextResponse } from 'next/server';
import { getGitStatus } from '@/lib/git';

export async function GET() {
  try {
    const status = await getGitStatus();
    return NextResponse.json({ success: true, data: status });
  } catch (error) {
    console.error('Error getting git status:', error);
    return NextResponse.json(
      { success: false, error: 'Failed to get git status' },
      { status: 500 }
    );
  }
}
