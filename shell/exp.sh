#!/usr/bin/env bash
# exp -- ExpKit Command-Line Interface
# Usage: exp [-OPTION] COMMAND [ARG]...
# 
# COMMAND is one of the following forms:
# 
#   exp init
# 
#   exp run PROGRAM [NAME=VALUE]...
#   exp plan [PROGRAM | NAME=VALUE]...
# 
#   exp history
#   exp summary
# 
# Global OPTION is one of:
#   -v      for increasing verbosity
# 
#
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2012-11-01
set -eu

if [ -z "${EXPKIT_HOME:-}" ]; then
    Self=$(readlink -f "$0" 2>/dev/null || {
        # XXX readlink -f is only available in GNU coreutils
        cd $(dirname -- "$0")
        n=$(basename -- "$0")
        if [ -L "$n" ]; then
            L=$(readlink "$n")
            if [ x"$L" = x"${L#/}" ]; then
                echo "$L"; exit
            else
                cd "$(dirname -- "$L")"
                n=$(basename -- "$L")
            fi
        fi
        echo "$(pwd -P)/$n"
    })
    Here=$(dirname "$Self")

    # Setup environment
    export EXPKIT_HOME=${Here%/@BINDIR@}
    export BINDIR="$EXPKIT_HOME/@BINDIR@"
    export TOOLSDIR="$EXPKIT_HOME/@TOOLSDIR@"
    export DATADIR="$EXPKIT_HOME/@DATADIR@"

    export PATH="$TOOLSDIR:$PATH"
    unset CDPATH
    export SHLVL=0 EXPKIT_LOGLVL=${EXPKIT_LOGLVL:-1}
fi


while getopts "v" opt; do
    case $opt in
        v)
            let EXPKIT_LOGLVL++
            ;;
    esac
done
shift $(($OPTIND - 1))


# Process input arguments
[ $# -gt 0 ] || usage "$0" "No COMMAND given"
Cmd=$1; shift


# Check if it's a valid command
exe=exp-"$Cmd"
if type "$exe" &>/dev/null; then
    set -- "$exe" "$@"
else
    usage "$0" "$Cmd: invalid COMMAND"
fi


# Run given command under this environment
exec "$@"
