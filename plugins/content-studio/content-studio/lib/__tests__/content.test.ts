import { describe, it, expect, beforeEach, jest } from '@jest/globals';
import fs from 'fs/promises';
import {
  slugifyTitle,
  generateFilename,
  isValidContentType,
  saveContent,
  createContent,
} from '../content';
import { ContentMetadata } from '@/types/content';

jest.mock('fs/promises');

const mockFs = fs as jest.Mocked<typeof fs>;

describe('Content Library', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('slugifyTitle', () => {
    it('should convert title to URL-safe slug', () => {
      expect(slugifyTitle('Hello World')).toBe('hello-world');
      expect(slugifyTitle('AI & Machine Learning!')).toBe('ai-machine-learning');
      expect(slugifyTitle('  spaces  ')).toBe('spaces');
    });

    it('should truncate long titles to 50 characters', () => {
      const long = 'a'.repeat(100);
      expect(slugifyTitle(long).length).toBeLessThanOrEqual(50);
    });
  });

  describe('generateFilename', () => {
    it('should combine slug and slugified title with .yaml extension', () => {
      expect(generateFilename('20260115-100000', 'My Test Post')).toBe(
        '20260115-100000-my-test-post.yaml'
      );
    });

    it('should handle empty title', () => {
      expect(generateFilename('20260115-100000', '')).toBe('20260115-100000.yaml');
    });
  });

  describe('isValidContentType', () => {
    it('should accept valid content types', () => {
      expect(isValidContentType('linkedin-post')).toBe(true);
      expect(isValidContentType('opinion')).toBe(true);
      expect(isValidContentType('blog-post')).toBe(true);
    });

    it('should reject invalid content types', () => {
      expect(isValidContentType('invalid')).toBe(false);
      expect(isValidContentType('')).toBe(false);
    });
  });

  describe('saveContent', () => {
    it('should write YAML file and update lastUpdated', async () => {
      mockFs.mkdir.mockResolvedValue(undefined);
      mockFs.writeFile.mockResolvedValue(undefined);

      const metadata: ContentMetadata = {
        stage: '01-ideas',
        type: 'linkedin-post',
        title: 'Test',
        slug: '20260115-100000',
        created: '2026-01-15',
        lastUpdated: '2026-01-15',
        status: 'concept',
        tags: [],
        feedbackLog: [],
      };

      const result = await saveContent('linkedin-post', '20260115-100000', metadata, 'Content');

      expect(mockFs.writeFile).toHaveBeenCalled();
      expect(result.lastUpdated).toBeDefined();
      expect(new Date(result.lastUpdated).getTime()).toBeGreaterThan(0);
    });
  });

  describe('createContent', () => {
    it('should generate YAML filename with slug and title', async () => {
      mockFs.mkdir.mockResolvedValue(undefined);
      mockFs.writeFile.mockResolvedValue(undefined);

      const metadata: ContentMetadata = {
        stage: '01-ideas',
        type: 'linkedin-post',
        title: 'Test Post',
        slug: '20260115-100000',
        created: '2026-01-15',
        lastUpdated: '2026-01-15',
        status: 'concept',
        tags: [],
        feedbackLog: [],
      };

      const filename = await createContent('linkedin-post', metadata, 'Content');

      expect(filename).toBe('20260115-100000-test-post.yaml');
    });
  });
});
