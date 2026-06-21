#!/bin/bash

export BASH_SILENCE_DEPRECATION_WARNING=1
export LC_CTYPE=en_US.utf8
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export PS1="\[\033[36m\]\u\[\033[m\]@\[\033[32m\]\h\$(/usr/local/bin/gitbranch.sh)\n\[\033[33;1m\]\w \[\033[m\]\$ "

alias nano="/usr/local/bin/nano"

unset HISTFILE
