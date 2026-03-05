// Content workflow types

export type ContentStage = '01-ideas' | '02-drafts' | '03-published';

export type ContentType =
  | 'linkedin-post'
  | 'article'
  | 'thread'
  | 'newsletter'
  | 'blog-post'
  | 'opinion';

export type ContentStatus =
  | 'concept'
  | 'outline'
  | 'draft'
  | 'review'
  | 'ready'
  | 'published';

export interface FeedbackEntry {
  date: string;
  reviewer: string;
  version: string;
  feedback: string;
  actionTaken?: string;
}

export interface EngagementMetrics {
  views?: number;
  reactions?: number;
  comments?: number;
  reposts?: number;
  lastUpdated?: string;  // ISO timestamp when metrics were recorded
}

export interface ContentImage {
  path: string;
  filename: string;
  alt?: string;
}

export interface ContentMetadata {
  stage: ContentStage;
  type: ContentType;
  title: string;
  slug: string;
  created: string;
  lastUpdated: string;
  status: ContentStatus;
  audience?: string;
  coreInsight?: string;
  keyMessage?: string;
  tags: string[];
  images?: ContentImage[];
  feedbackLog: FeedbackEntry[];

  // Draft-specific
  draftDate?: string;
  currentVersion?: string;

  // Published-specific
  publishedDate?: string;
  finalVersion?: string;
  channel?: string;
  url?: string;
  engagement?: EngagementMetrics | null;
  notes?: string;
}

export interface ContentFile {
  path: string;
  filename: string;
  stage: ContentStage;
  metadata: ContentMetadata;
  content: string;
  hasSuggestions?: boolean;
}

// Suggestion types

export type SuggestionType = 'replace' | 'insert' | 'delete' | 'comment';
export type SuggestionStatus = 'pending' | 'accepted' | 'rejected' | 'applied';
export type SuggestionPriority = 'high' | 'medium' | 'low';

export interface Suggestion {
  id: string;
  type: SuggestionType;
  status: SuggestionStatus;
  lineStart: number;
  lineEnd: number;

  // For replace/delete
  original?: string;

  // For replace/insert
  suggested?: string;

  // For comment
  comment?: string;

  reason: string;
  priority: SuggestionPriority;

  // Tracking
  createdAt: string;
  acceptedAt?: string;
  rejectedAt?: string;
  rejectionReason?: string;
}

export interface SuggestionFile {
  fileVersion: string;
  created: string;
  reviewer: string;
  overallAssessment: 'ready' | 'needs-revision' | 'needs-major-work';
  suggestions: Suggestion[];
}

// Git types

export interface GitStatus {
  branch: string;
  changes: GitChange[];
  ahead: number;
  behind: number;
}

export interface GitChange {
  path: string;
  status: string; // 'M' | 'A' | 'D' | 'R' | '?'
  staged: boolean;
}

export interface GitCommit {
  hash: string;
  message: string;
  author: string;
  date: string;
}

// API response types

export interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: string;
}

export interface ContentListResponse {
  stage: ContentStage;
  files: ContentFile[];
}

export interface SuggestionUpdateRequest {
  suggestionId: string;
  status: SuggestionStatus;
  rejectionReason?: string;
}
