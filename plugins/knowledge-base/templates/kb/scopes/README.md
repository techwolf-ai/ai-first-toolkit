# Scopes

Scopes let you customize which KB content is relevant for a specific context. For example, if you have different product lines or customer segments, a scope file tells the answering skill what to emphasize and what to exclude.

## How Scopes Work

1. Base answers come from the full KB
2. When a scope is active, `in_scope` items are emphasized and `out_of_scope` items are excluded
3. `notes` provide guidance on tone, emphasis, or talking points
4. `overrides` replace specific answers entirely (rarely needed)

## Creating a Scope

Create a YAML file in this directory:

```yaml
name: "Scope Name"
description: "When to use this scope"

in_scope:
  - "Feature or topic to emphasize"
  - "Another relevant capability"

out_of_scope:
  - "Feature not relevant in this context"

overrides: {}

notes:
  - "Guidance for answering in this context"
  - "Talking points to hit"
```

## Example

A SaaS company might have scopes for different customer segments:

**enterprise-customer.yaml**
```yaml
name: "Enterprise Customer"
description: "For enterprise prospects (1000+ employees)"

in_scope:
  - "SSO and SAML integration"
  - "Custom SLA options"
  - "Dedicated support"

out_of_scope:
  - "Self-serve pricing"
  - "Free tier features"

notes:
  - "Emphasize security certifications"
  - "Mention dedicated account management"
```
