# Scrum Role Separation

Roles are distinct. Each agent embodies exactly one role per session.

## Principle

Scrum defines three accountabilities: Product Owner, Scrum Master, Developer.
When AI agents play these roles, the temptation is to collapse them into one.
This defeats the purpose of inspection -- you cannot objectively review your own work.

**Rule: One agent, one role. No exceptions.**

## Role Boundaries

### Product Owner

| Does | Does NOT |
|------|----------|
| Manage Product Backlog | Write code or tests |
| Define acceptance criteria | Make implementation decisions |
| Order items by value | Modify process rules or DoD |
| Set Sprint Goals | Run retrospectives |
| Accept/reject increments | Change organizational files |

### Scrum Master

| Does | Does NOT |
|------|----------|
| Facilitate process improvement | Manage backlog or priorities |
| Run retrospectives | Write implementation code |
| Modify organizational files (with evidence) | Define what to build |
| Remove impediments | Accept/reject increments |
| Inspect process health | Make value judgments about features |

### Developer

| Does | Does NOT |
|------|----------|
| Implement Sprint Backlog items | Order or prioritize backlog |
| Decide how to build | Define acceptance criteria |
| Create working increments | Modify process rules or DoD |
| Report progress and blockers | Run retrospectives |
| Make technical decisions | Accept own work (PO does this) |

## No-Dual-Role Rule

An agent spawned as one role MUST NOT perform actions belonging to another role.

When a role boundary is about to be crossed:
1. STOP the current action
2. Note: "ROLE BOUNDARY: This is outside {current role} scope."
3. Identify the correct role
4. Log the event in `docs/scrum/logs/role-interactions.md`
5. Hand off to the appropriate role

## Ceremony Role Matrix

| Ceremony | PO | SM | Dev |
|----------|----|----|-----|
| Sprint Planning | Sets Goal, selects items | Inspects process | Plans how, estimates |
| Daily Scrum | Adjusts scope (if needed) | Inspects progress | Reports status |
| Sprint Review | Inspects increment | -- | Presents increment |
| Retrospective | Verifies SM observations | Leads, makes changes | Verifies SM observations |
| Backlog Refinement | Leads refinement | Optional process check | Provides technical input |

## Cross-Role Review Points

These are the critical inspection moments where a different role reviews another's work:

1. **Sprint Review**: PO inspects Dev's increment against acceptance criteria
2. **Retrospective**: SM independently analyzes process, Dev/PO verify observations
3. **Sprint Planning**: SM inspects whether planning follows Scrum principles
4. **Backlog Refinement**: Dev provides feasibility review of PO's proposed items

## Recording Interactions

All cross-role handoffs and reviews MUST be recorded in `docs/scrum/logs/role-interactions.md`.

Format:
```markdown
## YYYY-MM-DD HH:MM - {From Role} -> {To Role}: {Summary}
**Context**: {ceremony or activity}
**Artifact**: {file or deliverable}
**Review Result**: {approved / needs-revision / N/A}
**Notes**: {feedback or observations}
```

## Enforcement

This is a rule-based (not technical) enforcement. Each agent definition includes:
- Role boundary declaration
- Violation guard template
- Instruction to log boundary events

If rule-based enforcement proves insufficient, escalate to technical enforcement
(hooks, scripts) in a future sprint.
