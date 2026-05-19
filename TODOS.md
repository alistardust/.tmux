# TODOS

## Mouse-Mode Accessibility

**What:** Add accessible mouse interaction patterns (audible/text feedback on mouse events, accessible scroll behavior) for low-vision users with magnification.

**Why:** Current accessibility work covers screen reader / keyboard users. Low-vision users who use mouse with magnification have different needs (feedback on click targets, scroll position announcements). This is a separate user profile that requires its own research.

**Pros:** Covers a wider range of accessibility needs; makes the project more inclusive.

**Cons:** Significant research needed (how do NVDA/JAWS interact with terminal mouse events?); risk of phantom announcements; separate design spec required.

**Context:** Deferred from the v1 accessibility PR (`feature/accessibility-improvements`) because it is an "ocean" not a "lake": no prior art, unknown screen reader behavior with terminal mouse, different user profile than the primary target (Ali's co-worker using NVDA + keyboard). Needs its own brainstorming session and spec.

**Depends on:** v1 accessibility PR merged and validated with real screen reader users.

**Status:** Not started. Awaiting user feedback from v1 deployment.
