> Spec section: https://gitlab.com/acme/x/-/blob/<GITSHA>/docs/development/specs/matching-employees/engineering-spec.md#21-architecture

## Acceptance criteria

- `GET /jobs/{id}/matching_employees` returns the top-N matching employees for a job.
- The response is capped at 20 results by default.
- p95 latency < 300 ms at 50 rps.

## Dependencies

- Blocks: APP-0002
- BlockedBy: (none)
