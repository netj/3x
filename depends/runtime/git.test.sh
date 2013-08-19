#!/bin/sh
set -eu
error() { echo >&2 "$@"; false; }

git hash-object &>/dev/null ||
    error "git hash-object unavailable"
