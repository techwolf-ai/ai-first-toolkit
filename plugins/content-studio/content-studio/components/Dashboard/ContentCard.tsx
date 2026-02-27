'use client';

import { useState, DragEvent } from 'react';
import { ContentFile } from '@/types/content';
import { formatDistanceToNow } from 'date-fns';

interface ContentCardProps {
  content: ContentFile;
  color: string;
  onRefresh: () => void;
  onDragStart?: (content: ContentFile) => void;
  onDragEnd?: () => void;
  isDragging?: boolean;
}

const typeLabels: Record<string, string> = {
  'linkedin-post': 'LinkedIn',
  'opinion': 'Opinion',
  'article': 'Article',
  'thread': 'Thread',
  'newsletter': 'Newsletter',
  'blog-post': 'Blog'
};

export default function ContentCard({
  content,
  color,
  onRefresh,
  onDragStart,
  onDragEnd,
  isDragging = false
}: ContentCardProps) {
  const { metadata, filename, stage } = content;
  const [isHovered, setIsHovered] = useState(false);
  const [isDuplicating, setIsDuplicating] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);

  const handleDragStart = (e: DragEvent<HTMLDivElement>) => {
    // Set drag data - include content info for cross-component access
    e.dataTransfer.setData('application/json', JSON.stringify({
      slug: metadata.slug,
      stage: stage,
      filename: filename
    }));
    e.dataTransfer.effectAllowed = 'move';

    // Notify parent
    onDragStart?.(content);
  };

  const handleDragEnd = (e: DragEvent<HTMLDivElement>) => {
    onDragEnd?.();
  };

  const handleDuplicate = async (e: React.MouseEvent) => {
    e.stopPropagation(); // Prevent card click navigation

    if (isDuplicating) return;

    setIsDuplicating(true);
    try {
      const response = await fetch(`/api/content/${metadata.type}/${metadata.slug}/duplicate`, {
        method: 'POST'
      });

      const result = await response.json();

      if (result.success) {
        // Redirect to the new content in the editor (use type for URL)
        window.location.href = `/editor/${result.data.type}/${result.data.slug}`;
      } else {
        console.error('Failed to duplicate:', result.error);
        alert('Failed to duplicate content');
      }
    } catch (error) {
      console.error('Error duplicating content:', error);
      alert('Failed to duplicate content');
    } finally {
      setIsDuplicating(false);
    }
  };

  const handleDeleteClick = (e: React.MouseEvent) => {
    e.stopPropagation();
    setShowDeleteConfirm(true);
  };

  const handleDeleteConfirm = async (e: React.MouseEvent) => {
    e.stopPropagation();

    if (isDeleting) return;

    setIsDeleting(true);
    try {
      const response = await fetch(`/api/content/${metadata.type}/${metadata.slug}/delete`, {
        method: 'DELETE'
      });

      const result = await response.json();

      if (result.success) {
        onRefresh(); // Refresh the dashboard to show updated list
      } else {
        console.error('Failed to delete:', result.error);
        alert('Failed to delete content');
      }
    } catch (error) {
      console.error('Error deleting content:', error);
      alert('Failed to delete content');
    } finally {
      setIsDeleting(false);
      setShowDeleteConfirm(false);
    }
  };

  const handleDeleteCancel = (e: React.MouseEvent) => {
    e.stopPropagation();
    setShowDeleteConfirm(false);
  };

  // Extract slug from filename (remove .yaml extension)
  const slug = metadata.slug || filename.replace('.yaml', '').replace('.md', '');
  // URL uses type instead of stage for stable URLs
  const editorUrl = `/editor/${metadata.type}/${slug}`;

  // Get title and coreInsight from metadata (no longer extracted from content)
  const title = metadata.title || 'Untitled';
  const coreInsight = metadata.coreInsight || '';

  // Get first image if available
  const firstImage = metadata.images && metadata.images.length > 0 ? metadata.images[0] : null;

  return (
    <div
      draggable
      onDragStart={handleDragStart}
      onDragEnd={handleDragEnd}
      onClick={() => window.location.href = editorUrl}
      style={{
        borderRadius: '8px',
        border: '1px solid var(--color-border)',
        background: 'var(--color-bg-elevated)',
        cursor: isDragging ? 'grabbing' : 'grab',
        transition: 'all var(--transition-fast)',
        position: 'relative',
        opacity: isDragging ? 0.5 : 1,
        transform: isDragging ? 'scale(0.98)' : 'none',
        overflow: 'hidden'
      }}
      onMouseEnter={(e) => {
        if (!isDragging) {
          setIsHovered(true);
          e.currentTarget.style.borderColor = color;
          e.currentTarget.style.boxShadow = 'var(--shadow-md)';
          e.currentTarget.style.transform = 'translateY(-2px)';
        }
      }}
      onMouseLeave={(e) => {
        setIsHovered(false);
        e.currentTarget.style.borderColor = 'var(--color-border)';
        e.currentTarget.style.boxShadow = 'none';
        e.currentTarget.style.transform = isDragging ? 'scale(0.98)' : 'translateY(0)';
      }}
    >
      {/* Thumbnail image */}
      {firstImage && (
        <div
          style={{
            width: '100%',
            height: '60px',
            overflow: 'hidden',
            borderBottom: '1px solid var(--color-border)'
          }}
        >
          <img
            src={`/api/images/${firstImage.path}`}
            alt={firstImage.alt || ''}
            style={{
              width: '100%',
              height: '100%',
              objectFit: 'cover'
            }}
          />
        </div>
      )}

      {/* Type badge - top right (below action buttons area when no image) */}
      {!isHovered && (
        <span
          style={{
            position: 'absolute',
            top: firstImage ? '68px' : '8px',
            right: '8px',
            fontSize: '0.625rem',
            textTransform: 'uppercase',
            letterSpacing: '0.03em',
            padding: '0.1875rem 0.5rem',
            background: 'var(--color-bg-elevated)',
            border: '1px solid var(--color-border)',
            borderRadius: '4px',
            color: 'var(--color-text-muted)',
            fontWeight: 500,
            zIndex: 1
          }}
        >
          {typeLabels[metadata.type] || metadata.type}
        </span>
      )}

      {/* Card content */}
      <div style={{ padding: '0.75rem' }}>
      {/* Action buttons - show on hover */}
      {isHovered && !showDeleteConfirm && (
        <div style={{
          position: 'absolute',
          top: '0.5rem',
          right: '0.5rem',
          display: 'flex',
          gap: '4px'
        }}>
          {/* Duplicate button */}
          <button
            onClick={handleDuplicate}
            disabled={isDuplicating}
            title="Duplicate"
            style={{
              width: '28px',
              height: '28px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              background: 'var(--color-bg-elevated)',
              border: '1px solid var(--color-border)',
              borderRadius: '6px',
              cursor: isDuplicating ? 'wait' : 'pointer',
              opacity: isDuplicating ? 0.5 : 1,
              transition: 'all var(--transition-fast)',
              color: 'var(--color-text-muted)',
              fontSize: '0.875rem'
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.background = 'var(--color-bg-subtle)';
              e.currentTarget.style.color = 'var(--color-text)';
              e.currentTarget.style.borderColor = color;
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.background = 'var(--color-bg-elevated)';
              e.currentTarget.style.color = 'var(--color-text-muted)';
              e.currentTarget.style.borderColor = 'var(--color-border)';
            }}
          >
            {isDuplicating ? (
              <span style={{ fontSize: '0.75rem' }}>...</span>
            ) : (
              <svg
                width="14"
                height="14"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
              >
                <rect x="9" y="9" width="13" height="13" rx="2" ry="2" />
                <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1" />
              </svg>
            )}
          </button>

          {/* Delete button */}
          <button
            onClick={handleDeleteClick}
            title="Delete"
            style={{
              width: '28px',
              height: '28px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              background: 'var(--color-bg-elevated)',
              border: '1px solid var(--color-border)',
              borderRadius: '6px',
              cursor: 'pointer',
              transition: 'all var(--transition-fast)',
              color: 'var(--color-text-muted)',
              fontSize: '0.875rem'
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.background = '#fef2f2';
              e.currentTarget.style.color = '#dc2626';
              e.currentTarget.style.borderColor = '#fca5a5';
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.background = 'var(--color-bg-elevated)';
              e.currentTarget.style.color = 'var(--color-text-muted)';
              e.currentTarget.style.borderColor = 'var(--color-border)';
            }}
          >
            <svg
              width="14"
              height="14"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
            >
              <polyline points="3 6 5 6 21 6" />
              <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2" />
              <line x1="10" y1="11" x2="10" y2="17" />
              <line x1="14" y1="11" x2="14" y2="17" />
            </svg>
          </button>
        </div>
      )}

      {/* Delete confirmation overlay */}
      {showDeleteConfirm && (
        <div
          style={{
            position: 'absolute',
            inset: 0,
            background: 'rgba(255,255,255,0.95)',
            borderRadius: '8px',
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            justifyContent: 'center',
            gap: '0.75rem',
            padding: '1rem',
            zIndex: 10
          }}
        >
          <p style={{ fontSize: '0.875rem', color: 'var(--color-text)', textAlign: 'center', fontWeight: 500 }}>
            Delete this content?
          </p>
          <div style={{ display: 'flex', gap: '0.5rem' }}>
            <button
              onClick={handleDeleteConfirm}
              disabled={isDeleting}
              style={{
                padding: '0.375rem 0.75rem',
                fontSize: '0.8125rem',
                background: '#dc2626',
                color: 'white',
                border: 'none',
                borderRadius: '6px',
                cursor: isDeleting ? 'wait' : 'pointer',
                fontWeight: 500
              }}
            >
              {isDeleting ? 'Deleting...' : 'Delete'}
            </button>
            <button
              onClick={handleDeleteCancel}
              disabled={isDeleting}
              style={{
                padding: '0.375rem 0.75rem',
                fontSize: '0.8125rem',
                background: 'var(--color-bg-subtle)',
                color: 'var(--color-text)',
                border: '1px solid var(--color-border)',
                borderRadius: '6px',
                cursor: 'pointer',
                fontWeight: 500
              }}
            >
              Cancel
            </button>
          </div>
        </div>
      )}

      {/* Title */}
      <h3
        style={{
          fontFamily: 'var(--font-display)',
          fontWeight: 500,
          fontSize: '0.875rem',
          color: 'var(--color-text)',
          marginBottom: '0.375rem',
          lineHeight: 1.4,
          display: '-webkit-box',
          WebkitLineClamp: 2,
          WebkitBoxOrient: 'vertical',
          overflow: 'hidden',
          paddingRight: '3.5rem'
        }}
      >
        {title}
      </h3>

      {/* Core Insight */}
      {coreInsight && (
        <p
          style={{
            fontSize: '0.8125rem',
            color: 'var(--color-text-secondary)',
            marginBottom: '0.5rem',
            lineHeight: 1.4,
            display: '-webkit-box',
            WebkitLineClamp: 2,
            WebkitBoxOrient: 'vertical',
            overflow: 'hidden'
          }}
        >
          {coreInsight}
        </p>
      )}

      {/* Footer */}
      <div
        style={{
          fontSize: '0.75rem',
          color: 'var(--color-text-muted)',
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center'
        }}
      >
        <span>{formatDistanceToNow(new Date(metadata.lastUpdated), { addSuffix: true })}</span>
        {/* Engagement badge for published posts */}
        {stage === '03-published' && metadata.engagement && typeof metadata.engagement === 'object' && metadata.engagement.reactions !== undefined && (
          <span
            style={{
              display: 'inline-flex',
              alignItems: 'center',
              gap: '0.25rem',
              padding: '0.125rem 0.375rem',
              borderRadius: '4px',
              fontSize: '0.6875rem',
              fontWeight: 500,
              background: metadata.engagement.reactions >= 100
                ? '#dcfce7'
                : metadata.engagement.reactions >= 30
                  ? '#fef3c7'
                  : '#f3f4f6',
              color: metadata.engagement.reactions >= 100
                ? '#166534'
                : metadata.engagement.reactions >= 30
                  ? '#92400e'
                  : '#6b7280'
            }}
            title={`${metadata.engagement.views ?? 0} views, ${metadata.engagement.reactions ?? 0} reactions, ${metadata.engagement.comments ?? 0} comments, ${metadata.engagement.reposts ?? 0} reposts`}
          >
            <svg
              width="10"
              height="10"
              viewBox="0 0 24 24"
              fill="currentColor"
              stroke="none"
            >
              <path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"/>
            </svg>
            {metadata.engagement.reactions}
          </span>
        )}
      </div>
      </div>
    </div>
  );
}
