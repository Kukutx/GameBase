# UI deep-mode reference

Read this only for pixel-level reproduction, an experimental prototype or a whole-screen production closing. Ordinary UI analysis and a local implementation do not need this file.

## Pixel-level reproduction

Use this only when the reference is an explicit acceptance baseline.

First confirm that the comparison premises the current task declares are comparable enough: for example the viewport size and stretch scale, the theme, the locale, the fonts and font fallback, the window scale, the animation and in-game time state, dynamic data, and the platform or rendering conditions the task really requires to be the same. A difference can only be used for locating, and stays `UNVERIFIED`, when a key condition **that the current acceptance defines as a premise** is not met. When crossing platforms or renderers is itself the goal of the reproduction, do not treat that expected difference mechanically as an environment blocker; still judge by the final observable output the user asked for.

Once the environment is comparable:

- Fix the target viewport, at the same size as the reference or at an explicit scale ratio.
- Compare the geometric and visual quantities that really affect how it looks: position, width and height, spacing, font size and weight, corner radius, colour, shadow, image proportions, scroll areas and fixed action areas.
- First reach an implementation that can be previewed, then re-verify with screenshots or key frames of the same size; keep converging while there is a visible deviation.
- When the user asks for exact or pixel-level, and a deterministic screenshot or diff gate can be used, it is the PASS/FAIL evidence. A subjective visual judgement by a vision or language model, perceptual similarity and how it looks to a person are diagnostics only; they cannot by themselves raise an unverified result to PASS.
- When the reference has unstable sources such as animation, random content, time or loaded data, first show that the baseline is stable enough by freezing the state or by repeated captures; when the reference itself is unstable under the same conditions, stay `UNVERIFIED`.
- When the reference changes materially during the comparison, the old comparison result is void; confirm the new baseline again, and do not modify old evidence to let the current implementation pass.
- Text in a reference image is copied character by character. When it cannot be read, collect the evidence again (the original image at a higher resolution, or the original screen); do not guess from an old image that was cropped and enlarged.
- Without a reference that can be verified, only the structure can be borrowed, and pixel-level agreement is not claimed.
- Brand and art assets, text and game capabilities that do not exist here do not become requirements of the game because a reproduction was asked for. If the user explicitly asks for these concepts to be reproduced too, judge them by authorization and licence.

Pixel or visual agreement and product coverage are separate: a PASS on one screenshot proves only that scene and its observable dimensions; it does not prove that hidden states, interaction, permissions, error states or a whole-screen production closing are done.

## Experimental prototype

- A local mock or presentation-layer state may be used on an authorized experimental screen to express a concept that does not exist yet.
- The experimental layer does not automatically change services, data contracts, the save schema, the real permission or player-progress state, release configuration or dependencies.
- Experimental assets do not automatically become assets that can ship.
- The goal of a prototype is to test the player's task, the information structure or an interaction hypothesis; do not build production infrastructure in passing so that it "looks like a complete game".
- Options shown side by side must really differ in layout, information hierarchy or primary action; changing only the colour or the text is not a different option.
- After a tested decision is merged into the formal implementation, the prototype code does not stay on the main line; a prototype is not promoted directly to production code.

## Whole-screen production closing

Only for a whole-screen restructuring, or when the user explicitly asks for a complete production-level closing, check systematically the states that relate to the screen's real responsibility, for example:

- Loading / Empty / Error / Unavailable / Locked / Disabled / Success / Partial data;
- long text, both languages, viewport scaling and aspect ratio, the theme, keyboard and gamepad navigation, and scrolling;
- focus / hover / pressed, the size of click targets, where focus goes when a screen opens and closes, and the accessibility settings the game exposes;
- confirmation of dangerous actions and protection against repeating an action while it is in progress.

This is a set of **candidate dimensions**, not a mechanical checklist. A state that does not naturally exist is not added for completeness; a local fix checks only the states the change directly affects.

## Input material

- Screenshot: align first on the dimensions the user named. Even when pixel-level was not asked for, an explicit constraint on layout, text or elements is not downgraded to borrowing a skeleton. A pixel task compares at the same size.
- Video: extract key frames only when the implementation or reproduction needs them; a pure analysis may summarize the flow and motion characteristics directly.
- A named game or product: without a screen or source that can be verified, borrow only the structure and do not claim a complete reproduction.
- A bare idea: first turn it into the current screen structure. When the user only wants a proposal, stop at the proposal; write only when implementation is explicitly requested.
