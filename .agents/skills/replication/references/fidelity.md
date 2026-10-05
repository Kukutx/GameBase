# Fidelity

## Exact comparison

A required comparison accepts only a deterministic comparator: identical bytes, identical text, identical JSON after canonical key ordering, identical file trees, identical decoded pixels of an image, identical decoded samples of audio, identical decoded frames of a video. A change to how a comparator decides is a new comparator, not a silent change to an old one; results produced under the old one are not reinterpreted.

## Required comparisons and diagnostics

Required comparisons decide the result. Diagnostics only help to locate a problem and may use a difference mask, a perceptual similarity score, a model's description of two images, a state diff or a trace summary. A diagnostic can never turn "different" or "not verified" into "same".

## Order of judgment

```text
baseline unchanged
-> each run's origin known
-> each run used the case's scenario
-> environments comparable
-> required comparisons
```

When an earlier step does not hold, the result is **not verified** — even when the artifacts happen to differ. The difference is then a diagnostic, not a finding against the replica.

## Environment

Record what the comparison depends on and require it to match: viewport size and stretch settings, renderer, locale, fonts, engine version, fixed timestep, random seed, in-game day and time, input sequence. When matching across platforms or renderers is itself the goal, that expected difference is not an environment blocker; judge by the output the user asked for.

## Reference stability

When the reference can be nondeterministic, capture it more than once under the same conditions. The required comparisons must agree between the captures. Otherwise the reference is unstable: try a seed, a fixed time, a checkpoint or a fixed timestep; when it cannot be frozen, the result is **not verified**.

## Coverage is not fidelity

```text
every compared case is the same  !=  the product is complete
```

The whole target is matched only when every coverage item the user required is claimed by a case and every one of those cases is the same. Report what was compared and what was not.

## Media

- **Image**: compare the decoded pixels. A screenshot that was taken proves nothing until it has been checked for a blank frame or a fallback. Do not silently reduce a high bit-depth image to compare it.
- **Audio**: which resource plays and what the player finally hears are different dimensions; compare each one that matters.
- **Video**: identical frames do not show that the sound track matches; when the final playback has to agree, compare frames and audio.
