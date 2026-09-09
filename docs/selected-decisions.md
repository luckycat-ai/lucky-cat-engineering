# Selected decisions

Six decisions that shaped the system, in the form they were recorded: what was
decided, what else was on the table, and what it cost. The internal records
carry more; these are the ones that transfer.

---

## 1 — One repository for tightly coupled products

**Decision.** The owner app, the customer ordering app and the field-sales
copilot share one repository. The AI receptionist for trades does not.

**Context.** They are sold separately, so the instinct is to split them. But a
diner's order in the customer app appears on the owner's screen through the same
tables, the same policies, the same realtime channels and the same deployment.

**Alternatives.** A repository per product, or a monorepo with a package manager
and workspace tooling.

**Why.** A repository boundary should follow **what changes together**, not what
appears on separate invoices. Splitting these would mean a schema change lands in
two repositories, in two pull requests, with a window in which the two disagree —
and that window is where tenant-isolation bugs live. The receptionist product
shares no schema and no release, so it stays out.

**Trade-off.** The repository is large and a newcomer needs a map to know what is
live. That map exists, is machine-readable, and a gate fails when it stops
matching the tree — the cost paid deliberately rather than absorbed.

---

## 2 — One codebase, N tenants

**Decision.** A store is a row and a configuration. Never a branch, never a fork,
never a per-client deployment.

**Alternatives.** A fork per client, which is how the first client was almost
onboarded.

**Why.** A fix applied once reaches every tenant. A fork means a security patch
has to be remembered N times, and the Nth is the one that gets missed.

**Trade-off.** Every feature must be configurable rather than hardcoded, which is
more work per feature. One legacy fork still exists, frozen, and it is the living
argument for the rule: it did not receive a fix the canonical code did.

---

## 3 — Row-Level Security is the tenant boundary

**Decision.** Isolation is enforced in the database, not in the application.

**Alternatives.** Filtering in an API layer, or a per-tenant schema.

**Why.** A missing application filter fails **open** — it returns everyone's rows
with no error. A missing grant fails **closed** — the query returns nothing, and
that is visible immediately. Choose the failure mode you can survive.

**Trade-off.** Policies are harder to read than application code, and a policy
calling a helper per row has a real performance cost that had to be found and
fixed. Both are worth it for a boundary that also holds for a database console
and a one-off script.

---

## 4 — `main` and `production` are different things

**Decision.** Trunk and the production pointer are separate. Merging publishes
nothing; a release is an explicit command.

**Alternatives.** Keep trunk as the deploy branch — simpler, and it worked.

**Why.** It conflated "this change is correct" with "this should be live now".
Separating them lets documentation, tests and gates land without touching what a
customer sees, and makes a release a decision with a timestamp.

**Trade-off.** One more step, and a real hazard: renaming the default branch
without updating the pre-push guard would disable the production gate **silently**.
That is written down where someone about to rename it will read it.

---

## 5 — Canonical source and generated output are explicit

**Decision.** Every directory is classified, and generated output is never edited
by hand.

**Alternatives.** Convention and care.

**Why.** Convention failed. Someone edits the served copy, the next build
overwrites it, and the symptom is "my change did nothing" — an afternoon lost
with no error message anywhere.

**Trade-off.** A machine-readable map has to be maintained. A gate fails when it
drifts, so it is maintained.

---

## 6 — Some AI features have no model in them

**Decision.** The daily briefing is deterministic SQL. No language model.

**Alternatives.** Generate it. It reads like a natural fit.

**Why.** The content is arithmetic over a store's own rows. A model would add
latency, cost, a provider dependency and a non-zero chance of inventing a number
the owner then acts on. The retrieval copilot, by contrast, answers open
questions over prose — that is a model problem.

**Trade-off.** The briefing is rigid; changing what it says means writing SQL. In
exchange it cannot be wrong in the way that matters, and it cannot fail because a
provider is down.

---

**Next:** [architecture](architecture.md) ·
[evidence and limitations](evidence-and-limitations.md)
