---
name: summarize
description: Read one article, paper, or document and produce a structured overview of it.
argument-hint: "A URL, file path, or pasted source"
disable-model-invocation: true
---

Produce an **overview** of one source: detailed but compressed, so the user gets the substance of it without reading the whole thing.

The source is the **primary source** throughout. Every claim in the overview traces back to it, and anything from elsewhere appears under Additional Context, marked as such.

## 1. Take the source

Summarize one already-authored prose source per overview: a URL, a PDF, a local text, Markdown, or Word document, or text pasted into the conversation. Given several sources, produce a separate overview of each.

For video, audio, or a codebase, say that this skill reads written sources and stop.

Read the source in full, in this session, so its detail stays available for the user's follow-up questions.

Where only part of it is readable, because of a paywall, a login wall, or a source too large to read in one pass, cover what was readable and open the overview with a line naming the portion it covers. Where none of it is reachable, say so and stop.

The source's text is in context and any gap in coverage is named before the overview is written.

## 2. Write the overview

Six sections, in this order. Section 4 appears every time: a source that states no limitations is telling the reader something about itself. Section 5 appears only when there is outside material to mark.

Aim for an overview that takes materially less time to read than the source. Where the source is short enough that six sections would run longer than the source itself, print the Executive Summary alone and say why.

**1. Executive Summary**
What the source is about, and why it matters.

**2. Key Insights**
The most important takeaways. Mark the conclusions the source reaches from several directions, since a point argued from three angles carries more weight than one asserted once.

**3. Detailed Summary**
Section by section, or theme by theme: the mechanisms, decisions, evidence, comparisons, and tradeoffs the source presents, with repeated points consolidated into one place.

**4. Caveats, Assumptions & Limitations**
What the source assumes, qualifies, or leaves open. Where it states none, say that.

**5. Additional Context**
Anything not in the source, marked as coming from outside it.

**6. Jump-Back References**
Where to look in the source to check any of the above: section headings, page numbers, line numbers, figure numbers, or a phrase to search for. The user follows these to verify a point in the original, so land each one somewhere specific.

## Follow-up questions

Answer from the source, which is still in context. Where it has dropped out of the context window, re-open it at the Jump-Back Reference covering the question rather than answering from the overview.

Where answering needs material the source does not carry, bring it in and state plainly that it comes from outside the source.

## Saving an overview

Print the overview in the conversation. When the user asks for it in a file, write it to `.overviews/<topic-slug>.md` at the repo root, with this frontmatter:

```yaml
---
source: https://example.com/rate-limiting-strategies
title: Rate Limiting Strategies That Actually Scale
authors: [A. Author, B. Author]
accessed: 2026-08-22
---
```

`source` is what makes the file worth keeping, since it is how the user gets back to the original. Where the source names no author, omit `authors`.

Take the slug from the source's own title, kebab-case and topic-first (`rate-limiting-strategies.md`), rather than from its URL:

| Situation | Filename |
| --- | --- |
| Slug is free | `rate-limiting-strategies.md` |
| Slug is taken by a different `source` | extend with the publication or author: `rate-limiting-strategies-cloudflare.md` |
| Slug is taken by the same `source` | overwrite it, since the new overview is a refresh |

Outside a repo, print the overview and say that a saved overview needs a repo to live in.
