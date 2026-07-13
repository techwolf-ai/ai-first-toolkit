| | |
| --- | --- |
| Epic | APP-0000 |
| Product opportunity | Faster job-to-employee matching |
| Version | 1 |
| AI feature | No |

## Delivery Stakeholders

| Role | Person |
| ---- | ------ |
| PM | A. Example |
| EM | B. Example |

# Product Specifications

## 1. What value does this bring?

### 1.1. Problem

Recruiters cannot see, for a given job, which internal employees best match it.

### 1.2. Solution

Surface a ranked list of matching employees for each job.

### 1.3. Objectives

Reduce time-to-shortlist for internal mobility.

### 1.4. Key results / metrics

| Metric | Target |
| ------ | ------ |
| Time-to-shortlist | −30% |

## 2. User stories

**Must haves**

| User story | In scope |
| ---------- | -------- |
| As a recruiter, I want a ranked match list for a job, so that I can shortlist faster. | ✓ |

**Won't haves**

| User story | Reason |
| ---------- | ------ |
| Cross-company matching | Out of scope for internal mobility. |

## 3. Functional requirements

### 3.1. Inputs

| Input | Source | Notes |
| ----- | ------ | ----- |
| Job profile | Job service | Refreshed nightly |

### 3.2. Endpoints

| Endpoint | Customer-visible behaviour | Priority |
| -------- | -------------------------- | -------- |
| `GET /jobs/{id}/matching_employees` | Returns the top-N matching employees for a job. | Must-have |

## 4. Design decisions for product approval

### 4.1. *Ranking surface*

Proposed: show top 20. Rationale: fits the shortlist workflow.

## 5. Rollout & Adoption

### 5.1. Customer demand

Two pilot customers have requested internal-mobility matching.
