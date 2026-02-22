import { readFile } from "fs/promises";
import { homedir } from "os";
import { join } from "path";

const SETTINGS_PATH = join(
  homedir(),
  "Library",
  "Application Support",
  "FineTune",
  "settings.json",
);

interface FineTuneSettings {
  appVolumes?: Record<string, number>;
  appMutes?: Record<string, boolean>;
  appDeviceRouting?: Record<string, string>;
  ddcVolumes?: Record<string, number>;
  ddcMuteStates?: Record<string, boolean>;
  outputDevicePriority?: string[];
}

export interface AppVolumeState {
  volume: number;
  muted: boolean;
}

export interface DeviceVolumeState {
  volume: number;
  muted: boolean;
}

export interface FineTuneDeviceSettings {
  deviceVolumes: Record<string, DeviceVolumeState>;
  outputDevicePriority: string[];
  /** Device UIDs that FineTune has saved (from app device routings). Used to fix Studio Display etc. */
  deviceUIDsInUse: string[];
}

/**
 * Read FineTune settings from disk. Returns volume (0–100+) and mute per bundle ID.
 * Gracefully returns empty map if file is missing or invalid.
 */
export async function getFineTuneVolumeState(): Promise<
  Record<string, AppVolumeState>
> {
  try {
    const raw = await readFile(SETTINGS_PATH, "utf-8");
    const data = JSON.parse(raw) as FineTuneSettings;
    const result: Record<string, AppVolumeState> = {};
    const volumes = data.appVolumes ?? {};
    const mutes = data.appMutes ?? {};
    const ids = new Set([...Object.keys(volumes), ...Object.keys(mutes)]);
    for (const id of ids) {
      const v = volumes[id];
      const m = mutes[id];
      result[id] = {
        volume: typeof v === "number" ? Math.round(v * 100) : 100,
        muted: typeof m === "boolean" ? m : false,
      };
    }
    return result;
  } catch {
    return {};
  }
}

/**
 * Read FineTune device settings from disk: per-device volume (0–100) and mute,
 * and output device priority order. Gracefully returns empty data if file missing or invalid.
 */
export async function getFineTuneDeviceSettings(): Promise<FineTuneDeviceSettings> {
  try {
    const raw = await readFile(SETTINGS_PATH, "utf-8");
    const data = JSON.parse(raw) as FineTuneSettings;
    const ddcVolumes = data.ddcVolumes ?? {};
    const ddcMuteStates = data.ddcMuteStates ?? {};
    const deviceVolumes: Record<string, DeviceVolumeState> = {};
    const uids = new Set([
      ...Object.keys(ddcVolumes),
      ...Object.keys(ddcMuteStates),
    ]);
    for (const uid of uids) {
      const v = ddcVolumes[uid];
      const m = ddcMuteStates[uid];
      deviceVolumes[uid] = {
        volume: typeof v === "number" ? Math.round(v) : 100,
        muted: typeof m === "boolean" ? m : false,
      };
    }
    const deviceUIDsInUse = Array.from(
      new Set(Object.values(data.appDeviceRouting ?? {})),
    );
    return {
      deviceVolumes,
      outputDevicePriority: Array.isArray(data.outputDevicePriority)
        ? data.outputDevicePriority
        : [],
      deviceUIDsInUse,
    };
  } catch {
    return {
      deviceVolumes: {},
      outputDevicePriority: [],
      deviceUIDsInUse: [],
    };
  }
}
