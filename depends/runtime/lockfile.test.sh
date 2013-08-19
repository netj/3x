#!/usr/bin/env bash
set -eu
# optional
if {
    ! type lockfile &&
    ! type dotlockfile &&
    ! type lockfile-create lockfile-remove &&
    true
} &>/dev/null; then
    echo >&2 "None of lockfile, dotlockfile or lockfile-create/remove available"
    false
fi
