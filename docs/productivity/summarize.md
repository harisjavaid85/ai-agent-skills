## What it does

`/summarize` reads one article, paper, or document you point it at and gives you back a structured **overview** of it: what it says, what matters in it, what it hedges, and where to look in the original to check any of that. The point is to get the substance of a long source without spending the time to read it.

The overview never stands in for the source. Every claim traces back to what the source actually says, anything from outside it is labelled as coming from outside, and the last section is a list of jump-back references so you can go read the paragraph that a summary line came from. That is what separates it from pasting a link into a chat box and hoping.

## When to reach for it

You invoke this by typing `/summarize`, and the agent won't reach for it on its own.

| Situation | Skill |
| --- | --- |
| You have one source in hand and want its substance fast | `/summarize` |
| You have a question and don't know which sources answer it | [research](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/research.md) |
| You want the current conversation condensed for another agent | [handoff](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/productivity/handoff.md) |
| You want to understand a codebase | [bootstrap-context](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/bootstrap-context.md) |

It takes a URL, a PDF, a local text or Markdown or Word document, or text you paste in. One source per overview: hand it three URLs and you get three overviews, not a merged one.

## The overview

Six sections, always in the same order, so you learn where to look:

| Section | What it carries |
| --- | --- |
| Executive Summary | what the source is about and why it matters |
| Key Insights | the takeaways, with the conclusions the source reaches from several directions marked as such |
| Detailed Summary | section by section: mechanisms, decisions, evidence, tradeoffs |
| Caveats, Assumptions & Limitations | what it assumes or leaves open, printed even when the answer is "it states none" |
| Additional Context | anything from outside the source, and only that |
| Jump-Back References | headings, page numbers, figures, phrases to search for |

The last three do the unglamorous work. **Additional Context** is a quarantine: it keeps the model's own knowledge from quietly blending into what the author wrote. **Caveats** prints every time because a source that hedges nothing is telling you something about itself. And the **jump-back references** are the reason the overview is safe to trust, since any line you doubt is one lookup away from the paragraph that produced it.

After the overview lands, the source is still in the [context window](https://www.aihero.dev/ai-coding-dictionary/context-window), so follow-up questions get answered from the source itself rather than from the summary. Reading the overview and then asking three sharpening questions is the intended way to use it, not a workaround.

Where a source is paywalled, behind a login, or too long to read in one pass, the overview opens by naming the portion it covers rather than presenting a partial read as a complete one.

## Where it lands

By default the overview is printed in the conversation and nothing is written to disk. Ask for it in a file and it goes to `.overviews/<topic-slug>.md` at the repo root, with `source`, `title`, `authors`, and `accessed` in the frontmatter. The slug comes from the source's title rather than its URL, so `.overviews/` reads as a table of contents rather than a pile of citekeys. Outside a repo, you get the overview in the conversation and a note that a saved one needs a repo to live in.

`.overviews/` is gitignored, like `.plans/` and `.handoffs/`.

## Common questions

**How is this different from `/research`?**
`/summarize` condenses one artifact you already have. `/research` answers a question you have, by going and finding sources that bear on it. If you can paste the link, you want this one; if you'd have to go looking first, you want research.

**Why won't it summarize my current session?**
Because a conversation is a [primary source](https://www.aihero.dev/ai-coding-dictionary/primary-source) and an article is not. Summarizing someone's blog post costs nothing, since the post is still at its URL. Summarizing the session you're in replaces the reasoning as it happened with a flattened account of it, and the next session is then confidently wrong about whatever got flattened. That trade-off is what the phase-boundary options in [ask-author](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/ask-author.md) exist to weigh, and `handoff` is the skill for when you decide to pay it.

**Can it do a YouTube talk, a podcast, or a repo?**
No. It reads already-authored prose. Video and audio would need transcription, and a codebase is a different job with different failure modes.

**Why is `.overviews/` gitignored rather than committed?**
So the directory stays a personal scratch pile you can accumulate in freely. An overview worth sharing is worth promoting somewhere durable and writing properly, which is a deliberate step rather than a side effect of running a skill.

## It's working if

- You can decide whether the source is worth reading in full, from the overview alone.
- The follow-up questions you ask after reading it are sharper than the ones you'd have asked before.
- When you chase a jump-back reference into the original, it lands on the passage the overview drew from.
- Facts the source never stated appear under Additional Context, and nowhere else.
- A paywalled or truncated read says so at the top instead of reading like a complete summary.

## Where it fits

A reach-for-it-anytime standalone, off every flow. Its nearest neighbour is [research](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/research.md), which covers the other half of reading legwork (a question across sources you don't have yet, rather than one source you do), and [handoff](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/productivity/handoff.md), which condenses a conversation rather than a document. For the whole map, see [ask-author](https://github.com/harisjavaid85/ai-agent-skills/blob/main/docs/engineering/ask-author.md).
