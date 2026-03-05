// Content file operations - Type-based folder structure with descriptive filenames
// Files stored in: content/posts/{type}/{slug}-{slugified-title}.yaml

import fs from 'fs/promises';
import path from 'path';
import yaml from 'js-yaml';
import { ContentFile, ContentStage, ContentMetadata, ContentType, SuggestionFile } from '@/types/content';
import { POSTS_DIR, IMAGES_DIR } from '@/lib/paths';

// All valid content types
const CONTENT_TYPES: ContentType[] = ['linkedin-post', 'opinion', 'article', 'blog-post', 'thread', 'newsletter'];

interface YamlContent extends ContentMetadata {
  content: string;
}

async function ensureDir(dir: string): Promise<void> {
  try {
    await fs.mkdir(dir, { recursive: true });
  } catch {
    // Directory exists
  }
}

// Slugify a title for use in filename
function slugifyTitle(title: string): string {
  return title
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '')
    .substring(0, 50); // Limit length
}

// Generate the expected filename from slug and title
function generateFilename(slug: string, title: string): string {
  const slugifiedTitle = slugifyTitle(title);
  if (slugifiedTitle) {
    return `${slug}-${slugifiedTitle}.yaml`;
  }
  return `${slug}.yaml`;
}

// Get the type folder path
function getTypeDir(type: ContentType): string {
  return path.join(POSTS_DIR, type);
}

// Find a file by slug within a type folder (handles both old and new naming)
async function findFileBySlug(type: ContentType, slug: string): Promise<string | null> {
  const typeDir = getTypeDir(type);

  try {
    await ensureDir(typeDir);
    const files = await fs.readdir(typeDir);

    // Look for file starting with the slug
    const matchingFile = files.find(f =>
      f.startsWith(slug) && f.endsWith('.yaml') && !f.endsWith('.suggestions.json')
    );

    return matchingFile ? path.join(typeDir, matchingFile) : null;
  } catch {
    return null;
  }
}

// Search for a file by slug across all type folders
async function findFileBySlugAcrossTypes(slug: string): Promise<{ path: string; type: ContentType } | null> {
  for (const type of CONTENT_TYPES) {
    const filePath = await findFileBySlug(type, slug);
    if (filePath) {
      return { path: filePath, type };
    }
  }
  return null;
}

export async function getAllContent(): Promise<Record<ContentStage, ContentFile[]>> {
  const result: Record<ContentStage, ContentFile[]> = {
    '01-ideas': [],
    '02-drafts': [],
    '03-published': []
  };

  try {
    // Ensure base posts directory exists
    await ensureDir(POSTS_DIR);

    // Scan all type folders
    for (const type of CONTENT_TYPES) {
      const typeDir = getTypeDir(type);

      try {
        await ensureDir(typeDir);
        const files = await fs.readdir(typeDir);
        const yamlFiles = files.filter(f => f.endsWith('.yaml') && !f.includes('.suggestions'));

        const contentFiles = await Promise.all(
          yamlFiles.map(async filename => {
            const filePath = path.join(typeDir, filename);
            const raw = await fs.readFile(filePath, 'utf-8');
            const data = yaml.load(raw) as YamlContent;

            const { content, ...metadata } = data;

            // Check if suggestions file exists
            const suggestionsPath = filePath.replace('.yaml', '.suggestions.json');
            let hasSuggestions = false;
            try {
              await fs.access(suggestionsPath);
              hasSuggestions = true;
            } catch {
              // No suggestions file
            }

            return {
              path: filePath,
              filename,
              stage: metadata.stage,
              metadata: metadata as ContentMetadata,
              content: content || '',
              hasSuggestions
            };
          })
        );

        // Group by stage
        for (const file of contentFiles) {
          if (result[file.stage]) {
            result[file.stage].push(file);
          }
        }
      } catch {
        // Type folder doesn't exist or is empty, skip
      }
    }

    // Also check the old flat structure for backwards compatibility
    try {
      const rootFiles = await fs.readdir(POSTS_DIR);
      const yamlFiles = rootFiles.filter(f => f.endsWith('.yaml') && !f.includes('.suggestions'));

      for (const filename of yamlFiles) {
        const filePath = path.join(POSTS_DIR, filename);
        const stat = await fs.stat(filePath);

        // Skip if it's a directory
        if (stat.isDirectory()) continue;

        try {
          const raw = await fs.readFile(filePath, 'utf-8');
          const data = yaml.load(raw) as YamlContent;
          const { content, ...metadata } = data;

          const suggestionsPath = filePath.replace('.yaml', '.suggestions.json');
          let hasSuggestions = false;
          try {
            await fs.access(suggestionsPath);
            hasSuggestions = true;
          } catch {
            // No suggestions file
          }

          const file = {
            path: filePath,
            filename,
            stage: metadata.stage,
            metadata: metadata as ContentMetadata,
            content: content || '',
            hasSuggestions
          };

          if (result[file.stage]) {
            result[file.stage].push(file);
          }
        } catch {
          // Skip invalid files
        }
      }
    } catch {
      // No root files
    }

    // Sort each stage by lastUpdated descending
    for (const stage of Object.keys(result) as ContentStage[]) {
      result[stage].sort((a, b) =>
        new Date(b.metadata.lastUpdated).getTime() - new Date(a.metadata.lastUpdated).getTime()
      );
    }

    return result;
  } catch (error) {
    console.error('Error reading content:', error);
    return result;
  }
}

export async function getContentByStage(stage: ContentStage): Promise<ContentFile[]> {
  const allContent = await getAllContent();
  return allContent[stage];
}

export async function getContentByType(type: ContentType, slug: string): Promise<ContentFile | null> {
  const typeDir = getTypeDir(type);
  await ensureDir(typeDir);

  // Find file by slug prefix
  const filePath = await findFileBySlug(type, slug);

  if (!filePath) {
    // Try the old flat structure as fallback
    const oldPath = path.join(POSTS_DIR, `${slug}.yaml`);
    try {
      await fs.access(oldPath);
      const raw = await fs.readFile(oldPath, 'utf-8');
      const data = yaml.load(raw) as YamlContent;
      const { content, ...metadata } = data;

      if (metadata.type !== type) {
        return null;
      }

      const suggestionsPath = oldPath.replace('.yaml', '.suggestions.json');
      let hasSuggestions = false;
      try {
        await fs.access(suggestionsPath);
        hasSuggestions = true;
      } catch {
        // No suggestions
      }

      return {
        path: oldPath,
        filename: `${slug}.yaml`,
        stage: metadata.stage,
        metadata: metadata as ContentMetadata,
        content: content || '',
        hasSuggestions
      };
    } catch {
      return null;
    }
  }

  try {
    const raw = await fs.readFile(filePath, 'utf-8');
    const data = yaml.load(raw) as YamlContent;
    const { content, ...metadata } = data;

    const suggestionsPath = filePath.replace('.yaml', '.suggestions.json');
    let hasSuggestions = false;
    try {
      await fs.access(suggestionsPath);
      hasSuggestions = true;
    } catch {
      // No suggestions
    }

    return {
      path: filePath,
      filename: path.basename(filePath),
      stage: metadata.stage,
      metadata: metadata as ContentMetadata,
      content: content || '',
      hasSuggestions
    };
  } catch {
    return null;
  }
}

// Legacy function for backwards compatibility
export async function getContentBySlug(stage: ContentStage, slug: string): Promise<ContentFile | null> {
  // Try to find the file across all type folders
  const found = await findFileBySlugAcrossTypes(slug);

  if (found) {
    const content = await getContentByType(found.type, slug);
    if (content && content.metadata.stage === stage) {
      return content;
    }
  }

  // Fallback: try old flat structure
  const oldPath = path.join(POSTS_DIR, `${slug}.yaml`);
  try {
    await fs.access(oldPath);
    const raw = await fs.readFile(oldPath, 'utf-8');
    const data = yaml.load(raw) as YamlContent;
    const { content, ...metadata } = data;

    if (metadata.stage !== stage) {
      return null;
    }

    const suggestionsPath = oldPath.replace('.yaml', '.suggestions.json');
    let hasSuggestions = false;
    try {
      await fs.access(suggestionsPath);
      hasSuggestions = true;
    } catch {
      // No suggestions
    }

    return {
      path: oldPath,
      filename: `${slug}.yaml`,
      stage,
      metadata: metadata as ContentMetadata,
      content: content || '',
      hasSuggestions
    };
  } catch {
    return null;
  }
}

export async function saveContent(
  type: ContentType,
  slug: string,
  metadata: ContentMetadata,
  content: string,
  currentFilePath?: string
): Promise<{ lastUpdated: string; newPath?: string }> {
  const typeDir = getTypeDir(type);
  await ensureDir(typeDir);

  // Update lastUpdated with full ISO timestamp
  const lastUpdated = new Date().toISOString();
  metadata.lastUpdated = lastUpdated;

  // Generate the correct filename based on title
  const newFilename = generateFilename(slug, metadata.title);
  const newFilePath = path.join(typeDir, newFilename);

  // Build YAML structure with content
  const yamlData: YamlContent = {
    ...metadata,
    content
  };

  const yamlContent = yaml.dump(yamlData, {
    lineWidth: -1,
    quotingType: '"',
    forceQuotes: false
  });

  await fs.writeFile(newFilePath, yamlContent, 'utf-8');

  // If the file was at a different path, delete the old one
  if (currentFilePath && currentFilePath !== newFilePath) {
    try {
      await fs.unlink(currentFilePath);

      // Also move suggestions file if it exists
      const oldSuggestionsPath = currentFilePath.replace('.yaml', '.suggestions.json');
      const newSuggestionsPath = newFilePath.replace('.yaml', '.suggestions.json');
      try {
        await fs.access(oldSuggestionsPath);
        await fs.rename(oldSuggestionsPath, newSuggestionsPath);
      } catch {
        // No suggestions file
      }
    } catch {
      // Old file doesn't exist, that's fine
    }
  }

  return { lastUpdated, newPath: newFilePath };
}

export async function createContent(
  type: ContentType,
  metadata: ContentMetadata,
  content: string
): Promise<string> {
  const typeDir = getTypeDir(type);
  await ensureDir(typeDir);

  // Generate filename with title
  const filename = generateFilename(metadata.slug, metadata.title);

  await saveContent(type, metadata.slug, metadata, content);
  return filename;
}

export async function moveContent(
  type: ContentType,
  slug: string,
  toStage: ContentStage
): Promise<void> {
  const content = await getContentByType(type, slug);
  if (!content) {
    throw new Error('Content not found');
  }

  // Update stage in metadata
  content.metadata.stage = toStage;

  await saveContent(type, slug, content.metadata, content.content, content.path);
}

export async function deleteContent(type: ContentType, slug: string): Promise<void> {
  const content = await getContentByType(type, slug);
  if (!content) {
    throw new Error('Content not found');
  }

  await fs.unlink(content.path);

  // Also delete suggestions if they exist
  const suggestionsPath = content.path.replace('.yaml', '.suggestions.json');
  try {
    await fs.unlink(suggestionsPath);
  } catch {
    // No suggestions file
  }

  // Delete images folder if it exists
  const imagesPath = path.join(IMAGES_DIR, slug);
  try {
    await fs.rm(imagesPath, { recursive: true });
  } catch {
    // No images folder
  }
}

// Suggestion file operations

export async function getSuggestions(type: ContentType, slug: string): Promise<SuggestionFile | null> {
  const content = await getContentByType(type, slug);
  if (!content) return null;

  const suggestionsPath = content.path.replace('.yaml', '.suggestions.json');

  try {
    const raw = await fs.readFile(suggestionsPath, 'utf-8');
    return JSON.parse(raw) as SuggestionFile;
  } catch {
    return null;
  }
}

export async function saveSuggestions(
  type: ContentType,
  slug: string,
  suggestions: SuggestionFile
): Promise<void> {
  const content = await getContentByType(type, slug);
  if (!content) throw new Error('Content not found');

  const suggestionsPath = content.path.replace('.yaml', '.suggestions.json');
  await fs.writeFile(suggestionsPath, JSON.stringify(suggestions, null, 2), 'utf-8');
}

export async function deleteSuggestions(type: ContentType, slug: string): Promise<void> {
  const content = await getContentByType(type, slug);
  if (!content) return;

  const suggestionsPath = content.path.replace('.yaml', '.suggestions.json');

  try {
    await fs.unlink(suggestionsPath);
  } catch {
    // File doesn't exist
  }
}

// Image path helper
export function getImageDir(slug: string): string {
  return path.join(IMAGES_DIR, slug);
}

// Helper to validate content type
export function isValidContentType(type: string): type is ContentType {
  return CONTENT_TYPES.includes(type as ContentType);
}

export { CONTENT_TYPES, slugifyTitle, generateFilename };
