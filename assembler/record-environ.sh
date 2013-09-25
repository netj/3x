#!/usr/bin/env bash
[ $# -gt 0 ] || { echo >&2 "Usage: record-environ.sh [NAME[=VALUE]]..."; exit 2; }
for _3X_decl; do
    _3X_name=${_3X_decl%%=*}
    _3X_orig=_3X_ORIG_$_3X_name
    if declare -p -- $_3X_orig &>/dev/null; then
        echo "$_3X_name=${!_3X_orig}"
    elif declare -p -- $_3X_name &>/dev/null; then
        echo "$_3X_name=${!_3X_name}"
    else
        case $_3X_decl in
            *=*) echo "$_3X_name=${_3X_decl#$_3X_name=}" ;;
        esac
    fi
done
