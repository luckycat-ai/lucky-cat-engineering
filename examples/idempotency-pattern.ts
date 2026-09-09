/**
 * Idempotent payment webhook handling — the pattern, not the implementation.
 *
 * Illustrative simplified example. This is NOT production code. Table names,
 * event shapes and the commercial model are generic here.
 *
 * THE PROBLEM
 *
 * A payment provider guarantees at-least-once delivery. It will resend an event
 * after a timeout, after a 500, and sometimes after a 200 it did not hear. The
 * handler therefore runs more than once for the same payment, and the second run
 * must be indistinguishable from the first — or a customer is charged once and
 * credited twice.
 *
 * Retrying is not the edge case. It is the normal case.
 */

type PaymentEvent = {
  id: string;                    // provider's event id
  type: string;
  data: { object: { id: string; amount: number; currency: string; tenant: string } };
};

/**
 * The key is the PAYMENT's identity, not the EVENT's.
 *
 * This is the part that is easy to get wrong. Deduplicating on the event id
 * stops the same delivery being processed twice, and does nothing about two
 * different events describing one payment — which is exactly what happens when a
 * payment is confirmed and then updated. The ledger must be keyed by the thing
 * that must exist at most once: the payment.
 */
function ledgerKey(e: PaymentEvent): string {
  return e.data.object.id;
}

export async function handlePaymentEvent(db: Db, raw: string, signature: string) {
  // 1 ─ Verify before parsing.
  //
  // The signature is checked against the RAW body. Parsing first and
  // re-serialising changes bytes — key order, whitespace, number formatting —
  // and the signature then fails for correct events, which tends to be
  // "fixed" by skipping verification.
  const event = verifySignature(raw, signature);   // throws on mismatch

  // 2 ─ Record the delivery, and let the database decide if it is new.
  //
  // A read-then-write check is a race: two concurrent redeliveries both read
  // "not seen" and both proceed. The uniqueness constraint is the only
  // arbiter that holds under concurrency.
  const firstDelivery = await db.insertIfAbsent('payment_events', {
    id: event.id,
    type: event.type,
    status: 'processing',
  });

  if (!firstDelivery) {
    // Already handled, or in flight. Acknowledge so the provider stops
    // retrying. Returning an error here would guarantee more duplicates.
    return { status: 200, body: 'already processed' };
  }

  try {
    // 3 ─ The effect itself is idempotent, independently of step 2.
    //
    // Step 2 is an optimisation, not the guarantee. If this process dies
    // between the insert and the effect, the retry must still be safe. So the
    // ledger row carries the payment id as its primary key and the write is a
    // no-op on conflict.
    await db.insertIfAbsent('ledger_entries', {
      id:       ledgerKey(event),          // payment id — at most one entry, ever
      tenant:   event.data.object.tenant,
      amount:   event.data.object.amount,
      currency: event.data.object.currency,
      kind:     'accrual',
    });

    // 4 ─ Accrual and transfer are separate records.
    //
    // "What is owed" and "what has been sent" are different facts with
    // different lifecycles. Collapsing them into one row makes a failed
    // transfer indistinguishable from a payment that never happened, and
    // reconciliation becomes guesswork.

    await db.update('payment_events', event.id, { status: 'done' });
    return { status: 200, body: 'ok' };

  } catch (err) {
    // 5 ─ Leave the marker in 'processing' rather than deleting it.
    //
    // A row stuck in 'processing' is a visible, queryable symptom. A deleted
    // row is silence, and silence looks identical to success.
    await db.update('payment_events', event.id, {
      status: 'failed',
      error: String(err).slice(0, 500),
    });
    throw err;   // 5xx → the provider retries → step 2 lets it through again
  }
}

/**
 * WHAT THIS EXAMPLE OMITS
 *
 * Amount and currency validation against the order, the state machine that
 * decides which transitions are legal, refunds, disputes, partial captures,
 * multi-party splits, payout scheduling, and the reconciliation job that
 * compares the ledger against the provider's own record.
 *
 * It also omits the commercial model. The percentages, the plans and who pays
 * what are business terms, not engineering, and they are not published here.
 *
 * THE ONE LINE WORTH KEEPING
 *
 * Uniqueness lives in the database. Every other layer — the provider's
 * deduplication, the in-memory check, the "we already saw this" flag — is an
 * optimisation on top of a constraint that is the only thing standing between a
 * redelivery and a double credit.
 */

// ── types elided ────────────────────────────────────────────────────────────
type Db = {
  insertIfAbsent(table: string, row: Record<string, unknown>): Promise<boolean>;
  update(table: string, id: string, patch: Record<string, unknown>): Promise<void>;
};
declare function verifySignature(raw: string, signature: string): PaymentEvent;
