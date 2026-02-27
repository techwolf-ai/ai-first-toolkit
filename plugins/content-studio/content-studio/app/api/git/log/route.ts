// GET /api/git/log - Get commit history

import { NextRequest, NextResponse } from 'next/server';
import { getCommitLog } from '@/lib/git';

export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams;
    const limit = parseInt(searchParams.get('limit') || '10');

    const log = await getCommitLog(limit);

    return NextResponse.json({ success: true, data: log });
  } catch (error) {
    console.error('Error getting commit log:', error);
    return NextResponse.json(
      { success: false, error: 'Failed to get commit log' },
      { status: 500 }
    );
  }
}
