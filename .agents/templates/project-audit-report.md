# Project audit report template

> Use this only when the user explicitly asks for the audit report to be archived. The template is a structure to cut down; it does not require every section, a number of problems, scores or a long-term roadmap. Leave out whatever is unrelated to the current audit goal.

## Audit scope

- Time / current revision:
- The question the user wants answered:
- In scope:
- Excluded / unreadable:
- Limits of the evidence:

If a key area could not be read, write "partial audit" explicitly; do not let "no problems found" stand in for a statement of coverage.

## Conclusion

Answer the question the user cares about most in one to three sentences.

- Is there a clear blocker:
- The most valuable action now:

## Findings

List only high-value problems that can be backed by evidence. Merge those with the same root cause; do not create entries for the sake of a complete template.

### <short title>

- **Severity (optional)**: P0 / P1 / P2 / P3
- **Kind of conclusion**: fact / inference
- **Symptom / trigger condition**:
- **Impact**:
- **Evidence**: `path:function/class/resource/section`, or runtime evidence
- **Counter-evidence / existing protection**:
- **Smallest recommendation**:
- **How to verify**:
- **Does it need confirmation from the user or a design decision**:

## Unknowns / to be verified

List only the items that affect the current judgement but lack evidence.

| Unknown | Current gap | Smallest way to verify | Why it matters |
|---|---|---|---|

## Priorities

The summary lists the most valuable actions first. A full audit keeps every problem that holds and its status; the length of the summary does not limit coverage or an authorized repair.

| Order | Action | Expected benefit | Dependency / blocker | Acceptance evidence |
|---:|---|---|---|---|

## Optional: coverage statement

For an explicit full audit of a named scope, or a whole-repository or system-level audit; automated scanning, reading of the body, sampling and runtime verification are stated separately.

| Area / chain | Status: read / sampled / excluded / unreadable | Note |
|---|---|---|

## Optional: long-term or platform assessment

Add this only when the user explicitly asks for a roadmap, a time scale, or a platform, store or compliance matrix. Do not generate a 1/3/6/12-month plan, fixed platforms or dimension scores by default.

## Boundary of the report

- Historical plans, archives and old audits in the report are leads only; the current conclusion must go back to this round's evidence.
- Do not record secrets, personal or other sensitive player data, attack steps that can be used directly, or large passages of internal logs.
- When the matching verification was not run, write "not verified"; do not claim "fixed / passed / runs".
- The audit report itself does not create new authorization to repair. When the current request has already explicitly authorized "fix the problems that are found", keep that authorization and hand over through the normal implementation flow; otherwise a repair still needs matching authorization.
