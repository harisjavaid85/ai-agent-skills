/** Terminal for this run: stop dispatching, file a partial PR, exit 1. */
export class IncompleteError extends Error {}

// Failure classes, failing closed at ticket scope: only a systemic fault ends
// the run, everything else costs one ticket at most.

export type FailureClass = "transient" | "local" | "systemic";

const TRANSIENT =
  /(429|rate.?limit|overloaded|too many requests|50[234]|bad gateway|ETIMEDOUT|ECONNRESET|ENOTFOUND|EAI_AGAIN|socket hang up|timed? ?out)/i;
const SYSTEMIC =
  /(401|unauthorized|invalid.{0,10}(api.?key|token)|authentication fail|bad credentials|credit balance|insufficient.{0,10}quota)/i;

export function classify(e: unknown): FailureClass {
  // The whole text, not message()'s first line: runPhase() appends the
  // provider's own account of the failure below that line.
  const text = e instanceof Error ? e.message : String(e);
  // Transient wins a tie: a rate-limited 403 says "rate limit" too.
  if (TRANSIENT.test(text)) return "transient";
  if (SYSTEMIC.test(text)) return "systemic";
  return "local";
}
