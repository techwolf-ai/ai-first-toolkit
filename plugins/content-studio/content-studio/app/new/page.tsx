'use client';

import { useState } from 'react';
import { ContentType } from '@/types/content';
import ThemeToggle from '@/components/ThemeToggle/ThemeToggle';

export default function NewIdeaPage() {
  const [title, setTitle] = useState('');
  const [type, setType] = useState<ContentType>('linkedin-post');
  const [coreInsight, setCoreInsight] = useState('');
  const [creating, setCreating] = useState(false);
  const [error, setError] = useState<string | null>(null);

  function generateSlug(): string {
    const now = new Date();
    const year = now.getFullYear();
    const month = String(now.getMonth() + 1).padStart(2, '0');
    const day = String(now.getDate()).padStart(2, '0');
    const hours = String(now.getHours()).padStart(2, '0');
    const minutes = String(now.getMinutes()).padStart(2, '0');
    const seconds = String(now.getSeconds()).padStart(2, '0');
    return `${year}${month}${day}-${hours}${minutes}${seconds}`;
  }

  async function handleCreate(e: React.FormEvent) {
    e.preventDefault();

    if (!title.trim()) {
      setError('Title is required');
      return;
    }

    setCreating(true);
    setError(null);

    try {
      const now = new Date();
      const slug = generateSlug();

      // Start with empty content - title and core insight are in metadata
      const content = '';

      const res = await fetch('/api/content', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          stage: '01-ideas',
          metadata: {
            stage: '01-ideas',
            type,
            title,
            slug,
            created: now.toISOString(),
            lastUpdated: now.toISOString(),
            coreInsight: coreInsight || '',
            tags: [],
            feedbackLog: []
          },
          content
        })
      });

      const data = await res.json();

      if (data.success) {
        window.location.href = `/editor/${type}/${slug}`;
      } else {
        setError(data.error || 'Failed to create idea');
      }
    } catch (err) {
      setError('Failed to create idea');
      console.error(err);
    } finally {
      setCreating(false);
    }
  }

  return (
    <div style={{ minHeight: '100vh', background: 'var(--color-bg)' }}>
      {/* Theme toggle in top right corner */}
      <div style={{ position: 'fixed', top: '1.5rem', right: '1.5rem', zIndex: 50 }}>
        <ThemeToggle />
      </div>

      <div style={{ maxWidth: '40rem', margin: '0 auto', padding: '3rem 1.5rem' }}>
        <div className="animate-slide-up" style={{ marginBottom: '2rem' }}>
          <button
            onClick={() => window.location.href = '/'}
            className="btn btn-ghost"
            style={{ marginBottom: '1rem', marginLeft: '-0.75rem' }}
          >
            <svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5">
              <path d="M10 12L6 8L10 4" strokeLinecap="round" strokeLinejoin="round"/>
            </svg>
            Back to Dashboard
          </button>
          <h1
            style={{
              fontFamily: 'var(--font-display)',
              fontSize: '2rem',
              fontWeight: 500,
              color: 'var(--color-text)',
              letterSpacing: '-0.02em'
            }}
          >
            New Idea
          </h1>
          <p style={{ color: 'var(--color-text-secondary)', marginTop: '0.5rem' }}>
            Capture a new concept for thought leadership content
          </p>
        </div>

        <form
          onSubmit={handleCreate}
          className="card animate-slide-up stagger-1"
          style={{ padding: '2rem' }}
        >
          {error && (
            <div
              style={{
                marginBottom: '1.5rem',
                padding: '1rem',
                background: 'var(--color-danger-bg)',
                border: '1px solid var(--color-danger)',
                color: 'var(--color-danger)',
                borderRadius: '8px',
                fontSize: '0.875rem'
              }}
            >
              {error}
            </div>
          )}

          <div style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
            <div>
              <label htmlFor="title" className="label">
                Title <span style={{ color: 'var(--color-danger)' }}>*</span>
              </label>
              <input
                type="text"
                id="title"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                placeholder="What's the idea about?"
                className="input"
                style={{
                  fontFamily: 'var(--font-display)',
                  fontSize: '1.125rem'
                }}
                autoFocus
              />
            </div>

            <div>
              <label htmlFor="type" className="label">
                Content Type
              </label>
              <select
                id="type"
                value={type}
                onChange={(e) => setType(e.target.value as ContentType)}
                className="input"
              >
                <option value="linkedin-post">LinkedIn Post</option>
                <option value="opinion">Opinion</option>
                <option value="article">Article</option>
                <option value="blog-post">Blog Post</option>
                <option value="thread">Thread</option>
                <option value="newsletter">Newsletter</option>
              </select>
            </div>

            <div>
              <label htmlFor="coreInsight" className="label">
                Core Insight
              </label>
              <textarea
                id="coreInsight"
                value={coreInsight}
                onChange={(e) => setCoreInsight(e.target.value)}
                placeholder="What's the non-obvious thing you want people to understand?"
                rows={4}
                className="input"
                style={{ resize: 'vertical' }}
              />
            </div>
          </div>

          <div style={{ marginTop: '2rem', display: 'flex', gap: '0.75rem' }}>
            <button
              type="submit"
              disabled={creating}
              className="btn btn-primary"
              style={{ flex: 1, padding: '0.875rem 1rem' }}
            >
              {creating ? 'Creating...' : 'Create Idea'}
            </button>
            <button
              type="button"
              onClick={() => window.location.href = '/'}
              className="btn btn-secondary"
              style={{ padding: '0.875rem 1.5rem' }}
            >
              Cancel
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
