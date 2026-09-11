import { git, message, sh, shInput } from "./git.mts";
import { branchExists, localWipBranches, removeWorktreeFor, worktreeFor } from "./branches.mts";
import { IncompleteError } from "./failures.mts";

// ---------------------------------------------------------------------------
// Saving a bailed attempt's unfinished work. This is the only path that saves
// it: a work-carrying attempt parks in its own local slot `<shared>-wip-<N>-<k>`
// (never overwritten), and at finalize each open ticket's highest slot is
// published once to the unnumbered `<shared>-wip-<N>`. Callers pass the run
// context, so the subsystem runs against any repo a test points it at.
// ---------------------------------------------------------------------------

export type Save = {
  reason: string;
  attempt: number;
  tries: number;
  /** `local` only: the resolved `.scratch/<slug>/issues/NN-*.md` path. */
  ticketFile?: string;
};

export type SaveCtx = {
  tracker: "github" | "local";
  shared: string;
  disclaimer: string;
};

function ticketNn(ticketFile: string | undefined, ticket: number): string {
  return ticketFile?.match(/(\d+)[^/]*\.md$/)?.[1] ?? String(ticket);
}

/**
 * Pure so it can be checked without git. On `local` the subject names the ticket
 * by `NN` and the body points at the file, since a bare `#NN` would link to an
 * unrelated GitHub issue.
 */
export function bailOutMessage(ctx: SaveCtx, ticket: number, save: Save): string {
  const ref =
    ctx.tracker === "github" ? `#${ticket}` : `ticket ${ticketNn(save.ticketFile, ticket)}`;
  const lines = [`Save unfinished work for ${ref}`, ""];
  if (ctx.tracker === "local" && save.ticketFile) lines.push(`Ticket: ${save.ticketFile}`);
  lines.push(
    `Attempt ${save.attempt} of ${save.tries} did not close the ticket: ${save.reason}`,
    "The to-done loop saved the attempt's uncommitted changes here.",
    "Do not merge this commit as-is, take what is useful after inspection.",
    "",
    ctx.disclaimer,
  );
  return lines.join("\n");
}

/** The ticket and slot number a `<shared>-wip-<N>-<k>` branch names, or undefined. */
function slotParts(shared: string, branch: string): { ticket: number; k: number } | undefined {
  const m = branch.slice(`${shared}-wip-`.length).match(/^(\d+)-(\d+)$/);
  return m ? { ticket: Number(m[1]), k: Number(m[2]) } : undefined;
}

/** The first free `<shared>-wip-<ticket>-<k>` slot, k from 1. */
export function nextWipSlot(shared: string, ticket: number): string {
  const taken = new Set(
    localWipBranches(shared)
      .map((b) => slotParts(shared, b))
      .filter((p) => p?.ticket === ticket)
      .map((p) => p!.k),
  );
  let k = 1;
  while (taken.has(k)) k++;
  return `${shared}-wip-${ticket}-${k}`;
}

/**
 * Commits a failed attempt's dirty worktree onto the ticket branch. Bypasses
 * hooks (a quarantine commit, never merged) and feeds the free-text message via
 * stdin. Being the only save, a failed commit throws rather than swallowing, so
 * the work survives; saveBailOut runs it first, before any removal or drop.
 */
export function snapshotBailOut(ctx: SaveCtx, branch: string, ticket: number, save: Save): void {
  const worktree = worktreeFor(branch);
  if (!worktree) {
    console.error(`   no worktree survived ticket ${ticket}; nothing to preserve`);
    return;
  }
  if (!sh(`git -C ${worktree} status --porcelain`)) return; // clean: nothing to snapshot
  try {
    sh(`git -C ${worktree} add -A`);
    shInput(`git -C ${worktree} commit --no-verify -F -`, bailOutMessage(ctx, ticket, save));
  } catch (e) {
    throw new IncompleteError(
      `could not snapshot ticket ${ticket}'s unfinished work in ${worktree}: ` +
        `${message(e)}; left intact for recovery`,
    );
  }
}

/**
 * Snapshots the worktree, then parks a work-carrying attempt in its own free
 * slot and drops an empty one. The snapshot runs first, so its throw on a failed
 * commit escapes before the worktree is removed or a branch dropped.
 */
export function saveBailOut(ctx: SaveCtx, branch: string, ticket: number, save: Save): void {
  snapshotBailOut(ctx, branch, ticket, save);
  // Before the drop-or-park: worktreeFor resolves by branch name, so one still
  // attached here would follow the ref to the slot.
  removeWorktreeFor(branch);
  if (!branchExists(branch)) return;

  // No commits beyond the shared tip means an empty attempt; dropping it keeps
  // it from burying an earlier attempt's slot.
  if (Number(git(`rev-list --count ${ctx.shared}..${branch}`)) === 0) {
    git(`update-ref -d refs/heads/${branch}`);
    console.error(`   ticket ${ticket} left no work; dropped ${branch}`);
    return;
  }

  const slot = nextWipSlot(ctx.shared, ticket);
  try {
    // Empty old-value: update-ref refuses to overwrite, so a slot is never lost.
    git(`update-ref refs/heads/${slot} ${git(`rev-parse ${branch}`)} ""`);
  } catch (e) {
    // Thrown, not logged: a later dispatch's recut would drop the ticket branch.
    throw new IncompleteError(
      `could not save ticket ${ticket} as ${slot}: ${message(e)}; ` +
        `its work is left on ${branch} for recovery`,
    );
  }
  try {
    git(`update-ref -d refs/heads/${branch}`);
  } catch (e) {
    console.error(`   could not drop ${branch} after saving it as ${slot}: ${message(e)}`);
  }
}

export type StuckBranch = {
  ticket: number;
  /** The ticket's highest local slot. */
  slot: string;
  /** The unnumbered remote name it is published to. */
  remote: string;
};

/** Each open ticket's highest slot; the loop never merges or deletes a slot. */
export function stuckTickets(
  shared: string,
  isClosed: (ticket: number) => boolean,
): StuckBranch[] {
  const byTicket = new Map<number, { k: number; slot: string }[]>();
  for (const slot of localWipBranches(shared)) {
    const parts = slotParts(shared, slot);
    if (!parts) continue;
    if (!byTicket.has(parts.ticket)) byTicket.set(parts.ticket, []);
    byTicket.get(parts.ticket)!.push({ k: parts.k, slot });
  }

  const stuck: StuckBranch[] = [];
  for (const [ticket, slots] of [...byTicket].sort((a, b) => a[0] - b[0])) {
    if (isClosed(ticket)) continue;
    const highest = [...slots].sort((a, b) => a.k - b.k).at(-1)!.slot;
    stuck.push({ ticket, slot: highest, remote: `${shared}-wip-${ticket}` });
  }
  return stuck;
}

/**
 * Force-pushes each stuck ticket's highest slot to the unnumbered
 * `<shared>-wip-<ticket>` (safe: the numbered slots stay local). Returns the
 * remote names for the PR. A failed push throws, so the PR never lists fewer
 * stuck tickets than there are; rerunning is safe.
 */
export function publishStuckBranches(
  shared: string,
  isClosed: (ticket: number) => boolean,
): string[] {
  const stuck = stuckTickets(shared, isClosed);
  for (const { slot, remote } of stuck) {
    git(`push --force origin refs/heads/${slot}:refs/heads/${remote}`);
  }
  return stuck.map((s) => s.remote);
}
