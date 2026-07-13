# Product Specifications

## 1. What value does this bring?

### 1.1. Problem

Support agents retype the same macro reply dozens of times a day.

### 1.2. Solution

A one-click "insert canned reply" action in the agent console.

## 2. User stories

**Must haves**

| User story | In scope |
| ---------- | -------- |
| As a support agent, I want to insert a saved reply in one click, so that I stop retyping. | ✓ |

## 3. Functional requirements

### 3.1. Inputs

| Input | Source | Notes |
| ----- | ------ | ----- |
| Saved replies | Console settings | Per-team list |

## Engineering notes

- Store replies on the existing team-settings record; no new table.
