// File system watcher for real-time updates

import chokidar, { FSWatcher } from 'chokidar';
import path from 'path';

const CONTENT_DIR = path.join(process.cwd(), '../content');

let watcher: FSWatcher | null = null;

export type FileChangeHandler = (event: 'add' | 'change' | 'unlink', filepath: string) => void;

export function initFileWatcher(onFileChange: FileChangeHandler): FSWatcher {
  if (watcher) {
    return watcher;
  }

  watcher = chokidar.watch(CONTENT_DIR, {
    ignored: /(^|[\/\\])\../, // ignore dotfiles
    persistent: true,
    ignoreInitial: true,
    awaitWriteFinish: {
      stabilityThreshold: 300,
      pollInterval: 100
    }
  });

  watcher
    .on('add', filepath => {
      const relativePath = path.relative(CONTENT_DIR, filepath);
      onFileChange('add', relativePath);
    })
    .on('change', filepath => {
      const relativePath = path.relative(CONTENT_DIR, filepath);
      onFileChange('change', relativePath);
    })
    .on('unlink', filepath => {
      const relativePath = path.relative(CONTENT_DIR, filepath);
      onFileChange('unlink', relativePath);
    });

  return watcher;
}

export function closeFileWatcher(): void {
  if (watcher) {
    watcher.close();
    watcher = null;
  }
}

export function getWatcher(): FSWatcher | null {
  return watcher;
}
