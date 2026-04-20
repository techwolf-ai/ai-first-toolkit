---
title: "Password Policy"
description: "Minimum length, complexity, and MFA rules for account access"
category: security
tags: [password, mfa, authentication]
sources: ["Company handbook §4.2"]
last_updated: "2026-04-20"
related:
  - security/access-control.md
---

## Requirements

- Passwords must be a minimum of 12 characters in length.
- Passwords must include at least one upper-case letter, one lower-case letter, one number, and one special character.
- Passwords must not contain the user's name, username, or other easily guessable personal information.

## Multi-Factor Authentication

Multi-factor authentication is required for every account that accesses systems containing Confidential or Secret data, and for every user with elevated privileges.

MFA must use at least two different authentication factors: something the user knows (a password), something the user possesses (a security token or mobile device), or something inherent to the user (a fingerprint).

## Rotation

User passwords do not need to be rotated on a schedule. Passwords for privileged accounts must be rotated every 90 days.

## Why This Entry Looks Like This

- Every claim is a short, self-contained, quotable sentence.
- Specific numbers (12 characters, 90 days) are preserved; no rounding.
- Headers group related rules so `/kb-answer` can cite the right block.
- `related:` points to other entries that an answer on this topic would probably touch.

Replace this file with a real entry from your domain, or delete it once your KB has a few real entries.
