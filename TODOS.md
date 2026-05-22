# TODOS

## Mouse-Mode Accessibility (Remaining: Low-Vision / Magnification Users)

**What:** Research and implement accessible mouse interaction patterns for low-vision users who use magnification software alongside terminal mouse mode.

**Why:** The setup wizard (Chunk 6, Task 14) addresses the keyboard/SR user story: text-only `[M]` indicator, enhanced toggle feedback with longer display-time, scroll guidance in `prefix + A`, and wizard explanation of the mouse tradeoff. What remains is the magnification user story: click-target feedback, scroll-position announcements, and integration with NVDA/JAWS mouse-tracking modes.

**Already addressed (in Chunk 6):**
- `prefix + m` toggle exists and is documented
- Accessibility mode replaces Unicode mouse indicator with `[M]`
- Toggle feedback uses descriptive text with accessible display-time
- Help binding (`prefix + A`) includes scroll mode instructions
- Wizard explains mouse on/off tradeoff for SR users

**Still open:**
- How do NVDA/JAWS interact with terminal mouse events? (needs real device testing)
- Should mouse-on mode announce pane/window under cursor on click?
- Scroll position announcements (which line am I on?) in copy-mode
- Click-target semantics (pane borders, status items): likely a terminal limitation

**Pros:** Covers a wider range of accessibility needs; makes the project more inclusive.

**Cons:** Significant research needed; risk of phantom announcements; separate design spec required. Terminal mouse semantics are opaque to screen readers.

**Context:** Deferred because it is an "ocean" not a "lake": no prior art, unknown screen reader behavior with terminal mouse events, different user profile than the primary target.

**Depends on:** v1 accessibility PR merged and validated; setup wizard shipped with basic mouse accessibility improvements (Chunk 6).

**Status:** Not started. Awaiting real-user feedback from v1 deployment.
