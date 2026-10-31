---
name: refactor-code
description: Improve the structure of existing code (extract functions/modules, remove duplication, simplify conditionals, improve naming and typing) in small, behaviour-preserving steps protected by tests. Use when the user asks to refactor, clean up, simplify, restructure, decouple, or pay down tech debt in existing code.
---

# Refactor Code

## Purpose

Make code easier to understand and change **without changing its observable behaviour**. Every
step is small, reviewable and verified by tests. Refactoring is never mixed with feature work or
bug fixes in the same change.

## When to use

- "Refactor / clean up / simplify this", "this function is too long", "remove duplication"
- Preparing code for a feature (refactor first, then implement — separate commits/PRs)
- Migrating to a pattern the project has already adopted elsewhere

### When NOT to use

- The user wants new behaviour → `implement-feature` (refactor only what the feature needs).
- Large rewrites or framework migrations → write a spec and get approval; do not start coding.
- Code without tests where tests cannot be added → explain the risk and ask how to proceed.

## Required context

1. `.ai-harness/project-context.md` — conventions, modules that must not change, commands.
2. `.ai-harness/instructions/general.md` and the stack file(s) for the target code.
3. The target code **and all its callers** (search: `grep -rn "function_name" .`, IDE references).
   Public APIs, serializers, event payloads, DB schema and CLI interfaces are contracts.
4. Existing tests covering the target; coverage report if available.
5. The motivation: what change is this refactor enabling? Keeps the scope honest.

## Steps

1. **Define the goal and boundaries.** One sentence: what will be better, and what will not change
   (public interfaces, behaviour, performance characteristics, DB schema).
2. **Find code smells concretely:** long functions, deep nesting, duplicated logic, unclear names,
   god classes, leaky abstractions, mixed I/O and business logic, missing types.
3. **Secure a safety net.** Run existing tests. If coverage of the target is weak, add
   characterisation tests first with the `write-tests` skill (they capture current behaviour, even
   odd behaviour — note suspected bugs instead of fixing them).
4. **Plan small steps** and show the plan if the refactor spans more than a few functions or files.
   Typical sequence: rename → extract function → move to module → replace conditional with
   polymorphism/lookup table → delete dead code.
5. **Approval checkpoint — stop and ask** before: changing public/exported interfaces, renaming
   DB columns/tables, changing serialized formats, deleting code that might be used dynamically
   (signals, reflection, string-based imports, templates), or touching more files than agreed.
6. **Execute step by step.** After each step run the relevant tests. Keep commits atomic and
   behaviour-preserving. Use the project's tooling for mechanical work (IDE rename, `ruff --fix`,
   `eslint --fix`) where it is already configured.
   - Python: extract pure functions out of views/models into services the way the project does;
     add type hints; replace mutable default args; use dataclasses/Pydantic models already in use.
   - JS/TS/React: extract custom hooks for reused stateful logic, split large components, replace
     prop drilling with existing context/store patterns, tighten types (remove `any`).
7. **Preserve compatibility.** If an interface must change, keep a thin deprecated alias/adapter
   and note its removal as a follow-up.
8. **Verify.** Full relevant suite, linters and type checkers (`ruff check`, `mypy`, `npx tsc --noEmit`,
   `npm run lint`). Compare behaviour for edge cases noted in step 3.
9. **Review** using the `code-review` skill; the diff should read as "same behaviour, clearer code".

## Expected output

- Goal and boundaries of the refactor.
- Summary of each step (what changed and why it is better), files touched.
- Confirmation behaviour is unchanged: tests/linters/type checks run with results.
- Suspected bugs found but intentionally not fixed; deprecated aliases and follow-ups.

## Validation checklist

- [ ] No behaviour change (tests green before and after, same outputs for edge cases)
- [ ] Characterisation tests added where coverage was missing
- [ ] Public interfaces, schemas and payloads unchanged, or change approved with compatibility shim
- [ ] No feature work or bug fixes mixed in
- [ ] Changes follow existing project patterns; no new framework/library introduced without approval
- [ ] Dead code removed only after confirming no dynamic usage
- [ ] Linters and type checkers pass
