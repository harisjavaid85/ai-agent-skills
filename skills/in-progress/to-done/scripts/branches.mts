import { git, message } from "./git.mts";

// ---------------------------------------------------------------------------
// Branch, ref, and worktree queries used by both the loop's normal branch
// lifecycle and the bail-out save subsystem. The shared branch is passed in
// rather than read from module scope, so these run against any repo a test
// points them at.
// ---------------------------------------------------------------------------

export function refExists(ref: string): boolean {
  try {
    git(`show-ref --verify --quiet ${ref}`);
    return true;
  } catch {
    return false;
  }
}

export function branchExists(branch: string): boolean {
  return refExists(`refs/heads/${branch}`);
}

/** The worktree holding a branch, if one survived a previous run. */
export function worktreeFor(branch: string): string | undefined {
  let listing: string;
  try {
    listing = git("worktree list --porcelain");
  } catch {
    return undefined;
  }
  for (const block of listing.split(/\n\s*\n/)) {
    if (new RegExp(`^branch refs/heads/${branch}$`, "m").test(block)) {
      return block.match(/^worktree (.+)$/m)?.[1];
    }
  }
  return undefined;
}

/** Split out of dropTicketBranch because parkBailOut needs it without the ref. */
export function removeWorktreeFor(branch: string): void {
  const worktree = worktreeFor(branch);
  if (worktree) {
    try {
      git(`worktree remove --force ${worktree}`);
    } catch (e) {
      console.error(`   could not remove the worktree at ${worktree}: ${message(e)}`);
    }
  }
  try {
    git("worktree prune");
  } catch {
    /* pruning is opportunistic */
  }
}

export function localWipBranches(shared: string): string[] {
  try {
    return git(`branch --list "${shared}-wip-*" --format='%(refname:short)'`)
      .split("\n")
      .map((b) => b.trim())
      .filter(Boolean);
  } catch (e) {
    console.error(`   could not list bail-out branches: ${message(e)}`);
    return [];
  }
}
