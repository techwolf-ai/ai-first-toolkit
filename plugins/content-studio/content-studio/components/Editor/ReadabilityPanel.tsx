'use client';

import { useState, useMemo } from 'react';
import { getReadabilityExplanation, analyzeSentences, SentenceAnalysis } from '@/lib/readability';

interface ReadabilityPanelProps {
  content: string;
  isOpen: boolean;
  onClose: () => void;
}

export default function ReadabilityPanel({ content, isOpen, onClose }: ReadabilityPanelProps) {
  const [expandedSection, setExpandedSection] = useState<'problems' | 'warnings' | 'good' | null>('problems');

  const explanation = useMemo(() => getReadabilityExplanation(content), [content]);
  const sentences = useMemo(() => analyzeSentences(content), [content]);

  const problemSentences = sentences.filter(s => s.score === 'problem');
  const warningSentences = sentences.filter(s => s.score === 'warning');
  const goodSentences = sentences.filter(s => s.score === 'good');

  if (!isOpen) return null;

  const getScoreColor = (score: number) => {
    if (score >= 60) return '#22c55e';
    if (score >= 30) return '#f59e0b';
    return '#ef4444';
  };

  return (
    <div
      style={{
        position: 'fixed',
        top: 0,
        right: 0,
        width: '380px',
        height: '100vh',
        background: 'var(--color-bg)',
        borderLeft: '1px solid var(--color-border)',
        boxShadow: '-8px 0 30px rgba(0,0,0,0.08)',
        zIndex: 100,
        display: 'flex',
        flexDirection: 'column',
        overflow: 'hidden'
      }}
    >
      {/* Header */}
      <div
        style={{
          padding: '1.25rem 1.5rem',
          borderBottom: '1px solid var(--color-border)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          background: 'var(--color-bg-elevated)'
        }}
      >
        <h2 style={{
          fontSize: '0.9375rem',
          fontWeight: 600,
          color: 'var(--color-text)',
          letterSpacing: '-0.01em'
        }}>
          Readability
        </h2>
        <button
          onClick={onClose}
          style={{
            background: 'var(--color-bg-subtle)',
            border: 'none',
            cursor: 'pointer',
            padding: '0.375rem 0.625rem',
            color: 'var(--color-text-muted)',
            fontSize: '0.75rem',
            borderRadius: '4px',
            fontWeight: 500
          }}
        >
          Close
        </button>
      </div>

      {/* Content */}
      <div style={{ flex: 1, overflow: 'auto' }}>
        {/* Score Card */}
        <div style={{ padding: '1.5rem', borderBottom: '1px solid var(--color-border)' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '1.25rem' }}>
            {/* Score Circle */}
            <div
              style={{
                width: '72px',
                height: '72px',
                borderRadius: '50%',
                background: `conic-gradient(${getScoreColor(explanation.score)} ${explanation.score * 3.6}deg, var(--color-border) 0deg)`,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                flexShrink: 0
              }}
            >
              <div
                style={{
                  width: '58px',
                  height: '58px',
                  borderRadius: '50%',
                  background: 'var(--color-bg)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  flexDirection: 'column'
                }}
              >
                <span style={{
                  fontWeight: 700,
                  fontSize: '1.5rem',
                  color: getScoreColor(explanation.score),
                  lineHeight: 1
                }}>
                  {explanation.score}
                </span>
              </div>
            </div>

            <div style={{ flex: 1 }}>
              <div style={{
                fontWeight: 600,
                fontSize: '1rem',
                color: 'var(--color-text)',
                marginBottom: '0.25rem'
              }}>
                {explanation.label}
              </div>
              <div style={{
                fontSize: '0.8125rem',
                color: 'var(--color-text-secondary)',
                lineHeight: 1.4
              }}>
                {explanation.interpretation}
              </div>
            </div>
          </div>

          {/* Quick Stats */}
          <div
            style={{
              display: 'flex',
              gap: '1.5rem',
              marginTop: '1.25rem',
              paddingTop: '1.25rem',
              borderTop: '1px solid var(--color-border)'
            }}
          >
            <Stat
              label="Words/sent"
              value={explanation.wordsPerSentence}
              warning={explanation.wordsPerSentence > 20}
            />
            <Stat
              label="Syllables/word"
              value={explanation.syllablesPerWord}
              warning={explanation.syllablesPerWord > 1.6}
            />
            <Stat
              label="Sentences"
              value={explanation.totalSentences}
            />
          </div>
        </div>

        {/* Sentence Sections */}
        <div style={{ padding: '0.5rem 0' }}>
          {/* Problems */}
          <SentenceSection
            title="Needs work"
            count={problemSentences.length}
            color="#ef4444"
            bgColor="rgba(239, 68, 68, 0.08)"
            sentences={problemSentences}
            isExpanded={expandedSection === 'problems'}
            onToggle={() => setExpandedSection(expandedSection === 'problems' ? null : 'problems')}
          />

          {/* Warnings */}
          <SentenceSection
            title="Could simplify"
            count={warningSentences.length}
            color="#f59e0b"
            bgColor="rgba(245, 158, 11, 0.08)"
            sentences={warningSentences}
            isExpanded={expandedSection === 'warnings'}
            onToggle={() => setExpandedSection(expandedSection === 'warnings' ? null : 'warnings')}
          />

          {/* Good */}
          <SentenceSection
            title="Good"
            count={goodSentences.length}
            color="#22c55e"
            bgColor="rgba(34, 197, 94, 0.08)"
            sentences={goodSentences}
            isExpanded={expandedSection === 'good'}
            onToggle={() => setExpandedSection(expandedSection === 'good' ? null : 'good')}
          />
        </div>

        {/* Score Guide */}
        <div
          style={{
            margin: '0.5rem 1.5rem 1.5rem',
            padding: '1rem',
            background: 'var(--color-bg-subtle)',
            borderRadius: '8px'
          }}
        >
          <div style={{
            fontSize: '0.6875rem',
            fontWeight: 600,
            color: 'var(--color-text-muted)',
            textTransform: 'uppercase',
            letterSpacing: '0.05em',
            marginBottom: '0.625rem'
          }}>
            Flesch-Kincaid Scale
          </div>
          <div style={{ fontSize: '0.8125rem', color: 'var(--color-text-secondary)', lineHeight: 1.7 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
              <span style={{ width: '8px', height: '8px', borderRadius: '50%', background: '#22c55e' }} />
              <span><strong>60+</strong> Easy — ideal for LinkedIn</span>
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
              <span style={{ width: '8px', height: '8px', borderRadius: '50%', background: '#f59e0b' }} />
              <span><strong>30-59</strong> Moderate complexity</span>
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
              <span style={{ width: '8px', height: '8px', borderRadius: '50%', background: '#ef4444' }} />
              <span><strong>0-29</strong> Difficult — academic level</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function Stat({ label, value, warning }: { label: string; value: number; warning?: boolean }) {
  return (
    <div>
      <div style={{
        fontSize: '0.6875rem',
        color: 'var(--color-text-muted)',
        textTransform: 'uppercase',
        letterSpacing: '0.03em',
        marginBottom: '0.25rem'
      }}>
        {label}
      </div>
      <div style={{
        fontSize: '1.125rem',
        fontWeight: 600,
        color: warning ? '#f59e0b' : 'var(--color-text)'
      }}>
        {value}
      </div>
    </div>
  );
}

function SentenceSection({
  title,
  count,
  color,
  bgColor,
  sentences,
  isExpanded,
  onToggle
}: {
  title: string;
  count: number;
  color: string;
  bgColor: string;
  sentences: SentenceAnalysis[];
  isExpanded: boolean;
  onToggle: () => void;
}) {
  if (count === 0) return null;

  return (
    <div style={{ borderBottom: '1px solid var(--color-border)' }}>
      <button
        onClick={onToggle}
        style={{
          width: '100%',
          padding: '0.875rem 1.5rem',
          background: 'none',
          border: 'none',
          cursor: 'pointer',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          textAlign: 'left'
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.625rem' }}>
          <span style={{
            width: '10px',
            height: '10px',
            borderRadius: '50%',
            background: color
          }} />
          <span style={{
            fontSize: '0.875rem',
            fontWeight: 500,
            color: 'var(--color-text)'
          }}>
            {title}
          </span>
          <span style={{
            fontSize: '0.75rem',
            color: 'var(--color-text-muted)',
            background: 'var(--color-bg-subtle)',
            padding: '0.125rem 0.5rem',
            borderRadius: '10px'
          }}>
            {count}
          </span>
        </div>
        <svg
          width="16"
          height="16"
          viewBox="0 0 16 16"
          fill="none"
          stroke="var(--color-text-muted)"
          strokeWidth="1.5"
          style={{
            transform: isExpanded ? 'rotate(180deg)' : 'rotate(0deg)',
            transition: 'transform 0.2s'
          }}
        >
          <path d="M4 6L8 10L12 6" strokeLinecap="round" strokeLinejoin="round"/>
        </svg>
      </button>

      {isExpanded && (
        <div style={{ padding: '0 1.5rem 1rem' }}>
          {sentences.map((sentence, i) => (
            <div
              key={i}
              style={{
                padding: '0.75rem 1rem',
                marginBottom: '0.5rem',
                background: bgColor,
                borderRadius: '6px',
                borderLeft: `3px solid ${color}`
              }}
            >
              <p style={{
                fontSize: '0.875rem',
                color: 'var(--color-text)',
                lineHeight: 1.55,
                margin: 0
              }}>
                {sentence.text}
              </p>
              {sentence.issues.length > 0 && (
                <p style={{
                  fontSize: '0.75rem',
                  color: color,
                  marginTop: '0.5rem',
                  marginBottom: 0,
                  fontWeight: 500
                }}>
                  {sentence.issues[0]}
                </p>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
