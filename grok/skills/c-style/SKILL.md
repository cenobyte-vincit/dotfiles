---
name: c-style
description: >
  Apply personal C coding standards when writing, editing, or reviewing C source
  and headers. Use when working on .c or .h files, C libraries, embedded C,
  or when the user asks for C style, conventions, or code review.
metadata:
  short-description: "Personal C style guide (OpenBSD KNF)"
---

# C Coding Standards

Apply these standards to **all C code you write or edit** — new and existing — unless the repository has its own **AGENTS.md** or **CLAUDE.md** that overrides them.

## Target platform

Respect the platform the user specifies for the code:

| User specifies | Generate |
|----------------|----------|
| **macOS**, **BSD**, or **OpenBSD** (or no platform — default) | BSD/macOS code only — libc provides **`__progname`**, native `<err.h>`, no Linux paths |
| **Linux** | Linux code that **follows the BSD convention** — same `__progname` / `<err.h>` / `strlcpy` patterns as BSD; not glibc-native alternatives |

When the target is **macOS or BSD**:

- **Do not** include `#if defined(__linux__)`, `#ifdef __linux__`, or other Linux-only branches.
- **Do not** include Linux-only comments (glibc version notes, `-lbsd` fallbacks, etc.).
- **Do not** mix portable `#if` ladders that mention Linux alongside BSD — write the BSD/macOS version directly.
- Use **`__progname`** directly — provided by libc on macOS/BSD. No `setprogname()`, no `extern char *__progname`, no assignment in `main`.

When the target is **Linux**:

- **Follow the BSD convention** — use **`__progname`**, `<err.h>`, `errx`/`usage`, and `strlcpy`/`strlcat` the same way as on BSD.
- **Do not** use glibc-native alternatives such as `program_invocation_short_name`.
- Declare **`extern char *__progname;`** in translation units that reference it (see below).

Include Linux-specific setup **only** when the user explicitly asks for a **Linux** target.

### Linux and the BSD convention

When the user targets **Linux**, treat it as **BSD-style C on a Linux host** — not glibc-native CLI patterns:

| Topic | Use (BSD convention) | Do not use (glibc-native) |
|-------|----------------------|---------------------------|
| Program name | `__progname` | `program_invocation_short_name` |
| Fatal errors | `<err.h>` — `errx`, `err`, `warnx` | Ad-hoc `perror` / bare `fprintf` |
| String copy | `strlcpy` / `strlcat` | Unchecked `strcpy` / misused `strncpy` |

On Linux, declare **`extern char *__progname;`** in any translation unit that references it. Default (no platform) remains macOS/BSD.

## Design intent (CLI programs)

Command-line programs follow a consistent **OpenBSD CLI layout**: program name via **`__progname`**, fatal errors via **`errx`**, misuse via **`usage`**, guard clauses, file headers, and function comments — provided natively by `<err.h>` and `<stdlib.h>`.

| Concern | Approach |
|---------|----------|
| Program name | **`__progname`** — libc on macOS/BSD; `extern` on Linux |
| Fatal errors | `errx(1, …)` from `<err.h>` |
| Usage mistakes | `usage()` → stderr, `exit(1)` |
| Preconditions | Guard clauses — early `return` / `errx`, flat happy path |
| File identity | Header block at top of each `.c` / `.h` |
| `main()` flow | argc/usage → guards → work |

**Libraries** (no `main`) omit `usage` and CLI ordering; keep headers, comments, guards, and string safety.

## OpenBSD style (KNF)

All C code uses **OpenBSD Kernel Normal Form** ([style(9)](https://man.openbsd.org/style.9)):

- **Tabs only** for indentation — 8-column tab stops. Never use spaces to indent code.
- **80-column** soft line limit where practical.
- **Function definitions:** return type on its own line, name and arguments on the next, opening `{` on a line by itself.
- **Prototypes** in headers omit parameter names: `int foo(int, char *);`
- **Control flow** (`if`, `while`, `for`, `switch`): opening `{` on the **same line** as the keyword; `else` on the same line as the closing `}`.
- **`return (val);`** — parenthesise the returned value (traditional KNF).
- **No Yoda conditions.** Guard clauses / early returns over deep nesting.
- **Function calls:** no space before `(` — `foo(bar)`, not `foo (bar)`.
- **Control keywords:** space after — `if (`, `while (`, `for (`, `switch (`.
- **Variables:** declare at the top of each block; sort roughly largest-to-smallest, then alphabetical.
- **Prototypes in `.c` files:** use `static` on file-local helpers; omit parameter names in forward declarations.
- **Includes:** system headers in angle brackets (`<err.h>`), project headers quoted (`"module.h"`); see **Includes** for order.
- **Comments:** `/* */` only for new comments (see **Comments**); do not add `//`.
- Match existing OpenBSD-tree code in a project when present.

### Blank lines (required)

- **No consecutive blank lines** — never two or more empty lines in a row.
- **At most one** blank line between any two blocks of code (functions, declarations, guard groups, logical steps in `main`).
- **Zero** blank lines between blocks is fine when the code reads clearly without a separator.

```c
/* Bad — double blank between blocks */
const char *path;

path = argv[1];


if (!*path)
	errx(1, "empty path");

/* Good — no blank, or a single blank */
const char *path;

path = argv[1];
if (!*path)
	errx(1, "empty path");
```

## File header

Every `.c` and `.h` file starts with a **comment header** at the top of the file:

```c
/*
 * foobar.c - Extract a key from a JSON file and print its value.
 *
 * Reads one file path from argv, parses JSON, prints the "name" field.
 * Requires a C17 compiler and strlcpy support.
 */
```

Rules:

- **First line:** `filename - ` + one concise sentence (basename of the file).
- **Blank ` * ` line**, then a longer description (behaviour, arguments, dependencies, side effects).
- Closing ` */` before `#include` directives.

## CLI program skeleton

Every **command-line program** must include:

1. File header (see above)
2. **`usage()`** — when the program takes arguments
3. Fatal errors via **`errx(1, …)`** from `<err.h>` — not ad-hoc `fprintf` + `exit`
4. Guard clauses for preconditions; flat happy path after guards
5. **`__progname`** used in `usage()` / messages — libc on macOS/BSD; `extern char *__progname;` on Linux (see below)

### CLI entry file naming

**Never use `main.c`.** Name the CLI entry file after the project — lowercase slug of the project name:

| Project name | CLI entry file |
|--------------|----------------|
| Foobar 2.0 | `foobar.c` |
| machosec | `machosec.c` |

Rules: lowercase; drop version suffixes; remove spaces and punctuation; use the core project identifier.

Default skeleton for **macOS / BSD** (also when no platform is specified):

```c
/*
 * foobar.c - Extract a key from a JSON file and print its value.
 *
 * Takes one argument: path to a JSON file. Prints the "name" field to stdout.
 */

#include <err.h>
#include <stdio.h>
#include <stdlib.h>

static void usage(void);

static void
usage(void)
{
	fprintf(stderr, "usage: %s <file>\n", __progname);
	exit(1);
}

int
main(int argc, char *argv[])
{
	const char *path;

	if (argc != 2)
		usage();

	path = argv[1];
	if (!*path)
		errx(1, "empty path");

	/* ... */
	return (0);
}
```

**Linux only** — when the user explicitly targets Linux, declare `extern char *__progname;` at file scope in any `.c` that references it. Do **not** include this in macOS/BSD code.

- Programs with **no arguments** omit `usage()` and the `argc` guard.

### `__progname`

- Always use **`__progname`** in `usage()` and user-facing messages — never a hard-coded program name.
- **macOS / BSD (default):** libc provides **`__progname`** — use it directly. No `setprogname()`, no `extern` declaration, no assignment in `main`, no `#if defined(__linux__)`.
- **Linux (only when specified):** follows the **BSD `__progname` convention** — not `program_invocation_short_name` or other glibc-specific APIs. Declare **`extern char *__progname;`** in any translation unit that references it.
- **`errx()`** from `<err.h>` prefixes messages with the program name via `__progname`.

### `errx()` and `usage()`

```c
#include <err.h>

/* Fatal — includes program name, no errno */
errx(1, "cannot open %s", path);

/* Fatal with errno */
err(1, "cannot open %s", path);

/* Wrong argc — never errx for usage mistakes */
if (argc != 2)
	usage();
```

- **`errx(eval, fmt, …)`** — all unrecoverable fatal errors (eval is usually `1`).
- **`usage()`** — prints `usage: %s …` with **`__progname`** to **stderr**, then **`exit(1)`**.
- Do not use bare `fprintf(stderr, …); exit(1);` for standardised errors — use `errx` or `usage`.
- Library functions return error codes for recoverable failures; allocation failure is never recoverable — use **`errx`** (see **Allocation**).

### `main()` ordering (CLI)

1. `argc` check → `usage()` when the program expects arguments
2. Other precondition guards (`errx` or early `return 0` only for benign cases)
3. Bind `argv` entries to `const` pointers / validated values
4. Program logic

## Guard clauses (preferred over nested `if`)

**Prefer guard clauses** — early `return`, `goto cleanup`, or `errx` — over nested `if` trees. Idiomatic OpenBSD C favours a flat happy path.

### `errx()` guards — negative test with `!` (required)

Every **`if`** that calls **`errx()`** must use **negative testing** — the condition is negated with **`!`** (or an equivalent failure test such as `== NULL`). No braced body; no `else` branch:

```c
if (!*path)
	errx(1, "empty path");

if (!(fp = fopen(path, "r")))
	errx(1, "cannot open %s", path);

if (!S_ISREG(st.st_mode))
	errx(1, "%s: not a regular file", path);
```

Rules:

- **`if (!predicate)`** then **`errx`** on the next line — guard-clause form, not a braced block.
- **Negate the success condition** — write `if (!*path)`, not `if (path[0] == '\0')`.
- **No `else errx`** — if the happy path needs a branch, structure the check as `if (!ok) errx(…);` then continue flat.
- Do **not** use `!predicate && errx(…)` expression statements — use **`if (!…) errx(…)`**.

```c
/* Bad — positive test */
if (path[0] == '\0')
	errx(1, "empty path");

/* Bad — if/else + errx */
if (fp != NULL)
	fread(buf, 1, sizeof(buf), fp);
else
	errx(1, "cannot open %s", path);

/* Bad — && errx expression */
!*path && errx(1, "empty path");

/* Good — if (!…) errx */
if (!*path)
	errx(1, "empty path");

if (!(fp = fopen(path, "r")))
	errx(1, "cannot open %s", path);
```

**`usage()`** and library **`return`** guards are unchanged — the **`!`** rule applies to **`errx()` only**.

### Other guards

```c
#include <unistd.h>

static int
process(const char *path)
{
	if (path == NULL)
		return (-1);

	if (access(path, R_OK) != 0)
		return (-1);

	/* happy path — no extra nesting */
	return (do_work(path));
}
```

CLI **`usage()`** — not `errx` — for wrong `argc`:

```c
/* Bad */
if (argc != 2) {
	fprintf(stderr, "wrong args\n");
	exit(1);
}

/* Good */
if (argc != 2)
	usage();
```

Use a full `if`/`else` only when **both** branches do substantial work. If a branch only errors out with **`errx`**, rewrite as `if (!predicate) errx(…)`.

Additional control-flow rules:

- `switch` on enums should include a `default` that handles unknown values (assert or error return).
- Loop indices: use `size_t` for array indexing when the bound is a `size_t`.
- Never use `goto` except for centralized cleanup in allocation-heavy functions.

## Comments

Comments are **concise** — *what* and *why*, not the obvious. Use British English in comment prose.

### Comment style (KNF)

- **New comments** use `/* */` only — do **not** add new `//` comments.
- **Existing `//` comments** may remain; do not rewrite them unless you are already editing that code.
- **Single sentence:** `/* sentence */` on one line.
- **Multiple sentences:** block form:

```c
/*
 * Copy src to dst; returns -1 if src is missing.
 * Caller must provide writable dst with room for the full path.
 */
```

### Function comments (required)

Place a block comment **immediately before** every function (`static` helpers and public API) — **except `main()`** and a skeleton **`usage()`** that matches this guide:

```c
/*
 * Copy src to dst; returns -1 if src is missing.
 */
static int
copy_file(const char *src, const char *dst)
{
	/* ... */
}
```

- Cover **what** and **why** — not the function name alone.
- **`main()`** and standard skeleton **`usage()`** need no function comment.

### Inline comments (non-obvious code only)

One sentence before complicated logic — workarounds, platform quirks, non-obvious algorithms:

```c
/* strlcpy return >= size means truncation — treat as error. */
if (strlcpy(buf, src, sizeof(buf)) >= sizeof(buf))
	return (-1);
```

Do **not** comment obvious assignments, simple guards, or routine `strlcpy` where the code is self-explanatory.

### Public API documentation (headers)

Public functions in headers use a brief block comment:

```c
/*
 * Append bytes to buf. Returns 0 on success. Aborts on allocation failure.
 * Ownership of src is unchanged. buf must be initialized.
 */
int buffer_append(buffer_t *buf, const void *src, size_t len);
```

Document: preconditions, postconditions, error returns, pointer ownership, thread safety where relevant.

## Toolchain

- Standard: **ISO C17** (`-std=c17`).
- Baseline flags: `-std=c17 -Wall -Wextra -Werror -pedantic`.
- Add `-Wshadow -Wconversion -Wformat=2 -Wnull-dereference` when the project tolerates them.
- Debug builds: `-g -O0 -fsanitize=address,undefined` when feasible.
- Release builds: `-O2` or project default.
- Never silence warnings instead of fixing them.

## Makefile and cppcheck

### When required

A **Makefile**, **README.md** cppcheck note, and **cppcheck** target are required when you:

- Create a **new standalone C project**, or
- Add substantial new C code and the repo has **no** existing build/analysis setup

They are **not** required when editing C in a repo that already has its own build system and conventions (per **AGENTS.md** / **CLAUDE.md**).

### During Grok development

When working in Grok, run **cppcheck** on the C sources you touch:

- If the project **Makefile** has a cppcheck/check target, use that during development.
- If there is **no** Makefile cppcheck target, run **cppcheck** directly before finishing (e.g. `cppcheck --enable=warning,performance,portability --error-exitcode=1 -I. *.c` or the project's source paths).

### Makefile requirements

- Targets at minimum: `all`, `clean`, and a lint/check target that runs **cppcheck**.
- Verify cppcheck is installed (`command -v` or equivalent):

```makefile
CPPCHECK ?= cppcheck

SRCS = foobar.c util.c

check-cppcheck:
	@command -v $(CPPCHECK) >/dev/null 2>&1 || { \
		echo "cppcheck not found — install it (see README)" >&2; exit 1; }
	$(CPPCHECK) --enable=warning,performance,portability \
		--error-exitcode=1 -I. $(SRCS)

lint: check-cppcheck
check: lint
```

### Documentation requirements

**README.md** must list **cppcheck** as a **required development dependency**, with install hints and the make target (e.g. `make check-cppcheck`).

## String safety

**Never use unsafe string functions.** Banned: `strcpy`, `strcat`, `sprintf`, `gets`, and misused `strncpy`/`strncat`.

| Unsafe | Use instead |
|--------|-------------|
| `strcpy`, `strncpy` (misused) | `strlcpy` |
| `strcat`, `strncat` (misused) | `strlcat` |
| `sprintf` | `snprintf` |

- **`strlcpy` / `strlcat`** for every string copy and concatenation (native on BSD/macOS; on **Linux-only** code, glibc **2.38+** / 2023).
- Check return `>= size` for truncation; handle as error.
- Use `snprintf` for formatted output; check return for truncation.
- Non-string bytes: `memcpy`/`memmove` with explicit lengths.
- Prefer length-delimited buffers (`char *`, `size_t len`) when parsing untrusted input.

```c
if (strlcpy(dst, src, sizeof(dst)) >= sizeof(dst))
	return (-1);
```

## File layout

### Small programs (single `.c` file)

Small CLI tools and utilities need **no dedicated `.h` file**. Keep everything in one `.c` — `main`, `usage`, and `static` helpers:

```
Makefile
README.md
foobar.c            # complete program — no foobar.h required
```

Split out a header only when the program **grows** — multiple `.c` files, a shared API between modules, or declarations consumed by tests/other translation units.

### Larger projects (split when needed)

Flat layout:

```
Makefile
README.md
foobar.c            # CLI entry (__progname, usage, errx pattern)
module.c
module.h            # public API — only when shared across .c files
module_internal.h   # optional: symbols shared within the module only
```

Or with `src/` when the project warrants it:

```
Makefile
README.md
src/
  foobar.c
  module.c
  module.h
include/            # optional shared public headers
tests/
  functional/
    run_tests.sh
    fixtures/
    t001_good_args.sh
    ...
  unit/
    test_module.c
```

- One primary module per `.c` file when practical.
- **`.h` files hold the public API** between compilation units; keep internal helpers `static` in `.c` until a second file needs them.
- Internal helpers live in the same `.c` as `static` functions unless shared across multiple `.c` files in one module (then use `module_internal.h`).
- Do not expose internal symbols in public headers.
- Add `module.h` when the program outgrows a single file — not before.

### Includes

Order within a `.c` file:

1. The module's own header (`#include "module.h"`) — skip for single-file programs.
2. C standard library headers (`<stdint.h>`, `<string.h>`, …).
3. POSIX or platform headers (`<unistd.h>`, …) — only when needed.
4. Other project headers.

In headers, include only what the header itself needs for its declarations. Use forward declarations to reduce coupling when possible.

## Naming

| Kind | Convention | Example |
|------|------------|---------|
| Functions | `snake_case`, module prefix for public API | `buffer_append()` |
| Types | `snake_case_t` | `buffer_t` |
| Macros / constants | `SCREAMING_SNAKE` | `MAX_LINE_LEN` |
| Static | `static` + `snake_case` | `static int parse_int(void)` |
| Loop counters | `i`, `j`, `k` | nested and `for` loops |
| Globals | Avoid; `g_` if required | `g_config` |

### Naming and visibility

- **Public API**: prefix with the module name when it avoids collisions — `list_push()`, not `push()`.
- **Static functions**: no prefix required; keep file-local.
- **Enum values**: `enum_name_VALUE` or scoped prefix — be consistent per module.
- **Typedef struct**: prefer tagged structs; typedef name matches `struct` tag when used.

```c
typedef struct buffer {
	uint8_t *data;
	size_t len;
	size_t cap;
} buffer_t;
```

## Functions, memory, and errors

- Short, single-purpose functions; `const` on unmodified inputs.
- Library helpers: return `0` / `-1` on recoverable failure; set `errno` when appropriate. Allocation failure is not recoverable — **`errx`**.
- CLI `main`: `usage()` for bad argc; `errx()` for fatal runtime errors; `err()` when `errno` applies (e.g. `fopen`).
- `goto cleanup` only for multi-step teardown; label `cleanup`.
- Check all allocations; match every `free` to an owner.

### Allocation

Check every **`malloc`**, **`calloc`**, and **`realloc`**. On NULL, **`errx(1, …)`** with the function name as the message — in **all** C code (CLI, libraries, helpers):

```c
int *nums;

nums = malloc(n * sizeof(*nums));
if (nums == NULL)
	errx(1, "malloc");
```

- Assign, then check — `p = malloc(…);` on one line, `if (p == NULL)` on the next; no assignment inside the `if` condition.
- Size with **`sizeof(*p)`** (or `n * sizeof(*p)` for arrays) — never `sizeof(struct foo)` when a pointer is already in scope.
- Message is the literal function name — **`"malloc"`**, **`"calloc"`**, **`"realloc"`** — no format string, no size argument.
- Do not **`return (-1)`**, **`goto cleanup`**, or propagate allocation failure — abort with **`errx`**.

### Cleanup with goto

```c
int
foo(void)
{
	int rc;
	char *a;
	char *b;

	rc = 0;
	a = NULL;
	b = NULL;

	a = malloc(64);
	if (a == NULL)
		errx(1, "malloc");

	b = malloc(64);
	if (b == NULL)
		errx(1, "malloc");

	/* work */

cleanup:
	free(a);
	free(b);
	return (rc);
}
```

### Temporary files and directories

Use POSIX **`mkdtemp(3)`** and **`mkstemp(3)`** — never **`mktemp`**, **`tmpnam`**, or **`tempnam`**. Templates end in **`XXXXXX`**; creation is exclusive with safe permissions (`0700` dir, `0600` file).

**Base directory** — build from **`secure_getenv("TMPDIR")`**, falling back to **`/tmp`** (short-lived) or **`/var/tmp`** (longer-lived). Use plain **`getenv`** only when the program is known never to run privileged.

**Temporary file** — single scratch file:

```c
#include <stdlib.h>
#include <unistd.h>

char path[] = "/tmp/foobar.XXXXXX";
int fd;

fd = mkstemp(path);
if (fd < 0)
	err(1, "mkstemp");

/* ... use fd ... */

unlink(path);
close(fd);
```

**Temporary directory** — scratch dir; prefer a dir fd and **`openat(2)`** for files created inside:

```c
#include <fcntl.h>
#include <stdlib.h>
#include <unistd.h>

char dir[] = "/tmp/foobar.XXXXXX";
int dfd;

if (mkdtemp(dir) == NULL)
	err(1, "mkdtemp");

dfd = open(dir, O_RDONLY | O_DIRECTORY | O_CLOEXEC);
if (dfd < 0)
	err(1, "open %s", dir);

/* optional: unlink(dir) — name disappears; dfd still valid until close */

/* create files inside via openat(dfd, ...) or mkstemp on a path under dir */

close(dfd);
rmdir(dir);
```

Rules:

- Template is a **writable char array** — `mkdtemp` / `mkstemp` modify it in place.
- **Assign, then check** — same discipline as allocation checks.
- Fatal creation failure: **`err(1, "mkdtemp")`** / **`err(1, "mkstemp")`** — libc sets **`errno`** (same class as **`fopen`**).
- **Multiple temp files** in one run: one **`mkdtemp`** dir, then files inside via **`openat(dfd, …)`** or **`mkstemp`** on a path under that dir — do not litter `/tmp` with many unrelated prefixes.
- **Do not** `open` then **`chmod`** — modes are set atomically at creation.
- **Always clean up** — **`unlink`** / **`close`** / **`rmdir`** on every exit path; use **`goto cleanup`** when several temps are active.
- **Linux only** (when the user explicitly targets Linux) and no pathname is needed: **`open("/tmp", O_TMPFILE | O_RDWR, 0600)`** or **`memfd_create(…)`** are stronger equivalents — no directory entry, no path races. Default (macOS/BSD) stays **`mkstemp`** / **`mkdtemp`**.

## Integer and pointer safety

- Check overflow before `n * sizeof(T)` allocations.
- Do not subtract unsigned values without proving order.
- Validate external input ranges before use as indices or allocation sizes.
- `NULL` checks on out-parameters only when the API allows NULL; otherwise document as a precondition.

## Preprocessor

- Minimize macros. Prefer `static inline` functions for small helpers.
- Macro arguments and the macro body must be fully parenthesized.
- Multi-statement macros: `do { ... } while (0)`.
- No macro-generated control flow that hides `return` or `break` unless well-documented.

## Const correctness

- Pointers to data that will not be modified: `const T *`.
- Pointer-to-const-pointer when the pointer itself must not change: `T *const`.
- Both: `const T *const`.

## Threading (when applicable)

- Document thread safety per function: "thread-safe", "not thread-safe", or "caller must synchronize".
- Protect shared mutable state with project-standard mutex primitives.
- Do not rely on static mutable state without synchronization unless proven safe.

## Testing

New or substantial standalone programs follow the **`code-workflow`** skill for discovery, test plans, and TDD via **`make test`**. C projects use **two tiers**:

| Tier | Target | Makefile target |
|------|--------|-----------------|
| **Functional** | Built CLI binary end-to-end | **`make test-functional`** |
| **Unit** | Modules and helpers in-process | **`make test-unit`** |

**`make test`** runs **`test-unit`** then **`test-functional`**.

### Functional tests (required)

Shell scripts under **`tests/functional/`** invoke the built program and assert the CLI contract. Follow **`bash-style`** for runners and scenario scripts.

Every CLI program needs functional coverage for **arguments** and **inputs**:

- **Good arguments** — valid flags and positionals; program completes with exit `0` and expected behaviour.
- **Bad arguments** — invalid `argc`, flags, or combinations; program **does not proceed** into main work — **`usage()`** or **`errx()`**, non-zero exit, expected stderr.
- **Good inputs** — known-valid files, stdin, or env; inputs are **parsed and honoured**; happy-path stdout, side effects, exit `0`.
- **Bad inputs** — missing, empty, malformed, or inaccessible inputs; program **fails cleanly** — non-zero exit, expected stderr, **no partial success output** or half-written artefacts.

Store reusable payloads in **`tests/functional/fixtures/`**. Use **`mkdtemp`** / **`mkstemp`** for scratch paths (see **Temporary files and directories**). Assert stderr matches **`usage: %s …`** or **`__progname`:**-prefixed **`errx`** messages.

### Unit tests (required)

C test binaries under **`tests/unit/`** link production sources and exercise functions without spawning the CLI.

- Cover **public API** and **`static`** helpers (compile test TU with the module `.c`, or use a test-only internal header).
- Cover **recoverable error returns** (`-1`, `NULL`, etc.) — not fatals that call **`errx`** / **`usage`** (those belong in functional tests).
- One primary test file per module when practical: **`tests/unit/test_<module>.c`**.

#### Minimal harness

Use a small local harness — no external test framework required:

```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define TEST_ASSERT(cond) do { \
	if (!(cond)) { \
		fprintf(stderr, "FAIL %s:%d: %s\n", __FILE__, __LINE__, #cond); \
		return (1); \
	} \
} while (0)

static int
test_parse_good(void)
{
	/* ... */
	return (0);
}

int
main(void)
{
	if (test_parse_good() != 0)
		exit (1);
	printf("PASS\n");
	return (0);
}
```

Test functions return **`0`** on success, **`1`** on failure; **`main`** exits non-zero if any test fails.

#### Optional depth

- **Allocation failure** — injectable allocators or wrapper hooks when practical.
- **Fuzz / property tests** — parsers and decoders that handle untrusted input; run separately or behind a Makefile target, not required for every project.

### Makefile

New standalone C projects expose **`test-unit`**, **`test-functional`**, and **`test`** (see **`code-workflow`**). Document all three in **README.md**.

## Headers

```c
#ifndef MODULE_H
#define MODULE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

int buffer_append(buffer_t *, const void *, size_t);
void buffer_free(buffer_t *);

#ifdef __cplusplus
}
#endif

#endif /* MODULE_H */
```

## Review checklist

- [ ] **Scope** — applied unless repo **AGENTS.md** / **CLAUDE.md** overrides
- [ ] **OpenBSD KNF** — tabs, function brace layout, 80-column discipline, `/* */` for new comments; no consecutive blank lines
- [ ] **File header** on every `.c` (and `.h` when present)
- [ ] **CLI entry** named after project (`foobar.c`), never `main.c`
- [ ] **Small programs** stay single-file; `.h` only when size/API warrants a split
- [ ] **Target platform** respected — BSD convention on Linux; no Linux `#if` on macOS/BSD code
- [ ] **CLI:** `__progname` (libc on macOS/BSD; `extern char *__progname;` on Linux), `usage()`, `errx()`; `main()` ordering
- [ ] **Guard clauses** preferred; **`errx`**: `if (!predicate) errx(…)` — never positive test, never `else errx`, never `&& errx`
- [ ] **Function comments** (what + why) on helpers; **`main()`** and skeleton **`usage()`** exempt
- [ ] **Makefile** + **cppcheck** + **README** — new standalone projects; **cppcheck** run during Grok dev either way
- [ ] **`strlcpy`/`strlcat`/`snprintf`** — no `strcpy`/`strcat`/`sprintf`
- [ ] `-Wall -Wextra -Werror -pedantic` clean
- [ ] Allocations checked — NULL → **`errx(1, "malloc")`** (or `"calloc"` / `"realloc"`); resources freed on every exit path
- [ ] **Temp files/dirs** — `mkstemp` / `mkdtemp` only; `secure_getenv("TMPDIR")`; cleaned up on every exit path
- [ ] **Functional tests** — `tests/functional/` covers good/bad CLI args and good/bad inputs; **`make test-functional`** green
- [ ] **Unit tests** — `tests/unit/` covers public API and critical helpers; **`make test-unit`** green; fatals tested only via functional suite
