#!/usr/bin/env bash
# sanity-checks.sh
# Usage: . sanity-checks.sh; checkIfNameIsSane NAME SRC
#        . sanity-checks.sh; checkIfValueIsSane VALUE NAME SRC
#
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2013-01-31

shopt -s extglob

checkIfNameIsSane() {
    local name=$1; shift
    local src=$1; shift
    case $name in
        [A-Za-z_]*([A-Za-z0-9_])) ;;
        *)
            error "$src: Invalid character in the name." "" \
                "Names can only contain alphanumeric characters and underscore (_)," \
                "and must begin with alphabetic character or underscore." \
                #
            ;;
    esac
}

checkIfValueIsSane() {
    local value=$1; shift
    local name=$1; shift
    local src=$1; shift
    case $value in
        +([A-Za-z0-9@%:.+=_-])) ;;
        *)
            error "$src: Invalid character in pattern value $value for $name." "" \
                "Values can only contain alphanumeric characters," \
                "underscore (_), dot/period (.), hyphen (-), colon (:)," \
                "plus (+), equals (=), at (@), and percent (%) signs." \
                #
            ;;
    esac
}
