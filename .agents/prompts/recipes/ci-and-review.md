# CI, runners and local change review recipe

Read only for designing, changing, speeding up or troubleshooting GitHub Actions and CI, for hosted runners that cannot start, or when the user asks for a review of the current diff, the current branch or the change before a commit or a push. An ordinary explanation of source code, a single-file implementation, or a scoped or whole-repository audit does not trigger it. By default do not rerun, cancel or delete a remote run, do not change repository variables, and do not stage, commit or push, unless the current request explicitly covers that action.

## CI/CD design and performance review

For a change to CI/CD, the build and release chain, the test strategy or runners, or automated gates, and for a review of how long they take, read `.agents/rules/ci-performance.md`. A review of an ordinary source diff alone does not load that rule.

First draw the job dependencies that actually block the release or the feedback, and the points where work is repeated, then choose the smallest necessary change; with run data, compare queueing, execution, cache state and total runner-minutes, and without data state clearly that it is a static assessment. A new heavy gate must state its independent verification value, its effect on time and budget, and why reuse or layering is not possible; check the change selection, the required checks, test isolation, the origin of artifacts and the safety of cancellation, and do not let "everything is green" replace the performance acceptance.

## Troubleshooting GitHub Actions / CI

First use the current read-only GitHub and project entry points to get the recent runs, the failed job and the necessary logs, and locate the stage that really failed. A Godot step fails on a non-zero exit code or on any `ERROR:` or `SCRIPT ERROR:` output line, so read the log for those lines and not only for the exit code. After a change under `.github/workflows/**`, run the workflow assertions of the project:

```
node tools/validate.js
```

They live in `test/unit/test_project_configuration.gd` and run in the GUT step.

A failure is attributed with one of three conclusions only: a problem in the code, an occasional problem of the infrastructure or the environment, or insufficient evidence. When the log is incomplete, name the part that is missing; do not conclude "not a code problem" from partial evidence.

Do not skip tests, swallow errors, loosen a release guard or change a secret or an environment to make CI green.

## Hosted runners that cannot start

This repository runs on GitHub-hosted runners only: `.github/workflows/ci.yml`, `.github/workflows/release.yml`, `.github/workflows/engine-compat.yml` and `.github/workflows/addon-freshness.yml` have no self-hosted fallback and no runner selection variable. Do not load this detail into an unrelated task.

- When a hosted job seems to be blocked by billing, a spending limit, included minutes or availability, first read the job and check-run evidence. Only a job that got no runner, ran no step and carries a GitHub annotation that explicitly points at such a gate counts as a hosted outage; an ordinary failure in the code is not one.
- Without an explicit decision by the user, do not add a self-hosted runner, a runner selection variable or a parallel workflow, and do not copy the workflows, secrets, environments or the repository. When the authorization is not enough, stay read-only and state the smallest approval that would be needed.
- Meanwhile run the equivalent checks locally (`node tools/validate.js`, `node tools/export.js`, `node tools/smoke_export.js`, `npm run --prefix tools/web_smoke smoke:web`) and report them as local evidence; they do not make a pending or blocked remote check pass.
- Once hosted runners are available again, the same workflows run again unchanged.
- A self-hosted runner is a persistent environment; system-level cleanup that suits only a one-off GitHub-hosted machine is not reused on one. An open-source repository does not put untrusted pull requests on a personal self-hosted runner.

## Local quality review before a commit or a push

Goal: review whether the change the user named is good enough to commit or push; by default only read the Git state, and do not stage, commit or push.

A Finding must be traceable to what the named diff or branch changes, or to the regression surface that change directly affects. A surrounding existing problem that this change does not introduce, widen or expose is not a Blocker or a Warning of the current review; when it is really worth mentioning, mark it separately as an out-of-scope observation. Only when the user explicitly asks for a scoped or whole-repository audit is the audit scope applied; an ordinary change review is not widened automatically.

Basics:

```
git status --short
git diff --check
```

Pick the smallest related checks for what really changed, for example:

- GDScript, scenes, resources and content: `node tools/validate.js --skip-soak` while iterating, and without `--skip-soak` when the change touches save data or time progression
- Player-visible text: `node tools/check_localization.js`
- Tools: `node tools/validate.js`, which runs the packaging self-test, plus the tool that changed
- Export and packaging: `node tools/export.js --preset <preset>` and `node tools/smoke_export.js`; for the Web target also `npm run --prefix tools/web_smoke smoke:web`
- CI workflows: the workflow assertions in `test/unit/test_project_configuration.gd`
- `.agents`: `node tools/validate_rules.js --strict` plus a review of the related pressure-test scenarios

Check whether the goal is complete, whether the scope crept, whether schemas, generated output and consumers are in step (content ids and the manifest, saved keys and `SaveMigration`, exported resource fields and the scenes and resources that set them, text and its Simplified Chinese entry), whether a workaround, a second source of truth or compatibility without a basis was introduced, and whether changes from another session got mixed in. In the conclusion, say in one sentence whether this change can be taken back and how far its effect reaches: a save format that a published build has written, a pushed release tag and a published release with its packages are the kind that cannot be taken back; for everything else state how it is taken back. Evidence is written as a before-and-after comparison (the specific check that failed before and passes now, or the behaviour in the running game or the exported build); "checks pass" alone is not evidence. A check that did not run is not reported as passed; when the Git state is abnormal, do not repair the index and do not write files back from HEAD.
