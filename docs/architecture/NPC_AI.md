# NPC / Social / Optional LLM Architecture

## Principle

NPCs must remain intelligent and playable offline. External AI is enrichment, never authority or a hard dependency.

## NPC stack

```text
NPCDefinition
NPCRuntimeState
NPCMemory
RelationshipGraph
SkillProfile
Schedule
Utility/priority selection
LimboAI execution
Dialogue Manager deterministic dialogue
Local SocialDirector
Optional AIOrchestrator
```

## Relationships

Store multiple dimensions instead of only a single friendship score. Candidate dimensions:
- affection
- trust
- respect
- attraction
- resentment
- fear
- familiarity

Friend/crush/partner/enemy-like labels are derived states with explicit narrative exceptions where needed.

## NPC generation

NPC generation is pre-procedural: archetypes, weighted compatible traits, skill biases, visual profiles and narrative constraints prevent nonsense combinations while keeping variety.

Chapter 1 caps meaningful village population around ten.

## Social Director

The local SocialDirector detects opportunities from schedules, relationships, recent memories and world state.

Most events are resolved locally from templates/rules. Some candidates may request optional LLM enrichment.

## LLM pipeline

Never:
`LLM -> world mutation`.

Always:
`compressed Memory Capsule -> provider -> structured SocialIntent -> schema check -> local semantic validator -> event planner/queue -> LimboAI/Dialogue Manager/local systems`.

A provider may propose topics, tones, microevents, invitations or short text variants. Generated results can be cached in the save.

## Provider abstraction

Planned interface:
- disabled/local-only provider;
- OpenAI-compatible HTTP provider;
- provider-specific adapters only where necessary;
- custom endpoint/proxy support later.

Player-owned API credentials are never shipped in the repository. Networking failure must degrade silently to local behavior.

## Scheduling/budget

LLM work is asynchronous and priority-based. Important relationships/story NPCs may receive higher opportunity weight, while a fairness/debt mechanism prevents low-priority NPCs from never receiving enrichment.
