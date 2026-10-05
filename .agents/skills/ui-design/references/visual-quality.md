# Visual quality: recognizing the "default way"

Read this only when the user explicitly asks for a visual upgrade, for removing the template look or for more identity, or when a new screen is designed without a reference image. A local layout fix, a pixel-level reproduction and an implementation with a clear reference do not read this page.

This page is a heuristic for diagnosis. It is not a style guide and it creates no new authorization. The priority is fixed:

```text
the reference and constraints the user named > current game facts and game states > the current theme and art direction > the heuristics of this page
```

A direction the user or the reference has already set is followed, including when it happens to be one of the looks listed below. Use this page only for the part the reference does not cover and the theme does not prescribe.

## Fix three axes before starting

The screen's responsibility decides these three axes, not the other way round:

- **Layout variation**: should this screen be stable, repetitive and regular (inventory, lists, settings), or may it be asymmetric and vary in rhythm (the title screen, a screen that presents content)?
- **Motion intensity**: does motion only need to give feedback on an action, or does it need to express a spatial relation and a change of state?
- **Information density**: does the player need to scan a lot of information quickly, or should content and art be given room?

For inventory, list and settings screens, "more modern" means clear hierarchy, suitable density and unambiguous actions; it does not mean larger margins and more motion.

## Common default ways

Each of these is right on some screens; the problem is that they appear without looking at the content. On seeing one, ask: is it decided by the current task, the kind of content, the game state or the game's identity? If so, keep it; if not, consider simplifying, replacing or rearranging.

- Neighbouring areas repeat the same layout for no reason; three parallel pieces of information are made into three panels of equal weight where a list, a section or plain body text fits better.
- Everything is wrapped in a rounded panel, with the same corner radius and the same grey shadow, without hierarchy.
- Every heading has a small all-capitals, widely spaced label above it; `01 / 02 / 03` numbering is used on content that is not a sequence.
- One word in a heading is singled out with a different colour, bold or italic.
- A string of metadata joined with middle dots, arrows added to link and button text, small data labels written in a monospaced font.
- Decorative numbers, status dots, version numbers and fake data previews with no real basis.
- A decorative underline or colour bar under a heading, a panel outlined on one side only, whole paragraphs of centred body text, a gradient that appears without regard to the game's palette.
- Every block fades in and slides up, and every panel has a hover or focus transition. Keep motion that a player action triggers and that shows "what changed"; of motion that plays by itself, keep one deliberately placed instance.
- Corner radius, accent colour, shadow and font-size levels drift without meaning inside one screen and away from the current theme.
- Filler phrases with no game information appear in the text. Text rules follow `.agents/rules/localization.md`.

A structural element is information in itself: a border, a number, a divider or a small label should express a real relation in the content, not decorate.

For every motion it must be possible to say what it expresses, and it must really be finished; the game's reduced-motion setting takes effect. The theme, the accent colour and the corner radius stay consistent inside one screen, and buttons and input controls have enough contrast. Before delivery, read every visible string again.

## Method

1. First write a short design proposal: colour, the roles of the fonts, the layout concept, the principle that is unique to this screen. Colour, fonts, spacing, corner radius and motion come from the current theme; no separate set is started.
2. Before starting, check the proposal against the task: which part is the default "I would do this for any screen of the same kind"? Change that part, and say what was changed and why.
3. Concentrate the effort in one place: let one element be what this screen is remembered for, keep the rest restrained, and delete decoration that does not serve the task.
4. During implementation, check hierarchy, density and rhythm yourself with screenshots.
5. When looking at a screenshot, take the view of someone who did not take part in the implementation: first check whether text overflows, is cut off or overlaps, then look at hierarchy and rhythm. Stop once the real problems found in the first pass are fixed; do not redo repeatedly for the sake of "a little better".
6. Finishing only refines the existing elements: alignment, spacing, overlap, out-of-bounds content and empty space. When tempted to add one more element, first ask how to make the existing ones more complete.

## Verification

Without a run or a screenshot, only a static risk can be stated; a visual problem cannot be said to be confirmed or solved. When there is a reference, compare on the dimensions the user named. Structure, text, states and features that were not asked to change this time stay untouched.

A visual redo does not silently change these: the names of scenes and navigation entries, settings fields and their keys, input action names, art assets and the palette, legal and licence text, and the node names, paths and other identifiers that tests and scripts rely on. When one of them really has to change, state it separately.
