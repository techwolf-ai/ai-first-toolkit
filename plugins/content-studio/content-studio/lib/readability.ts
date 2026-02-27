/**
 * Readability Score Utilities
 *
 * Implements Flesch-Kincaid Reading Ease score calculation
 * Formula: 206.835 - 1.015 * (words/sentences) - 84.6 * (syllables/words)
 */

/**
 * Count sentences in text by splitting on sentence-ending punctuation
 */
export function countSentences(text: string): number {
  // Remove markdown formatting that might interfere
  const cleanText = text
    .replace(/```[\s\S]*?```/g, '') // Remove code blocks
    .replace(/`[^`]+`/g, '')         // Remove inline code
    .replace(/\[([^\]]+)\]\([^)]+\)/g, '$1') // Convert links to text
    .replace(/#{1,6}\s+/g, '')       // Remove headers
    .replace(/[*_]{1,2}([^*_]+)[*_]{1,2}/g, '$1') // Remove bold/italic
    .trim();

  if (!cleanText) return 0;

  // Split by sentence-ending punctuation (. ! ?)
  // Account for abbreviations like "Mr." "Dr." etc. by requiring space or end after
  const sentences = cleanText.split(/[.!?]+(?:\s|$)/).filter(s => s.trim().length > 0);

  return Math.max(sentences.length, 1);
}

/**
 * Count syllables in a word using vowel group heuristic
 * - Count vowel groups (a, e, i, o, u, y)
 * - Subtract 1 for silent e at end
 * - Minimum 1 syllable per word
 */
export function countSyllables(word: string): number {
  const cleanWord = word.toLowerCase().replace(/[^a-z]/g, '');

  if (cleanWord.length === 0) return 0;
  if (cleanWord.length <= 2) return 1;

  // Count vowel groups
  const vowelGroups = cleanWord.match(/[aeiouy]+/g);
  let syllableCount = vowelGroups ? vowelGroups.length : 1;

  // Subtract for silent e at end (but not for words like "be", "he")
  if (cleanWord.endsWith('e') && cleanWord.length > 2 && !/[aeiouy]e$/i.test(cleanWord.slice(0, -1) + 'e')) {
    // Check if the 'e' is truly silent (preceded by consonant)
    const beforeE = cleanWord[cleanWord.length - 2];
    if (!/[aeiouy]/.test(beforeE)) {
      syllableCount = Math.max(syllableCount - 1, 1);
    }
  }

  // Handle common suffixes that add syllables
  if (cleanWord.endsWith('le') && cleanWord.length > 2) {
    const beforeLe = cleanWord[cleanWord.length - 3];
    if (/[^aeiouy]/.test(beforeLe)) {
      syllableCount = Math.max(syllableCount, 2);
    }
  }

  return Math.max(syllableCount, 1);
}

/**
 * Count total syllables in text
 */
export function countTotalSyllables(text: string): number {
  const words = extractWords(text);
  return words.reduce((total, word) => total + countSyllables(word), 0);
}

/**
 * Extract words from text, removing markdown formatting
 */
function extractWords(text: string): string[] {
  // Remove markdown formatting
  const cleanText = text
    .replace(/```[\s\S]*?```/g, '')   // Remove code blocks
    .replace(/`[^`]+`/g, '')           // Remove inline code
    .replace(/\[([^\]]+)\]\([^)]+\)/g, '$1') // Convert links to text
    .replace(/#{1,6}\s+/g, '')         // Remove headers
    .replace(/[*_]{1,2}([^*_]+)[*_]{1,2}/g, '$1') // Remove bold/italic
    .replace(/[^a-zA-Z\s]/g, ' ')      // Remove non-letter characters
    .trim();

  return cleanText.split(/\s+/).filter(word => word.length > 0);
}

/**
 * Calculate word count from text
 */
export function countWords(text: string): number {
  return extractWords(text).length;
}

/**
 * Calculate Flesch-Kincaid Reading Ease score
 *
 * Formula: 206.835 - 1.015 * (words/sentences) - 84.6 * (syllables/words)
 *
 * Score interpretation:
 * - 90-100: Very Easy (5th grade)
 * - 80-89: Easy (6th grade)
 * - 70-79: Fairly Easy (7th grade)
 * - 60-69: Standard (8th-9th grade)
 * - 50-59: Fairly Difficult (10th-12th grade)
 * - 30-49: Difficult (College)
 * - 0-29: Very Difficult (College graduate)
 */
export function calculateReadability(text: string): number {
  const words = extractWords(text);
  const wordCount = words.length;

  if (wordCount === 0) return 0;

  const sentenceCount = countSentences(text);
  const syllableCount = words.reduce((total, word) => total + countSyllables(word), 0);

  const wordsPerSentence = wordCount / sentenceCount;
  const syllablesPerWord = syllableCount / wordCount;

  const score = 206.835 - (1.015 * wordsPerSentence) - (84.6 * syllablesPerWord);

  // Clamp to 0-100 range
  return Math.round(Math.max(0, Math.min(100, score)));
}

/**
 * Get readability label based on score
 */
export function getReadabilityLabel(score: number): string {
  if (score >= 60) return 'Easy';
  if (score >= 30) return 'Moderate';
  return 'Difficult';
}

/**
 * Get readability color based on score
 * - Green (60-100): Easy to read
 * - Yellow (30-59): Moderate
 * - Red (0-29): Difficult
 */
export function getReadabilityColor(score: number): string {
  if (score >= 60) return '#22c55e'; // Green
  if (score >= 30) return '#eab308'; // Yellow
  return '#ef4444'; // Red
}

/**
 * Get full readability info
 */
export interface ReadabilityInfo {
  score: number;
  label: string;
  color: string;
}

export function getReadabilityInfo(text: string): ReadabilityInfo {
  const score = calculateReadability(text);
  return {
    score,
    label: getReadabilityLabel(score),
    color: getReadabilityColor(score)
  };
}

/**
 * Get detailed explanation of the readability score
 */
export function getReadabilityExplanation(text: string): {
  score: number;
  label: string;
  wordsPerSentence: number;
  syllablesPerWord: number;
  totalWords: number;
  totalSentences: number;
  interpretation: string;
  suggestions: string[];
} {
  const words = text
    .replace(/```[\s\S]*?```/g, '')
    .replace(/`[^`]+`/g, '')
    .replace(/\[([^\]]+)\]\([^)]+\)/g, '$1')
    .replace(/#{1,6}\s+/g, '')
    .replace(/[*_]{1,2}([^*_]+)[*_]{1,2}/g, '$1')
    .replace(/[^a-zA-Z\s]/g, ' ')
    .trim()
    .split(/\s+/)
    .filter(w => w.length > 0);

  const wordCount = words.length;
  const sentenceCount = countSentences(text);
  const syllableCount = words.reduce((total, word) => total + countSyllables(word), 0);

  const wordsPerSentence = wordCount / Math.max(sentenceCount, 1);
  const syllablesPerWord = syllableCount / Math.max(wordCount, 1);
  const score = calculateReadability(text);
  const label = getReadabilityLabel(score);

  // Generate interpretation
  let interpretation = '';
  if (score >= 70) {
    interpretation = 'Very readable. Easy for most audiences.';
  } else if (score >= 60) {
    interpretation = 'Good readability. Clear for general audiences.';
  } else if (score >= 50) {
    interpretation = 'Moderate. May require some attention from readers.';
  } else if (score >= 30) {
    interpretation = 'Challenging. Best for educated/technical audiences.';
  } else {
    interpretation = 'Difficult. Consider simplifying for broader reach.';
  }

  // Generate suggestions
  const suggestions: string[] = [];
  if (wordsPerSentence > 20) {
    suggestions.push(`Average sentence length is ${wordsPerSentence.toFixed(1)} words. Try breaking up sentences longer than 20 words.`);
  }
  if (syllablesPerWord > 1.6) {
    suggestions.push(`Many complex words (${syllablesPerWord.toFixed(2)} syllables/word avg). Consider simpler alternatives.`);
  }
  if (suggestions.length === 0 && score < 60) {
    suggestions.push('Try shorter sentences and simpler word choices.');
  }
  if (score >= 60) {
    suggestions.push('Readability is good for LinkedIn content.');
  }

  return {
    score,
    label,
    wordsPerSentence: Math.round(wordsPerSentence * 10) / 10,
    syllablesPerWord: Math.round(syllablesPerWord * 100) / 100,
    totalWords: wordCount,
    totalSentences: sentenceCount,
    interpretation,
    suggestions
  };
}

/**
 * Analyze individual sentences for readability issues
 */
export interface SentenceAnalysis {
  text: string;
  wordCount: number;
  avgSyllables: number;
  score: 'good' | 'warning' | 'problem';
  issues: string[];
}

export function analyzeSentences(text: string): SentenceAnalysis[] {
  // Clean markdown but preserve sentence structure
  const cleanText = text
    .replace(/```[\s\S]*?```/g, '')
    .replace(/`[^`]+`/g, '')
    .replace(/\[([^\]]+)\]\([^)]+\)/g, '$1')
    .replace(/#{1,6}\s+/g, '')
    .replace(/[*_]{1,2}([^*_]+)[*_]{1,2}/g, '$1')
    .trim();

  if (!cleanText) return [];

  // Split into sentences
  const sentences = cleanText
    .split(/(?<=[.!?])\s+/)
    .map(s => s.trim())
    .filter(s => s.length > 0);

  return sentences.map(sentence => {
    const words = sentence
      .replace(/[^a-zA-Z\s]/g, ' ')
      .split(/\s+/)
      .filter(w => w.length > 0);

    const wordCount = words.length;
    const syllableCount = words.reduce((total, word) => total + countSyllables(word), 0);
    const avgSyllables = wordCount > 0 ? syllableCount / wordCount : 0;

    const issues: string[] = [];
    let score: 'good' | 'warning' | 'problem' = 'good';

    // Check for long sentences
    if (wordCount > 30) {
      issues.push(`Very long (${wordCount} words)`);
      score = 'problem';
    } else if (wordCount > 20) {
      issues.push(`Long sentence (${wordCount} words)`);
      score = 'warning';
    }

    // Check for complex words
    if (avgSyllables > 2) {
      issues.push(`Complex words (${avgSyllables.toFixed(1)} syllables avg)`);
      score = 'problem';
    } else if (avgSyllables > 1.7) {
      issues.push(`Some complex words`);
      if (score !== 'problem') score = 'warning';
    }

    // Find specific long words (4+ syllables)
    const longWords = words.filter(w => countSyllables(w) >= 4);
    if (longWords.length > 0) {
      issues.push(`Complex: ${longWords.slice(0, 3).join(', ')}${longWords.length > 3 ? '...' : ''}`);
    }

    return {
      text: sentence,
      wordCount,
      avgSyllables: Math.round(avgSyllables * 100) / 100,
      score,
      issues
    };
  });
}
