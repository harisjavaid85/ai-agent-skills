import { test } from "node:test";
import assert from "node:assert/strict";
import { classify } from "./failures.mts";

// Case 7: classify() verdicts, including the new session-limit systemic match.
test("classify: session limit is systemic", () => {
  assert.equal(
    classify(new Error("You've hit your session limit · resets 6:40pm (UTC)")),
    "systemic",
  );
});

test("classify: keeps its existing verdicts", () => {
  assert.equal(classify(new Error("429 too many requests")), "transient");
  assert.equal(classify(new Error("503 bad gateway")), "transient");
  assert.equal(classify(new Error("ECONNRESET")), "transient");
  assert.equal(classify(new Error("401 unauthorized")), "systemic");
  assert.equal(classify(new Error("bad credentials")), "systemic");
  assert.equal(classify(new Error("something the loop cannot place")), "local");
});
