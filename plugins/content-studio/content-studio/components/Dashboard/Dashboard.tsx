'use client';

import { useEffect, useState, useMemo } from 'react';
import { ContentFile, ContentStage, ContentType } from '@/types/content';
import StageColumn from './StageColumn';
import GitStatus from '../Git/GitStatus';
import ThemeToggle from '../ThemeToggle/ThemeToggle';

const CONTENT_TYPES: { value: ContentType | 'all'; label: string }[] = [
  { value: 'all', label: 'All Types' },
  { value: 'linkedin-post', label: 'LinkedIn Post' },
  { value: 'opinion', label: 'Opinion' },
  { value: 'article', label: 'Article' },
  { value: 'thread', label: 'Thread' },
  { value: 'newsletter', label: 'Newsletter' },
  { value: 'blog-post', label: 'Blog Post' },
];

export default function Dashboard() {
  const [content, setContent] = useState<Record<ContentStage, ContentFile[]>>({
    '01-ideas': [],
    '02-drafts': [],
    '03-published': []
  });
  const [loading, setLoading] = useState(true);
  const [showGit, setShowGit] = useState(false);
  const [hasChanges, setHasChanges] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [typeFilter, setTypeFilter] = useState<ContentType | 'all'>('all');
  const [draggingItem, setDraggingItem] = useState<ContentFile | null>(null);
  const [isMoving, setIsMoving] = useState(false);

  useEffect(() => {
    loadContent();
    loadGitStatus();

    // Poll git status every 5 seconds
    const gitInterval = setInterval(loadGitStatus, 5000);

    // Poll content every 2 seconds to pick up external file changes
    const contentInterval = setInterval(loadContent, 2000);

    return () => {
      clearInterval(gitInterval);
      clearInterval(contentInterval);
    };
  }, []);

  async function loadGitStatus() {
    try {
      const res = await fetch('/api/git/status');
      const data = await res.json();
      if (data.success) {
        setHasChanges(data.data.changes.length > 0);
      }
    } catch (error) {
      console.error('Error loading git status:', error);
    }
  }

  async function loadContent() {
    try {
      const res = await fetch('/api/content');
      const data = await res.json();

      if (data.success) {
        setContent(data.data);
      }
    } catch (error) {
      console.error('Error loading content:', error);
    } finally {
      // Only clear loading on first load
      if (loading) {
        setLoading(false);
      }
    }
  }

  // Filter content based on search query and type filter
  const filterContent = (items: ContentFile[]): ContentFile[] => {
    return items.filter((item) => {
      // Type filter
      if (typeFilter !== 'all' && item.metadata.type !== typeFilter) {
        return false;
      }

      // Search filter (case-insensitive)
      if (searchQuery.trim()) {
        const query = searchQuery.toLowerCase();
        const titleMatch = item.metadata.title?.toLowerCase().includes(query);
        const tagsMatch = item.metadata.tags?.some(tag =>
          tag.toLowerCase().includes(query)
        );
        const contentMatch = item.content?.toLowerCase().includes(query);
        const coreInsightMatch = item.metadata.coreInsight?.toLowerCase().includes(query);

        if (!titleMatch && !tagsMatch && !contentMatch && !coreInsightMatch) {
          return false;
        }
      }

      return true;
    });
  };

  // Drag and drop handlers
  const handleDragStart = (contentItem: ContentFile) => {
    setDraggingItem(contentItem);
  };

  const handleDragEnd = () => {
    setDraggingItem(null);
  };

  const handleDrop = async (
    targetStage: ContentStage,
    data: { slug: string; stage: ContentStage; filename: string }
  ) => {
    // Don't process if already moving or dropping in same stage
    if (isMoving || data.stage === targetStage) return;

    setIsMoving(true);

    // Find the content item being moved
    const movingContent = content[data.stage].find(
      item => item.metadata.slug === data.slug
    );

    if (!movingContent) {
      setIsMoving(false);
      return;
    }

    // Optimistically update the UI
    setContent(prev => {
      const newContent = { ...prev };

      // Remove from source stage
      newContent[data.stage] = prev[data.stage].filter(
        item => item.metadata.slug !== data.slug
      );

      // Add to target stage with updated stage in metadata
      const updatedItem: ContentFile = {
        ...movingContent,
        stage: targetStage,
        metadata: {
          ...movingContent.metadata,
          stage: targetStage
        }
      };
      newContent[targetStage] = [updatedItem, ...prev[targetStage]];

      return newContent;
    });

    try {
      // Call API to update the content's stage (use type for URL, not stage)
      const response = await fetch(`/api/content/${movingContent.metadata.type}/${data.slug}/move`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ targetStage })
      });

      const result = await response.json();

      if (!result.success) {
        console.error('Failed to move content:', result.error);
        // Revert on failure by reloading content
        await loadContent();
      }
    } catch (error) {
      console.error('Error moving content:', error);
      // Revert on error by reloading content
      await loadContent();
    } finally {
      setIsMoving(false);
      setDraggingItem(null);
    }
  };

  // Memoized filtered content for each stage
  const filteredContent = useMemo(() => ({
    '01-ideas': filterContent(content['01-ideas']),
    '02-drafts': filterContent(content['02-drafts']),
    '03-published': filterContent(content['03-published']),
  }), [content, searchQuery, typeFilter]);

  if (loading) {
    return (
      <div
        className="flex items-center justify-center min-h-screen"
        style={{ background: 'var(--color-bg)' }}
      >
        <div className="animate-fade-in" style={{ color: 'var(--color-text-muted)' }}>
          Loading content...
        </div>
      </div>
    );
  }

  return (
    <div style={{ background: 'var(--color-bg)', height: '100vh', padding: '2rem', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      {/* Header */}
      <header className="animate-slide-up" style={{ marginBottom: '1rem', flexShrink: 0 }}>
        <div className="flex items-center justify-between gap-4">
          <h1
            style={{
              fontFamily: 'var(--font-display)',
              fontSize: '1.5rem',
              fontWeight: 500,
              color: 'var(--color-text)',
              letterSpacing: '-0.02em',
              whiteSpace: 'nowrap'
            }}
          >
            Content Studio
          </h1>

          {/* Search and Filter - moved to header */}
          <div style={{ display: 'flex', gap: '0.75rem', alignItems: 'center', flex: 1, maxWidth: '500px' }}>
            <div style={{ position: 'relative', flex: 1 }}>
              <svg
                width="14"
                height="14"
                viewBox="0 0 16 16"
                fill="none"
                stroke="var(--color-text-muted)"
                strokeWidth="2"
                style={{
                  position: 'absolute',
                  left: '10px',
                  top: '50%',
                  transform: 'translateY(-50%)',
                  pointerEvents: 'none',
                }}
              >
                <circle cx="7" cy="7" r="5" />
                <path d="M11 11l3 3" strokeLinecap="round" />
              </svg>
              <input
                type="text"
                placeholder="Search..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="input"
                style={{
                  padding: '0.5rem 0.75rem',
                  paddingLeft: '32px',
                  fontSize: '0.875rem'
                }}
              />
            </div>
            <select
              value={typeFilter}
              onChange={(e) => setTypeFilter(e.target.value as ContentType | 'all')}
              className="input"
              style={{
                width: 'auto',
                minWidth: '120px',
                cursor: 'pointer',
                appearance: 'none',
                backgroundImage: `url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 12 12' fill='none' stroke='%236b6560' stroke-width='2'%3E%3Cpath d='M3 4.5l3 3 3-3' stroke-linecap='round' stroke-linejoin='round'/%3E%3C/svg%3E")`,
                backgroundRepeat: 'no-repeat',
                backgroundPosition: 'right 10px center',
                padding: '0.5rem 0.75rem',
                paddingRight: '28px',
                fontSize: '0.875rem'
              }}
            >
              {CONTENT_TYPES.map((type) => (
                <option key={type.value} value={type.value}>
                  {type.label}
                </option>
              ))}
            </select>
            {(searchQuery || typeFilter !== 'all') && (
              <button
                onClick={() => {
                  setSearchQuery('');
                  setTypeFilter('all');
                }}
                className="btn btn-ghost"
                style={{ whiteSpace: 'nowrap', padding: '0.5rem 0.75rem', fontSize: '0.875rem' }}
              >
                Clear
              </button>
            )}
          </div>

          <div className="flex gap-2">
            <button
              onClick={() => window.location.href = '/new'}
              className="btn btn-primary"
              style={{ padding: '0.5rem 0.75rem', fontSize: '0.875rem' }}
            >
              <svg width="14" height="14" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="2">
                <path d="M8 3v10M3 8h10" strokeLinecap="round"/>
              </svg>
              New
            </button>

            <button
              onClick={() => setShowGit(!showGit)}
              className="btn btn-secondary"
              style={{
                background: showGit ? 'var(--color-bg-subtle)' : 'var(--color-bg-elevated)',
                padding: '0.5rem 0.75rem',
                fontSize: '0.875rem'
              }}
            >
              <span
                style={{
                  width: '8px',
                  height: '8px',
                  borderRadius: '50%',
                  background: hasChanges ? 'var(--color-warning)' : 'var(--color-success)'
                }}
              />
              Git
            </button>

            <ThemeToggle />
          </div>
        </div>
      </header>

      {/* Git Status Panel */}
      {showGit && (
        <div className="animate-slide-up" style={{ marginBottom: '1.5rem' }}>
          <GitStatus onClose={() => setShowGit(false)} />
        </div>
      )}

      {/* Kanban Board */}
      <div
        className="grid gap-6"
        style={{ gridTemplateColumns: 'repeat(3, 1fr)', flex: 1, minHeight: 0 }}
      >
        <div className="animate-slide-up stagger-1" style={{ minHeight: 0 }}>
          <StageColumn
            stage="01-ideas"
            title="Ideas"
            color="#8b5cf6"
            content={filteredContent['01-ideas']}
            onRefresh={loadContent}
            onDrop={handleDrop}
            onDragStart={handleDragStart}
            onDragEnd={handleDragEnd}
            draggingItem={draggingItem}
          />
        </div>

        <div className="animate-slide-up stagger-2" style={{ minHeight: 0 }}>
          <StageColumn
            stage="02-drafts"
            title="Drafts"
            color="#f59e0b"
            content={filteredContent['02-drafts']}
            onRefresh={loadContent}
            onDrop={handleDrop}
            onDragStart={handleDragStart}
            onDragEnd={handleDragEnd}
            draggingItem={draggingItem}
          />
        </div>

        <div className="animate-slide-up stagger-3" style={{ minHeight: 0 }}>
          <StageColumn
            stage="03-published"
            title="Published"
            color="#10b981"
            content={filteredContent['03-published']}
            onRefresh={loadContent}
            onDrop={handleDrop}
            onDragStart={handleDragStart}
            onDragEnd={handleDragEnd}
            draggingItem={draggingItem}
          />
        </div>
      </div>
    </div>
  );
}
