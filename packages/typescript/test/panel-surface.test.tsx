import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";

import { PanelSurface } from "../src/panel-surface";
import type { PanelSlot } from "../src/shell";

/**
 * The panel renders its slots through the SAME view registry the stream uses —
 * so a view can move between inline and panel with no change to the view itself.
 */
describe("PanelSurface", () => {
  const slots: PanelSlot[] = [
    { view: { viewId: "checklist", data: { title: "Set up your line" } }, windowId: "w1" },
  ];

  it("resolves a pinned slot through the registry", () => {
    const html = renderToStaticMarkup(
      <PanelSurface
        slots={slots}
        viewRegistry={{ checklist: (v) => <div>TASK: {String(v.data.title)}</div> }}
      />,
    );
    expect(html).toContain("TASK: Set up your line");
  });

  it("renders the empty state when nothing is pinned", () => {
    const html = renderToStaticMarkup(
      <PanelSurface slots={[]} empty={<div>All caught up</div>} />,
    );
    expect(html).toContain("All caught up");
  });

  it("falls back to a placeholder for an unregistered view", () => {
    const html = renderToStaticMarkup(<PanelSurface slots={slots} />);
    expect(html).toContain("[checklist]");
  });
});
