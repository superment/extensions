import { execFile } from "child_process";
import { promisify } from "util";

const execFileAsync = promisify(execFile);

const FINETUNE_SCHEME = "finetune://";

/**
 * Open a FineTune URL. Launches FineTune if needed; the app handles the action.
 * Uses execFile (no shell) so the URL is passed unchanged to macOS open.
 */
export async function openFineTuneUrl(url: string): Promise<void> {
  const fullUrl = url.startsWith(FINETUNE_SCHEME)
    ? url
    : `${FINETUNE_SCHEME}${url}`;
  await execFileAsync("/usr/bin/open", [fullUrl]);
}

/**
 * Set volume for one or more apps (0-100, or up to 400 with FineTune boost).
 */
export async function setVolume(
  bundleId: string,
  percent: number,
): Promise<void> {
  const params = new URLSearchParams({
    app: bundleId,
    volume: String(Math.round(percent)),
  });
  await openFineTuneUrl(`set-volumes?${params.toString()}`);
}

/**
 * Step volume up or down for an app (only affects apps currently active in FineTune).
 */
export async function stepVolume(
  bundleId: string,
  direction: "up" | "down",
): Promise<void> {
  const params = new URLSearchParams({ app: bundleId, direction });
  await openFineTuneUrl(`step-volume?${params.toString()}`);
}

/**
 * Set mute state for one or more apps.
 */
export async function setMute(bundleId: string, muted: boolean): Promise<void> {
  const params = new URLSearchParams({ app: bundleId, muted: String(muted) });
  await openFineTuneUrl(`set-mute?${params.toString()}`);
}

/**
 * Toggle mute for one or more apps.
 */
export async function toggleMute(bundleIds: string[]): Promise<void> {
  const params = new URLSearchParams();
  bundleIds.forEach((id) => params.append("app", id));
  await openFineTuneUrl(`toggle-mute?${params.toString()}`);
}

/**
 * Route an app to a specific output device (UID from our device list; must match FineTune's Core Audio UID).
 * Encodes device UID with encodeURIComponent so colons and commas (e.g. Studio Display "8,9") are preserved.
 */
export async function setDevice(
  bundleId: string,
  deviceUID: string,
): Promise<void> {
  const uid = deviceUID?.trim();
  if (!uid) return;
  const q = `app=${encodeURIComponent(bundleId)}&device=${encodeURIComponent(uid)}`;
  await openFineTuneUrl(`set-device?${q}`);
}

/**
 * Reset apps to 100% and unmute. Pass no args for all apps, or specific bundle IDs.
 */
export async function reset(bundleIds?: string[]): Promise<void> {
  if (!bundleIds?.length) {
    await openFineTuneUrl("reset");
    return;
  }
  const params = new URLSearchParams();
  bundleIds.forEach((id) => params.append("app", id));
  await openFineTuneUrl(`reset?${params.toString()}`);
}
