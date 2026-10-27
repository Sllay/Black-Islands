# ADR-0003 — Local-first NPC AI

Status: Accepted

## Decision

Core NPC simulation is offline/local. LimboAI is the preferred behavior execution layer; deterministic dialogue and Black Island social systems remain authoritative.

External LLM providers are optional enrichment only. Their outputs are proposals validated by local code before entering an event queue.

## Why

The game must work offline, remain deterministic enough to debug/save and must not grant an external model authority over inventories, deaths, relationships or other persistent state.
