#!/usr/bin/env bash
# sql-vocabs.sh -- SQL vocabularies for shell
# Usage: . sql-vocabs.sh
#        ty=$(sql-type NAME)
#        sqlValue=$(sql-literal $ty "$v")
#        sqlValues=$(sql-csv $ty "$v1" "$v2" ...)
#
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2013-03-08

sql-name() {
    local name=$1
    case $name in
        *"#") echo "${name%#}" ;;
        *)    echo "_$name"    ;;
    esac
}

_varTypes=
sql-type() {
    local name=$1
    case $name in
        *"#") # internal columns
            echo TEXT
            return
    esac
    # TODO use associative arrays if available
    : ${_varTypes:=$(3x-inputs -t; 3x-outputs -t)}
    ty=$(sed -n "/^$name:/ { s/^[^:]*://p; q; }" <<<"$_varTypes")
    case $ty in
        "")
            error "$name: Unknown variable"
            ;;
        ratio|ordinal|numeric|int|float)
            echo NUM
            ;;
        nominal|string|text|*)
            echo TEXT
            ;;
    esac
}

sql-literal() {
    local ty=$1 val=$2
    case $ty in
        NUM|INT|REAL)
            ;;
        TEXT)
            val=${val:+"'"${val//"'"/"''"}"'"}
            ;;
        *)
            error "$ty: Unknown SQL value type"
            ;;
    esac
    echo -n "${val:-NULL}"
}

sql-csv() {
    local ty=$1; shift
    local sqlValues=
    for val; do sqlValues+=", $(sql-literal $ty $val)"; done
    echo -n "${sqlValues#, }"
}

sql-values-expr() {
    local fmtMore=$1; shift
    local esc= vars= fmt= varName=
    for varName; do
        case $(sql-type $varName) in
            TEXT)
                esc+=" $varName=\${$varName:+\"'\"\${$varName//\"'\"/\"''\"}\"'\"}"
                ;;
        esac
        vars+="\"\${$varName:-NULL}\"" fmt+="%s"
        vars+=' ' fmt+=', '
    done
    echo "$esc; printf \"(${fmt%, }${fmtMore:+, $fmtMore})\" $vars"
}
