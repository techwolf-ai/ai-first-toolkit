'use client';

import { useState, useRef, useCallback, useMemo } from 'react';
import ReactMarkdown from 'react-markdown';
import PlatformPreview from './PlatformPreview';
import TextHighlighter from './TextHighlighter';
import { ContentType, ContentImage } from '@/types/content';

export type EditorMode = 'edit' | 'preview';

interface MarkdownEditorProps {
  content: string;
  onChange: (content: string) => void;
  mode?: EditorMode;
  onModeChange?: (mode: EditorMode) => void;
  // Platform preview props
  contentType?: ContentType;
  title?: string;
  coreInsight?: string;
  authorName?: string;
  authorTitle?: string;
  date?: string;
  images?: ContentImage[];
  slug?: string;
}

export default function MarkdownEditor({
  content,
  onChange,
  mode: controlledMode,
  onModeChange,
  contentType,
  title,
  coreInsight,
  authorName,
  authorTitle,
  date,
  images,
  slug
}: MarkdownEditorProps) {
  const [internalMode, setInternalMode] = useState<EditorMode>('edit');
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const highlightRef = useRef<HTMLDivElement>(null);
  const gutterRef = useRef<HTMLDivElement>(null);

  // Compute paragraph numbers (non-empty lines only)
  const paragraphNumbers = useMemo(() => {
    const lines = content.split('\n');
    let num = 0;
    return lines.map(line => {
      if (line.trim() === '') return null;
      num++;
      return num;
    });
  }, [content]);

  // Sync scroll between textarea, highlight layer, and gutter using CSS transforms
  // (GPU-accelerated, no frame delay compared to scrollTop sync)
  const handleScroll = useCallback(() => {
    if (textareaRef.current) {
      const scrollTop = textareaRef.current.scrollTop;
      const scrollLeft = textareaRef.current.scrollLeft;
      if (highlightRef.current) {
        highlightRef.current.style.transform = `translate(${-scrollLeft}px, ${-scrollTop}px)`;
      }
      if (gutterRef.current) {
        gutterRef.current.style.transform = `translateY(${-scrollTop}px)`;
      }
    }
  }, []);

  // Use controlled mode if provided, otherwise use internal state
  const mode = controlledMode !== undefined ? controlledMode : internalMode;
  const setMode = (newMode: EditorMode) => {
    if (onModeChange) {
      onModeChange(newMode);
    } else {
      setInternalMode(newMode);
    }
  };

  return (
    <div>
      {/* Toolbar - tabs at the top */}
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          paddingBottom: '1rem',
          marginBottom: '1.5rem',
          borderBottom: '1px solid var(--color-border)'
        }}
      >
        <div style={{ display: 'flex', gap: '0.25rem' }}>
          <button
            onClick={() => setMode('edit')}
            className="btn"
            style={{
              padding: '0.5rem 0.875rem',
              fontSize: '0.8125rem',
              background: mode === 'edit' ? 'var(--color-accent-subtle)' : 'transparent',
              color: mode === 'edit' ? 'var(--color-accent)' : 'var(--color-text-secondary)',
              fontWeight: mode === 'edit' ? 500 : 400
            }}
          >
            Edit
          </button>
          <button
            onClick={() => setMode('preview')}
            className="btn"
            style={{
              padding: '0.5rem 0.875rem',
              fontSize: '0.8125rem',
              background: mode === 'preview' ? 'var(--color-accent-subtle)' : 'transparent',
              color: mode === 'preview' ? 'var(--color-accent)' : 'var(--color-text-secondary)',
              fontWeight: mode === 'preview' ? 500 : 400
            }}
          >
            Preview
          </button>
        </div>
      </div>

      {/* Content Area */}
      {mode === 'edit' ? (
        <div>
          <label
            style={{
              display: 'block',
              fontSize: '0.75rem',
              fontWeight: 600,
              color: 'var(--color-text-muted)',
              marginBottom: '0.5rem',
              textTransform: 'uppercase',
              letterSpacing: '0.05em'
            }}
          >
            Content
          </label>
          {/* Editor container with highlight layer */}
          <div
            style={{
              position: 'relative',
              background: 'var(--color-bg)',
              borderRadius: '6px',
              border: '1px solid var(--color-border)'
            }}
          >
            {/* Highlight layer - positioned behind textarea */}
            <div
              style={{
                position: 'absolute',
                top: 0,
                left: 0,
                right: 0,
                bottom: 0,
                overflow: 'hidden',
                pointerEvents: 'none'
              }}
            >
              <div
                ref={highlightRef}
                style={{
                  padding: '0.75rem 1rem 0.75rem 3.5rem',
                  fontFamily: "'SF Mono', 'Fira Code', Consolas, monospace",
                  fontSize: '0.875rem',
                  lineHeight: 1.7,
                  willChange: 'transform'
                }}
              >
                <TextHighlighter
                  content={content}
                  style={{
                    fontFamily: "'SF Mono', 'Fira Code', Consolas, monospace",
                    fontSize: '0.875rem',
                    lineHeight: 1.7
                  }}
                />
              </div>
            </div>
            {/* Paragraph number gutter */}
            <div
              style={{
                position: 'absolute',
                top: 0,
                left: 0,
                right: 0,
                bottom: 0,
                overflow: 'hidden',
                pointerEvents: 'none',
                zIndex: 2
              }}
            >
              <div
                ref={gutterRef}
                style={{
                  padding: '0.75rem 1rem 0.75rem 3.5rem',
                  fontFamily: "'SF Mono', 'Fira Code', Consolas, monospace",
                  fontSize: '0.875rem',
                  lineHeight: 1.7,
                  willChange: 'transform'
                }}
              >
                <div style={{ whiteSpace: 'pre-wrap', wordWrap: 'break-word', overflowWrap: 'break-word' }}>
                  {content.split('\n').map((line, i) => (
                    <div key={i} style={{ position: 'relative' }}>
                      <span style={{ visibility: 'hidden' }}>{line || '\u00A0'}</span>
                      {paragraphNumbers[i] != null && (
                        <span
                          style={{
                            position: 'absolute',
                            top: 0,
                            left: '-2.75rem',
                            width: '2rem',
                            textAlign: 'right',
                            color: 'var(--color-text-muted)',
                            visibility: 'visible',
                            fontSize: '0.75rem',
                            opacity: 0.5
                          }}
                        >
                          {paragraphNumbers[i]}
                        </span>
                      )}
                    </div>
                  ))}
                </div>
              </div>
            </div>
            {/* Textarea - transparent background to show highlights */}
            <textarea
              ref={textareaRef}
              value={content}
              onChange={e => onChange(e.target.value)}
              onScroll={handleScroll}
              style={{
                width: '100%',
                minHeight: '500px',
                fontFamily: "'SF Mono', 'Fira Code', Consolas, monospace",
                fontSize: '0.875rem',
                lineHeight: 1.7,
                resize: 'vertical',
                background: 'transparent',
                position: 'relative',
                zIndex: 1,
                caretColor: 'var(--color-text)',
                color: 'var(--color-text)',
                border: 'none',
                outline: 'none',
                padding: '0.75rem 1rem 0.75rem 3.5rem'
              }}
              placeholder="Start writing your content..."
            />
          </div>
        </div>
      ) : (
        // Preview mode - show platform preview if type is set, otherwise generic markdown
        <div style={{ minHeight: '500px' }}>
          {contentType ? (
            <PlatformPreview
              content={content}
              title={title || ''}
              coreInsight={coreInsight}
              type={contentType}
              authorName={authorName}
              authorTitle={authorTitle}
              date={date}
              images={images}
              slug={slug}
            />
          ) : (
            <div
              className="prose"
              style={{
                minHeight: '500px',
                padding: '1rem',
                border: '1px solid var(--color-border)',
                borderRadius: '6px',
                background: 'var(--color-bg)'
              }}
            >
              {content ? (
                <ReactMarkdown>{content}</ReactMarkdown>
              ) : (
                <p style={{ color: 'var(--color-text-muted)' }}>No content yet</p>
              )}
            </div>
          )}
        </div>
      )}

      {/* Helper Text */}
      <div
        style={{
          marginTop: '1rem',
          fontSize: '0.75rem',
          color: 'var(--color-text-muted)'
        }}
      >
        <p>
          <strong>Tip:</strong> Use Markdown syntax for formatting. Headers start with #, lists with -, links with [text](url).
        </p>
        <p style={{ marginTop: '0.5rem' }}>
          <strong>Shortcuts:</strong> {typeof navigator !== 'undefined' && navigator.platform?.includes('Mac') ? 'Cmd' : 'Ctrl'}+S to save, {typeof navigator !== 'undefined' && navigator.platform?.includes('Mac') ? 'Cmd' : 'Ctrl'}+Shift+P to toggle preview, Esc to go back.
        </p>
      </div>
    </div>
  );
}
