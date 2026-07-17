# SwiftUI Prototype

Generate **several radically different native SwiftUI variations** for one screen or view state. The user compares them in Simulator, a SwiftUI preview, or the app's existing DEBUG-only navigation, then the prototype is deleted or the winning direction is folded into production code.

If the question is about web UI, use [UI.md](UI.md). If the question is about logic/state rather than what something looks like, use [LOGIC.md](LOGIC.md).

## When this is the right shape

- "What should this SwiftUI screen look like?"
- "Try a few layouts for this Settings section."
- "I want to compare native iOS interaction patterns before committing."
- Any native iOS UI question where browser routes, DOM focus checks, URL search params, or TSX components would be fake context.

## Shape

Prefer embedding the prototype at the closest native seam:

- **Existing screen state, preferred:** keep the current navigation, models, and sample data shape, but swap the rendered subtree between variants.
- **SwiftUI preview:** use a `PreviewProvider` or `#Preview` with fixed sample data when the screen can be judged in isolation.
- **DEBUG-only prototype host:** add a clearly named temporary host only when the screen cannot be reached safely through existing navigation.

Never require web-only machinery such as routes, query parameters, DOM APIs, browser focus checks, TSX components, or `process.env`.

## Process

### 1. State the question and pick N

Default to **3 variants**. More than 5 usually becomes noise. Write a one-line comment near the prototype:

> "Three prototype variants of the profile settings section, switchable from a DEBUG-only segmented control."

### 2. Generate native variants

Each variant should be a small SwiftUI view with the same input shape, for example `VariantA`, `VariantB`, and `VariantC`.

Variants must be structurally different: different layout, hierarchy, grouping, control placement, or navigation model. Do not count color-only or copy-only tweaks as variants.

Use native SwiftUI and the app's existing components, typography, spacing, environment values, and preview fixtures where available.

### 3. Wire a native selector

Use a temporary selector that fits the host:

- `Picker` with segmented style for inline comparison.
- Preview variants shown as separate `#Preview` entries.
- DEBUG-only launch argument or local `@State` selector when the prototype is reached in Simulator.

Keep the selector out of release builds with `#if DEBUG` if it is reachable from the app. Put all prototype-only types behind clear names such as `Prototype`, `VariantA`, or `DebugVariantSelector`.

### 4. Keep it safe

- Do not call real destructive actions from a prototype variant.
- Use sample data, inert closures, or DEBUG-only stubs unless the question explicitly requires live app state.
- Surface enough state on screen to judge the design: empty, populated, loading, error, and long-text cases when relevant.

### 5. Hand it over

Tell the user exactly how to view it: the preview name, simulator path, launch argument, or DEBUG-only menu location.

### 6. Capture the answer and clean up

Once a direction wins, record the decision in the issue, PR, ADR, or a temporary `NOTES.md`, then delete the losing variants and selector. Rewrite the winning direction as production-quality SwiftUI instead of shipping the throwaway prototype structure.

## Anti-patterns

- **Browser-shaped SwiftUI prototypes.** URL params, DOM checks, and TSX components do not answer native iOS questions.
- **A fake standalone screen when real surrounding navigation matters.** Prefer embedding in the real host screen.
- **Prototype controls leaking to release builds.** Guard reachable selectors with `#if DEBUG`.
- **Promoting prototype code directly.** The prototype answers the design question; production code still needs normal structure, tests where appropriate, and accessibility review.
