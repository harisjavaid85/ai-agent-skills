---
"ai-agent-skills": patch
---

Stop `/to-tickets` writing a `Blocked by` body section where the tracker links blockers natively.

On a tracker with native dependencies the link is the canonical, UI-rendered record, and a body copy beside it is a second place for the two to disagree, and a reader trusts whichever they see first. The section is now written only where the platform has no native relationship, which is also the only case in which anything downstream has to parse it. Local file trackers are unchanged.
