#!/usr/bin/env bash
#
# install_grok_skills - Install Grok AGENTS.md and skills into ~/.grok.
#
# Copies grok/AGENTS.md and grok/skills/* from this dotfiles repository
# into ~/.grok. Safe to re-run; overwrites existing files. Expects to live
# at the repository root beside a grok/ directory.
#
set -euo pipefail
IFS=$'\n\t'

readonly __script_path="${BASH_SOURCE[0]}"
readonly __progname="$(basename "${__script_path}")"
readonly PATH="/usr/sbin:/usr/bin:/sbin:/bin"

errx() {
	echo -e "${__progname}: $*" >&2

	exit 1
}

# Copy AGENTS.md from the repository into ~/.grok.
copy_agents() {
	local -r src_agents="${1}"
	local -r dest_root="${2}"

	echo "${FUNCNAME[0]} installing ${src_agents}"

	cp -f "${src_agents}" "${dest_root}/AGENTS.md"
}

# Copy each skill directory from grok/skills/ into ~/.grok/skills/.
copy_skills() {
	local -r src_skills="${1}"
	local -r dest_skills="${2}"
	local skill

	for skill in "${src_skills}"/*; do
		[ -d "${skill}" ] || \
			continue

		echo "${FUNCNAME[0]} installing ${skill}"

		cp -Rf "${skill}" "${dest_skills}/"
	done
}

main() {
	local -r repo_root="$(cd "$(dirname "${__script_path}")" && pwd)"
	local -r src_root="${repo_root}/grok"
	local -r src_agents="${src_root}/AGENTS.md"
	local -r src_skills="${src_root}/skills"
	local -r dest_root="${HOME}/.grok"
	local -r dest_skills="${dest_root}/skills"

	[ ! -d "${src_root}" ] && \
		errx "source directory not found: ${src_root}"

	[ ! -f "${src_agents}" ] && \
		errx "source file not found: ${src_agents}"

	[ ! -d "${src_skills}" ] && \
		errx "source directory not found: ${src_skills}"

	mkdir -p "${dest_root}" "${dest_skills}"

	copy_agents "${src_agents}" "${dest_root}"
	copy_skills "${src_skills}" "${dest_skills}"

	echo "${FUNCNAME[0]} done — installed to ${dest_root}"
}

main "$@"
