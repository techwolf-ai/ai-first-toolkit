import { describe, it, expect } from '@jest/globals';
import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import ContentCard from '../Dashboard/ContentCard';
import { ContentFile } from '@/types/content';

describe('ContentCard', () => {
  const mockContent: ContentFile = {
    path: '/test/content.md',
    filename: '2025-12-27-test-post.md',
    stage: '01-ideas',
    metadata: {
      stage: '01-ideas',
      type: 'linkedin-post',
      title: 'Test Post',
      slug: 'test-post',
      created: '2025-12-27',
      lastUpdated: '2025-12-27',
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

  it('should display type and status badges', () => {
    render(<ContentCard content={mockContent} color="#8b5cf6" onRefresh={() => {}} />);

    expect(screen.getByText('linkedin-post')).toBeInTheDocument();
    expect(screen.getByText('concept')).toBeInTheDocument();
  });

  it('should show core insight', () => {
    render(<ContentCard content={mockContent} color="#8b5cf6" onRefresh={() => {}} />);

    expect(screen.getByText('This is a test insight')).toBeInTheDocument();
  });

  it('should display tags', () => {
    render(<ContentCard content={mockContent} color="#8b5cf6" onRefresh={() => {}} />);

    expect(screen.getByText('test')).toBeInTheDocument();
    expect(screen.getByText('example')).toBeInTheDocument();
  });

  it('should show suggestions indicator when present', () => {
    const contentWithSuggestions = {
      ...mockContent,
      hasSuggestions: true,
    };

    render(<ContentCard content={contentWithSuggestions} color="#8b5cf6" onRefresh={() => {}} />);

    expect(screen.getByText('📝 Has suggestions')).toBeInTheDocument();
  });

  it('should show audience when provided', () => {
    render(<ContentCard content={mockContent} color="#8b5cf6" onRefresh={() => {}} />);

    expect(screen.getByText('Test audience')).toBeInTheDocument();
  });
});
