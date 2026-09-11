import { execSync } from "node:child_process";

export const sh = (command: string): string =>
  execSync(command, {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  }).trim();

/** Like `sh`, but pipes `input` to stdin (for a free-text `git commit -F -`). */
export const shInput = (command: string, input: string): string =>
  execSync(command, { encoding: "utf8", input, stdio: ["pipe", "pipe", "pipe"] }).trim();

export const git = (args: string): string => sh(`git ${args}`);

/**
 * Everything the error says. `execSync` sets `message` to "Command failed: <cmd>"
 * and puts the real reason in `stderr`, so the first line alone names the command
 * with no reason attached.
 */
export const message = (e: unknown): string => {
  if (!(e instanceof Error)) return String(e).trim();
  const stderr = (e as { stderr?: unknown }).stderr?.toString().trim();
  return (stderr ? `${e.message.split("\n")[0]}\n${stderr}` : e.message).trim();
};
