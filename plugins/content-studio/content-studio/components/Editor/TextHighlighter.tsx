'use client';

import { useMemo } from 'react';
import { analyzeSentences } from '@/lib/readability';

interface TextHighlighterProps {
  content: string;
  style?: React.CSSProperties;
}

export default function TextHighlighter({ content, style }: TextHighlighterProps) {
  const highlightedContent = useMemo(() => {
    if (!content) return null;

    const sentences = analyzeSentences(content);

    // Build a map of sentence text to their score
    const sentenceScores = new Map<string, 'good' | 'warning' | 'problem'>();
    sentences.forEach(s => {
      // Normalize the sentence text for matching
      sentenceScores.set(s.text.trim(), s.score);
    });

    // Split content into parts and highlight sentences
    const parts: { text: string; score: 'good' | 'warning' | 'problem' | null }[] = [];

    // Simple approach: split by sentence boundaries and match
    let remaining = content;

    for (const sentence of sentences) {
      const sentenceText = sentence.text;
      const idx = remaining.indexOf(sentenceText.split('.')[0]); // Find start of sentence

      if (idx > 0) {
        // Add text before this sentence (whitespace, etc.)
        parts.push({ text: remaining.substring(0, idx), score: null });
      }

      if (idx >= 0) {
        // Find the full sentence including punctuation
        const fullSentenceEnd = remaining.indexOf(sentenceText) + sentenceText.length;
        if (fullSentenceEnd > idx) {
          const fullSentence = remaining.substring(idx, fullSentenceEnd);
          parts.push({ text: fullSentence, score: sentence.score });
          remaining = remaining.substring(fullSentenceEnd);
        }
      }
    }

    // Add any remaining text
    if (remaining) {
      parts.push({ text: remaining, score: null });
    }

    return parts;
  }, [content]);

  // Simpler approach: just highlight the whole text with sentence analysis
  const simpleHighlight = useMemo(() => {
    if (!content) return [];

    const sentences = analyzeSentences(content);
    const result: { text: string; score: 'good' | 'warning' | 'problem' | null }[] = [];

    let processedLength = 0;

    for (const sentence of sentences) {
      // Find this sentence in the original content
      const searchStart = processedLength;
      const sentenceStart = content.indexOf(sentence.text, searchStart);

      if (sentenceStart === -1) continue;

      // Add any text before this sentence (whitespace, newlines)
      if (sentenceStart > processedLength) {
        result.push({
          text: content.substring(processedLength, sentenceStart),
          score: null
        });
      }

      // Add the sentence with its score
      result.push({
        text: sentence.text,
        score: sentence.score
      });

      processedLength = sentenceStart + sentence.text.length;
    }

    // Add any remaining text
    if (processedLength < content.length) {
      result.push({
        text: content.substring(processedLength),
        score: null
      });
    }

    return result;
  }, [content]);

  const getHighlightStyle = (score: 'good' | 'warning' | 'problem' | null): React.CSSProperties => {
    switch (score) {
      case 'problem':
        return {
          backgroundColor: 'rgba(239, 68, 68, 0.15)',
          borderRadius: '2px',
          boxDecorationBreak: 'clone' as const
        };
      case 'warning':
        return {
          backgroundColor: 'rgba(245, 158, 11, 0.12)',
          borderRadius: '2px',
          boxDecorationBreak: 'clone' as const
        };
      default:
        return {};
    }
  };

  return (
    <div
      style={{
        ...style,
        pointerEvents: 'none',
        whiteSpace: 'pre-wrap',
        wordWrap: 'break-word',
        overflowWrap: 'break-word',
        color: 'transparent'
      }}
      aria-hidden="true"
    >
      {simpleHighlight.map((part, i) => (
        <span key={i} style={getHighlightStyle(part.score)}>
          {part.text}
        </span>
      ))}
    </div>
  );
}
