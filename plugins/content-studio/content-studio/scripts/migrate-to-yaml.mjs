#!/usr/bin/env node

/**
 * Migration script: Convert MD files with frontmatter to YAML files in single folder
 *
 * Run with: node scripts/migrate-to-yaml.mjs
 */

import fs from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';
import matter from 'gray-matter';
import yaml from 'js-yaml';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const CONTENT_DIR = path.join(__dirname, '../../content');
const POSTS_DIR = path.join(CONTENT_DIR, 'posts');
const IMAGES_DIR = path.join(CONTENT_DIR, 'images');
const STAGES = ['01-ideas', '02-drafts', '03-published'];

async function ensureDir(dir) {
  try {
    await fs.mkdir(dir, { recursive: true });
  } catch (error) {
    // Directory exists
  }
}

function extractTitleFromContent(content) {
  const match = content.match(/^#\s+(.+)$/m);
  return match ? match[1].trim() : null;
}

function extractCoreInsightFromContent(content) {
  const match = content.match(/## Core Insight\s*\n+([^\n#]+)/);
  return match ? match[1].trim() : null;
}

function cleanContent(content, title) {
  let cleaned = content;

  // Remove title heading (# Title)
  cleaned = cleaned.replace(/^#\s+.+\s*\n*/m, '');

  // Remove ## Core Insight section (heading + following paragraph)
  cleaned = cleaned.replace(/## Core Insight\s*\n+[^\n#]+\s*\n*/g, '');

  // Remove template sections that shouldn't be in content
  cleaned = cleaned.replace(/## Key Concept Connection[\s\S]*?(?=##|$)/g, '');
  cleaned = cleaned.replace(/## Context & Background[\s\S]*?(?=##|$)/g, '');
  cleaned = cleaned.replace(/## Target Audience[\s\S]*?(?=##|$)/g, '');
  cleaned = cleaned.replace(/## Initial Thoughts[\s\S]*?(?=##|$)/g, '');
  cleaned = cleaned.replace(/## The Counterintuitive Angle[\s\S]*?(?=##|$)/g, '');
  cleaned = cleaned.replace(/## Related Ideas[\s\S]*?(?=##|$)/g, '');
  cleaned = cleaned.replace(/## Next Steps[\s\S]*?(?=##|$)/g, '');
  cleaned = cleaned.replace(/## Writing Checklist[\s\S]*?(?=##|$)/g, '');
  cleaned = cleaned.replace(/## LinkedIn Notes[\s\S]*?(?=##|$)/g, '');
  cleaned = cleaned.replace(/## Publication Details[\s\S]*?(?=##|$)/g, '');
  cleaned = cleaned.replace(/## Performance[\s\S]*?(?=##|$)/g, '');
  cleaned = cleaned.replace(/## Reflections[\s\S]*?(?=##|$)/g, '');

  // Remove horizontal rules
  cleaned = cleaned.replace(/^---+\s*$/gm, '');

  // Trim extra whitespace
  cleaned = cleaned.trim();

  return cleaned;
}

async function migrateFile(sourcePath, stage) {
  const filename = path.basename(sourcePath);

  try {
    // Read and parse
    const raw = await fs.readFile(sourcePath, 'utf-8');
    const { data: metadata, content } = matter(raw);

    // Extract or use existing values
    const extractedTitle = extractTitleFromContent(content);
    const extractedInsight = extractCoreInsightFromContent(content);

    // Use metadata title, or extracted, or filename
    const title = metadata.title && metadata.title.trim()
      ? metadata.title
      : extractedTitle || filename.replace(/^\d{4}-\d{2}-\d{2}-/, '').replace('.md', '');

    // Use metadata coreInsight or extracted
    const coreInsight = metadata.coreInsight && metadata.coreInsight.trim()
      ? metadata.coreInsight
      : extractedInsight || '';

    // Generate slug from metadata or filename
    let slug = metadata.slug && metadata.slug.trim() && !metadata.slug.includes(' ')
      ? metadata.slug
      : filename.replace(/^\d{4}-\d{2}-\d{2}-/, '').replace('.md', '');

    // Shorten very long slugs
    if (slug.length > 60) {
      slug = slug.substring(0, 60).replace(/-$/, '');
    }

    // Clean content
    const cleanedContent = cleanContent(content, extractedTitle);

    // Build YAML structure
    const yamlData = {
      stage: stage,
      type: metadata.type || 'linkedin-post',
      title: title,
      slug: slug,
      created: metadata.created || new Date().toISOString().split('T')[0],
      lastUpdated: metadata.lastUpdated || new Date().toISOString().split('T')[0],
      status: metadata.status || 'draft',
      coreInsight: coreInsight,
      tags: metadata.tags || [],
      feedbackLog: metadata.feedbackLog || [],
      content: cleanedContent
    };

    // Add optional fields if present
    if (metadata.audience) yamlData.audience = metadata.audience;
    if (metadata.keyMessage) yamlData.keyMessage = metadata.keyMessage;
    if (metadata.keyConcepts) yamlData.keyConcepts = metadata.keyConcepts;
    if (metadata.draftDate) yamlData.draftDate = metadata.draftDate;
    if (metadata.currentVersion) yamlData.currentVersion = metadata.currentVersion;
    if (metadata.publishedDate) yamlData.publishedDate = metadata.publishedDate;
    if (metadata.finalVersion) yamlData.finalVersion = metadata.finalVersion;
    if (metadata.channel) yamlData.channel = metadata.channel;
    if (metadata.url) yamlData.url = metadata.url;
    if (metadata.engagement !== undefined) yamlData.engagement = metadata.engagement;
    if (metadata.notes) yamlData.notes = metadata.notes;

    // Write YAML file
    const targetPath = path.join(POSTS_DIR, `${slug}.yaml`);
    const yamlContent = yaml.dump(yamlData, {
      lineWidth: -1,
      quotingType: '"',
      forceQuotes: false
    });

    await fs.writeFile(targetPath, yamlContent, 'utf-8');

    // Move images if they exist
    const stageImagesDir = path.join(CONTENT_DIR, stage, 'images', slug);
    const targetImagesDir = path.join(IMAGES_DIR, slug);

    try {
      await fs.access(stageImagesDir);
      await ensureDir(targetImagesDir);
      const images = await fs.readdir(stageImagesDir);
      for (const img of images) {
        await fs.rename(
          path.join(stageImagesDir, img),
          path.join(targetImagesDir, img)
        );
      }
      console.log(`  Moved ${images.length} images for ${slug}`);
    } catch {
      // No images
    }

    return {
      source: sourcePath,
      target: targetPath,
      slug,
      success: true
    };
  } catch (error) {
    return {
      source: sourcePath,
      target: '',
      slug: filename,
      success: false,
      error: error.message
    };
  }
}

async function migrate() {
  console.log('Starting migration to YAML format...\n');

  // Create target directories
  await ensureDir(POSTS_DIR);
  await ensureDir(IMAGES_DIR);

  const results = [];

  for (const stage of STAGES) {
    const stageDir = path.join(CONTENT_DIR, stage);

    try {
      const files = await fs.readdir(stageDir);
      const mdFiles = files.filter(f => f.endsWith('.md') && !f.includes('.suggestions'));

      console.log(`\n${stage}: ${mdFiles.length} files`);

      for (const file of mdFiles) {
        const sourcePath = path.join(stageDir, file);
        const result = await migrateFile(sourcePath, stage);
        results.push(result);

        if (result.success) {
          console.log(`  ✓ ${file} → ${result.slug}.yaml`);
        } else {
          console.log(`  ✗ ${file}: ${result.error}`);
        }
      }
    } catch (error) {
      console.log(`  Skipping ${stage}: directory not found or empty`);
    }
  }

  // Summary
  const successful = results.filter(r => r.success).length;
  const failed = results.filter(r => !r.success).length;

  console.log('\n--- Migration Summary ---');
  console.log(`Successful: ${successful}`);
  console.log(`Failed: ${failed}`);
  console.log(`\nFiles written to: ${POSTS_DIR}`);

  if (failed === 0 && successful > 0) {
    console.log('\nMigration complete! You can now:');
    console.log('1. Verify the YAML files in content/posts/');
    console.log('2. Delete the old stage folders (01-ideas, 02-drafts, 03-published)');
    console.log('3. Restart the content-studio dev server');
  }
}

// Run
migrate().catch(console.error);
