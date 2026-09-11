import { execSync } from "node:child_process";

export const sh = (command: string): string =>
  execSync(command, {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  }).trim();

/**
 * Like `sh`, but pipes `input` to the command's stdin. The loop's failure reason
 * is free text, so a bail-out message goes to `git commit -F -` through stdin
 * rather than a quoted `-m` that the shell would try to parse.
 */
export const shInput = (command: string, input: string): string =>
  execSync(command, { encoding: "utf8", input, stdio: ["pipe", "pipe", "pipe"] }).trim();

export const git = (args: string): string => sh(`git ${args}`);

/**
 * Everything the error actually says. `execSync` sets `message` to
 * "Command failed: <cmd>" and puts the process's own stderr in `stderr`, so
 * reading the first line alone reports every git and gh failure as the command
 * that failed with no reason attached.
 */
export const message = (e: unknown): string => {
  if (!(e instanceof Error)) return String(e).trim();
  const stderr = (e as { stderr?: unknown }).stderr?.toString().trim();
  return (stderr ? `${e.message.split("\n")[0]}\n${stderr}` : e.message).trim();
};
