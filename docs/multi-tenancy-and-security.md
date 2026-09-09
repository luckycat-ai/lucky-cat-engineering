# Multi-tenancy and security

One codebase, many tenants, one database. The interesting question is not how
tenants are stored — it is **where the boundary is enforced**, and what happens
when the layer above it is wrong.

---

## The boundary is in Postgres, not in the front end

Row-Level Security is the tenant boundary. Not a `WHERE` clause in the client,
not a filter in an API layer, not a check in a React hook.

The reasoning is about failure modes rather than elegance. A front-end filter
fails open: forget it in one query and that query returns everyone's rows, with
no error and no log line. An RLS policy fails closed: forget to grant and the
query returns nothing, which is visible in the first minute of testing.

It also survives the parts of the system nobody remembers to audit — a database
console, a one-off script, a future service written by a future person.

### The pattern

```sql
-- Illustrative simplified example — not production code.

CREATE POLICY orders_tenant_read
  ON public.orders
  FOR SELECT
  TO authenticated
  USING ( owns_store(store_id) );
```

`owns_store()` resolves the caller's membership from `auth.uid()` — the identity
in the verified JWT — against a membership table. The full pattern, with the
non-obvious parts commented, is in
[`examples/rls-pattern.sql`](../examples/rls-pattern.sql).

**The client never supplies the tenant identifier that decides access.** It may
send one to say *which* store it is asking about; the policy independently
resolves what that caller is allowed to see. If those two disagree, the policy
wins and the answer is an empty set.

---

## Anonymous sessions are still authenticated

A diner ordering from a QR code does not create an account. The customer app
signs in anonymously, which means that in Postgres terms **a random member of the
public is `authenticated`**.

This is worth stating plainly because it inverts a common assumption. "Signed in"
is not a permission. Every policy that matters resolves membership, so an
anonymous session lands in the same place as any other caller with no membership:
zero rows.

The practical consequence is that the advisory tooling flags a long list of
policies as reachable by anonymous sign-ins. That list is a property of the
product, not a defect — and knowing the difference is the whole job.

---

## SECURITY DEFINER, reviewed function by function

A `SECURITY DEFINER` function runs with the owner's privileges. It is not a
vulnerability — it is a deliberate privilege escalation, and the only question
that matters is **what it checks before it uses that privilege**.

Every such function reachable by an authenticated caller was read and classified
by its gate:

| Gate | What it means |
|---|---|
| caller identity | resolves membership or admin status before touching data |
| bearer token | the caller is a *device*, not a person — a kitchen display nobody signs into, holding a hashed token, rate-limited on misses |
| `auth.uid()` directly | operates only on the caller's own row |
| none, read-only | answers a question asked *before* there is anyone to authorise: opening hours, collection slots, whether a code is valid |

The outcome that matters: **nothing writes without a gate.**

Two things that review taught, both worth more than the result:

- **A gate does not have to look like a gate.** Two functions appeared ungated
  until reading showed a SHA-256 bearer token compared against a stored hash,
  with rate limiting on failures. A kitchen tablet cannot hold a password.
- **A pattern that silently matches nothing reads exactly like a clean result.**
  A first pass classified two writing functions as read-only because the search
  pattern was subtly wrong. The lesson is to make a checker prove it can fail
  before believing that it passed.

---

## Adversarial tests, not happy paths

Tenant isolation is tested by trying to break it:

- two real tenants, each attempting to read the other's rows;
- an authenticated non-member attempting to read views intended for one role;
- an authenticated non-member attempting to **write** through a definer view —
  a write through such a view executes as its owner and would bypass the
  underlying policies, so a regression there would be silent and serious;
- a service-role assertion proving the protected views actually contain rows, so
  that "zero rows returned" cannot be a false green caused by an empty table.

That last one is the point of the suite. A security test that passes because
there was nothing to steal has proved nothing.

### A test that passes because it did not run is worse than no test

The isolation suite needs credentials. It once ran in CI with no environment
block, found nothing to connect to, skipped every case, and reported success —
a green job that measured exactly zero.

The fix was not only the missing configuration. Skipping is now legitimate on a
developer machine, where a service-role key has no business being, and a **hard
failure inside CI**, where a missing credential is a configuration defect rather
than a fact of life. The distinction between "passed" and "not measured" is
enforced by the runner and printed in the summary.

---

## What is deliberately not described here

Table names beyond the illustrative example, policy bodies, function names,
project identifiers, endpoints, role names, storage buckets and anything that
would help someone probe the live system. The patterns are the transferable part;
the specifics are not.

---

**Next:** [AI engineering](ai-engineering.md) ·
[delivery and reliability](delivery-and-reliability.md) ·
[evidence and limitations](evidence-and-limitations.md)
