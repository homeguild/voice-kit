import type { ReactNode } from "react";

import {
  defaultTheme,
  type ConversationTheme,
  type MessageViewBuilder,
} from "./conversation-stream";
import type { PanelSlot } from "./shell";

/**
 * The PANEL surface — the persistent "current focus" beside the stream
 * (docs/agent-shell.md). Renders the panel's pinned slots through the SAME view
 * registry the stream uses, so a view can be shown inline or in the panel with no
 * change to the view itself. The host decides WHERE the panel physically sits
 * (right rail on desktop, a sheet/tab on phone); this just renders its contents.
 */

export interface PanelSurfaceProps {
  /** The pinned slots (from ShellState.panel), most-recent last. */
  slots: readonly PanelSlot[];
  /** `viewId` → a native component (§7) — the same registry the stream uses. */
  viewRegistry?: Record<string, MessageViewBuilder>;
  theme?: ConversationTheme;
  /** Rendered when nothing is pinned (onboarding not started / all caught up). */
  empty?: ReactNode;
}

export function PanelSurface({
  slots,
  viewRegistry = {},
  theme = defaultTheme,
  empty = null,
}: PanelSurfaceProps) {
  if (slots.length === 0) return <>{empty}</>;
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 12, padding: 16 }}>
      {slots.map((slot, i) => {
        const builder = viewRegistry[slot.view.viewId];
        return (
          <div key={slot.windowId ?? `${slot.view.viewId}-${i}`}>
            {builder ? (
              builder(slot.view)
            ) : (
              <div
                style={{
                  padding: 12,
                  border: `1px solid ${theme.draftBorder}`,
                  borderRadius: 12,
                  color: theme.systemText,
                }}
              >
                [{slot.view.viewId}]
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}
