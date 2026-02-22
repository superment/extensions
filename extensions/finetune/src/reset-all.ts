import { showHUD, showToast, Toast } from "@raycast/api";
import { reset } from "./lib/finetune";

export default async function ResetAllCommand() {
  try {
    await reset();
    await showHUD("Reset all apps to 100%");
  } catch (err) {
    await showToast({
      style: Toast.Style.Failure,
      title: "Failed to reset",
      message:
        err instanceof Error
          ? err.message
          : "FineTune may not be installed. Install from Homebrew: brew install --cask finetune",
    });
  }
}
