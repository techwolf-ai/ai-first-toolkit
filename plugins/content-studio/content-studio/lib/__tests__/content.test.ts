import { describe, it, expect, beforeEach, afterEach, jest } from '@jest/globals';
import fs from 'fs/promises';
import path from 'path';
import {
  getContentByStage,
  getAllContent,
  getContentBySlug,
  saveContent,
  createContent,
} from '../content';
import { ContentStage, ContentMetadata } from '@/types/content';

// Mock fs module
jest.mock('fs/promises');

const mockFs = fs as jest.Mocked<typeof fs>;

describe('Content Library', () => {
  const testContentDir = '/test/content';

  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('getContentByStage', () => {
    it('should return empty array when directory is empty', async () => {
      mockFs.readdir.mockResolvedValue([]);

      const result = await getContentByStage('01-ideas');

      expect(result).toEqual([]);
    });

    it('should filter out non-markdown files', async () => {
      mockFs.readdir.mockResolvedValue([
        'test.md',
        'test.txt',
        'test.suggestions.json',
      ] as any);

      mockFs.readFile.mockResolvedValue('---\ntitle: Test\n---\nContent');

      const result = await getContentByStage('01-ideas');

      expect(result).toHaveLength(1);
      expect(result[0].filename).toBe('test.md');
    });

    it('should parse frontmatter correctly', async () => {
      const fileContent = `---
stage: idea
type: linkedin-post
title: Test Post
slug: test-post
created: 2025-12-27
lastUpdated: 2025-12-27
status: concept
tags: [test]
feedbackLog: []
---

# Test Content`;

      mockFs.readdir.mockResolvedValue(['test.md'] as any);
      mockFs.readFile.mockResolvedValue(fileContent);
      mockFs.access.mockRejectedValue(new Error('No suggestions'));

      const result = await getContentByStage('01-ideas');

      expect(result).toHaveLength(1);
      expect(result[0].metadata.title).toBe('Test Post');
      expect(result[0].metadata.type).toBe('linkedin-post');
      expect(result[0].content).toContain('# Test Content');
    });

    it('should detect suggestions file', async () => {
      mockFs.readdir.mockResolvedValue(['test.md'] as any);
      mockFs.readFile.mockResolvedValue('---\ntitle: Test\n---\nContent');
      mockFs.access.mockResolvedValue(undefined);

      const result = await getContentByStage('01-ideas');

      expect(result[0].hasSuggestions).toBe(true);
    });
  });

  describe('saveContent', () => {
    it('should update lastUpdated field', async () => {
      const metadata: ContentMetadata = {
        stage: '01-ideas',
        type: 'linkedin-post',
        title: 'Test',
        slug: 'test',
        created: '2025-12-27',
        lastUpdated: '2025-12-27',
        status: 'concept',
        tags: [],
        feedbackLog: [],
      };

      mockFs.writeFile.mockResolvedValue(undefined);

      await saveContent('01-ideas', 'test.md', metadata, 'Content');

      expect(mockFs.writeFile).toHaveBeenCalled();
      const writtenContent = (mockFs.writeFile as any).mock.calls[0][1];
      expect(writtenContent).toContain('lastUpdated:');
    });
  });

  describe('createContent', () => {
    it('should generate filename with date and slug', async () => {
      const metadata: ContentMetadata = {
        stage: '01-ideas',
        type: 'linkedin-post',
        title: 'Test Post',
        slug: 'test-post',
        created: '2025-12-27',
        lastUpdated: '2025-12-27',
        status: 'concept',
        tags: [],
        feedbackLog: [],
      };

      mockFs.writeFile.mockResolvedValue(undefined);

      const filename = await createContent('01-ideas', metadata, 'Content');

      expect(filename).toMatch(/^\d{4}-\d{2}-\d{2}-test-post\.md$/);
    });
  });
});
