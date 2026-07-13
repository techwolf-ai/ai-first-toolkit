# Diagram with a pastel fill that declares color

The no-color rule would pass this (color: is present), but the pastel fill is still
light-on-light on the dark reviewer, so the pastel blocklist must catch it.

```mermaid
flowchart TD
    A[Caller] --> B[Service]
    classDef new fill:#E8F5E9,stroke:#333,color:#000
    class B new
```
