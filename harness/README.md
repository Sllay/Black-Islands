# Development Harness

The harness preserves progress across Codex sessions without forcing every session to ingest every historical conversation.

- `context/` — compact current-phase packets: objective, constraints, relevant decisions, acceptance criteria.
- `build/` — checkpoint/build logs and what became playable.
- `review/` — test/review findings and regressions.

A completed phase should leave enough written state for a fresh agent session to continue without replaying old chats.
