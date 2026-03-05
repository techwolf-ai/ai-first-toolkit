import path from 'path';

export const REPO_DIR = path.join(process.cwd(), '..');
export const CONTENT_DIR = path.join(REPO_DIR, 'content');
export const POSTS_DIR = path.join(CONTENT_DIR, 'posts');
export const IMAGES_DIR = path.join(CONTENT_DIR, 'images');

export function isPathWithin(filePath: string, baseDir: string): boolean {
  const resolved = path.resolve(filePath);
  const resolvedBase = path.resolve(baseDir);
  return resolved.startsWith(resolvedBase + path.sep) || resolved === resolvedBase;
}
