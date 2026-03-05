import { describe, it, expect, beforeEach, jest } from '@jest/globals';

// Create mock functions with explicit any type
const mockStatus = jest.fn<() => Promise<unknown>>();
const mockAdd = jest.fn<() => Promise<unknown>>();
const mockCommit = jest.fn<() => Promise<unknown>>();
const mockPush = jest.fn<() => Promise<unknown>>();
const mockLog = jest.fn<() => Promise<unknown>>();

// Mock simple-git module
jest.mock('simple-git', () => {
  return jest.fn(() => ({
    status: mockStatus,
    add: mockAdd,
    commit: mockCommit,
    push: mockPush,
    log: mockLog,
  }));
});

// Import after mocking
import { getGitStatus, commitChanges, pushChanges } from '../git';

describe('Git Library', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('getGitStatus', () => {
    it('should return formatted git status', async () => {
      mockStatus.mockResolvedValue({
        current: 'main',
        files: [
          { path: 'test.md', working_dir: 'M', index: ' ' },
          { path: 'test2.md', working_dir: 'A', index: 'A' },
        ],
        ahead: 1,
        behind: 0,
      });

      const status = await getGitStatus();

      expect(status.branch).toBe('main');
      expect(status.changes).toHaveLength(2);
      expect(status.changes[0].path).toBe('test.md');
      expect(status.changes[0].status).toBe('M');
      expect(status.changes[1].staged).toBe(true);
    });
  });

  describe('commitChanges', () => {
    it('should commit with provided message', async () => {
      mockCommit.mockResolvedValue({
        commit: 'abc123',
        summary: { changes: 2 },
      });

      const result = await commitChanges('Test commit');

      expect(mockCommit).toHaveBeenCalledWith('Test commit');
      expect(result.hash).toBe('abc123');
    });
  });

  describe('pushChanges', () => {
    it('should push to origin', async () => {
      mockPush.mockResolvedValue({});

      await pushChanges();

      expect(mockPush).toHaveBeenCalledWith('origin', 'HEAD');
    });

    it('should push to specified branch', async () => {
      mockPush.mockResolvedValue({});

      await pushChanges('main');

      expect(mockPush).toHaveBeenCalledWith('origin', 'main');
    });
  });
});
