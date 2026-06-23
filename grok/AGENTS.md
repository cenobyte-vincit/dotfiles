# Grok preferences

Use **British English** in everything: replies, comments, commit messages, documentation, CLI help, and any other prose (e.g. colour, organise, behaviour — not American spellings).

## Personal coding standards

When writing or editing C code, follow the `c-style` skill.

When writing or editing bash/shell scripts, follow the `bash-style` skill.

When creating or substantially extending a bash script or C program, follow the `code-workflow` skill before writing implementation code. Prefer starting with `/goal <objective>`.

Defaults: C17 with `-Wall -Wextra -Werror`; bash with `set -euo pipefail`.

## Text files

All text files must end with a **trailing newline** (POSIX linebreak). When writing or editing a file, ensure the final line is terminated — but **do not** append an extra blank line if one is already present.
