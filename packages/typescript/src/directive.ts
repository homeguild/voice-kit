import type { MessageView } from "./message";

/**
 * The agent shell's two-surface routing (docs/agent-shell.md). A directive from
 * the agent carries a view AND where it renders:
 *
 *  - `inline` — appended to the STREAM as a message (part of the conversation;
 *    scrolls with history). Charts the agent produced, one-off forms, and
 *    confirmations live here.
 *  - `panel`  — pinned to the PANEL surface (the persistent "current focus":
 *    onboarding tasks, a live dashboard, a settings form). Stays until the agent
 *    or the user changes it.
 *
 * This is the one protocol addition over agent-ui-arch.md; everything else (the
 * view registry, the two-channel emit, view-event feedback) is unchanged.
 */
export type DirectiveTarget = "inline" | "panel";

/** A view the agent asked to show, and where. `windowId` identifies it so a later
 *  directive can update/dismiss it; `options` carries host hints (placement/size). */
export interface Directive {
  readonly view: MessageView;
  readonly target: DirectiveTarget;
  readonly windowId?: string;
  readonly options?: Readonly<Record<string, unknown>>;
}
