'use client';

import { useEffect, useState } from 'react';
import { GitStatus as GitStatusType, GitCommit } from '@/types/content';

interface GitStatusProps {
  onClose: () => void;
}

export default function GitStatus({ onClose }: GitStatusProps) {
  const [status, setStatus] = useState<GitStatusType | null>(null);
  const [commits, setCommits] = useState<GitCommit[]>([]);
  const [commitMessage, setCommitMessage] = useState('');
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    loadGitStatus();
    loadCommits();

    // Auto-refresh every 5 seconds
    const interval = setInterval(() => {
      loadGitStatus();
    }, 5000);

    return () => clearInterval(interval);
  }, []);

  async function loadGitStatus() {
    try {
      const res = await fetch('/api/git/status');
      const data = await res.json();
      if (data.success) {
        setStatus(data.data);
      }
    } catch (error) {
      console.error('Error loading git status:', error);
    }
  }

  async function loadCommits() {
    try {
      const res = await fetch('/api/git/log?limit=5');
      const data = await res.json();
      if (data.success) {
        setCommits(data.data);
      }
    } catch (error) {
      console.error('Error loading commits:', error);
    }
  }

  async function handleCommit() {
    if (!commitMessage.trim()) {
      alert('Please enter a commit message');
      return;
    }

    setLoading(true);
    try {
      const res = await fetch('/api/git/commit', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          files: status?.changes.map(c => c.path) || [],
          message: commitMessage
        })
      });

      const data = await res.json();
      if (data.success) {
        setCommitMessage('');
        await loadGitStatus();
        await loadCommits();
      } else {
        alert(`Commit failed: ${data.error}`);
      }
    } catch (error) {
      console.error('Error committing:', error);
      alert('Failed to commit changes');
    } finally {
      setLoading(false);
    }
  }

  async function handlePush() {
    if (!confirm('Push changes to remote?')) return;

    setLoading(true);
    try {
      const res = await fetch('/api/git/push', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
      });

      const data = await res.json();
      if (data.success) {
        alert('Changes pushed successfully');
        await loadGitStatus();
      } else {
        alert(`Push failed: ${data.error}`);
      }
    } catch (error) {
      console.error('Error pushing:', error);
      alert('Failed to push changes');
    } finally {
      setLoading(false);
    }
  }

  if (!status) {
    return (
      <div className="card" style={{ padding: '1.5rem' }}>
        <p style={{ color: 'var(--color-text-muted)' }}>Loading git status...</p>
      </div>
    );
  }

  const hasChanges = status.changes.length > 0;

  return (
    <div className="card">
      {/* Header */}
      <div
        style={{
          padding: '1rem 1.25rem',
          borderBottom: '1px solid var(--color-border)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between'
        }}
      >
        <div>
          <h3
            style={{
              fontWeight: 600,
              color: 'var(--color-text)',
              fontSize: '0.9375rem'
            }}
          >
            Git Status
          </h3>
          <p style={{ fontSize: '0.8125rem', color: 'var(--color-text-secondary)', marginTop: '0.25rem' }}>
            Branch: <code style={{
              fontFamily: 'var(--font-mono)',
              background: 'var(--color-bg-subtle)',
              padding: '0.125rem 0.375rem',
              borderRadius: '4px',
              fontSize: '0.75rem'
            }}>{status.branch}</code>
          </p>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
          <button
            onClick={() => { loadGitStatus(); loadCommits(); }}
            className="btn btn-ghost"
            style={{ padding: '0.375rem', fontSize: '1rem' }}
            title="Refresh"
          >
            <svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5">
              <path d="M14 8A6 6 0 1 1 8 2" strokeLinecap="round"/>
              <path d="M8 2L10 4L8 6" strokeLinecap="round" strokeLinejoin="round"/>
            </svg>
          </button>
          <button
            onClick={onClose}
            className="btn btn-ghost"
            style={{ padding: '0.375rem', fontSize: '1rem' }}
          >
            <svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5">
              <path d="M4 4L12 12M12 4L4 12" strokeLinecap="round"/>
            </svg>
          </button>
        </div>
      </div>

      <div style={{ padding: '1.25rem' }}>
        {/* Changes */}
        {hasChanges ? (
          <div>
            <h4
              style={{
                fontSize: '0.8125rem',
                fontWeight: 500,
                color: 'var(--color-text-secondary)',
                marginBottom: '0.75rem'
              }}
            >
              Changes ({status.changes.length})
            </h4>
            <div
              style={{
                maxHeight: '8rem',
                overflowY: 'auto',
                marginBottom: '1rem'
              }}
            >
              {status.changes.map(change => (
                <div
                  key={change.path}
                  style={{
                    fontFamily: 'var(--font-mono)',
                    fontSize: '0.75rem',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '0.5rem',
                    padding: '0.375rem 0'
                  }}
                >
                  <span
                    style={{
                      width: '1.25rem',
                      textAlign: 'center',
                      fontWeight: 600,
                      color: change.status === 'M' ? 'var(--color-warning)'
                        : change.status === 'A' ? 'var(--color-success)'
                        : change.status === 'D' ? 'var(--color-danger)'
                        : 'var(--color-text-muted)'
                    }}
                  >
                    {change.status}
                  </span>
                  <span style={{ color: 'var(--color-text-secondary)' }}>
                    {change.path}
                  </span>
                </div>
              ))}
            </div>

            {/* Commit Form */}
            <div style={{ marginTop: '1rem' }}>
              <textarea
                value={commitMessage}
                onChange={e => setCommitMessage(e.target.value)}
                placeholder="Commit message..."
                className="input"
                style={{
                  fontSize: '0.875rem',
                  resize: 'none',
                  marginBottom: '0.75rem'
                }}
                rows={3}
              />
              <div style={{ display: 'flex', gap: '0.5rem' }}>
                <button
                  onClick={handleCommit}
                  disabled={loading || !commitMessage.trim()}
                  className="btn btn-primary"
                  style={{ flex: 1, fontSize: '0.8125rem' }}
                >
                  {loading ? 'Committing...' : 'Commit'}
                </button>
                <button
                  onClick={handlePush}
                  disabled={loading || hasChanges}
                  className="btn btn-secondary"
                  style={{
                    flex: 1,
                    fontSize: '0.8125rem',
                    background: !loading && !hasChanges ? 'var(--color-success-bg)' : undefined,
                    color: !loading && !hasChanges ? 'var(--color-success)' : undefined,
                    borderColor: !loading && !hasChanges ? 'var(--color-success)' : undefined
                  }}
                >
                  {loading ? 'Pushing...' : 'Push'}
                </button>
              </div>
            </div>
          </div>
        ) : (
          <div
            style={{
              textAlign: 'center',
              color: 'var(--color-text-muted)',
              padding: '1.5rem 1rem',
              fontSize: '0.875rem'
            }}
          >
            No changes to commit
          </div>
        )}

        {/* Recent Commits */}
        {commits.length > 0 && (
          <div style={{ marginTop: '1.5rem', paddingTop: '1rem', borderTop: '1px solid var(--color-border)' }}>
            <h4
              style={{
                fontSize: '0.8125rem',
                fontWeight: 500,
                color: 'var(--color-text-secondary)',
                marginBottom: '0.75rem'
              }}
            >
              Recent Commits
            </h4>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '0.625rem' }}>
              {commits.map(commit => (
                <div
                  key={commit.hash}
                  style={{
                    borderLeft: '2px solid var(--color-border)',
                    paddingLeft: '0.75rem'
                  }}
                >
                  <p
                    style={{
                      fontSize: '0.8125rem',
                      fontWeight: 500,
                      color: 'var(--color-text)',
                      display: '-webkit-box',
                      WebkitLineClamp: 1,
                      WebkitBoxOrient: 'vertical',
                      overflow: 'hidden'
                    }}
                  >
                    {commit.message}
                  </p>
                  <p style={{ fontSize: '0.6875rem', color: 'var(--color-text-muted)' }}>
                    <code style={{ fontFamily: 'var(--font-mono)' }}>
                      {commit.hash.substring(0, 7)}
                    </code>
                    {' '}&middot;{' '}{commit.author}
                  </p>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
