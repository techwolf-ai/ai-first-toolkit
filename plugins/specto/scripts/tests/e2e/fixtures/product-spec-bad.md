# Product Specifications

## 3. Functional requirements

### 3.2. Endpoints

Full contract (this belongs in the engineering spec, not here):

```sql
CREATE TABLE match_cache (job_id int, employee_id int);
```

The per-tenant flag is stored in `customfield_10105`.

### 3.3. Storage model

Results are cached in Postgres with a 24h TTL.

## 1. What value does this bring?

### 1.1. Problem

(Value section placed AFTER the functional requirements — wrong order.)

## 2. User stories

No MoSCoW buckets here — just a flat list.

- The recruiter sees a match list.
