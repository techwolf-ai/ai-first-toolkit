<!--
MR description template for the `implement-ticket` skill.
The skill renders this file by substituting every `{{placeholder}}` and passes
the result to `scripts/forge/create-mr.sh` (via a temp file or stdin).
Placeholders:
  {{ticket_key}}        ticket key, e.g. ABC-123
  {{ticket_title}}      ticket summary
  {{ticket_url}}        link to the ticket
  {{summary}}           one short paragraph: what changed and why
  {{test_plan}}         how this was verified (tests added/run, commands)
  {{spec_anchor_url}}   heading-anchor link to the spec section, e.g.
                        .../engineering-spec.md#23-storage-model  (never #L115)
  {{acceptance_criteria}}  the ticket AC, as a checklist
-->

## Summary

{{summary}}

## Test plan

{{test_plan}}

## Spec link

[{{ticket_key}} spec section]({{spec_anchor_url}})

## Ticket

[{{ticket_key}} — {{ticket_title}}]({{ticket_url}})

Acceptance criteria:

{{acceptance_criteria}}
