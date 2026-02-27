'use client';

import { useState, DragEvent } from 'react';
import { ContentFile, ContentStage } from '@/types/content';
import ContentCard from './ContentCard';

interface StageColumnProps {
  stage: ContentStage;
  title: string;
  color: string;
  content: ContentFile[];
  onRefresh: () => void;
  onDrop?: (targetStage: ContentStage, data: { slug: string; stage: ContentStage; filename: string }) => void;
  onDragStart?: (content: ContentFile) => void;
  onDragEnd?: () => void;
  draggingItem?: ContentFile | null;
}

export default function StageColumn({
  stage,
  title,
  color,
  content,
  onRefresh,
  onDrop,
  onDragStart,
  onDragEnd,
  draggingItem
}: StageColumnProps) {
  const [isDragOver, setIsDragOver] = useState(false);

  // Check if this column is a valid drop target (different from source stage)
  const isValidDropTarget = draggingItem && draggingItem.stage !== stage;

  const handleDragOver = (e: DragEvent<HTMLDivElement>) => {
    e.preventDefault();
    e.dataTransfer.dropEffect = 'move';

    if (isValidDropTarget && !isDragOver) {
      setIsDragOver(true);
    }
  };

  const handleDragEnter = (e: DragEvent<HTMLDivElement>) => {
    e.preventDefault();
    if (isValidDropTarget) {
      setIsDragOver(true);
    }
  };

  const handleDragLeave = (e: DragEvent<HTMLDivElement>) => {
    // Only set isDragOver to false if we're leaving the column entirely
    const rect = e.currentTarget.getBoundingClientRect();
    const x = e.clientX;
    const y = e.clientY;

    if (x < rect.left || x > rect.right || y < rect.top || y > rect.bottom) {
      setIsDragOver(false);
    }
  };

  const handleDrop = (e: DragEvent<HTMLDivElement>) => {
    e.preventDefault();
    setIsDragOver(false);

    try {
      const data = JSON.parse(e.dataTransfer.getData('application/json'));

      // Only process if dropping in a different stage
      if (data.stage !== stage && onDrop) {
        onDrop(stage, data);
      }
    } catch (error) {
      console.error('Error parsing drop data:', error);
    }
  };

  return (
    <div
      onDragOver={handleDragOver}
      onDragEnter={handleDragEnter}
      onDragLeave={handleDragLeave}
      onDrop={handleDrop}
      className="card flex flex-col"
      style={{
        height: '100%',
        outline: isDragOver && isValidDropTarget ? `2px dashed ${color}` : 'none',
        outlineOffset: '-2px',
        background: isDragOver && isValidDropTarget ? `${color}08` : undefined,
        transition: 'outline 0.15s ease, background 0.15s ease'
      }}
    >
      {/* Header */}
      <div
        style={{
          padding: '1rem 1.25rem',
          borderBottom: '1px solid var(--color-border)'
        }}
      >
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2.5">
            <span
              style={{
                width: '10px',
                height: '10px',
                borderRadius: '50%',
                background: color
              }}
            />
            <h2
              style={{
                fontWeight: 600,
                color: 'var(--color-text)',
                fontSize: '0.9375rem'
              }}
            >
              {title}
            </h2>
          </div>
          <span
            style={{
              fontSize: '0.8125rem',
              fontWeight: 500,
              color: 'var(--color-text-muted)',
              background: 'var(--color-bg-subtle)',
              padding: '0.25rem 0.625rem',
              borderRadius: '100px'
            }}
          >
            {content.length}
          </span>
        </div>
      </div>

      {/* Content List */}
      <div
        className="flex-1 overflow-y-auto"
        style={{ padding: '1rem' }}
      >
        {content.length === 0 ? (
          <div
            style={{
              textAlign: 'center',
              color: 'var(--color-text-muted)',
              padding: '3rem 1rem',
              fontSize: '0.875rem'
            }}
          >
            No {title.toLowerCase()} yet
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
            {content.map((item, index) => (
              <div
                key={item.filename}
                className="animate-fade-in"
                style={{ animationDelay: `${index * 50}ms` }}
              >
                <ContentCard
                  content={item}
                  color={color}
                  onRefresh={onRefresh}
                  onDragStart={onDragStart}
                  onDragEnd={onDragEnd}
                  isDragging={draggingItem?.metadata.slug === item.metadata.slug}
                />
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
