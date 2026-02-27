'use client';

import { use, useEffect, useState, useRef, useCallback, useMemo } from 'react';
import { ContentFile, ContentMetadata, ContentType } from '@/types/content';
import MarkdownEditor, { EditorMode } from '@/components/Editor/MarkdownEditor';
import MetadataPanel from '@/components/Editor/MetadataPanel';
import { ContentImage } from '@/types/content';
import { getReadabilityInfo } from '@/lib/readability';
import ThemeToggle from '@/components/ThemeToggle/ThemeToggle';
import ReadabilityPanel from '@/components/Editor/ReadabilityPanel';

interface EditorPageProps {
  params: Promise<{
    type: string;
    slug: string;
  }>;
}

export default function EditorPage({ params }: EditorPageProps) {
  const { type, slug } = use(params);

  const [content, setContent] = useState<ContentFile | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [lastSaved, setLastSaved] = useState<Date | null>(null);
  const [uploading, setUploading] = useState(false);
  const [editorMode, setEditorMode] = useState<EditorMode>('edit');
  const [showReadabilityPanel, setShowReadabilityPanel] = useState(false);
  const [exporting, setExporting] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const lastKnownUpdate = useRef<string | null>(null);
  const lastSavedSnapshot = useRef<string | null>(null);

  // Create a snapshot of content for comparison (excludes lastUpdated)
  function createSnapshot(contentFile: ContentFile): string {
    const { lastUpdated, ...metadataWithoutTimestamp } = contentFile.metadata;
    return JSON.stringify({ metadata: metadataWithoutTimestamp, content: contentFile.content });
  }

  // Calculate word count, character count, and reading time
  function getWordCount(text: string): number {
    return text.split(/\s+/).filter(word => word.length > 0).length;
  }

  function getCharCount(text: string): number {
    return text.length;
  }

  const wordCount = content ? getWordCount(content.content) : 0;
  const charCount = content ? getCharCount(content.content) : 0;
  const readingTime = Math.ceil(wordCount / 200);

  // Calculate readability score (memoized for performance)
  const readability = useMemo(() => {
    if (!content || !content.content) {
      return { score: 0, label: 'N/A', color: '#9c9691' };
    }
    return getReadabilityInfo(content.content);
  }, [content?.content]);

  // Check if there are unsaved changes
  const hasUnsavedChanges = useCallback(() => {
    if (!content || lastSavedSnapshot.current === null) return false;
    return createSnapshot(content) !== lastSavedSnapshot.current;
  }, [content]);

  useEffect(() => {
    loadContent();
  }, [type, slug]);

  // Warn before leaving with unsaved changes
  useEffect(() => {
    function handleBeforeUnload(e: BeforeUnloadEvent) {
      if (hasUnsavedChanges()) {
        e.preventDefault();
        e.returnValue = '';
        return '';
      }
    }

    window.addEventListener('beforeunload', handleBeforeUnload);
    return () => window.removeEventListener('beforeunload', handleBeforeUnload);
  }, [hasUnsavedChanges]);

  // Auto-save every 30 seconds
  useEffect(() => {
    const interval = setInterval(() => {
      if (content) {
        handleSave();
      }
    }, 30000);

    return () => clearInterval(interval);
  }, [content]);

  // Poll for external file changes every 2 seconds
  useEffect(() => {
    const pollInterval = setInterval(async () => {
      if (saving) return; // Don't poll while saving

      try {
        const res = await fetch(`/api/content/${type}/${slug}`);
        const data = await res.json();

        if (data.success && data.data) {
          const serverLastUpdated = data.data.metadata.lastUpdated;

          // If this is the first poll, just store the timestamp
          if (lastKnownUpdate.current === null) {
            lastKnownUpdate.current = serverLastUpdated;
            return;
          }

          // If server has a newer version, update the content
          if (serverLastUpdated !== lastKnownUpdate.current) {
            lastKnownUpdate.current = serverLastUpdated;
            setContent(data.data);
            // Update snapshot so we don't detect this as a local change
            lastSavedSnapshot.current = createSnapshot(data.data);
          }
        }
      } catch (error) {
        // Silently ignore polling errors
      }
    }, 2000);

    return () => clearInterval(pollInterval);
  }, [type, slug, saving]);

  // Toggle between edit and preview modes
  const togglePreviewMode = useCallback(() => {
    setEditorMode(prev => prev === 'edit' ? 'preview' : 'edit');
  }, []);

  // Navigate back to dashboard
  const goBack = useCallback(() => {
    if (hasUnsavedChanges()) {
      if (!confirm('You have unsaved changes. Are you sure you want to leave?')) {
        return;
      }
    }
    window.location.href = '/';
  }, [hasUnsavedChanges]);

  // Keyboard shortcuts
  useEffect(() => {
    function handleKeyDown(e: KeyboardEvent) {
      const isMac = navigator.platform.toUpperCase().indexOf('MAC') >= 0;
      const modifierKey = isMac ? e.metaKey : e.ctrlKey;

      // Cmd/Ctrl+S: Save
      if (modifierKey && e.key === 's') {
        e.preventDefault();
        if (content) {
          handleSave();
        }
        return;
      }

      // Cmd/Ctrl+Shift+P: Toggle preview mode
      if (modifierKey && e.shiftKey && e.key.toLowerCase() === 'p') {
        e.preventDefault();
        togglePreviewMode();
        return;
      }

      // Escape: Go back to dashboard
      if (e.key === 'Escape') {
        e.preventDefault();
        goBack();
        return;
      }
    }

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [content, togglePreviewMode, goBack]);

  async function loadContent() {
    try {
      const res = await fetch(`/api/content/${type}/${slug}`);
      const data = await res.json();

      if (data.success) {
        setContent(data.data);
        // Store initial snapshot for change detection
        lastSavedSnapshot.current = createSnapshot(data.data);
      }
    } catch (error) {
      console.error('Error loading content:', error);
    } finally {
      setLoading(false);
    }
  }

  async function handleSave() {
    if (!content) return;

    // Check if content has actually changed
    const currentSnapshot = createSnapshot(content);
    if (currentSnapshot === lastSavedSnapshot.current) {
      return; // No changes, skip save
    }

    setSaving(true);
    try {
      const res = await fetch(`/api/content/${type}/${slug}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          metadata: content.metadata,
          content: content.content
        })
      });

      if (res.ok) {
        setLastSaved(new Date());
        // Update snapshot after successful save
        lastSavedSnapshot.current = currentSnapshot;
        // Update lastKnownUpdate to avoid detecting our own save as external change
        const data = await res.json();
        if (data.lastUpdated) {
          lastKnownUpdate.current = data.lastUpdated;
        }
      }
    } catch (error) {
      console.error('Error saving content:', error);
    } finally {
      setSaving(false);
    }
  }

  function updateMetadata(metadata: ContentMetadata) {
    if (content) {
      setContent({ ...content, metadata });
    }
  }

  function updateContent(newContent: string) {
    if (content) {
      setContent({ ...content, content: newContent });
    }
  }

  async function handleImageUpload(e: React.ChangeEvent<HTMLInputElement>) {
    const files = e.target.files;
    if (!files || files.length === 0 || !content) return;

    setUploading(true);
    const newImages: ContentImage[] = [];

    try {
      for (const file of Array.from(files)) {
        const formData = new FormData();
        formData.append('file', file);
        formData.append('type', type);
        formData.append('slug', slug);

        const res = await fetch('/api/upload', {
          method: 'POST',
          body: formData
        });

        const data = await res.json();
        if (data.success) {
          newImages.push({
            path: data.data.path,
            filename: data.data.filename,
            alt: ''
          });
        } else {
          console.error(`Upload failed for ${file.name}: ${data.error}`);
        }
      }

      if (newImages.length > 0) {
        const existingImages = content.metadata.images || [];
        updateMetadata({
          ...content.metadata,
          images: [...existingImages, ...newImages]
        });
      }

      if (newImages.length < files.length) {
        alert(`${files.length - newImages.length} image(s) failed to upload`);
      }
    } catch (error) {
      console.error('Upload error:', error);
      alert('Failed to upload images');
    } finally {
      setUploading(false);
      if (fileInputRef.current) {
        fileInputRef.current.value = '';
      }
    }
  }

  function removeImage(index: number) {
    if (!content) return;
    const images = [...(content.metadata.images || [])];
    images.splice(index, 1);
    updateMetadata({ ...content.metadata, images });
  }

  async function handleExportPDF() {
    setExporting(true);
    try {
      const res = await fetch(`/api/content/${type}/${slug}/export`);
      if (!res.ok) {
        throw new Error('Export failed');
      }

      // Get the blob and trigger download
      const blob = await res.blob();
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `${slug}-${content?.metadata.stage.replace(/^\d+-/, '')}.pdf`;
      document.body.appendChild(a);
      a.click();
      window.URL.revokeObjectURL(url);
      document.body.removeChild(a);
    } catch (error) {
      console.error('Error exporting PDF:', error);
      alert('Failed to export PDF');
    } finally {
      setExporting(false);
    }
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-screen" style={{ background: 'var(--color-bg)' }}>
        <div className="animate-fade-in" style={{ color: 'var(--color-text-muted)' }}>
          Loading...
        </div>
      </div>
    );
  }

  if (!content) {
    return (
      <div className="flex items-center justify-center min-h-screen" style={{ background: 'var(--color-bg)' }}>
        <div style={{ color: 'var(--color-text-muted)' }}>Content not found</div>
      </div>
    );
  }

  return (
    <div className="h-screen flex flex-col" style={{ background: 'var(--color-bg)' }}>
      {/* Header */}
      <header
        className="animate-slide-up"
        style={{
          background: 'var(--color-bg-elevated)',
          borderBottom: '1px solid var(--color-border)',
          padding: '1rem 1.5rem'
        }}
      >
        <div className="flex items-center justify-between gap-6">
          <div className="flex items-center gap-4 flex-1 min-w-0">
            <button
              onClick={goBack}
              className="btn btn-ghost shrink-0"
              style={{ padding: '0.5rem 0.75rem' }}
            >
              <svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5">
                <path d="M10 12L6 8L10 4" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
              Back
            </button>

            <h1
              style={{
                fontFamily: "'Newsreader', Georgia, serif",
                fontSize: '1.25rem',
                fontWeight: 500,
                color: 'var(--color-text)',
                letterSpacing: '-0.01em',
                flex: 1,
                overflow: 'hidden',
                textOverflow: 'ellipsis',
                whiteSpace: 'nowrap'
              }}
            >
              {content.metadata.title || 'Untitled'}
            </h1>

            {/* Word count, character count, reading time */}
            <span style={{ fontSize: '0.75rem', color: 'var(--color-text-muted)', whiteSpace: 'nowrap' }}>
              {wordCount} words · {charCount.toLocaleString()} chars · {readingTime} min read
            </span>

            {/* Readability score - clickable */}
            <button
              onClick={() => setShowReadabilityPanel(true)}
              style={{
                fontSize: '0.75rem',
                whiteSpace: 'nowrap',
                display: 'flex',
                alignItems: 'center',
                gap: '0.375rem',
                background: 'none',
                border: 'none',
                cursor: 'pointer',
                padding: '0.25rem 0.5rem',
                borderRadius: '4px',
                transition: 'background 0.15s'
              }}
              onMouseEnter={(e) => { e.currentTarget.style.background = 'var(--color-bg-subtle)'; }}
              onMouseLeave={(e) => { e.currentTarget.style.background = 'none'; }}
              title="Click for detailed readability analysis"
            >
              <span
                style={{
                  width: '8px',
                  height: '8px',
                  borderRadius: '50%',
                  backgroundColor: readability.color,
                  display: 'inline-block'
                }}
              />
              <span style={{ color: 'var(--color-text-secondary)' }}>
                Readability: {readability.score} ({readability.label})
              </span>
            </button>

            {/* Save status */}
            <span style={{ fontSize: '0.75rem', color: 'var(--color-text-muted)', whiteSpace: 'nowrap' }}>
              {saving ? (
                <span style={{ color: 'var(--color-accent)' }}>Saving...</span>
              ) : lastSaved ? (
                `Saved ${lastSaved.toLocaleTimeString()}`
              ) : (
                'Not saved'
              )}
            </span>
          </div>

          <div className="flex items-center gap-3">
            <ThemeToggle />
            <button
              onClick={handleExportPDF}
              disabled={exporting}
              className="btn btn-secondary shrink-0"
              title="Export as PDF for review"
            >
              {exporting ? 'Exporting...' : 'Export PDF'}
            </button>
            <button
              onClick={handleSave}
              disabled={saving}
              className="btn btn-primary shrink-0"
            >
              {saving ? 'Saving...' : 'Save'}
            </button>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <div className="flex-1 flex overflow-hidden">
        {/* Metadata Panel */}
        <aside
          className="w-64 overflow-y-auto animate-slide-in"
          style={{
            background: 'var(--color-bg-elevated)',
            borderRight: '1px solid var(--color-border)'
          }}
        >
          <MetadataPanel
            metadata={content.metadata}
            onChange={updateMetadata}
          />
        </aside>

        {/* Editor */}
        <main className="flex-1 overflow-y-auto" style={{ padding: '2rem' }}>
          <div
            className="card animate-slide-up"
            style={{
              maxWidth: '52rem',
              margin: '0 auto',
              padding: '2rem'
            }}
          >
            {/* Title Field */}
            <div style={{ marginBottom: '1.5rem' }}>
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
                Title
              </label>
              <input
                type="text"
                value={content.metadata.title || ''}
                onChange={e => updateMetadata({ ...content.metadata, title: e.target.value })}
                className="input"
                style={{
                  fontSize: '1.25rem',
                  fontFamily: "'Newsreader', Georgia, serif",
                  fontWeight: 500,
                  padding: '0.75rem 1rem'
                }}
                placeholder="Enter title..."
              />
            </div>

            {/* Core Insight Field */}
            <div style={{ marginBottom: '1.5rem' }}>
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
                Core Insight
              </label>
              <textarea
                value={content.metadata.coreInsight || ''}
                onChange={e => updateMetadata({ ...content.metadata, coreInsight: e.target.value })}
                className="input"
                style={{
                  fontSize: '0.9375rem',
                  minHeight: '5rem',
                  resize: 'vertical',
                  lineHeight: 1.6
                }}
                placeholder="What's the non-obvious thing you want people to understand?"
              />
            </div>

            <MarkdownEditor
              content={content.content}
              onChange={updateContent}
              mode={editorMode}
              onModeChange={setEditorMode}
              contentType={content.metadata.type}
              title={content.metadata.title}
              coreInsight={content.metadata.coreInsight}
              date={content.metadata.created}
              images={content.metadata.images}
              slug={slug}
            />

            {/* Images Section */}
            <div style={{ marginTop: '2rem' }}>
              <div
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  marginBottom: '1rem'
                }}
              >
                <label
                  style={{
                    fontSize: '0.75rem',
                    fontWeight: 600,
                    color: 'var(--color-text-muted)',
                    textTransform: 'uppercase',
                    letterSpacing: '0.05em'
                  }}
                >
                  Images
                </label>
                <div>
                  <input
                    ref={fileInputRef}
                    type="file"
                    accept="image/*"
                    multiple
                    onChange={handleImageUpload}
                    style={{ display: 'none' }}
                  />
                  <button
                    onClick={() => fileInputRef.current?.click()}
                    disabled={uploading}
                    className="btn btn-secondary"
                    style={{ padding: '0.5rem 0.75rem', fontSize: '0.8125rem' }}
                  >
                    {uploading ? 'Uploading...' : 'Add Images'}
                  </button>
                </div>
              </div>

              {content.metadata.images && content.metadata.images.length > 0 ? (
                <div
                  style={{
                    display: 'grid',
                    gridTemplateColumns: 'repeat(auto-fill, minmax(150px, 1fr))',
                    gap: '1rem'
                  }}
                >
                  {content.metadata.images.map((image, index) => (
                    <div
                      key={image.path}
                      style={{
                        position: 'relative',
                        borderRadius: '8px',
                        overflow: 'hidden',
                        border: '1px solid var(--color-border)',
                        background: 'var(--color-bg)'
                      }}
                    >
                      <img
                        src={`/api/images/images/${slug}/${image.filename}`}
                        alt={image.alt || image.filename}
                        style={{
                          width: '100%',
                          height: '120px',
                          objectFit: 'cover'
                        }}
                      />
                      <div
                        style={{
                          padding: '0.5rem',
                          fontSize: '0.75rem',
                          color: 'var(--color-text-secondary)',
                          overflow: 'hidden',
                          textOverflow: 'ellipsis',
                          whiteSpace: 'nowrap'
                        }}
                      >
                        {image.filename}
                      </div>
                      <button
                        onClick={() => {
                          const url = `/api/images/images/${slug}/${image.filename}`;
                          const a = document.createElement('a');
                          a.href = url;
                          a.download = image.filename;
                          document.body.appendChild(a);
                          a.click();
                          document.body.removeChild(a);
                        }}
                        style={{
                          position: 'absolute',
                          top: '0.5rem',
                          right: '2.25rem',
                          width: '24px',
                          height: '24px',
                          borderRadius: '50%',
                          background: 'rgba(0,0,0,0.6)',
                          color: 'white',
                          border: 'none',
                          cursor: 'pointer',
                          fontSize: '12px',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center'
                        }}
                        title="Download image"
                      >
                        ↓
                      </button>
                      <button
                        onClick={() => removeImage(index)}
                        style={{
                          position: 'absolute',
                          top: '0.5rem',
                          right: '0.5rem',
                          width: '24px',
                          height: '24px',
                          borderRadius: '50%',
                          background: 'rgba(0,0,0,0.6)',
                          color: 'white',
                          border: 'none',
                          cursor: 'pointer',
                          fontSize: '14px',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center'
                        }}
                        title="Remove image"
                      >
                        ×
                      </button>
                    </div>
                  ))}
                </div>
              ) : (
                <div
                  style={{
                    padding: '2rem',
                    textAlign: 'center',
                    border: '2px dashed var(--color-border)',
                    borderRadius: '8px',
                    color: 'var(--color-text-muted)',
                    fontSize: '0.875rem'
                  }}
                >
                  No images yet. Click "Add Images" to upload.
                </div>
              )}
            </div>
          </div>
        </main>
      </div>

      {/* Readability Panel */}
      <ReadabilityPanel
        content={content.content}
        isOpen={showReadabilityPanel}
        onClose={() => setShowReadabilityPanel(false)}
      />
    </div>
  );
}
