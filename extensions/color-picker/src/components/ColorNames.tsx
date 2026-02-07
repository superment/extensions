import { Action, ActionPanel, Icon, List } from "@raycast/api";
import { Color } from "color-namer";
import { isMac, normalizeColorHex } from "../lib/utils";

export const ColorNameListItem = ({ color }: { color: Color }) => {
  const hexCode = isMac ? color.hex.replace(/^#/, "") : color.hex;
  return (
    <List.Item
      icon={{
        source: Icon.CircleFilled,
        tintColor: {
          light: hexCode,
          dark: hexCode,
          adjustContrast: false,
        },
      }}
      title={color.name}
      accessories={[
        {
          tag: {
            value: normalizeColorHex(color.hex),
            color: hexCode,
          },
        },
      ]}
      actions={
        <ActionPanel>
          <Action.CopyToClipboard content={color.name} title="Copy Name" />
          <Action.CopyToClipboard content={color.hex} title="Copy Hex" />
        </ActionPanel>
      }
    />
  );
};
