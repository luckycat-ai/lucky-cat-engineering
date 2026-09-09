-- ============================================================================
-- Tenant isolation with Row-Level Security — the pattern, not the implementation
--
-- Illustrative simplified example. This is NOT production code: table names,
-- column names, role names and policy names here are generic, and the real
-- schema is not described. What transfers is the shape.
-- ============================================================================


-- 1. Membership is a table, not a claim in a token ---------------------------
--
-- Putting the tenant list inside the JWT is tempting and it ages badly: revoking
-- access then means waiting for a token to expire. A membership row is revoked
-- the moment it is deleted.

create table tenant_members (
  tenant_id  text not null,
  user_id    uuid not null references auth.users (id) on delete cascade,
  role       text not null check (role in ('owner', 'staff')),
  primary key (tenant_id, user_id)
);


-- 2. One helper answers the only question that matters ----------------------
--
-- SECURITY DEFINER so it can read the membership table regardless of the
-- caller's own grants. That is a deliberate privilege escalation, and it is
-- acceptable only because the function's entire body is the authorisation
-- check -- it takes no action on the caller's behalf.
--
-- `search_path` is pinned. Without it, a caller who controls a schema can make
-- an unqualified name resolve somewhere else while the function runs as its
-- owner.
--
-- STABLE lets the planner call it once per query rather than once per row.

create or replace function belongs_to_tenant(p_tenant text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
      from tenant_members m
     where m.tenant_id = p_tenant
       and m.user_id   = auth.uid()   -- identity from the verified JWT
  );
$$;


-- 3. The policy ------------------------------------------------------------
--
-- USING filters what a caller can SEE.
-- WITH CHECK filters what a caller can WRITE.
--
-- Both are required. A policy with only USING lets a caller INSERT a row into
-- somebody else's tenant -- they simply cannot read it back afterwards, which
-- is a data-integrity problem that hides itself.

alter table orders enable row level security;

create policy orders_tenant_read
  on orders
  for select
  to authenticated
  using ( belongs_to_tenant(tenant_id) );

create policy orders_tenant_write
  on orders
  for all
  to authenticated
  using      ( belongs_to_tenant(tenant_id) )
  with check ( belongs_to_tenant(tenant_id) );


-- 4. Index the column the policy filters on --------------------------------
--
-- Every query against this table now carries the tenant predicate. Without an
-- index this is a sequential scan that grows with total rows across all
-- tenants, so the busiest tenant degrades the quietest one.

create index orders_tenant_created
  on orders (tenant_id, created_at desc);


-- ============================================================================
-- WHY THIS SHAPE
--
-- The client never supplies the identifier that decides access. It may send one
-- to say WHICH tenant it is asking about; the policy independently resolves
-- what this caller may see. When the two disagree, the policy wins and the
-- answer is an empty set.
--
-- The failure modes are asymmetric, and that is the whole argument:
--
--   forgetting an application-layer filter  -> returns everyone's rows,
--                                              no error, no log line
--   forgetting a grant or a policy          -> returns nothing,
--                                              obvious in the first test
--
-- Choose the failure you can survive.
--
--
-- WHAT THIS EXAMPLE OMITS
--
-- Anonymous sessions. In an app where a member of the public orders without an
-- account, `authenticated` includes strangers -- so "signed in" is not a
-- permission, and every policy still resolves membership. A stranger and a
-- non-member land in the same place: zero rows.
--
-- Roles beyond membership, service-role paths, definer views and the write
-- grants on them, and the adversarial test suite that tries to defeat all of
-- the above. Those are described in docs/multi-tenancy-and-security.md.
-- ============================================================================
