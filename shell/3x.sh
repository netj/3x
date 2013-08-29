#!/usr/bin/env bash
# 3x -- eXecutable eXploratory eXperiments
# Usage: 3x [-OPTION] COMMAND [ARG]...
# 
# COMMAND is one of the following forms:
# 
# > 3x setup DIR ...
# 
# > 3x gui
# 
# > 3x plan [NAME[=VALUE[,VALUE]...]]...
# > 3x start
# > 3x stop
# > 3x status
# 
# > 3x queue [QUEUE]
# > 3x target [TARGET]
# 
# > 3x results [RUN | QUEUE]... [QUERY]...
# 
# > 3x plan results RESULTS_QUERY
# > 3x plan skip    RESULTS_QUERY
# 
# > 3x inputs  [-v] [NAME]...
# > 3x outputs [-v] [NAME]...
# 
# > 3x init
# > 3x define input
# > 3x define output
# > 3x define program 
# 
# Global OPTION is one of:
#   -v      increase verbosity
#   -q      suppress all messages
#   -t      force logging to non-ttys
#           (default is to log messages to stderr only when it's a tty)
#
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2012-11-01
set -eu

if [ -z "${_3X_HOME:-}" ]; then
    export _3X_COMMAND=${POJANG_ORIGINAL_COMMAND:-$0}
    export USAGE_TOOL_COMMAND=3x  USAGE_TOOL_PATH=$_3X_COMMAND
    unset POJANG_ORIGINAL_COMMAND
    Self=$(readlink -f "$0" 2>/dev/null || {
        # XXX readlink -f is only available in GNU coreutils
        cd $(dirname -- "$_3X_COMMAND")
        n=$(basename -- "$_3X_COMMAND")
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

    # Keep a backup of some environment variables
    for v in PATH NODE_PATH
    do  vbak=_3X_ORIG_$v
          declare -p $v    &>/dev/null || continue
        ! declare -p $vbak &>/dev/null || continue
        export $vbak=${!v}
    done

    # Setup environment
    export _3X_HOME=${Here%/@BINDIR@}
    export BINDIR="$_3X_HOME/@BINDIR@"
    export TOOLSDIR="$_3X_HOME/@TOOLSDIR@"
    export DATADIR="$_3X_HOME/@DATADIR@"
    export GUIDIR="$_3X_HOME/@GUIDIR@"
    export LIBDIR="$_3X_HOME/@LIBDIR@"
    export LIBEXECDIR="$_3X_HOME/@LIBEXECDIR@"
    export DOCSDIR="$_3X_HOME/@DOCSDIR@"
    export NODE_PATH="$LIBDIR/node_modules${NODE_PATH:+:$NODE_PATH}"
    insertOptionalPATH() {
        local dir=
        for dir; do
            [ -d "$dir" ] || continue
            PATH="$dir:$PATH"
        done
    }
    PATH="$LIBEXECDIR/depends.runtime/.all/bin:$PATH"
    insertOptionalPATH \
        "$LIBEXECDIR"/depends/.all/bin \
        "$LIBDIR"/node_modules/.bin \
        #
    PATH="$TOOLSDIR:$PATH"
    export PATH
    unset CDPATH
    export SHLVL=0 _3X_LOGLVL=${_3X_LOGLVL:-1}
    # export _3X_LOG_TO_NONTTY=
fi

# make sure everything we need is available
check-runtime-deps-once

while getopts "vtq" opt; do
    case $opt in
        v)
            let ++_3X_LOGLVL
            ;;
        q)
            _3X_LOGLVL=0
            ;;
        t)
            export _3X_LOG_TO_NONTTY=true
            ;;
    esac
done
shift $(($OPTIND - 1))


# Process input arguments
[ $# -gt 0 ] || usage "$0" "No COMMAND given"
Cmd=$1; shift


# Check if it's a valid command
exe=3x-"$Cmd"
if type "$exe" &>/dev/null; then
    set -- "$exe" "$@"
else
    usage "$0" "$Cmd: invalid COMMAND"
fi


# Run given command under this environment
exec "$@"
