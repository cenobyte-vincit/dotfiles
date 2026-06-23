---
name: code-workflow
description: >
  Default workflow for implementing new bash scripts and C programs: discovery
  questions, CLI and OS specification, functional test design, test-driven
  development with Makefile test targets, then language-skill verification.
  Prefer starting with /goal <objective>. Use when implementing, building, or
  creating a new script, CLI tool, or C program; when extending one
  substantially; or when the user runs /code-workflow or /goal.
metadata:
  short-description: "Discovery → tests → TDD → done"
---

# Code Workflow

Orchestrate **new or substantial** bash scripts and C programs through discovery, test design, test-driven implementation, and verification.

Apply **`bash-style`** when the deliverable is shell, and **`c-style`** when the deliverable is C. This skill governs **process**; those skills govern **code shape**.

If the repository already has **AGENTS.md**, **CLAUDE.md**, a **Makefile**, or a test harness, ask which conventions to follow and defer to them when they conflict with scaffolding below.

## Preferred start: `/goal`

**Start every full run with `/goal`** — it is the preferred entry point for this workflow.

When the user asks to implement, build, or create a bash script or C program and **no goal is active**:

1. **Suggest** `/goal` with a draft objective derived from what they said (purpose, CLI hints, OS if known).
2. If they prefer to continue without `/goal`, proceed — but still follow all phases below and tell them `/goal` is recommended for multi-turn work.

When **`/goal <objective>`** is used (or a goal is already active), treat the objective as the session outcome, call **`update_goal`** as phases advance, and set **`completed: true`** only in **Phase 4**.

Example:

```
/goal Build the foobar CLI (macOS): parse JSON config, validate paths;
      all make test and make check green
```

`/code-workflow` alone is a valid explicit trigger but is secondary to `/goal` for starting a new piece of work.

## Hard gates

Do **not** write implementation code until:

1. **Discovery** is complete and the user has approved the specification summary.
2. **Functional tests** are drafted, scaffolded (failing is fine), and the user has approved the test plan.

During implementation, do **not** start the next function or feature until the current one's tests pass via **`make test`**.

Do **not** mark the work **done** until every criterion in **Definition of done** is satisfied.

---

## Phase 1 — Discovery

Ask questions **one at a time** as regular conversation (do not batch them in a single form). Adapt follow-ups to answers; skip questions already answered.

### Required topics

Cover all of these before summarising:

| Topic | What to establish |
|-------|-------------------|
| **Purpose** | What the program does; inputs and outputs; side effects; failure modes |
| **CLI** | Arguments, flags, stdin/stdout/stderr, exit codes; or confirm no CLI |
| **Target OS** | macOS/BSD (default), Linux only, or cross-platform — drives `c-style` / `bash-style` platform rules |
| **Scope** | New standalone project vs extending an existing repo; name of the script or program |
| **Dependencies** | External binaries, libraries, privileges, or data the program needs |

### Discovery rules

- **No implementation** during discovery — no source files, no Makefile, no tests yet.
- After the topics are covered, present a **specification summary** (purpose, CLI, OS, layout, dependencies) and ask the user to approve or correct it.
- Proceed to Phase 2 only after explicit approval.

---

## Phase 2 — Functional test design

Guide the user into **functional** test cases before any production code.

### What to propose

Draft a numbered test plan covering:

- **Happy path** — typical successful use
- **Usage errors** — wrong argument count, invalid flags
- **Precondition failures** — missing files, bad permissions, missing dependencies
- **Edge cases** — empty input, boundary values, malformed data
- **Platform-specific behaviour** — only when OS targeting requires it

Present the plan and ask the user to approve, add, or remove cases.

### Scaffold (after test-plan approval)

Create test infrastructure **before** the program under test:

1. **Makefile** with a **`test`** target (and **`check`** / **`lint`** per language skill).
2. **Test files** that invoke the program or script and assert exit codes and output.
3. Run **`make test`** — tests should **fail** until implementation exists (red phase).

### Layout — new standalone bash script

```
Makefile
README.md
script_name.sh          # stub or absent until Phase 3
tests/
  run_tests.sh          # test runner — follows bash-style
  t001_happy_path.sh    # one scenario per file when practical
  ...
```

### Layout — new standalone C program

Follow **`c-style`** file layout. Minimum:

```
Makefile
README.md
program_name.c          # stub or minimal main until Phase 3
tests/
  test_module.c         # unit tests for each module / helper
  ...
```

Split headers and modules per **`c-style`** when the program outgrows a single file.

### Makefile — `test` target (required)

Every new standalone project must expose:

```makefile
.PHONY: all clean test check lint

test:
	@$(MAKE) -f Makefile.test test
```

Or inline the test recipe in the main Makefile. The **`test`** target must be the single entry point Grok runs during development.

**Bash** — `test` runs the test runner (e.g. `tests/run_tests.sh`) and propagates failure:

```makefile
test:
	@./tests/run_tests.sh
```

**C** — `test` builds and runs test binaries; fail on any non-zero exit:

```makefile
TEST_BINS = tests/test_module

test: $(TEST_BINS)
	@for t in $(TEST_BINS); do \
		echo "==> $$t"; \
		./$$t || exit 1; \
	done
```

Also include **`check`** / **`lint`** targets required by **`c-style`** (cppcheck) or **`bash-style`** (shellcheck) for new standalone projects.

Document **`make test`** and dev dependencies in **README.md**.

### Test runner conventions

**Bash test scripts** follow **`bash-style`** (shebang, `set -euo pipefail`, `errx`, tabs). Each test:

- Invokes the script under test with known inputs.
- Compares **exit code** and **stdout/stderr** to expectations (`diff`, `grep`, or `[[ … ]]`).
- Prints `PASS` / `FAIL` with a short description; the runner exits non-zero on any failure.

**C tests** are small programs or functions that call the unit under test and **`return (1)`** / **`exit (1)`** on assertion failure. Test **`static`** helpers by compiling test translation units with the same `.c` file or via a test-only header — keep production symbols `static` until a header is warranted.

Proceed to Phase 3 only after the scaffold exists and the user has approved the test plan.

---

## Phase 3 — Test-driven implementation

Default: implement **one function or cohesive feature at a time** in this loop:

1. **Add or extend tests** for the next unit of behaviour.
2. **Implement** the minimal code to pass those tests.
3. **Apply** **`bash-style`** or **`c-style`** while writing — platform, guards, naming, comments.
4. Run **`make test`** — fix until green.
5. Summarise what passed; ask whether to continue to the next unit or adjust scope.

When several units are **independent**, use **parallel subagents** (see below) instead of strict serial work.

### Rules

- **Red → green → refactor** within each step; do not accumulate untested functions.
- New **helpers** get tests in the same loop before callers depend on them.
- **CLI wiring** (`main`, argument parsing) comes after core logic has unit tests, unless the logic is inseparable from the CLI.
- If a test was wrong, fix the test **with user agreement**, then re-run **`make test`**.

### Parallel implementation via subagents

Grok can run implementation in parallel using **`spawn_subagent`**. Subagents are enabled by default. Use parallel work when units have **no dependency order** and **disjoint file ownership**.

#### When parallel is appropriate

| Parallel OK | Stay serial |
|-------------|-------------|
| Independent helpers or modules (e.g. `parse_line` and `format_date`) | B depends on A's behaviour or symbols |
| Separate test files per unit (`tests/t010_*.sh`, `tests/test_parse.c`) | Shared single file being edited by multiple agents |
| Phase 2: drafting many test scaffolds at once | Integrating `main()` / CLI wiring before core units are tested |
| Distinct C modules with their own `.c` / test binary | Refactoring interfaces between coupled units |

Dependency order still wins: a caller's tests must not be implemented before the callee it relies on is green — unless the callee is stubbed and tests mock only the unit boundary.

#### Orchestrator pattern

The **parent session orchestrates**; subagents implement scoped slices. The parent must **not** narrate launches without actually calling **`spawn_subagent`** in the same response.

1. **Partition** the approved test plan into independent **work units**. Each unit lists: functions/behaviour, files it may edit, and test files it owns.
2. **Spawn** one subagent per unit — launch multiple subagents in a **single turn** when they are independent. Use **`background: true`** so they run concurrently.
3. **Subagent prompt** must include:
   - The unit scope and file ownership (only touch those files).
   - **`bash-style`** or **`c-style`** as applicable.
   - Instructions: write/extend tests for the unit → implement minimal code → run **`make test`** (or the unit's test subset) until green.
   - The shared spec summary from Phase 1 (CLI, OS, purpose).
4. **Wait** with **`wait_commands_or_subagents`** (`mode: wait_all`) or poll with **`get_command_or_subagent_output`**.
5. **Integrate** — parent runs full **`make test`**. Fix integration issues (wiring, `main`, Makefile, shared headers) serially.
6. **Gate** — do not start the next parallel batch until the full suite passes.

#### Avoiding edit conflicts

Default subagent isolation is **`none`** (shared workspace). Parallel subagents editing the **same file** will conflict.

- Assign **one primary source file + matching test file(s)** per subagent.
- For C, prefer separate **`tests/test_<module>`** binaries per module.
- If units must touch shared files (e.g. one `main.c`), keep those edits **serial** or use **`isolation: worktree`** per subagent and merge after each batch — worktrees add merge overhead; prefer file partitioning first.

#### Subagent types

| Type | Use for |
|------|---------|
| `general-purpose` | Implement unit + tests (default) |
| `explore` | Read-only: survey existing repo test layout before partitioning |
| `code-reviewer` | Optional post-batch review of a completed unit |

Do not use **`/implement`** for the TDD loop itself — that skill runs implement→review→fix. This workflow owns discovery, test design, and per-unit TDD; subagents here are scoped implementers, not the full `/implement` orchestration.

#### Example parallel batch

Three independent bash helpers `normalise_path`, `validate_input`, `render_output` — spawn three background subagents:

- Agent A: `tests/t010_normalise.sh` + `normalise_path()` in `script.sh`
- Agent B: `tests/t020_validate.sh` + `validate_input()` in `script.sh`

If all helpers live in one `script.sh`, either **serialize** edits to that file or split helpers into sourced files (`lib/normalise.sh`, etc.) so each subagent owns a separate path.

After all three return green locally, parent runs **`make test`**, then wires helpers together in `main()` in a final serial step.

---

## Phase 4 — Definition of done

Work is **done** only when **all** of the following hold:

| Check | Bash | C |
|-------|------|---|
| **`make test`** | All tests pass | All tests pass |
| **Lint / analysis** | `bash -n`, **shellcheck** (project target or direct) | **cppcheck** via `make check` or equivalent |
| **Style skill checklist** | **`bash-style`** review checklist complete | **`c-style`** review checklist complete |
| **Build** | Script executable; `bash -n` clean | `make all` with `-Wall -Wextra -Werror` clean |
| **Docs** | README lists test and lint commands | README lists cppcheck, test, and build commands |

Run the checks yourself before declaring done — do not ask the user to run them unless execution is impossible in the environment.

Optionally run **`/check-work`** for a final verification pass when the user wants it.

Report completion with:

- What was built (purpose, CLI, OS).
- Test count and **`make test`** result.
- Lint/analysis result.
- Any deliberate limitations or follow-ups.

---

## Goal mode (`/goal`)

**`/goal` is the preferred way to start this workflow** (see **Preferred start** above). It works alongside the phase structure at different layers:

| Mechanism | Role |
|-----------|------|
| **`/goal`** | Cross-turn objective — what to achieve; persists until `completed: true` |
| **`code-workflow`** | How to achieve it — phases, gates, TDD, verification |

When a goal is active (via **`/goal <objective>`** or an existing session goal), follow this skill's phases and use **`update_goal`** to log progress.

### Goal text

Phrase the objective as an **outcome**, not a process skip:

```
/goal Build the froobar CLI (macOS): parse JSON config, validate paths, exit codes documented; all make test and make check green
```

Avoid objectives that bypass gates (e.g. "implement without asking") — discovery and test-plan approval still require user input.

### `update_goal` usage

Log phase transitions and batch results; do **not** set **`completed: true`** until **Phase 4 — Definition of done** is fully satisfied:

```text
update_goal(message: "Phase 1 complete — spec approved")
update_goal(message: "Phase 2 complete — test scaffold failing as expected")
update_goal(message: "Phase 3 — parse_config green; wiring main next")
update_goal(completed: true, message: "make test and make check pass; bash-style checklist done")
```

Use **`blocked_reason`** only when genuinely stuck after multiple attempts — not while waiting for user answers in discovery or test-plan approval.

### Autonomy vs gates

| Phase | Goal mode behaviour |
|-------|---------------------|
| **Discovery** | Ask questions one at a time; pause for user answers — goal does not auto-fill the spec |
| **Test plan** | Pause for approval before scaffolding |
| **TDD / parallel subagents** | Drive autonomously through units; run **`make test`** each step |
| **Done** | **`update_goal(completed: true)`** only after full verification |

**`/goal status`**, **`/goal pause`**, **`/goal resume`**, and **`/goal clear`** work as usual. Pausing a goal does not suspend style-skill requirements.

---

## When this skill does not apply

- **Trivial edits** — typos, one-line fixes, comment-only changes: apply language skills directly; no full workflow.
- **Repos with established CI** — use the project's existing test commands; still follow the TDD loop spirit when adding behaviour.
- **Non-code tasks** — documentation-only, config tweaks, git operations: skip this skill.

---

## Quick reference

```
/goal <objective>   ← preferred start
    ↓
Discovery (questions → spec approval)
    ↓
Test plan (cases → user approval → scaffold → make test fails)
    ↓
TDD loop (test → implement → make test; parallel subagents when units are independent)
    ↓
Done (make test + lint + style checklists)
```