// Git operations using simple-git

import simpleGit, { SimpleGit } from 'simple-git';
import path from 'path';
import { GitStatus, GitChange, GitCommit } from '@/types/content';

const REPO_DIR = path.join(process.cwd(), '..');
const git: SimpleGit = simpleGit(REPO_DIR);

export async function getGitStatus(): Promise<GitStatus> {
  const status = await git.status();

  const changes: GitChange[] = status.files.map(file => ({
    path: file.path,
    status: file.working_dir,
    staged: file.index !== ' '
  }));

  return {
    branch: status.current || 'unknown',
    changes,
    ahead: status.ahead,
    behind: status.behind
  };
}

export async function stageFiles(files: string[]): Promise<void> {
  await git.add(files);
}

export async function unstageFiles(files: string[]): Promise<void> {
  await git.reset(files);
}

export async function commitChanges(message: string): Promise<GitCommit> {
  const result = await git.commit(message);

  return {
    hash: result.commit,
    message: result.summary.changes.toString(),
    author: '',
    date: new Date().toISOString()
  };
}

export async function pushChanges(branch?: string): Promise<void> {
  await git.push('origin', branch || 'HEAD');
}

export async function pullChanges(): Promise<void> {
  await git.pull();
}

export async function getCommitLog(limit = 10): Promise<GitCommit[]> {
  const log = await git.log({ maxCount: limit });

  return log.all.map(commit => ({
    hash: commit.hash,
    message: commit.message,
    author: commit.author_name,
    date: commit.date
  }));
}

export async function getDiff(filepath?: string): Promise<string> {
  if (filepath) {
    return await git.diff([filepath]);
  }
  return await git.diff();
}

export async function getCurrentBranch(): Promise<string> {
  const status = await git.status();
  return status.current || 'unknown';
}

export async function createBranch(branchName: string): Promise<void> {
  await git.checkoutLocalBranch(branchName);
}

export async function switchBranch(branchName: string): Promise<void> {
  await git.checkout(branchName);
}
