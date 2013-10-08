#!/usr/bin/env bash
# find-run-archive.sh -- Find the run archive of current experiment repository
# 
# > . find-run-archive.sh
# > cd "$_3X_ARCHIVE"
#
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2013-10-07

_3X_ROOT=$(3x-findroot)
export _3X_ROOT

export _3X_ARCHIVE="$_3X_ROOT"/.3x/files
