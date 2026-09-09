# Evidence and limitations

This page exists so that nothing else in this repository has to be taken on
trust. If a claim elsewhere is not supported here, treat it as unsupported.

The limitations are not buried. Several of them are the most useful thing on this
page, because a system's maturity is described more accurately by what it has not
yet had to survive than by what it does.

---

## Proven

| Claim | How it is known |
|---|---|
| The platform is deployed and serving | `luckycat.ie` is live, and the product apps are reachable as public demos |
| Multi-tenancy is enforced in Postgres | policies resolve membership; adversarial cross-tenant tests exist and are run |
| Isolation tests can actually fail | the suite asserts that the protected views contain rows, so "zero rows" cannot be a false green from an empty table |
| Deterministic gates run in CI | unit tests, AI guard evals, commercial-rule consistency, accessibility, SEO coherence, sub-processor coverage, canonical/generated drift, repository-map validity |
| AI guards are covered by evals | six guards, one eval group each, with a minimum case count per group so the dataset cannot be quietly emptied |
| The payment rail works in live infrastructure | exercised end to end against the live payment provider — see the limitation below on what that does **not** mean |
| Release is separated from merge | trunk and the production pointer are distinct; promotion is an explicit command, and rollback is the same operation reversed |
| An exact-SHA preview can be validated | a build of the exact tree is uploaded and asserted against before promotion |
| Backups leave the primary platform nightly | the object exists off-platform, verified by listing it, and its contents were cross-checked against the live database |
| Incidents become guardrails | each case in [agentic engineering](agentic-engineering.md) produced a test, a gate or a corrected document |

---

## Not proven

**There are no paying customers.** No real customer has placed an order and no
customer has paid. One local business tested the product; that is a test, not
traction. Nothing on this page or elsewhere in this repository should be read as
revenue, users or adoption.

**The live payment exercise was mine.** The rail was exercised with a small
amount of my own money to prove the path works end to end. It proves the
integration; it proves nothing about demand.

**Customer onboarding has never run end to end.** The provisioning path — the
first thing a new business would go through — has never been executed in
production. It is built and it is untested by reality, and I would rather say so
than let "the feature exists" imply "the journey works".

**Disaster recovery is unproven.** Backups are produced and verified as objects.
They have never been restored. A backup whose restore has never been exercised is
a hypothesis, and I do not describe it otherwise.

**Uptime is not instrumented on the ordering path.** External monitoring covers
the public marketing site. Nothing probes the ordering flow, sign-in, or the
server-side functions, so I have no uptime figure and do not quote one.

**Semantic quality of live model output is not evaluated.** The evals prove guard
and parser behaviour deterministically. Whether a given answer is *good* is not
measured. See [AI engineering](ai-engineering.md) for the full split.

**Scale is untested.** The system is designed for many tenants and has not
carried many. No load testing has been done, and any performance claim here would
be invented.

**One legacy fork exists, frozen.** An early per-client fork predates the
one-codebase rule. It did not receive a fix the canonical code received. It is
documented as an accepted risk rather than presented as clean.

---

## Numbers deliberately absent

There are no metrics on this page — no request counts, no latencies, no uptime
percentage, no user numbers, no revenue.

Not because they would be unflattering, but because I do not have instrumented,
defensible figures for them, and a number that cannot be defended in an interview
is worse than no number.

---

## How to check

The public surfaces are linked from the [README](../README.md). The production
source repository is private, so the code behind these claims is not open to
inspection — which is exactly why this page is specific about *how* each claim is
known rather than asserting it.

In a conversation I am happy to walk through the private repository, the CI
configuration, the gates, the migration preflight and verify scripts, and the
incident records that produced them.

---

**Back to:** [README](../README.md)
