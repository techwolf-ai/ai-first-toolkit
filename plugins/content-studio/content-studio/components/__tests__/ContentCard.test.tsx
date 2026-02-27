import { describe, it, expect } from '@jest/globals';
import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import ContentCard from '../Dashboard/ContentCard';
import { ContentFile } from '@/types/content';

describe('ContentCard', () => {
  const mockContent: ContentFile = {
    path: '/test/content.yaml',
    filename: '20260115-100000-test-post.yaml',
    stage: '01-ideas',
    metadata: {
      stage: '01-ideas',
      type: 'linkedin-post',
      title: 'Test Post',
      slug: '20260115-100000',
      created: '2026-01-15T10:00:00.000Z',
      lastUpdated: '2026-01-15T10:00:00.000Z',
      status: 'concept',
      audience: 'Test audience',
      coreInsight: 'This is a test insight',
      tags: ['test', 'example'],
      feedbackLog: [],
    },
    content: 'Test content',
    hasSuggestions: false,
  };

  it('should render content title', () => {
    render(<ContentCard content={mockContent} color="#8b5cf6" onRefresh={() => {}} />);

    expect(screen.getByText('Test Post')).toBeInTheDocument();
  });

  it('should display type badge with friendly label', () => {
    render(<ContentCard content={mockContent} color="#8b5cf6" onRefresh={() => {}} />);

    // ContentCard maps 'linkedin-post' to 'LinkedIn'
    expect(screen.getByText('LinkedIn')).toBeInTheDocument();
  });

  it('should show core insight', () => {
    render(<ContentCard content={mockContent} color="#8b5cf6" onRefresh={() => {}} />);

    expect(screen.getByText('This is a test insight')).toBeInTheDocument();
  });

  it('should show relative time', () => {
    render(<ContentCard content={mockContent} color="#8b5cf6" onRefresh={() => {}} />);

    // Should show some form of relative time (e.g., "X months ago")
    const timeElement = screen.getByText(/ago/);
    expect(timeElement).toBeInTheDocument();
  });

  it('should show engagement badge for published posts with reactions', () => {
    const publishedContent: ContentFile = {
      ...mockContent,
      stage: '03-published',
      metadata: {
        ...mockContent.metadata,
        stage: '03-published',
        engagement: {
          reactions: 145,
          comments: 23,
          reposts: 8,
        },
      },
    };

    render(<ContentCard content={publishedContent} color="#8b5cf6" onRefresh={() => {}} />);

    expect(screen.getByText('145')).toBeInTheDocument();
  });

  it('should not show engagement badge for draft posts', () => {
    render(<ContentCard content={mockContent} color="#8b5cf6" onRefresh={() => {}} />);

    // No reaction count should be visible
    expect(screen.queryByText('145')).not.toBeInTheDocument();
  });
});
