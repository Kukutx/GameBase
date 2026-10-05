# Skill authoring standard

A skill carries only **the guidance that adds real value to a specialized workflow**. It is not a second set of global rules, a store of project facts, a new source of authorization or a container for a product brand. The design goals are precise triggering, disclosure on demand and observable completion, not a tutorial on how an agent thinks in general.

## When a skill is worth having

Before adding or keeping a skill, answer: are the existing `AGENTS.md`, path rules, workflows and current sources of truth already enough? Use a skill only when there is a repeatable specialized judgement, a non-obvious flow, a route to dedicated tools or material, or a stable failure guard.

- A new skill or rule must be able to point at one failure that was already observed: one that happened in this repository, or one with a concrete origin in the source material. If it cannot be said which failure it prevents, it is not added. A rule distilled from an external source is first checked against this repository's code and configuration; a rule that contradicts the current state is not adopted.
- Before bringing in a third-party skill, check its origin and content as described in "Third-party skill review" below. A general tutorial-style skill aimed at new projects is registered as reference material, not installed as a skill that triggers automatically.
- The name describes the capability, for example `ui-design`, `project-audit`, `game-qa`. A general skill does not use a product, repository, organization or customer name as a prefix.
- Project identity, paths, language, lifecycle and tool entry points go in the Profile; domain semantics go in the Domain rule; current state stays in code, data contracts, configuration and fact documents.
- A general skill does not hard-code absolute paths on a machine, accounts, cloud resources, a fixed project version or the state of one game's content.

## Third-party skill review

Read the whole body and every script, and confirm it does not contradict this repository's rules. During the review, run none of its scripts and use only read-only commands. When no scanning tool was run, say so and lower the confidence of the conclusion accordingly.

- **Hidden content**: hidden text in the frontmatter and in parameter defaults (HTML comments, zero-width characters, look-alike characters, long base64 strings), hidden files and archives, precompiled files.
- **What it changes or connects to**: bundled hooks and host settings files, package-manager configuration that rewrites where dependencies come from, persistence entry points (scheduled tasks, shell configuration, startup hooks), writing into instruction files such as `AGENTS.md`, automatic installation of extensions, global installs, killing processes by port, fetching content at run time from a remote default branch (not pinned to a commit), reading the memory of other skills or agents.
- **What it pre-approves**: `allowed-tools` in the frontmatter pre-approves those commands. Look at each item it allows; an allowed item should be a complete command, not a command prefix. A tool or MCP server fetched and run on the spot with `npx` or similar executes code that was not reviewed. For a telemetry hook, find out what it reports and how to turn it off. Check whether an environment variable can skip, without confirmation, a step the skill itself says must stop.
- **Whether what it says matches what it does**: do the `description`, the permissions it declares and what its scripts really call agree? When one script has versions for several platforms, do the versions do the same thing? A `description` stuffed with broad trigger words is taking routes away from other skills.
- **Bundled scripts** (read each one to the end, without running it):
  - What it executes: compiling or injecting native code on the spot; patching a third-party library at run time; installing dependencies automatically; a "verification" script that really calls a paid interface; a script called "probe" or "check" that sends write requests or leaves side effects (judge whether a request is read-only by its address and parameters, not only by the method name); relying on the account currently logged in on the machine and its default project; concatenating outside data straight into SQL, a shell command or a code string, or directly executing a command string or source file passed to it; calling a cloud account's interface for fetching secrets; resending a write straight after the write request timed out, instead of reading back first.
  - What it changes: writing files to a fixed shared temporary path; rewriting the machine's CLI configuration; when it rewrites project files in place, whether there is a preview or a backup and whether it changes only the target it declares; whether it lists the objects before recursively deleting a remote path.
  - What it sends out: packing and uploading a whole directory with no exclusions, or with exclusions that cover only `.env`-style files and miss the project's own secret directory; uploading to a hard-coded third-party address; secret plaintext in the output; a token placed in command-line arguments; an address that credentials are sent to which an environment variable can rewrite.
  - Whether its report can be trusted: a timeout reported as success; swallowed exceptions; exiting with success anyway when credentials are missing or the request was refused; printing "passed" with nothing checked; swallowing a read error into an empty result, so that "it failed" and "there really is nothing" cannot be told apart; a result cut off by a count limit without saying so; a command that exits non-zero treated as success only because its output can still be parsed.
- **Example code**: the insecure patterns in the examples themselves (a cross-origin wildcard together with credentials, plaintext tokens, cookies without protective attributes) are not brought in along with the rule.
- **Licence**: does the licence allow copying and adaptation? When it does not, learn the method only and copy no content; when it does, keep the notices the licence requires. A licence that only says "use is subject to an agreement with some company" is treated as not allowing it.

The conclusion has three levels: usable; usable with sensitive behaviour (which must be documented, necessary, bounded and under the user's control); not used. High-risk behaviour whose purpose cannot be explained is not let through because of the fame of the source or a tool's score. The grounds for an exemption or for trust cannot come from what the reviewed object says about itself.

## Trigger / description

The frontmatter holds only `name` and `description`.

The `description` has only two jobs: **what this skill does; when it should trigger**. The more precise the better; it does not grab routes with synonyms, broad domain words or "must be used for any related task". When the `description` is changed because of examples that failed to trigger, generalize them into categories of intent; do not write those sentences in one by one.

Recommended form:

```text
<specific capability>. Use when <the task boundary that really needs this capability>; not for <the nearest task most likely to trigger it by mistake>.
```

There is no single best length; a short description must still tell neighbouring skills apart. A host may truncate descriptions when the skill list is large, so when the registration result the model sees shows truncation, shorten the wording so that the core capability and the nearest exclusion are still completely visible, instead of piling on more synonyms. When a trigger is changed, check at least one request that should trigger and one neighbouring request that should not.

## Root SKILL.md

The root file is first of all **the smallest router plus the shared contract**:

- State the boundary of use and the division of work with neighbouring skills.
- Keep only the domain knowledge, permission boundaries, completion conditions or failure guards that every trigger really needs.
- When there are several workflows, route by trigger condition to `reference.md` / `references/*` / a script / a template; do not make the model read a whole manual for one branch.
- Let the model decide ordinary steps from the evidence; do not force a fixed number of questions, order of thought, number of agents, number of tool calls, number of test runs, or a model or reasoning tier.
- Authorization, safety, Git, secret and scope principles that `AGENTS.md` / `project.md` already define are referenced to their owner, not repeated in every skill.

Skills are not required to use the same headings. `When to use / Read first / Order of work / Do not / Minimal verification` may appear where they carry information, but **they are not a format gate**; the format follows the capability itself.

## How to write

- Write the target behaviour positively; a prohibition brings the forbidden practice into the context. Only a hard guard that cannot be expressed positively is written as a prohibition, and it is placed together with the positive goal.
- Write why the rule exists instead of stacking forceful words; a model that knows the reason can handle a case that was not listed.
- A completion condition must be decidable and must also have force: when exhaustiveness is needed, write "every" into the condition (for example "every affected consumer is synchronized"). A vague condition leads to stopping early.
- The cost of a rule comes from the extra actions it triggers, not from its length: wording such as "check once more", "as thoroughly as possible" or "be sure to confirm" makes the model reread and recheck. For a rule that is loaded every time, it must be possible to say which concrete problem it avoids.
- Apply a no-op test sentence by sentence: if this sentence is deleted, does the model's default behaviour change? If not, delete the whole sentence; settle a disagreement with a replay.
- Write only what cannot be looked up in the environment: script names, configuration options and directory structure can be looked up directly, and writing them into a skill only makes a copy that goes stale. What is worth writing is the unwritten convention, the reason for a trade-off and the pitfall the configuration will not admit to.
- When something goes wrong, classify before acting: first rule out an occasional problem unrelated to the rules, and the case where the model did not read the necessary evidence. If a rule is missing or wrong, change the rule. If the rule is right but was not followed, adjust its wording and position or turn it into a deterministic check; do not stack a new rule on top.
- When the same kind of mechanical mistake keeps recurring (a fixed way of writing, a forbidden API, a path location, mismatched names), turn it into a deterministic check in the validator, a lint or a test, not into rule text. Only what needs judgement is written into a rule.
- Write a key constraint where it will be read: do not rely only on "please also read another skill" to carry it, because loading across files is not guaranteed; write the minimum necessary text in place.
- Content known to be out of date but kept for now is marked with the range that is out of date and points to the authoritative source. A usage with no supporting material is written as "not verified" with where to check; do not extrapolate from a similar language, platform or version. A third-party fact written into a skill (a limit, a price, the shape of an interface, command syntax) is first verified by reading the body of the official page; where a link can point to the official page, do not copy it. A link that opens is not verification.
- Read the draft through for decisions that were not written: a model that meets a gap picks something itself. Every gap is either filled explicitly or written as a real branch.
- The wording of a routing row and of the `description` decides whether the material gets read: put the keyword first, give one branch one trigger condition, and do not repeat the identity statement the body already has.

## Progressive disclosure

A supporting file is added only when it lowers the default context or provides real reuse:

```text
SKILL.md             # smallest entry and shared contract
reference.md         # optional: stable method / routes to material
references/<topic>   # optional: deep material that only one branch needs
scripts/             # optional: deterministic, reusable machine steps
templates/           # optional: output structures that are really reused
agents/              # optional: display / invocation metadata
```

The root file must say **when** each supporting file is read. Supporting files are linked directly from the root file, not reached through another supporting file. Do not move the body out and then require all of it to be read back every time, and do not hide the only hard constraint in a reference that cannot be discovered.

## Authorization and execution

A skill inherits the current user scope and the boundaries of `.agents/rules/project.md` that really apply. It cannot upgrade analysis into implementation, and it cannot widen a local implementation into authorization for dependencies, a release, third parties or Git publication.

When the user has already explicitly authorized a complete local fix, the "confirm first" in a skill's example does not create a second approval; what is skipped is the question, and the verification that proves the result works is still done. For an action that really needs new authorization, state only the smallest increment; a local blocker does not block other independent work that is already authorized.

## Verification and completion

- A completion condition describes an **observable result**, not how many rounds of thought the model should have.
- When work stops early, first write the completion condition more explicitly. Only when the condition itself cannot be written clearly, and jumping ahead was really observed, split the later steps behind a real context handover (a new session or a delegation). Splitting into two parts inside the same context is not splitting.
- Verification matches the risk of the change. The project's existing required gates are kept, but an equivalent check is not repeated when there is no failure, no new change and no specific open question.
- For a behavioural change, choose as needed among a normal input, an input with missing or conflicting information, and a neighbouring scenario that should not trigger. Without a real replay, say that it is only a static or manual review.
- Stop once every completion condition that applies to the current task is met. A real blocker pauses only the part that depends on it; report it clearly and go on to finish the other independent, authorized work. Do not keep widening the task for the sake of a longer report or of being "more complete".

## Quality gate

When reviewing a skill, ask first:

1. Is the trigger too wide, and does it overlap with another skill?
2. Does the root contain a long flow that belongs to only one branch?
3. Does it repeat rules that `project.md`, a workflow or a fact document already has?
4. Does it keep the real domain knowledge, tool dependencies, permission and failure boundaries, and completion conditions?
5. Do the old steps still correspond to a current failure mode, or do they only compensate for an older model?
6. Are the supporting files discoverable on demand, instead of forming another must-read stack?
7. Does an example break the skill's own rule? Is the same fact stated differently in two places? After files were moved or merged, do the references to them still work?

Passing a static format check does not prove that model behaviour improved. On a model upgrade, first check the current official guidance and the tools really available, then observe triggering, the range of files read, extra questions and verification behaviour with the relevant regression scenarios.

## Do not

- Do not add a skill that is only a persona, a slogan or an empty methodology.
- Do not copy large passages from an external repository, or a host's existing whole set of model prompts.
- Do not patch a rule conflict with a new skill; the conflict is resolved in its real owner.
- Do not force every skill into the same shape through fixed sections, fixed steps or a fixed checklist.
- Do not stack every model's own scaffolding unconditionally onto a shared skill "to be compatible with more models". Shared content keeps the constraints that are real across models; model-specific calibration is made conditional as needed.
