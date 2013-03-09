#!/usr/bin/env bash
# sql-vocabs.sh -- SQL vocabularies for shell
# Usage: . sql-vocabs.sh
#        ty=$(sql-type NAME)
#        sqlValue=$(sql-literal $ty "$v")
#        sqlValues=$(sql-csv $ty "$csv")
#
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2013-03-08

_varTypes=
sql-type() {
    local name=$1
    # TODO use associative arrays if available
    : ${_varTypes:=$(exp-inputs -t; exp-outputs -t)}
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
    local values=$1; shift
    local OFS=$IFS; IFS=,; set -- $values; IFS=$OFS
    local sqlValues=
    for val; do sqlValues+=", $(sql-literal $ty $val)"; done
    echo -n "${sqlValues#, }"
}
