import { exec, execFile } from "child_process";
import { promisify } from "util";
import { join } from "path";
import { environment } from "@raycast/api";
import { runAppleScript } from "@raycast/utils";

const execAsync = promisify(exec);
const execFileAsync = promisify(execFile);

export interface RunningApp {
  name: string;
  bundleId: string;
  appPath?: string;
}

/**
 * Resolve app bundle path from bundle ID (for icon). Returns undefined if not found.
 */
export async function getAppPath(
  bundleId: string,
): Promise<string | undefined> {
  try {
    const { stdout } = await execAsync(
      `mdfind "kMDItemCFBundleIdentifier == '${bundleId.replace(/'/g, "'\\\\''")}'" -onlyin / 2>/dev/null | head -1`,
      { timeout: 2000 },
    );
    const path = stdout.trim();
    return path && path.endsWith(".app") ? path : undefined;
  } catch {
    return undefined;
  }
}

const CORE_AUDIO_CLI = "finetune-audio-apps";

const FINETUNE_BUNDLE_ID = "com.finetuneapp.FineTune";

/**
 * Returns true if the FineTune app is installed (found by bundle ID).
 */
export async function isFineTuneInstalled(): Promise<boolean> {
  const path = await getAppPath(FINETUNE_BUNDLE_ID);
  return !!path;
}

/**
 * Get running apps that have active audio (Core Audio process list). Same as FineTune's UI list.
 * Returns null if the CLI is missing or fails (e.g. no Core Audio access).
 */
export async function getRunningAppsWithAudio(): Promise<RunningApp[] | null> {
  try {
    const binPath = join(environment.assetsPath, CORE_AUDIO_CLI);
    const { stdout } = await execFileAsync(binPath, [], {
      timeout: 10000,
      maxBuffer: 1024 * 1024,
    });
    const lines = stdout.trim().split("\n").filter(Boolean);
    const apps: RunningApp[] = [];
    const seen = new Set<string>();
    for (const line of lines) {
      const tab = line.indexOf("\t");
      if (tab === -1) continue;
      const name = line.slice(0, tab).trim();
      const bundleId = line.slice(tab + 1).trim();
      if (!bundleId || !name || seen.has(bundleId)) continue;
      seen.add(bundleId);
      apps.push({ name, bundleId });
    }
    return apps;
  } catch {
    return null;
  }
}

/**
 * Get running applications: prefers Core Audio list (apps with audio, like FineTune);
 * falls back to all running apps via AppleScript if the CLI is unavailable.
 * Resolves .app paths for icons.
 */
export async function getRunningApps(): Promise<RunningApp[]> {
  let apps: RunningApp[] | null = await getRunningAppsWithAudio();
  if (apps === null) {
    apps = await getRunningAppsFromAppleScript();
  }
  apps = apps.filter((app) => app.bundleId !== FINETUNE_BUNDLE_ID);
  const withPaths = await Promise.all(
    apps.map(async (app) => {
      const appPath = await getAppPath(app.bundleId);
      return { ...app, appPath };
    }),
  );
  return withPaths;
}

async function getRunningAppsFromAppleScript(): Promise<RunningApp[]> {
  const script = `
    set output to ""
    tell application "System Events"
      set procList to every process whose background only is false
      repeat with p in procList
        try
          set appName to name of p
          set appBundle to bundle identifier of p
          if appBundle is not "" and appName is not "" then
            set output to output & appName & "\\t" & appBundle & "\\n"
          end if
        end try
      end repeat
    end tell
    return output
  `;
  const result = await runAppleScript(script, { timeout: 10000 });
  const lines = result.trim().split("\n").filter(Boolean);
  const apps: RunningApp[] = [];
  const seen = new Set<string>();
  for (const line of lines) {
    const tab = line.indexOf("\t");
    if (tab === -1) continue;
    const name = line.slice(0, tab).trim();
    const bundleId = line.slice(tab + 1).trim();
    if (!bundleId || !name || seen.has(bundleId)) continue;
    seen.add(bundleId);
    apps.push({ name, bundleId });
  }
  return apps.sort((a, b) =>
    a.name.localeCompare(b.name, undefined, { sensitivity: "base" }),
  );
}
