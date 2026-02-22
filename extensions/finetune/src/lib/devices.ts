import { execFile } from "child_process";
import { promisify } from "util";
import { join } from "path";
import { environment } from "@raycast/api";

const execFileAsync = promisify(execFile);

const OUTPUT_DEVICES_CLI = "finetune-output-devices";

export interface OutputDevice {
  name: string;
  uid: string;
  /** Live volume 0–100 from Core Audio when available (built-in, etc.). Omitted for DDC-only devices. */
  volume?: number;
}

/**
 * List output devices via Core Audio. When withVolume is true, includes live volume for devices
 * that support it (e.g. built-in speakers). Returns [] if CLI is missing or fails.
 */
export async function getOutputDevices(
  withVolume = false,
): Promise<OutputDevice[]> {
  try {
    const binPath = join(environment.assetsPath, OUTPUT_DEVICES_CLI);
    const args = withVolume ? ["--with-volume"] : [];
    const { stdout } = await execFileAsync(binPath, args, {
      timeout: 10000,
      maxBuffer: 64 * 1024,
    });
    const lines = stdout.trim().split("\n").filter(Boolean);
    const devices: OutputDevice[] = [];
    for (const line of lines) {
      const parts = line.split("\t");
      if (parts.length < 2) continue;
      const name = parts[0].trim();
      const uid = parts[1].trim();
      if (!name || !uid) continue;
      const rawVol = parts[2]?.trim();
      const volume =
        rawVol !== undefined && rawVol !== ""
          ? parseInt(rawVol, 10)
          : undefined;
      devices.push({
        name,
        uid,
        ...(typeof volume === "number" && !Number.isNaN(volume)
          ? { volume: Math.max(0, Math.min(100, volume)) }
          : {}),
      });
    }
    return devices;
  } catch {
    return [];
  }
}

/**
 * Set output device volume (0–100) via Core Audio. Only works for devices that support
 * software volume (e.g. built-in). Throws if CLI fails or device doesn't support it.
 */
export async function setDeviceVolume(
  uid: string,
  percent: number,
): Promise<void> {
  const binPath = join(environment.assetsPath, OUTPUT_DEVICES_CLI);
  const value = Math.round(Math.max(0, Math.min(100, percent)));
  await execFileAsync(binPath, ["--set-volume", uid, String(value)], {
    timeout: 5000,
  });
}
