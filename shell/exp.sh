#!/usr/bin/env bash
# exp -- ExpKit Command-Line Interface
# Usage: exp [-OPTION] COMMAND [ARG]...
# 
# COMMAND is one of the following forms:
# 
#   exp setup DIR ...
# 
#   exp gui
# 
#   exp init
#   exp define condition
#   exp define measure
#   exp define program 
# 
#   exp plan   [NAME[=VALUE[,VALUE]...]]...
#   exp start  [NAME[=VALUE[,VALUE]...]]...
# 
#   exp start  BATCH
#   exp stop   BATCH
#   exp status BATCH
#   exp edit   BATCH
# 
#   exp batches [QUERY]
# 
#   exp results [BATCH | RUN]... [QUERY]...
# 
#   exp conditions [-v] [NAME]...
#   exp measures [-v] [NAME]...
# 
#   exp run [NAME=VALUE]...
#   exp findroot
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
    export GUIDIR="$EXPKIT_HOME/@GUIDIR@"
    export LIBDIR="$EXPKIT_HOME/@LIBDIR@"
    export NODE_PATH="$LIBDIR/node_modules${NODE_PATH:+:$NODE_PATH}"
    export PATH="$TOOLSDIR:$LIBDIR/node_modules/.bin:$PATH"
    unset CDPATH
    export SHLVL=0 EXPKIT_LOGLVL=${EXPKIT_LOGLVL:-1}
fi


while getopts "v" opt; do
    case $opt in
        v)
            let EXPKIT_LOGLVL++
            ;;
            # TODO quiet
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
