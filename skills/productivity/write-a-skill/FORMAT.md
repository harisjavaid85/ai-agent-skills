# Reference formats

The formats a skill draft reproduces.

## Skill structure

```
skill-name/
├── SKILL.md           # Behaviour: instructions, process, decision rules (required)
├── VOCABULARY.md      # Vocabulary: templates/formats/specs (only if needed)
└── scripts/           # Utility scripts (only if needed)
    └── helper.js
```

## SKILL.md template

```md
---
name: skill-name
description: Brief description of capability. Use when [specific triggers].
---

# Skill Name

## Vocabulary

[Only if a few terms/mappings; otherwise link to VOCABULARY.md]

## Quick start

[Minimal working example]

## Workflows

[Step-by-step processes with checklists for complex tasks]
```

## Description format

- Max 1024 chars
- Third person
- First sentence: what it does
- Second sentence: "Use when [specific triggers]"

**Good**:

```
Extract text and tables from PDF files, fill forms, merge documents. Use when working with PDF files or when user mentions PDFs, forms, or document extraction.
```

**Bad**: `Helps with documents.` — gives the agent no way to distinguish this from other document skills.
