'use client';

import { useState } from 'react';
import { ContentType, ContentImage } from '@/types/content';
import ReactMarkdown from 'react-markdown';

interface PlatformPreviewProps {
  content: string;
  title: string;
  coreInsight?: string;
  type: ContentType;
  authorName?: string;
  authorTitle?: string;
  date?: string;
  images?: ContentImage[];
  slug?: string;
}

// LinkedIn Post Preview
function LinkedInPreview({ content, authorName = 'Your Name', authorTitle = 'Your Title', images, slug }: {
  content: string;
  authorName?: string;
  authorTitle?: string;
  images?: ContentImage[];
  slug?: string;
}) {
  const [expanded, setExpanded] = useState(false);

  // LinkedIn preserves line breaks but doesn't use markdown
  const formattedContent = content
    .replace(/^#+ .+$/gm, '') // Remove markdown headers
    .replace(/\*\*(.+?)\*\*/g, '$1') // Remove bold
    .replace(/\*(.+?)\*/g, '$1') // Remove italics
    .replace(/\[(.+?)\]\(.+?\)/g, '$1') // Convert links to text
    .trim();

  // LinkedIn truncates at approximately 210 characters (about 3 lines)
  const TRUNCATE_LENGTH = 210;
  const needsTruncation = formattedContent.length > TRUNCATE_LENGTH;
  const displayContent = expanded || !needsTruncation
    ? formattedContent
    : formattedContent.substring(0, TRUNCATE_LENGTH).trim();

  return (
    <div style={{
      fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Oxygen, Ubuntu, sans-serif',
      background: '#f3f2ef',
      padding: '1rem',
      borderRadius: '8px',
      minHeight: '500px'
    }}>
      <div style={{
        background: '#ffffff',
        borderRadius: '8px',
        border: '1px solid #e0dfdc',
        overflow: 'hidden',
        maxWidth: '550px',
        margin: '0 auto'
      }}>
        {/* Author Header */}
        <div style={{
          padding: '12px 16px',
          display: 'flex',
          gap: '8px',
          alignItems: 'flex-start'
        }}>
          {/* Profile Picture Placeholder */}
          <div style={{
            width: '48px',
            height: '48px',
            borderRadius: '50%',
            background: 'linear-gradient(135deg, #0a66c2, #004182)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            color: 'white',
            fontWeight: 600,
            fontSize: '18px',
            flexShrink: 0
          }}>
            {authorName.split(' ').map(n => n[0]).join('').substring(0, 2)}
          </div>
          <div style={{ flex: 1 }}>
            <div style={{
              fontWeight: 600,
              fontSize: '14px',
              color: 'rgba(0,0,0,0.9)',
              lineHeight: 1.3
            }}>
              {authorName}
            </div>
            <div style={{
              fontSize: '12px',
              color: 'rgba(0,0,0,0.6)',
              lineHeight: 1.3,
              marginTop: '2px'
            }}>
              {authorTitle}
            </div>
            <div style={{
              fontSize: '12px',
              color: 'rgba(0,0,0,0.6)',
              display: 'flex',
              alignItems: 'center',
              gap: '4px',
              marginTop: '2px'
            }}>
              <span>Now</span>
              <span style={{ fontSize: '10px' }}>•</span>
              <svg width="12" height="12" viewBox="0 0 16 16" fill="rgba(0,0,0,0.6)">
                <path d="M8 1a7 7 0 107 7 7 7 0 00-7-7zM3 8a5 5 0 011-3l.55.55A1.5 1.5 0 015 6.62v1.07a.75.75 0 00.22.53l.56.56a.75.75 0 01.22.53V11a.75.75 0 01-.22.53L4.5 12.59A5 5 0 013 8zm6.5 4.91a5 5 0 01-1.5.09v-2.18a.75.75 0 00-.22-.53l-.56-.56a.75.75 0 01-.22-.53V7.53A.75.75 0 007.22 7l.56-.56A.75.75 0 008 5.91V4a5 5 0 012.9 1.62l-.64.64a.75.75 0 00-.22.53v1.28a.75.75 0 00.22.53l1.17 1.17a.75.75 0 00.53.22h.62a5 5 0 01-3.08 2.92z"/>
              </svg>
            </div>
          </div>
        </div>

        {/* Post Content */}
        <div style={{
          padding: '0 16px 12px',
          fontSize: '14px',
          color: 'rgba(0,0,0,0.9)',
          lineHeight: 1.5,
          whiteSpace: 'pre-wrap'
        }}>
          {displayContent || 'Your LinkedIn post content will appear here...'}
          {needsTruncation && !expanded && (
            <span
              onClick={() => setExpanded(true)}
              style={{
                color: 'rgba(0,0,0,0.6)',
                cursor: 'pointer',
                fontWeight: 500
              }}
            >
              ...see more
            </span>
          )}
        </div>

        {/* Images - LinkedIn-accurate layouts */}
        {images && images.length > 0 && (
          <div style={{ marginBottom: '0' }}>
            {/* Single image */}
            {images.length === 1 && (
              <div style={{
                width: '100%',
                maxHeight: '350px',
                overflow: 'hidden',
                background: '#f3f2ef'
              }}>
                <img
                  src={`/api/images/images/${slug}/${images[0].filename}`}
                  alt={images[0].alt || images[0].filename}
                  style={{
                    width: '100%',
                    height: '100%',
                    objectFit: 'contain',
                    maxHeight: '350px'
                  }}
                />
              </div>
            )}

            {/* Two images - side by side */}
            {images.length === 2 && (
              <div style={{
                display: 'grid',
                gridTemplateColumns: '1fr 1fr',
                gap: '2px',
                height: '280px'
              }}>
                {images.map((image) => (
                  <div key={image.filename} style={{ overflow: 'hidden', background: '#f3f2ef' }}>
                    <img
                      src={`/api/images/images/${slug}/${image.filename}`}
                      alt={image.alt || image.filename}
                      style={{
                        width: '100%',
                        height: '100%',
                        objectFit: 'cover'
                      }}
                    />
                  </div>
                ))}
              </div>
            )}

            {/* Three images - large left, two stacked right */}
            {images.length === 3 && (
              <div style={{
                display: 'grid',
                gridTemplateColumns: '2fr 1fr',
                gridTemplateRows: '1fr 1fr',
                gap: '2px',
                height: '350px'
              }}>
                <div style={{ gridRow: '1 / 3', overflow: 'hidden', background: '#f3f2ef' }}>
                  <img
                    src={`/api/images/images/${slug}/${images[0].filename}`}
                    alt={images[0].alt || images[0].filename}
                    style={{
                      width: '100%',
                      height: '100%',
                      objectFit: 'cover'
                    }}
                  />
                </div>
                {images.slice(1, 3).map((image) => (
                  <div key={image.filename} style={{ overflow: 'hidden', background: '#f3f2ef' }}>
                    <img
                      src={`/api/images/images/${slug}/${image.filename}`}
                      alt={image.alt || image.filename}
                      style={{
                        width: '100%',
                        height: '100%',
                        objectFit: 'cover'
                      }}
                    />
                  </div>
                ))}
              </div>
            )}

            {/* Four or more images - 2x2 grid */}
            {images.length >= 4 && (
              <div style={{
                display: 'grid',
                gridTemplateColumns: '1fr 1fr',
                gridTemplateRows: '1fr 1fr',
                gap: '2px',
                height: '350px'
              }}>
                {images.slice(0, 4).map((image, index) => (
                  <div
                    key={image.filename}
                    style={{
                      position: 'relative',
                      overflow: 'hidden',
                      background: '#f3f2ef'
                    }}
                  >
                    <img
                      src={`/api/images/images/${slug}/${image.filename}`}
                      alt={image.alt || image.filename}
                      style={{
                        width: '100%',
                        height: '100%',
                        objectFit: 'cover'
                      }}
                    />
                    {images.length > 4 && index === 3 && (
                      <div style={{
                        position: 'absolute',
                        inset: 0,
                        background: 'rgba(0,0,0,0.55)',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        color: 'white',
                        fontSize: '28px',
                        fontWeight: 600
                      }}>
                        +{images.length - 4}
                      </div>
                    )}
                  </div>
                ))}
              </div>
            )}
          </div>
        )}

        {/* Engagement Bar */}
        <div style={{
          padding: '0 16px',
          fontSize: '12px',
          color: 'rgba(0,0,0,0.6)',
          display: 'flex',
          alignItems: 'center',
          gap: '4px'
        }}>
          <span style={{
            display: 'inline-flex',
            alignItems: 'center'
          }}>
            <span style={{
              background: '#378fe9',
              borderRadius: '50%',
              width: '16px',
              height: '16px',
              display: 'inline-flex',
              alignItems: 'center',
              justifyContent: 'center',
              marginRight: '-4px',
              border: '2px solid white',
              zIndex: 3
            }}>
              <svg width="10" height="10" viewBox="0 0 24 24" fill="white">
                <path d="M19.46 11l-3.91-3.91a7 7 0 01-1.69-2.74l-.49-1.47A2.76 2.76 0 0010.76 1 2.75 2.75 0 008 3.74v1.12a9.19 9.19 0 00.46 2.85L8.89 9H4.12A2.12 2.12 0 002 11.12a2.16 2.16 0 00.92 1.76A2.11 2.11 0 002 14.62a2.14 2.14 0 001.28 2 2 2 0 00-.28 1 2.12 2.12 0 002 2.12v.14A2.12 2.12 0 007.12 22h7.49a8.08 8.08 0 003.58-.84l.31-.16H21V11z"/>
              </svg>
            </span>
            <span style={{
              background: '#df704d',
              borderRadius: '50%',
              width: '16px',
              height: '16px',
              display: 'inline-flex',
              alignItems: 'center',
              justifyContent: 'center',
              marginRight: '-4px',
              border: '2px solid white',
              zIndex: 2
            }}>
              <svg width="10" height="10" viewBox="0 0 24 24" fill="white">
                <path d="M12.5 2.75a9.5 9.5 0 100 19 9.5 9.5 0 000-19zM7 10.5a1.5 1.5 0 113 0 1.5 1.5 0 01-3 0zm7 0a1.5 1.5 0 113 0 1.5 1.5 0 01-3 0zm-6 4.38a.5.5 0 01.35-.6 8.93 8.93 0 016.3 0 .5.5 0 11-.3.95 7.93 7.93 0 00-5.6 0 .5.5 0 01-.6-.35z"/>
              </svg>
            </span>
            <span style={{
              background: '#6dae4f',
              borderRadius: '50%',
              width: '16px',
              height: '16px',
              display: 'inline-flex',
              alignItems: 'center',
              justifyContent: 'center',
              border: '2px solid white',
              zIndex: 1
            }}>
              <svg width="10" height="10" viewBox="0 0 24 24" fill="white">
                <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zM8 14c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2zm4 4c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2zm0-8c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2zm4 4c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2z"/>
              </svg>
            </span>
          </span>
          <span style={{ marginLeft: '4px' }}>42</span>
        </div>

        {/* Divider */}
        <div style={{
          borderTop: '1px solid #e0dfdc',
          margin: '8px 16px 0'
        }} />

        {/* Action Buttons */}
        <div style={{
          display: 'flex',
          justifyContent: 'space-around',
          padding: '4px 8px'
        }}>
          {[
            { label: 'Like', icon: 'M19.46 11l-3.91-3.91a7 7 0 01-1.69-2.74l-.49-1.47A2.76 2.76 0 0010.76 1 2.75 2.75 0 008 3.74v1.12a9.19 9.19 0 00.46 2.85L8.89 9H4.12A2.12 2.12 0 002 11.12a2.16 2.16 0 00.92 1.76A2.11 2.11 0 002 14.62a2.14 2.14 0 001.28 2 2 2 0 00-.28 1 2.12 2.12 0 002 2.12v.14A2.12 2.12 0 007.12 22h7.49a8.08 8.08 0 003.58-.84l.31-.16H21V11z' },
            { label: 'Comment', icon: 'M7 9h10v1H7zm0 4h7v-1H7zm16-2a12 12 0 10-24 0 12 12 0 0024 0zM3 11a9 9 0 119 9 9 9 0 01-9-9z' },
            { label: 'Repost', icon: 'M13.96 5H6c-1.1 0-2 .9-2 2v5H2l3.5 4L9 12H7V7h6.96l-.96-2zm.08 14H21l-3.5-4L14 19h2v-5H9.04l.96 2H14v3h.04z' },
            { label: 'Send', icon: 'M21 3L0 10l7.66 4.26L16 8l-6.26 8.34L14 24l7-21z' }
          ].map(action => (
            <button
              key={action.label}
              style={{
                background: 'transparent',
                border: 'none',
                padding: '12px 8px',
                display: 'flex',
                alignItems: 'center',
                gap: '4px',
                color: 'rgba(0,0,0,0.6)',
                fontSize: '12px',
                fontWeight: 600,
                cursor: 'pointer',
                borderRadius: '4px'
              }}
            >
              <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor">
                <path d={action.icon}/>
              </svg>
              {action.label}
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}

// Article Preview
function ArticlePreview({ content, title, coreInsight, authorName = 'Your Name', date }: {
  content: string;
  title: string;
  coreInsight?: string;
  authorName?: string;
  date?: string;
}) {
  return (
    <div style={{
      fontFamily: 'Georgia, "Times New Roman", serif',
      background: '#ffffff',
      padding: '2rem',
      borderRadius: '8px',
      border: '1px solid #e8e6e1',
      minHeight: '500px',
      maxWidth: '700px',
      margin: '0 auto'
    }}>
      {/* Article Header */}
      <header style={{ marginBottom: '2rem', borderBottom: '1px solid #e8e6e1', paddingBottom: '1.5rem' }}>
        <h1 style={{
          fontSize: '2.5rem',
          fontWeight: 700,
          lineHeight: 1.2,
          color: '#1a1a1a',
          marginBottom: '1rem'
        }}>
          {title || 'Article Title'}
        </h1>

        {coreInsight && (
          <p style={{
            fontSize: '1.25rem',
            color: '#666',
            fontStyle: 'italic',
            marginBottom: '1rem',
            lineHeight: 1.5
          }}>
            {coreInsight}
          </p>
        )}

        <div style={{
          display: 'flex',
          alignItems: 'center',
          gap: '12px',
          fontSize: '0.875rem',
          color: '#666'
        }}>
          {/* Author Avatar */}
          <div style={{
            width: '40px',
            height: '40px',
            borderRadius: '50%',
            background: '#2d2a26',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            color: 'white',
            fontWeight: 600,
            fontSize: '14px',
            fontFamily: '-apple-system, BlinkMacSystemFont, sans-serif'
          }}>
            {authorName.split(' ').map(n => n[0]).join('').substring(0, 2)}
          </div>
          <div>
            <div style={{ fontWeight: 600, color: '#1a1a1a', fontFamily: '-apple-system, BlinkMacSystemFont, sans-serif' }}>
              {authorName}
            </div>
            <div style={{ fontFamily: '-apple-system, BlinkMacSystemFont, sans-serif' }}>
              {date ? new Date(date).toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' }) : 'Draft'}
            </div>
          </div>
        </div>
      </header>

      {/* Article Body */}
      <article style={{
        fontSize: '1.125rem',
        lineHeight: 1.8,
        color: '#2d2a26'
      }}>
        <div className="prose prose-lg">
          {content ? (
            <ReactMarkdown
              components={{
                h1: ({ children }) => <h1 style={{ fontSize: '2rem', fontWeight: 700, marginTop: '2rem', marginBottom: '1rem' }}>{children}</h1>,
                h2: ({ children }) => <h2 style={{ fontSize: '1.5rem', fontWeight: 600, marginTop: '1.5rem', marginBottom: '0.75rem' }}>{children}</h2>,
                h3: ({ children }) => <h3 style={{ fontSize: '1.25rem', fontWeight: 600, marginTop: '1.25rem', marginBottom: '0.5rem' }}>{children}</h3>,
                p: ({ children }) => <p style={{ marginBottom: '1.25rem' }}>{children}</p>,
                ul: ({ children }) => <ul style={{ marginBottom: '1.25rem', paddingLeft: '1.5rem' }}>{children}</ul>,
                ol: ({ children }) => <ol style={{ marginBottom: '1.25rem', paddingLeft: '1.5rem' }}>{children}</ol>,
                li: ({ children }) => <li style={{ marginBottom: '0.5rem' }}>{children}</li>,
                blockquote: ({ children }) => (
                  <blockquote style={{
                    borderLeft: '4px solid #0d7377',
                    paddingLeft: '1rem',
                    marginLeft: 0,
                    fontStyle: 'italic',
                    color: '#666'
                  }}>
                    {children}
                  </blockquote>
                ),
                a: ({ href, children }) => <a href={href} style={{ color: '#0d7377', textDecoration: 'underline' }}>{children}</a>,
                strong: ({ children }) => <strong style={{ fontWeight: 600 }}>{children}</strong>,
              }}
            >
              {content}
            </ReactMarkdown>
          ) : (
            <p style={{ color: '#9c9691' }}>Your article content will appear here...</p>
          )}
        </div>
      </article>
    </div>
  );
}

// Blog Post Preview
function BlogPreview({ content, title, coreInsight, authorName = 'Your Name', date }: {
  content: string;
  title: string;
  coreInsight?: string;
  authorName?: string;
  date?: string;
}) {
  return (
    <div style={{
      fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
      background: '#f8f9fa',
      padding: '1.5rem',
      borderRadius: '8px',
      minHeight: '500px'
    }}>
      <article style={{
        background: '#ffffff',
        borderRadius: '12px',
        overflow: 'hidden',
        maxWidth: '800px',
        margin: '0 auto',
        boxShadow: '0 1px 3px rgba(0,0,0,0.1)'
      }}>
        {/* Featured Image Placeholder */}
        <div style={{
          height: '240px',
          background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          color: 'white',
          fontSize: '1rem',
          fontWeight: 500
        }}>
          Featured Image
        </div>

        <div style={{ padding: '2rem' }}>
          {/* Category Tag */}
          <div style={{
            display: 'inline-block',
            background: '#e6f3f3',
            color: '#0d7377',
            padding: '4px 12px',
            borderRadius: '4px',
            fontSize: '0.75rem',
            fontWeight: 600,
            textTransform: 'uppercase',
            letterSpacing: '0.05em',
            marginBottom: '1rem'
          }}>
            Blog Post
          </div>

          {/* Title */}
          <h1 style={{
            fontSize: '2rem',
            fontWeight: 700,
            lineHeight: 1.3,
            color: '#1a1a1a',
            marginBottom: '0.75rem'
          }}>
            {title || 'Blog Post Title'}
          </h1>

          {/* Meta */}
          <div style={{
            display: 'flex',
            alignItems: 'center',
            gap: '16px',
            fontSize: '0.875rem',
            color: '#666',
            marginBottom: '1.5rem',
            paddingBottom: '1.5rem',
            borderBottom: '1px solid #eee'
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <div style={{
                width: '32px',
                height: '32px',
                borderRadius: '50%',
                background: '#2d2a26',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                color: 'white',
                fontWeight: 600,
                fontSize: '12px'
              }}>
                {authorName.split(' ').map(n => n[0]).join('').substring(0, 2)}
              </div>
              <span style={{ fontWeight: 500 }}>{authorName}</span>
            </div>
            <span style={{ color: '#ccc' }}>|</span>
            <span>{date ? new Date(date).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }) : 'Draft'}</span>
            <span style={{ color: '#ccc' }}>|</span>
            <span>{Math.ceil(content.split(/\s+/).length / 200)} min read</span>
          </div>

          {/* Intro/Core Insight */}
          {coreInsight && (
            <p style={{
              fontSize: '1.125rem',
              lineHeight: 1.6,
              color: '#444',
              marginBottom: '1.5rem',
              fontWeight: 500
            }}>
              {coreInsight}
            </p>
          )}

          {/* Content */}
          <div style={{
            fontSize: '1rem',
            lineHeight: 1.75,
            color: '#333'
          }}>
            {content ? (
              <ReactMarkdown
                components={{
                  h1: ({ children }) => <h1 style={{ fontSize: '1.75rem', fontWeight: 700, marginTop: '2rem', marginBottom: '1rem' }}>{children}</h1>,
                  h2: ({ children }) => <h2 style={{ fontSize: '1.5rem', fontWeight: 600, marginTop: '1.5rem', marginBottom: '0.75rem' }}>{children}</h2>,
                  h3: ({ children }) => <h3 style={{ fontSize: '1.25rem', fontWeight: 600, marginTop: '1.25rem', marginBottom: '0.5rem' }}>{children}</h3>,
                  p: ({ children }) => <p style={{ marginBottom: '1.25rem' }}>{children}</p>,
                  ul: ({ children }) => <ul style={{ marginBottom: '1.25rem', paddingLeft: '1.5rem' }}>{children}</ul>,
                  ol: ({ children }) => <ol style={{ marginBottom: '1.25rem', paddingLeft: '1.5rem' }}>{children}</ol>,
                  li: ({ children }) => <li style={{ marginBottom: '0.5rem' }}>{children}</li>,
                  blockquote: ({ children }) => (
                    <blockquote style={{
                      borderLeft: '4px solid #667eea',
                      paddingLeft: '1rem',
                      marginLeft: 0,
                      fontStyle: 'italic',
                      color: '#666'
                    }}>
                      {children}
                    </blockquote>
                  ),
                  a: ({ href, children }) => <a href={href} style={{ color: '#667eea', textDecoration: 'underline' }}>{children}</a>,
                }}
              >
                {content}
              </ReactMarkdown>
            ) : (
              <p style={{ color: '#9c9691' }}>Your blog content will appear here...</p>
            )}
          </div>
        </div>
      </article>
    </div>
  );
}

// Twitter/X Thread Preview
function ThreadPreview({ content, authorName = 'Your Name' }: {
  content: string;
  authorName?: string;
}) {
  // Split content into tweets (by double newlines or --- dividers)
  const tweets = content
    .split(/\n\n---\n\n|\n---\n|\n\n\n+/)
    .map(t => t.trim())
    .filter(t => t.length > 0);

  const displayTweets = tweets.length > 0 ? tweets : ['Your thread content will appear here...'];

  // Handle name for display
  const displayName = authorName;
  const handle = '@' + authorName.toLowerCase().replace(/\s+/g, '');

  return (
    <div style={{
      fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
      background: '#000000',
      padding: '1rem',
      borderRadius: '8px',
      minHeight: '500px'
    }}>
      <div style={{ maxWidth: '600px', margin: '0 auto' }}>
        {displayTweets.map((tweet, index) => {
          // Clean markdown from tweet content
          const cleanTweet = tweet
            .replace(/^#+ /gm, '')
            .replace(/\*\*(.+?)\*\*/g, '$1')
            .replace(/\*(.+?)\*/g, '$1')
            .replace(/\[(.+?)\]\((.+?)\)/g, '$1');

          return (
            <div key={index} style={{
              background: '#000000',
              borderBottom: index < displayTweets.length - 1 ? '1px solid #2f3336' : 'none',
              padding: '12px 16px',
              display: 'flex',
              gap: '12px'
            }}>
              {/* Thread line and avatar */}
              <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
                {/* Avatar */}
                <div style={{
                  width: '40px',
                  height: '40px',
                  borderRadius: '50%',
                  background: 'linear-gradient(135deg, #1d9bf0, #1a8cd8)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  color: 'white',
                  fontWeight: 700,
                  fontSize: '14px',
                  flexShrink: 0
                }}>
                  {authorName.split(' ').map(n => n[0]).join('').substring(0, 2)}
                </div>
                {/* Thread connector line */}
                {index < displayTweets.length - 1 && (
                  <div style={{
                    width: '2px',
                    flex: 1,
                    background: '#2f3336',
                    marginTop: '4px'
                  }} />
                )}
              </div>

              {/* Tweet Content */}
              <div style={{ flex: 1, minWidth: 0 }}>
                {/* Header */}
                <div style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '4px',
                  marginBottom: '4px'
                }}>
                  <span style={{
                    fontWeight: 700,
                    color: '#e7e9ea',
                    fontSize: '15px'
                  }}>
                    {displayName}
                  </span>
                  <svg width="18" height="18" viewBox="0 0 24 24" fill="#1d9bf0">
                    <path d="M22.25 12c0-1.43-.88-2.67-2.19-3.34.46-1.39.2-2.9-.81-3.91s-2.52-1.27-3.91-.81c-.66-1.31-1.91-2.19-3.34-2.19s-2.67.88-3.33 2.19c-1.4-.46-2.91-.2-3.92.81s-1.26 2.52-.8 3.91c-1.31.67-2.2 1.91-2.2 3.34s.89 2.67 2.2 3.34c-.46 1.39-.21 2.9.8 3.91s2.52 1.26 3.91.81c.67 1.31 1.91 2.19 3.34 2.19s2.68-.88 3.34-2.19c1.39.45 2.9.2 3.91-.81s1.27-2.52.81-3.91c1.31-.67 2.19-1.91 2.19-3.34zm-11.71 4.2L6.8 12.46l1.41-1.42 2.26 2.26 4.8-5.23 1.47 1.36-6.2 6.77z"/>
                  </svg>
                  <span style={{
                    color: '#71767b',
                    fontSize: '15px'
                  }}>
                    {handle}
                  </span>
                  <span style={{ color: '#71767b', fontSize: '15px' }}>·</span>
                  <span style={{
                    color: '#71767b',
                    fontSize: '15px'
                  }}>
                    {index + 1}/{displayTweets.length}
                  </span>
                </div>

                {/* Tweet Text */}
                <div style={{
                  color: '#e7e9ea',
                  fontSize: '15px',
                  lineHeight: 1.5,
                  whiteSpace: 'pre-wrap',
                  wordBreak: 'break-word'
                }}>
                  {cleanTweet}
                </div>

                {/* Engagement */}
                <div style={{
                  display: 'flex',
                  justifyContent: 'space-between',
                  marginTop: '12px',
                  maxWidth: '425px'
                }}>
                  {[
                    { icon: 'M1.751 10c0-4.42 3.584-8 8.005-8h4.366c4.49 0 8.129 3.64 8.129 8.13 0 2.96-1.607 5.68-4.196 7.11l-8.054 4.46v-3.69h-.067c-4.49.1-8.183-3.51-8.183-8.01zm8.005-6c-3.317 0-6.005 2.69-6.005 6 0 3.37 2.77 6.08 6.138 6.01l.351-.01h1.761v2.3l5.087-2.81c1.951-1.08 3.163-3.13 3.163-5.36 0-3.39-2.744-6.13-6.129-6.13H9.756z', count: '42' },
                    { icon: 'M4.5 3.88l4.432 4.14-1.364 1.46L5.5 7.55V16c0 1.1.896 2 2 2H13v2H7.5c-2.209 0-4-1.79-4-4V7.55L1.432 9.48.068 8.02 4.5 3.88zM16.5 6H11V4h5.5c2.209 0 4 1.79 4 4v8.45l2.068-1.93 1.364 1.46-4.432 4.14-4.432-4.14 1.364-1.46 2.068 1.93V8c0-1.1-.896-2-2-2z', count: '12' },
                    { icon: 'M16.697 5.5c-1.222-.06-2.679.51-3.89 2.16l-.805 1.09-.806-1.09C9.984 6.01 8.526 5.44 7.304 5.5c-1.243.07-2.349.78-2.91 1.91-.552 1.12-.633 2.78.479 4.82 1.074 1.97 3.257 4.27 7.129 6.61 3.87-2.34 6.052-4.64 7.126-6.61 1.111-2.04 1.03-3.7.477-4.82-.561-1.13-1.666-1.84-2.908-1.91zm4.187 7.69c-1.351 2.48-4.001 5.12-8.379 7.67l-.503.3-.504-.3c-4.379-2.55-7.029-5.19-8.382-7.67-1.36-2.5-1.41-4.86-.514-6.67.887-1.79 2.647-2.91 4.601-3.01 1.651-.09 3.368.56 4.798 2.01 1.429-1.45 3.146-2.1 4.796-2.01 1.954.1 3.714 1.22 4.601 3.01.896 1.81.846 4.17-.514 6.67z', count: '156' },
                    { icon: 'M8.75 21V3h2v18h-2zM18 21V8.5h2V21h-2zM4 21l.004-10h2L6 21H4zm9.248 0v-7h2v7h-2z', count: '2.4K' },
                  ].map((action, i) => (
                    <button
                      key={i}
                      style={{
                        background: 'transparent',
                        border: 'none',
                        display: 'flex',
                        alignItems: 'center',
                        gap: '8px',
                        color: '#71767b',
                        fontSize: '13px',
                        cursor: 'pointer',
                        padding: '0'
                      }}
                    >
                      <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
                        <path d={action.icon}/>
                      </svg>
                      {index === 0 && <span>{action.count}</span>}
                    </button>
                  ))}
                </div>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

// Newsletter Preview
function NewsletterPreview({ content, title, coreInsight, authorName = 'Your Name' }: {
  content: string;
  title: string;
  coreInsight?: string;
  authorName?: string;
}) {
  return (
    <div style={{
      fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
      background: '#e5e5e5',
      padding: '1.5rem',
      borderRadius: '8px',
      minHeight: '500px'
    }}>
      {/* Email Container */}
      <div style={{
        maxWidth: '600px',
        margin: '0 auto',
        background: '#ffffff',
        borderRadius: '4px',
        overflow: 'hidden',
        boxShadow: '0 2px 8px rgba(0,0,0,0.1)'
      }}>
        {/* Email Header */}
        <div style={{
          background: '#2d2a26',
          padding: '24px 32px',
          textAlign: 'center' as const
        }}>
          <div style={{
            display: 'inline-block',
            background: '#ffffff',
            color: '#2d2a26',
            padding: '8px 16px',
            borderRadius: '4px',
            fontWeight: 700,
            fontSize: '14px',
            letterSpacing: '0.05em'
          }}>
            NEWSLETTER
          </div>
        </div>

        {/* Email Body */}
        <div style={{ padding: '32px' }}>
          {/* Title */}
          <h1 style={{
            fontSize: '1.75rem',
            fontWeight: 700,
            lineHeight: 1.3,
            color: '#1a1a1a',
            marginBottom: '1rem',
            textAlign: 'center' as const
          }}>
            {title || 'Newsletter Title'}
          </h1>

          {/* Subtitle/Core Insight */}
          {coreInsight && (
            <p style={{
              fontSize: '1rem',
              color: '#666',
              textAlign: 'center' as const,
              marginBottom: '1.5rem',
              fontStyle: 'italic'
            }}>
              {coreInsight}
            </p>
          )}

          {/* Divider */}
          <div style={{
            height: '1px',
            background: '#e8e6e1',
            margin: '1.5rem 0'
          }} />

          {/* Greeting */}
          <p style={{
            fontSize: '1rem',
            color: '#333',
            marginBottom: '1rem'
          }}>
            Hi there,
          </p>

          {/* Content */}
          <div style={{
            fontSize: '1rem',
            lineHeight: 1.7,
            color: '#333'
          }}>
            {content ? (
              <ReactMarkdown
                components={{
                  h1: ({ children }) => <h1 style={{ fontSize: '1.5rem', fontWeight: 700, marginTop: '1.5rem', marginBottom: '0.75rem', color: '#1a1a1a' }}>{children}</h1>,
                  h2: ({ children }) => <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginTop: '1.25rem', marginBottom: '0.5rem', color: '#1a1a1a' }}>{children}</h2>,
                  h3: ({ children }) => <h3 style={{ fontSize: '1.1rem', fontWeight: 600, marginTop: '1rem', marginBottom: '0.5rem', color: '#1a1a1a' }}>{children}</h3>,
                  p: ({ children }) => <p style={{ marginBottom: '1rem' }}>{children}</p>,
                  ul: ({ children }) => <ul style={{ marginBottom: '1rem', paddingLeft: '1.5rem' }}>{children}</ul>,
                  ol: ({ children }) => <ol style={{ marginBottom: '1rem', paddingLeft: '1.5rem' }}>{children}</ol>,
                  li: ({ children }) => <li style={{ marginBottom: '0.5rem' }}>{children}</li>,
                  blockquote: ({ children }) => (
                    <blockquote style={{
                      borderLeft: '4px solid #0d7377',
                      paddingLeft: '1rem',
                      marginLeft: 0,
                      marginBottom: '1rem',
                      fontStyle: 'italic',
                      color: '#666',
                      background: '#f9f9f9',
                      padding: '1rem',
                      borderRadius: '0 4px 4px 0'
                    }}>
                      {children}
                    </blockquote>
                  ),
                  a: ({ href, children }) => (
                    <a href={href} style={{ color: '#0d7377', textDecoration: 'underline' }}>{children}</a>
                  ),
                  hr: () => <hr style={{ border: 'none', borderTop: '1px solid #e8e6e1', margin: '1.5rem 0' }} />,
                }}
              >
                {content}
              </ReactMarkdown>
            ) : (
              <p style={{ color: '#9c9691' }}>Your newsletter content will appear here...</p>
            )}
          </div>

          {/* Sign-off */}
          <div style={{ marginTop: '2rem' }}>
            <p style={{ marginBottom: '0.5rem' }}>Best,</p>
            <p style={{ fontWeight: 600 }}>{authorName}</p>
          </div>
        </div>

        {/* Email Footer */}
        <div style={{
          background: '#f8f8f8',
          padding: '24px 32px',
          textAlign: 'center' as const,
          fontSize: '0.75rem',
          color: '#999'
        }}>
          <p style={{ marginBottom: '0.5rem' }}>
            You received this email because you subscribed to our newsletter.
          </p>
          <p>
            <a href="#" style={{ color: '#0d7377', textDecoration: 'underline' }}>Unsubscribe</a>
            {' | '}
            <a href="#" style={{ color: '#0d7377', textDecoration: 'underline' }}>View in browser</a>
          </p>
        </div>
      </div>
    </div>
  );
}

// Main PlatformPreview Component
export default function PlatformPreview({
  content,
  title,
  coreInsight,
  type,
  authorName = 'Your Name',
  authorTitle = 'Your Title',
  date,
  images,
  slug
}: PlatformPreviewProps) {
  switch (type) {
    case 'linkedin-post':
      return <LinkedInPreview content={content} authorName={authorName} authorTitle={authorTitle} images={images} slug={slug} />;
    case 'article':
      return <ArticlePreview content={content} title={title} coreInsight={coreInsight} authorName={authorName} date={date} />;
    case 'blog-post':
      return <BlogPreview content={content} title={title} coreInsight={coreInsight} authorName={authorName} date={date} />;
    case 'thread':
      return <ThreadPreview content={content} authorName={authorName} />;
    case 'newsletter':
      return <NewsletterPreview content={content} title={title} coreInsight={coreInsight} authorName={authorName} />;
    default:
      return (
        <div style={{
          padding: '2rem',
          textAlign: 'center',
          color: '#9c9691',
          background: '#faf9f7',
          borderRadius: '8px',
          border: '1px solid #e8e6e1',
          minHeight: '500px',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center'
        }}>
          No platform preview available for this content type.
        </div>
      );
  }
}
