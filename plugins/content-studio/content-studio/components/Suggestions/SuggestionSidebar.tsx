'use client';

import { SuggestionFile, Suggestion, SuggestionStatus } from '@/types/content';
import { useState } from 'react';

interface SuggestionSidebarProps {
  suggestions: SuggestionFile;
  onUpdate: (updated: SuggestionFile) => void;
}

export default function SuggestionSidebar({ suggestions, onUpdate }: SuggestionSidebarProps) {
  const [expandedId, setExpandedId] = useState<string | null>(null);

  function updateSuggestionStatus(
    id: string,
    status: SuggestionStatus,
    rejectionReason?: string
  ) {
    const updated = {
      ...suggestions,
      suggestions: suggestions.suggestions.map(s =>
        s.id === id
          ? {
              ...s,
              status,
              acceptedAt: status === 'accepted' ? new Date().toISOString() : s.acceptedAt,
              rejectedAt: status === 'rejected' ? new Date().toISOString() : s.rejectedAt,
              rejectionReason
            }
          : s
      )
    };

    onUpdate(updated);
  }

  const pending = suggestions.suggestions.filter(s => s.status === 'pending');
  const accepted = suggestions.suggestions.filter(s => s.status === 'accepted');
  const rejected = suggestions.suggestions.filter(s => s.status === 'rejected');

  const priorityOrder = { high: 0, medium: 1, low: 2 };
  const sortedPending = [...pending].sort(
    (a, b) => priorityOrder[a.priority] - priorityOrder[b.priority]
  );

  return (
    <div className="p-6 space-y-6">
      {/* Header */}
      <div>
        <h2 className="font-semibold text-gray-900 mb-1">Suggestions from Claude</h2>
        <p className="text-sm text-gray-600">
          Reviewed: {new Date(suggestions.created).toLocaleDateString()}
        </p>
        <p className="text-sm text-gray-600">
          Version: {suggestions.fileVersion}
        </p>
      </div>

      {/* Overall Assessment */}
      <div className={`p-3 rounded-lg ${
        suggestions.overallAssessment === 'ready'
          ? 'bg-green-50 border border-green-200'
          : suggestions.overallAssessment === 'needs-revision'
          ? 'bg-yellow-50 border border-yellow-200'
          : 'bg-red-50 border border-red-200'
      }`}>
        <p className="text-sm font-medium">
          {suggestions.overallAssessment === 'ready'
            ? '✓ Ready to publish'
            : suggestions.overallAssessment === 'needs-revision'
            ? '⚠ Needs revision'
            : '⚠ Needs major work'}
        </p>
      </div>

      {/* Pending Suggestions */}
      {sortedPending.length > 0 && (
        <div>
          <h3 className="text-sm font-medium text-gray-700 mb-3">
            Pending ({sortedPending.length})
          </h3>
          <div className="space-y-3">
            {sortedPending.map(suggestion => (
              <SuggestionCard
                key={suggestion.id}
                suggestion={suggestion}
                expanded={expandedId === suggestion.id}
                onToggle={() => setExpandedId(expandedId === suggestion.id ? null : suggestion.id)}
                onAccept={() => updateSuggestionStatus(suggestion.id, 'accepted')}
                onReject={(reason) => updateSuggestionStatus(suggestion.id, 'rejected', reason)}
              />
            ))}
          </div>
        </div>
      )}

      {/* Accepted */}
      {accepted.length > 0 && (
        <div>
          <h3 className="text-sm font-medium text-gray-700 mb-3">
            Accepted ({accepted.length})
          </h3>
          <div className="space-y-2">
            {accepted.map(s => (
              <div key={s.id} className="text-sm p-2 bg-green-50 rounded border border-green-200">
                <p className="text-green-800 line-clamp-1">{s.reason}</p>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Rejected */}
      {rejected.length > 0 && (
        <div>
          <h3 className="text-sm font-medium text-gray-700 mb-3">
            Rejected ({rejected.length})
          </h3>
          <div className="space-y-2">
            {rejected.map(s => (
              <div key={s.id} className="text-sm p-2 bg-gray-50 rounded border border-gray-200">
                <p className="text-gray-600 line-clamp-1">{s.reason}</p>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

interface SuggestionCardProps {
  suggestion: Suggestion;
  expanded: boolean;
  onToggle: () => void;
  onAccept: () => void;
  onReject: (reason?: string) => void;
}

function SuggestionCard({ suggestion, expanded, onToggle, onAccept, onReject }: SuggestionCardProps) {
  const [rejectReason, setRejectReason] = useState('');

  const priorityColors = {
    high: 'bg-red-100 text-red-700',
    medium: 'bg-yellow-100 text-yellow-700',
    low: 'bg-gray-100 text-gray-700'
  };

  const typeIcons = {
    replace: '✏️',
    insert: '➕',
    delete: '🗑️',
    comment: '💭'
  };

  return (
    <div className="border border-gray-200 rounded-lg overflow-hidden">
      <div
        className="p-3 bg-white cursor-pointer hover:bg-gray-50"
        onClick={onToggle}
      >
        <div className="flex items-start justify-between mb-2">
          <div className="flex items-center gap-2">
            <span>{typeIcons[suggestion.type]}</span>
            <span className="text-sm font-medium text-gray-900">
              {suggestion.type === 'replace' && 'Replace'}
              {suggestion.type === 'insert' && 'Insert'}
              {suggestion.type === 'delete' && 'Delete'}
              {suggestion.type === 'comment' && 'Comment'}
            </span>
          </div>
          <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${priorityColors[suggestion.priority]}`}>
            {suggestion.priority}
          </span>
        </div>

        <p className="text-sm text-gray-700 mb-2">
          Lines {suggestion.lineStart}{suggestion.lineStart !== suggestion.lineEnd ? `-${suggestion.lineEnd}` : ''}
        </p>

        <p className="text-sm text-gray-600 line-clamp-2">
          {suggestion.reason}
        </p>
      </div>

      {expanded && (
        <div className="p-3 bg-gray-50 border-t border-gray-200 space-y-3">
          {suggestion.original && (
            <div>
              <p className="text-xs font-medium text-gray-700 mb-1">Current:</p>
              <div className="text-sm p-2 bg-white rounded border border-gray-200 font-mono">
                {suggestion.original}
              </div>
            </div>
          )}

          {suggestion.suggested && (
            <div>
              <p className="text-xs font-medium text-gray-700 mb-1">Suggested:</p>
              <div className="text-sm p-2 bg-white rounded border border-green-200 font-mono">
                {suggestion.suggested}
              </div>
            </div>
          )}

          {suggestion.comment && (
            <div className="text-sm p-2 bg-blue-50 rounded border border-blue-200">
              {suggestion.comment}
            </div>
          )}

          <div>
            <p className="text-xs font-medium text-gray-700 mb-1">Reason:</p>
            <p className="text-sm text-gray-600">{suggestion.reason}</p>
          </div>

          <div className="flex gap-2 pt-2">
            <button
              onClick={(e) => {
                e.stopPropagation();
                onAccept();
              }}
              className="flex-1 px-3 py-2 bg-green-600 text-white rounded text-sm hover:bg-green-700 transition-colors"
            >
              ✓ Accept
            </button>
            <button
              onClick={(e) => {
                e.stopPropagation();
                onReject(rejectReason);
              }}
              className="flex-1 px-3 py-2 bg-red-600 text-white rounded text-sm hover:bg-red-700 transition-colors"
            >
              ✗ Reject
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
