---
name: bash-style
description: >
  Apply personal bash/shell scripting standards when writing, editing, or
  reviewing shell scripts. Use for .sh files, bash scripts, shell functions,
  CI scripts, or when the user asks for shell style, conventions, or review.
metadata:
  short-description: "Personal bash style guide"
---

# Bash Coding Standards

Apply these standards to **all bash scripts you write or edit** — new and existing — unless the repository has its own **AGENTS.md** or **CLAUDE.md** that overrides them.

## Design intent (C-shaped CLI layout)

Scripts are structured like small **C command-line programs**, not minimal shell glue:

| C convention | Bash equivalent |
|--------------|-----------------|
| `main(argc, argv)` | `main()` + `main "$@"` as the last line |
| `errx(3)` / `err(3)` (`err.h`) | `errx()` — message on stderr, `exit 1` |
| `usage()` / program name | `usage()` + `readonly __progname="$(basename …)"` |
| `const` locals | `local -r` by default |
| Early precondition checks | Two-line guards (`test && \` / tab-indented action) |
| Tab-indented blocks | Tabs only — no space indentation |
| `for (i …; j …; k …)` | Loop variables `i`, `j`, `k` |

- A single **`main`** orchestrates work; helpers use **`snake_case`**.
- **Validation runs upfront** in a fixed order (see `main()` ordering below).
- **House style** for multi-step CLI tools — predictable layout, explicit failure paths, familiar to C/BSD systems programmers.
- **Bash still wins** when builtins replace externals; the goal is C-like **structure and control flow**, not fighting the shell.

## Interpreter and strict mode

Every executable script starts with:

```bash
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
```

| Flag | Purpose |
|------|---------|
| `-e` | Exit on command failure |
| `-u` | Treat unset variables as errors |
| `-o pipefail` | Pipeline fails if any stage fails |
| `IFS` | Restrict word splitting to newline and tab |

Omit `set` flags in scripts meant to be **sourced** — they affect the caller's shell.

## Script header

Immediately under the shebang, every script has a **comment header** block:

```bash
#!/usr/bin/env bash
#
# script-name - Concise one-sentence description.
#
# A longer description with more detail: what the script does, what it
# expects as input, platform or privilege requirements, and side effects.
#
set -euo pipefail
```

Rules:

- A single `#` on its own line separates the shebang from the header text, and separates the one-liner from the detailed description.
- **First header line:** script name (basename of the file, without directory) + ` - ` + one concise sentence.
- **Detailed block:** one or more comment lines explaining behaviour, arguments, dependencies, and constraints.
- End the header with a single `#` on its own line before `set -euo pipefail` and the rest of the script.
- Header comments use `#` at column 0 — not tab-indented.

## Required script skeleton

Every executable script must include:

1. `#!/usr/bin/env bash` shebang
2. Script header (see above)
3. `set -euo pipefail` and `IFS=$'\n\t'`
4. `readonly __progname="$(basename "${BASH_SOURCE[0]}")"` — script basename, not full path
5. `readonly PATH="/usr/sbin:/usr/bin:/sbin:/bin"` — immediately under `__progname`
6. An `errx()` helper
7. A `usage()` helper — **when the script takes command-line arguments**
8. A `main()` function containing all script logic
9. `main "$@"` as the **very last line** of the file — no trailing code or comments

```bash
#!/usr/bin/env bash
#
# parse-json - Extract a key from a JSON file and print its value.
#
# Takes one argument: a path to a JSON file. Requires jq in PATH.
# Prints the value of the top-level "name" field to stdout.
#
set -euo pipefail
IFS=$'\n\t'

readonly __progname="$(basename "${BASH_SOURCE[0]}")"
readonly PATH="/usr/sbin:/usr/bin:/sbin:/bin"

errx() {
	echo -e "${__progname}: $*" >&2

	exit 1
}

usage() {
	echo -e "usage: ${__progname} <file>" >&2

	exit 1
}

main() {
	[[ "$#" -ne 1 ]] && \
		usage

	for bin in jq yq; do
		! command -v "${bin}" >/dev/null 2>&1 && \
			errx "cannot find '${bin}' in 'PATH=${PATH}'"
	done

	local -r target="${1}"
	# ...
}

main "$@"
```

Scripts with **no arguments** omit `usage()` and the `"$#"` check.

### Script-relative paths

When the script must locate files beside itself (installers, bundled assets), add **`__script_path`** alongside **`__progname`**:

```bash
readonly __script_path="${BASH_SOURCE[0]}"
readonly __progname="$(basename "${__script_path}")"

main() {
	local -r repo_root="$(cd "$(dirname "${__script_path}")" && pwd)"
	# ...
}
```

Use **`__script_path`** for `dirname` / `cd`; use **`__progname`** only in messages and `usage()`.

### Default PATH

Every script resets `PATH` to a known baseline immediately after `__progname`:

```bash
readonly __progname="$(basename "${BASH_SOURCE[0]}")"
readonly PATH="/usr/sbin:/usr/bin:/sbin:/bin"
```

- **`__progname`** is the script **basename** (e.g. `install_skills.sh`) — matches C `__progname` / `errx` output, not the full path from `BASH_SOURCE[0]`.
- For **script-relative paths** (`dirname`, sourcing neighbours), keep the full path in a separate readonly, e.g. `readonly __script_path="${BASH_SOURCE[0]}"` — never `dirname "${__progname}"`.
- Fixed order: `/usr/sbin`, `/usr/bin`, `/sbin`, `/bin` — no other directories by default.
- `readonly` — do not mutate `PATH` later without an explicit, commented reason.
- Dependency-check `errx` messages report this `PATH`; tools must live in these directories or you must document and justify a deliberate extension.

## Naming

| Kind | Convention | Example |
|------|------------|---------|
| Program name var | `__progname` (readonly) | `readonly __progname="$(basename "${BASH_SOURCE[0]}")"` |
| Default `PATH` | fixed (readonly) | `readonly PATH="/usr/sbin:/usr/bin:/sbin:/bin"` |
| Functions | `snake_case` | `check_deps()`, `usage()` |
| Locals | `snake_case` | `local -r config_path=…`, `local i=0` |
| Loop counters | `i`, `j`, `k`, … | `for ((i = 0; i < n; i++))`, nested `j`, `k` |
| Dep-check loop | `bin` (fixed) | `for bin in jq yq; do` |
| Constants | `SCREAMING_SNAKE` | `readonly MAX_RETRIES=3` |
| Environment | `SCREAMING_SNAKE` | `OUTPUT_DIR` |

## Formatting

- **Tabs only** for indentation. Never use spaces.
- Tab-indent function bodies, `case` arms, loops, and continuation lines after `&&` / `||`.
- Max line length: 100 characters when practical.

### Blank lines (required)

- **No consecutive blank lines** — never two or more empty lines in a row.
- **At most one** blank line between any two blocks of code (functions, guard groups, declarations, logical steps in `main`).
- **Zero** blank lines between blocks is fine when the code reads clearly without a separator.
- **Exception:** skeleton **`errx()`** and **`usage()`** keep exactly **one** blank line between the `echo` and `exit 1` (see below).

```bash
# Bad — double blank between blocks
local -r path="${1}"


do_work "${path}"

# Good — no blank, or a single blank
local -r path="${1}"

do_work "${path}"
```

### `&&` and `||` line continuations (required)

When a test or command is followed by **`&&`** or **`||`**, split across two lines:

1. First line ends with **`&& \`** or **`|| \`** (backslash after the operator).
2. Right-hand side on the **next line**, indented **one tab deeper** than the first line.

```bash
# Good
[ ! -f "${path}" ] && \
	errx "file not found: ${path}"

[[ "$#" -ne 1 ]] && \
	usage

[ -f "${src}" ] || \
	return 1

! command -v "${bin}" >/dev/null 2>&1 && \
	errx "cannot find '${bin}' in 'PATH=${PATH}'"
```

```bash
# Bad — no backslash before the line break
[ ! -f "${path}" ] &&
	errx "file not found: ${path}"

# Bad — RHS on the same line when the guard spans two lines visually elsewhere
[ ! -d "${dir}" ] && errx "missing"
```

**Exception:** a short `&&` / `||` chain may stay on **one line** when the full expression fits within the 100-column limit (e.g. `try_once && return 0`, `$(cd "${dir}" && pwd)` inside a substitution).

### Guard clauses (preferred over `if`)

**Always prefer guard clauses** over `if`/`then`/`fi` for preconditions, validation, and early exits. Guards keep the happy path flat and avoid nested indentation — the same reason C code favours early `return` over deep `if` trees.

### `errx()` guards — negative test, `!`, and `&&` (required)

**Never** call `errx()` inside `if`/`then`/`fi`. Fatal precondition checks use a **negated** test on one line, then `&& errx` on the next (tab-indented):

```bash
[ ! -f "${path}" ] && \
	errx "file not found: ${path}"

[ ! -d "${src_root}" ] && \
	errx "source directory not found: ${src_root}"

! command -v "${bin}" >/dev/null 2>&1 && \
	errx "cannot find '${bin}' in 'PATH=${PATH}'"

[[ ! "$(uname -s)" =~ ^Darwin ]] && \
	errx "macOS (Darwin) required"
```

Rules:

- **Negate the failure condition** with `!` inside `[ ]` / `[[ ]]` or as a leading `!` on a command.
- Chain with **`&& errx`** — not `|| errx`, not `if … then errx … fi`.
- After guards, the happy path continues flat — no `else` branch for errors.

```bash
# Bad — if + errx
if [ ! -f "${path}" ]; then
	errx "file not found: ${path}"
fi

# Bad — positive test + else + errx
if [ -f "${path}" ]; then
	do_work "${path}"
else
	errx "file not found: ${path}"
fi

# Bad — || errx (positive success test inverted)
[ -d "${src_root}" ] || \
	errx "source directory not found: ${src_root}"

# Bad — && without backslash before line break
[ ! -f "${path}" ] &&
	errx "file not found: ${path}"

# Good — negative test + && \ + errx
[ ! -f "${path}" ] && \
	errx "file not found: ${path}"

do_work "${path}"
```

**`usage()`** and **`return 1`** use the same **`&& \`** / **`|| \`** split; the `!` + `&& errx` rule applies to **`errx()` only**.

### Other guards

Recoverable helper failures use `|| return 1` (no `errx`):

```bash
[ -f "${src}" ] || \
	return 1
```

Use a full `if`/`then`/`fi` **only** when:

- Both branches do substantial, non-trivial work (real `else` logic, not just an error exit)
- The branch body has **multiple statements** that cannot be reduced to a single guard action
- You need `elif` chains for three or more distinct cases (consider `case` instead)

If an `if` exists only to call `errx`, rewrite it as a negated `[ ! … ] && errx` guard.

- Use `[ ]` for simple numeric/string/file tests.
- Use `[[ ]]` for argument-count checks, platform checks (`uname` + `=~`), and regex matches.

## errx() and usage()

Do not rename, duplicate, or substitute `die()` or inline `echo` + `exit`.

```bash
errx() {
	echo -e "${__progname}: $*" >&2

	exit 1
}

usage() {
	echo -e "usage: ${__progname} <file>" >&2

	exit 1
}
```

- Both use `echo -e` (bash builtin). Exactly one blank line before `exit 1` (the only blank line inside these functions).
- **`errx`**: all fatal errors except wrong argument count.
- **`usage`**: lowercase `usage:` prefix; `${__progname}` never hard-coded; always `exit 1`.
- Only the argument description in `usage` changes per script (e.g. `<file>`, `<path>`, `<name>`).
- Non-fatal helper failures use `return 1`, not `exit`.

### Argument count

Validate at the top of `main()`, before dependency checks and other work:

```bash
[[ "$#" -ne 1 ]] && \
	usage

[[ "$#" -lt 1 ]] && \
	usage

[[ "$#" -ne 2 ]] && \
	usage
```

After validation, bind arguments: `local -r target="${1}"`, `local -r output="${2}"`.

## main() ordering

1. `[[ "$#" -ne N ]] && \` / `usage` — when script takes arguments
2. `[[ "$(uname -s)" =~ ^Darwin ]]` or `^Linux` — **platform-specific scripts only**
3. `for bin in …` dependency loop
4. Other precondition guards (`errx`)
5. Bind `"${1}"`, `"${2}"`, … to `local -r` named variables
6. Script logic

## Platform checks

When a script targets **one platform only**, after the `usage` / `"$#"` check, before the dependency loop:

```bash
# macOS-only
[[ ! "$(uname -s)" =~ ^Darwin ]] && \
	errx "macOS (Darwin) required"

# Linux-only
[[ ! "$(uname -s)" =~ ^Linux ]] && \
	errx "Linux required"
```

- `uname -s` returns `Darwin` (macOS) or `Linux` — `^Darwin` and `^Linux` are correct.
- Quote the substitution: `"$(uname -s)"`. Use **negated** `[[ ! … =~ … ]] && errx` — not `if`, not `|| errx`.
- Omit for cross-platform scripts.

## Bash internals first

Prefer **bash builtins and shell features** over external binaries. External tools go in the dependency loop; builtins do not.

| Prefer (builtin / shell) | Over (external) | When |
|--------------------------|-----------------|------|
| `echo -e`, `printf` | `/bin/echo` | Messages, errors, usage |
| `[[ ]]`, `(( ))` | `test`, `[` | Conditionals |
| `${var##*/}`, `${var%/*}` | `sed` | Simple string edit/strip |
| `$(<"${file}")`, `readarray` | `cat`, `head`, `tail` | Modest file reads |
| Bash arrays | `awk` split | Modest line lists |
| `command -v`, `type` | `which` | Tool lookup |

Use externals when bash is a poor fit: `jq`/`yq`, `git`, `docker`, platform tools (`codesign`, `otool`), etc.

`echo -e` and `printf` are **both** builtins — this style uses `echo -e` for `errx`, `usage`, and simple verbose lines; use `printf` for explicit format strings.

### Anti-patterns (avoid)

These follow from **bash internals first** — do not spawn a subprocess when a builtin or redirection suffices.

| Anti-pattern | Use instead |
|--------------|-------------|
| `cat "${file}"` alone or into a variable | `$(<"${file}")`, `readarray`, or `while read -r` |
| `cat "${file}" \| grep …` | `grep … -- "${file}"` |
| `cat "${file}" \| sed …` | `sed … "${file}"` or parameter expansion |
| `cat "${file}" \| awk …` | `awk … "${file}"` — or bash arrays / `read` when the logic is simple |
| `cat "${file}" \| while read` | `while IFS= read -r line <&3` with `3<"${file}"`, or `readarray` |
| `echo "$(cat "${file}")"` | `printf '%s' "$(<"${file}")"` or assign `$(<"${file}")` |
| `which foo` | `command -v foo` |
| `` `cmd` `` | `$(cmd)` |
| `ls \| grep foo` | globs (`foo*`), `find`, or `compgen` — not `ls` parsed as text |
| `grep -q pat && echo yes \|\| echo no` | `[[ … ]]` or a direct test |
| `test -f …` / bare `[` for bash logic | `[[ … ]]` |
| `export FOO=$(cat .env)` | `FOO=$(<.env)` then `export FOO`, or `set -a; source .env; set +a` when appropriate |
| `rm -rf $(find …)` | `find … -delete`, or a `while read` loop with `rm -f --` |

**Useless use of `cat` (UUOC)** — the most common mistake: `cat` does not add capability; it adds a process and a pipe. If the next command in the chain can take a file argument or stdin from a redirection, drop `cat`.

```bash
# Bad — UUOC
content="$(cat "${path}")"
grep pattern <(cat "${path}")

# Good
content="$(<"${path}")"
grep pattern -- "${path}"
```

```bash
# Bad — cat into a pipeline for line reading
cat "${path}" | while IFS= read -r line; do
	process "${line}"
done

# Good — open the file once on a dedicated fd
while IFS= read -r line <&3; do
	process "${line}"
done 3<"${path}"
```

Legitimate `cat` uses: concatenate **multiple** inputs (`cat a b >out`), or show a file to **stdout** for a human (`cat` as the final action). Reading one file into the shell is not one of them.

## Variables and quoting

- Inside functions: **`local -r` by default**; plain **`local`** only when reassigned (counters, mutable state).
- Never bare assignments inside functions without `local` or `local -r`.
- Quote all expansions: `"${var}"`, `"$@"`.
- `${var:-default}` for defaults; prefer `errx` over `${var:?}` for user-facing errors.

```bash
load_config() {
	local -r path="${1}"
	local -r config="$(<"${path}")"

	process "${config}"
}

retry() {
	local i=0
	local -r max=3

	while [ "${i}" -lt "${max}" ]; do
		try_once && return 0
		i=$((i + 1))
	done

	return 1
}
```

## Loop variables

**C-style naming:** `i`, then `j`, then `k` for counted, arithmetic, nested, and `for-in` loops.

```bash
for ((i = 0; i < ${#files[@]}; i++)); do
	process "${files[i]}"
done

for i in "${rows[@]}"; do
	for j in "${cols[@]}"; do
		matrix_cell "${i}" "${j}"
	done
done
```

- **Exception:** dependency-check loop always uses `bin`.
- `while read -r line` may use `line` when the variable is content, not an index.
- Not `idx`, `count`, `attempt`, `retries`.

## Functions

- All executable logic in `main()` or helpers called from `main()`.
- `return` for recoverable failures; `errx` for fatal errors (usually in `main()`).

```bash
# Copy src to dest; return 1 if src is missing so the caller can handle it.
backup_file() {
	local -r src="${1}"
	local -r dest="${2}"

	[ -f "${src}" ] || \
		return 1

	cp -- "${src}" "${dest}"
}
```

## Comments

Comments are **concise** — explain *what* and *why*, not the obvious. Use British English in comment prose.

### Function comments (required)

Place a comment **immediately before** every helper function — **except `main()`** and skeleton **`errx()`** / **`usage()`** that match this guide. One or two `#` lines: what the function does and why it exists.

```bash
main() {
	# ...
}

# Extract the "version" field from a JSON file via jq; stdout only.
get_version() {
	local -r file="${1}"
	# ...
}
```

- Cover **what** and **why** — not a restatement of the function name alone.
- **`main()`** and standard skeleton **`errx()`** / **`usage()`** need no function comment.

### Inline comments (non-obvious code only)

Add a **one-sentence** comment before (or after) complicated blocks — pipelines, non-obvious parameter expansion, workarounds, platform quirks, or multi-step logic:

```bash
# jq emits raw strings without quotes; -r avoids escaped quotes in the shell variable.
local -r name="$(jq -r '.name' "${file}")"

# Darwin codesign needs --deep for bundles; single files omit it.
[[ -d "${target}" ]] && \
	codesign --verify --deep --strict "${target}"
```

**Do not** comment the obvious:

```bash
# Bad — restates the code
i=$((i + 1))	# add 1 to i

# Good — no comment needed
i=$((i + 1))
```

Skip comments for: simple assignments, obvious guards, standard `local -r` bindings, and boilerplate that the style guide already mandates.

## Verbose messages

When verbose output is needed inside a function:

```bash
verify_item() {
	local -r target="${1}"

	echo "${FUNCNAME[0]} checking ${target}"
	# ...
}
```

- Always `${FUNCNAME[0]}` — never hard-code the function name.
- Verbose → **stdout**; `errx` / `usage` → **stderr**.
- Only when verbose logging is needed.

## External binary dependencies

After `usage` / `"$#"` check (and platform check if applicable), before other work:

```bash
for bin in jq yq; do
	! command -v "${bin}" >/dev/null 2>&1 && \
		errx "cannot find '${bin}' in 'PATH=${PATH}'"
done
```

- List only binaries the script actually calls.
- `command -v`, not `which`; silence stdout and stderr.
- Error format: `cannot find '${bin}' in 'PATH=${PATH}'`.
- When invoking: quote arguments; pass user paths after `--` (`rm -f -- "${path}"`).

## Temporary files and directories

Use **`mktemp`** and **`mktemp -d`** only — never **`mktemp -u`**, never predictable paths (`/tmp/$$`, `$RANDOM`, hand-built names). Templates end in **`XXXXXX`**; creation is exclusive with safe permissions.

**Base path** — use an **absolute template** so **`TMPDIR`** cannot redirect creation into an attacker-controlled directory:

- **`/tmp/${__progname}.XXXXXX`** — short-lived scratch (default)
- **`/var/tmp/${__progname}.XXXXXX`** — longer-lived or larger scratch

**Temporary directory** — default pattern:

```bash
local tmpdir=""

trap '[ -n "${tmpdir}" ] && rm -rf -- "${tmpdir}"' EXIT

tmpdir="$(mktemp -d "/tmp/${__progname}.XXXXXX")"
[ -d "${tmpdir}" ] || \
	errx "mktemp -d"
```

**Temporary file** — single scratch file:

```bash
local tmpfile=""

trap '[ -n "${tmpfile}" ] && rm -f -- "${tmpfile}"' EXIT

tmpfile="$(mktemp "/tmp/${__progname}.XXXXXX")"
[ -f "${tmpfile}" ] || \
	errx "mktemp"
```

**Multiple temp files** — one directory, files inside:

```bash
local tmpdir=""
local tmpfile=""
local tmpcfg=""

trap 'cleanup_temps' EXIT

# Remove scratch dir (and contents) and any standalone temp file on exit.
cleanup_temps() {
	[ -n "${tmpdir}" ] && rm -rf -- "${tmpdir}"
	[ -n "${tmpfile}" ] && rm -f -- "${tmpfile}"
}

tmpdir="$(mktemp -d "/tmp/${__progname}.XXXXXX")"
[ -d "${tmpdir}" ] || \
	errx "mktemp -d"

tmpfile="$(mktemp "${tmpdir}/part.XXXXXX")"
[ -f "${tmpfile}" ] || \
	errx "mktemp"

tmpcfg="$(mktemp "${tmpdir}/cfg.XXXXXX")"
[ -f "${tmpcfg}" ] || \
	errx "mktemp"
```

Rules:

- Register the **`EXIT` trap before** creating temps — so a later failure still runs cleanup once paths are set.
- **`local`** temps inside **`main()`** (or a helper that owns the lifecycle).
- Creation failure → **`errx "mktemp"`** or **`errx "mktemp -d"`** — guard clause, not `if`/`fi`.
- Cleanup: **`rm -f --`** for files, **`rm -rf --`** for directories; guard with **`[ -n … ]`** in the trap.
- **Do not** `chmod` after create — `mktemp` sets safe permissions at creation.
- **`mktemp`** is expected in the default **`PATH`** — no dependency-loop entry unless the script supports a stripped environment.

## Testing and linting

New or substantial standalone scripts follow the **`code-workflow`** skill for discovery, functional tests, and TDD via **`make test`**.

### When required

Run **`bash -n`** and **`shellcheck`** when you:

- Create a **new standalone script**, or
- Add substantial new bash code and the repo has **no** existing shell lint/CI setup

They are **not** required when editing scripts in a repo that already has its own conventions (per **AGENTS.md** / **CLAUDE.md**).

### During Grok development

When working in Grok, lint bash scripts you touch:

- If the project **Makefile** or CI has a shellcheck target, use that during development.
- If there is **no** project lint step, run **`shellcheck`** (and **`bash -n`**) directly before finishing.

```bash
bash -n script.sh
shellcheck script.sh
cat -A script.sh   # expect ^I for indents, not spaces
```

## Script file naming

- Use **`snake_case.sh`** — lowercase, words separated by underscores.
- Name after the script's purpose: `install_skills.sh`, `run_tests.sh`.
- **Never** `main.sh` — same rule as C's `foobar.c` vs `main.c`.

## Review checklist

- [ ] **Scope** — applied unless repo **AGENTS.md** / **CLAUDE.md** overrides
- [ ] `#!/usr/bin/env bash` and script header (spacer `#`, name + one-liner, spacer `#`, detail, spacer `#`)
- [ ] `set -euo pipefail`, `IFS=$'\n\t'`
- [ ] `readonly __progname="$(basename "${BASH_SOURCE[0]}")"` and `readonly PATH=…` on the next line
- [ ] `errx()` and `usage()` (if args) match standard implementations
- [ ] `[[ "$#" -ne N ]] && \` / `usage` when script takes arguments
- [ ] Platform-specific scripts: `uname -s` matches `^Darwin` or `^Linux`
- [ ] `for bin in …` dependency loop for non-system binaries
- [ ] `main()` ordering; `main "$@"` is the last line
- [ ] Tabs only; no consecutive blank lines; at most one blank between code blocks
- [ ] **`&& \`** / **`|| \`** line splits; guard clauses over `if`; **`errx`**: `[ ! … ] && \` / `! cmd && \` — never `if` + `errx`, never `|| errx`
- [ ] `local -r` by default; loop counters `i`, `j`, `k` (`bin` in dep loop)
- [ ] Function comment (what + why) on helpers; **`main()`** and skeleton **`errx()`** / **`usage()`** exempt
- [ ] **`shellcheck`** during Grok dev (project target or direct run)
- [ ] Verbose output: `echo "${FUNCNAME[0]} …"`
- [ ] Bash builtins before externals; no UUOC (`cat`/`head`/`tail` where `$(<file>)`, `readarray`, or `cmd file` suffices)
- [ ] `bash -n` and `shellcheck` clean
- [ ] **Temp files/dirs** — `mktemp` / `mktemp -d` with `/tmp/${__progname}.XXXXXX`; `EXIT` trap before creation; cleaned up on exit
