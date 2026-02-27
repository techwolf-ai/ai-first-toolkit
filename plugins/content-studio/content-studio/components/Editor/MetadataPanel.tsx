'use client';

import { ContentMetadata, EngagementMetrics } from '@/types/content';

interface MetadataPanelProps {
  metadata: ContentMetadata;
  onChange: (metadata: ContentMetadata) => void;
}

export default function MetadataPanel({ metadata, onChange }: MetadataPanelProps) {
  function updateField<K extends keyof ContentMetadata>(
    field: K,
    value: ContentMetadata[K]
  ) {
    onChange({ ...metadata, [field]: value });
  }

  function addTag(tag: string) {
    if (tag.trim() && !metadata.tags.includes(tag.trim())) {
      updateField('tags', [...metadata.tags, tag.trim()]);
    }
  }

  function removeTag(tag: string) {
    updateField('tags', metadata.tags.filter(t => t !== tag));
  }

  function updateEngagement(field: keyof EngagementMetrics, value: number | undefined) {
    const currentEngagement = metadata.engagement || {};
    const updated: EngagementMetrics = {
      ...currentEngagement,
      [field]: value,
      lastUpdated: new Date().toISOString()
    };
    // Remove undefined values
    if (value === undefined || value === null || isNaN(value as number)) {
      delete updated[field];
    }
    updateField('engagement', Object.keys(updated).length > 1 ? updated : null);
  }

  return (
    <div style={{ padding: '1.5rem' }}>
      <h2
        style={{
          fontSize: '0.8125rem',
          fontWeight: 600,
          color: 'var(--color-text-muted)',
          textTransform: 'uppercase',
          letterSpacing: '0.05em',
          marginBottom: '1.5rem'
        }}
      >
        Metadata
      </h2>

      <div style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
        {/* Stage */}
        <div>
          <label className="label">Stage</label>
          <select
            value={metadata.stage}
            onChange={e => updateField('stage', e.target.value as any)}
            className="input"
            style={{ fontSize: '0.875rem' }}
          >
            <option value="01-ideas">Ideas</option>
            <option value="02-drafts">Drafts</option>
            <option value="03-published">Published</option>
          </select>
        </div>

        {/* Type */}
        <div>
          <label className="label">Type</label>
          <select
            value={metadata.type}
            onChange={e => updateField('type', e.target.value as any)}
            className="input"
            style={{ fontSize: '0.875rem' }}
          >
            <option value="linkedin-post">LinkedIn Post</option>
            <option value="opinion">Opinion</option>
            <option value="article">Article</option>
            <option value="blog-post">Blog Post</option>
            <option value="thread">Thread</option>
            <option value="newsletter">Newsletter</option>
          </select>
        </div>

        {/* Tags */}
        <div>
          <label className="label">Tags</label>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.5rem', marginBottom: '0.625rem' }}>
            {metadata.tags.map(tag => (
              <span
                key={tag}
                style={{
                  display: 'inline-flex',
                  alignItems: 'center',
                  gap: '0.375rem',
                  padding: '0.25rem 0.625rem',
                  background: 'var(--color-bg-subtle)',
                  color: 'var(--color-text-secondary)',
                  borderRadius: '100px',
                  fontSize: '0.8125rem'
                }}
              >
                {tag}
                <button
                  onClick={() => removeTag(tag)}
                  style={{
                    background: 'none',
                    border: 'none',
                    padding: 0,
                    cursor: 'pointer',
                    color: 'var(--color-text-muted)',
                    fontSize: '1rem',
                    lineHeight: 1,
                    transition: 'color var(--transition-fast)'
                  }}
                  onMouseEnter={(e) => e.currentTarget.style.color = 'var(--color-danger)'}
                  onMouseLeave={(e) => e.currentTarget.style.color = 'var(--color-text-muted)'}
                >
                  ×
                </button>
              </span>
            ))}
          </div>
          <input
            type="text"
            onKeyDown={e => {
              if (e.key === 'Enter') {
                e.preventDefault();
                addTag((e.target as HTMLInputElement).value);
                (e.target as HTMLInputElement).value = '';
              }
            }}
            className="input"
            style={{ fontSize: '0.875rem' }}
            placeholder="Type and press Enter"
          />
        </div>

        {/* Engagement Metrics - only for published posts */}
        {metadata.stage === '03-published' && (
          <div
            style={{
              paddingTop: '1rem',
              borderTop: '1px solid var(--color-border)'
            }}
          >
            <label
              className="label"
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '0.5rem',
                marginBottom: '0.75rem'
              }}
            >
              Engagement
              <span
                style={{
                  fontSize: '0.6875rem',
                  padding: '0.125rem 0.375rem',
                  background: 'var(--color-bg-subtle)',
                  color: 'var(--color-text-muted)',
                  borderRadius: '4px',
                  fontWeight: 400,
                  textTransform: 'none',
                  letterSpacing: 'normal'
                }}
              >
                LinkedIn
              </span>
            </label>
            <div
              style={{
                display: 'grid',
                gridTemplateColumns: '1fr 1fr',
                gap: '0.75rem'
              }}
            >
              <div>
                <label
                  style={{
                    fontSize: '0.6875rem',
                    color: 'var(--color-text-muted)',
                    marginBottom: '0.25rem',
                    display: 'block'
                  }}
                >
                  Views
                </label>
                <input
                  type="number"
                  min="0"
                  value={metadata.engagement?.views ?? ''}
                  onChange={e => updateEngagement('views', e.target.value ? parseInt(e.target.value, 10) : undefined)}
                  className="input"
                  style={{ fontSize: '0.8125rem' }}
                  placeholder="0"
                />
              </div>
              <div>
                <label
                  style={{
                    fontSize: '0.6875rem',
                    color: 'var(--color-text-muted)',
                    marginBottom: '0.25rem',
                    display: 'block'
                  }}
                >
                  Reactions
                </label>
                <input
                  type="number"
                  min="0"
                  value={metadata.engagement?.reactions ?? ''}
                  onChange={e => updateEngagement('reactions', e.target.value ? parseInt(e.target.value, 10) : undefined)}
                  className="input"
                  style={{ fontSize: '0.8125rem' }}
                  placeholder="0"
                />
              </div>
              <div>
                <label
                  style={{
                    fontSize: '0.6875rem',
                    color: 'var(--color-text-muted)',
                    marginBottom: '0.25rem',
                    display: 'block'
                  }}
                >
                  Comments
                </label>
                <input
                  type="number"
                  min="0"
                  value={metadata.engagement?.comments ?? ''}
                  onChange={e => updateEngagement('comments', e.target.value ? parseInt(e.target.value, 10) : undefined)}
                  className="input"
                  style={{ fontSize: '0.8125rem' }}
                  placeholder="0"
                />
              </div>
              <div>
                <label
                  style={{
                    fontSize: '0.6875rem',
                    color: 'var(--color-text-muted)',
                    marginBottom: '0.25rem',
                    display: 'block'
                  }}
                >
                  Reposts
                </label>
                <input
                  type="number"
                  min="0"
                  value={metadata.engagement?.reposts ?? ''}
                  onChange={e => updateEngagement('reposts', e.target.value ? parseInt(e.target.value, 10) : undefined)}
                  className="input"
                  style={{ fontSize: '0.8125rem' }}
                  placeholder="0"
                />
              </div>
            </div>
            {metadata.engagement?.lastUpdated && (
              <p
                style={{
                  fontSize: '0.6875rem',
                  color: 'var(--color-text-muted)',
                  marginTop: '0.5rem'
                }}
              >
                Updated: {new Date(metadata.engagement.lastUpdated).toLocaleDateString()}
              </p>
            )}
          </div>
        )}

        {/* Dates */}
        <div
          style={{
            paddingTop: '1rem',
            borderTop: '1px solid var(--color-border)',
            fontSize: '0.75rem',
            color: 'var(--color-text-muted)'
          }}
        >
          <p style={{ marginBottom: '0.25rem' }}>Created: {metadata.created}</p>
          <p style={{ marginBottom: '0.25rem' }}>Updated: {metadata.lastUpdated}</p>
          {metadata.publishedDate && (
            <p>Published: {metadata.publishedDate}</p>
          )}
        </div>
      </div>
    </div>
  );
}
