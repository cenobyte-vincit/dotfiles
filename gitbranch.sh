#!/bin/bash
#
# used in PS1

/usr/bin/git branch 2>/dev/null | \
	awk '/\*/ { print "[git:",$2,"]" }' | \
	sed 's@git: @git:@; s@ ]@]@'
