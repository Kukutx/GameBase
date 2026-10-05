---
name: solution-grill
description: Challenge a proposal before implementation when the user explicitly asks to grill assumptions, compare important trade-offs, or resolve key decisions first. Not for ordinary clarification.
---

# Aligning on a solution in depth

Use this skill only when the user explicitly asks to **challenge the proposal or its key assumptions first**; it is not a preliminary step for an ordinary bug or a small change. When the user only asks to align, stay read-only. When the same request already explicitly asks to "grill / align first, then implement", this skill is responsible only for the decisions that come first; when they are done, hand over to the normal implementation flow, which inherits the implementation scope that request already has, and no second authorization is created. Dependencies, Git, release and external writes are still judged by their own boundaries.

## What to align on

First use the current code, data contracts, configuration and the necessary official facts to remove the questions the repository can already answer, and leave only what the user really has to decide: the game or design goal, the important trade-offs that would change what the player experiences, irreversible boundaries, the scope, and success criteria that can be verified.

Treat the open decisions as a tree with dependencies in order. In each round, ask at once every decision whose premises are already settled; number each question and attach a recommended answer with its grounds, so that the user only has to confirm or rewrite by number. A question whose answer depends on another open question of the same round is left for the next round and not guessed ahead. Facts are looked up by the agent; while a lookup is running, only the questions that depend on it pause and the rest are asked as usual. Decisions belong to the user; the agent recommends and does not decide for the user. Alignment is complete only when every branch has an explicit conclusion and no assumption was passed over by default. When an answer changes a conclusion settled earlier, reopen the affected branches. For a question that questions and answers cannot settle (how an interaction feels, a layout trade-off, one long screen or several steps), stop asking, build a prototype or a real sample, and come back to decide.

Reversible, low-impact implementation details are left for the later implementation stage to decide autonomously. Compatibility, migration or versions enter the discussion only when they really change the solution; several alternatives or a long-term roadmap are not produced to look thorough.

## End condition

End the grill stage when the Goal, the key decisions, the Non-goals, the scope and the Success criteria are enough for the following work to proceed safely. When the user only asked for a grill, summarize in the conversation the recommendation, the main grounds, the real trade-offs and the decisions that are still blocking, and stop. When the same request already explicitly asked for implementation afterwards, hand over directly to the normal implementation flow and go on to finish the whole goal, unless a real new blocker appears. Without an explicit request from the user, no spec, ADR or TODO is created.
