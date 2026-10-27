# Subagent Rules

## Allowed high-value uses

- independent technical research;
- implementation in a file/module set that does not overlap another agent;
- independent test/review of an implementation;
- profiling/analysis whose output is a compact report.

## Avoid delegation when

- the task depends tightly on the immediately preceding implementation;
- the parent already has the needed context;
- delegation costs more context than doing the task directly;
- multiple agents would modify the same subsystem/files.

## Limits

- normally 2–3 concurrent subagents maximum;
- depth 1 only unless explicitly authorized by a phase plan;
- assign explicit file ownership/scope;
- require a concise handoff, not a transcript.

## Handoff format

1. Outcome
2. Files changed/read
3. Validation/tests run
4. Risks/assumptions
5. Next action if any
