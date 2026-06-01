# Iterate — TDD-Loop Mode

Red-green-refactor. Spec lives in tests; implementation chases the spec.

## Goal capture template

Single question, capture in 1-2 sentences. Should include:
- **What capability is being added** (the new behavior, not the implementation)
- **What boundary it tests** (unit, integration, e2e)

Examples:
- "Rate limiter rejects the 11th request in a 60-second window. Unit test."
- "POST /orders returns 422 when items array is empty. Integration test."

## Checklist shape (red-green-refactor cycles)

Generated as a repeating pattern. Each "iteration of the iteration" is one cycle:

1. **Red** — write the failing test first. It MUST fail (and fail for the right reason — not a syntax error).
2. **Green** — make the minimum change to pass. Resist the urge to gold-plate.
3. **Refactor** — clean up while tests stay green. Optional but called out so it doesn't get skipped.
4. **(Loop)** — back to Red for the next behavior.

A typical iteration covers 3-5 cycles before the user wraps up or scope-shifts.

## Review threshold

Tied to commits on the test file, not file count: offer `/review tests` after **every commit that touches the test file**.

Rationale: TDD's failure mode is tests that *look* good but actually cover too narrow a slice or share fixtures that hide independence problems. A test-focused review at each test-file commit catches this early.

## What goes wrong in TDD mode

- **Writing the implementation first, then the test**: defeats the point. The test must fail before the implementation exists, or you're not testing what you think you are.
- **Writing tests that pass immediately**: usually means the assertion is too weak. The "Red" step is the discipline — if the new test passes on the unmodified code, the test is wrong.
- **Skipping refactor**: tests stay green, but the green code accumulates duplication and weird shapes. Schedule the refactor in the checklist explicitly.
- **One giant test covering many behaviors**: each cycle should add one behavior to one test (or one new test). Don't accumulate assertions in a single block.

## Interaction with `/execute`

If TDD-mode work expands into "this needs a real plan" (multiple WUs, dependencies between behaviors), exit `/iterate` and run `/build-plan` followed by `/execute`. TDD mode is for behaviors that fit in a single iteration session — not for whole feature flows.
