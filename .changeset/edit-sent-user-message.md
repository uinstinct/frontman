---
"@frontman-ai/client": minor
---

Add editing of an already-sent user message. Editing truncates the message's turn and everything after it, then re-runs the conversation from the edited text using the currently selected model and agent. Attachments and annotations are preserved; interactions are never mutated, so the truncation is recorded as its own event and applied as a projection.
