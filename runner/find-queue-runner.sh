#!/usr/bin/env bash
# find-queue-runner.sh -- Find the runner for the current queue
# > . find-queue-runner.sh
# > echo "$target"
# > queue-start
# > queue-stop
# > queue-refresh
# > queue-sync
# > queue-changed
#
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2013-06-24

. find-queue.sh

if [ -L "$queueDir"/target ]; then
    export targetDir=$(readlink -f "$queueDir"/target)
    export target=${targetDir##*/}
    export targetType=$(cat "$queueDir"/target/type 2>/dev/null) ||
        error "$target: No type defined for target execution environment"
else
    error "No target execution environment asscoaited with $queue" || true
    msg "Associate a target environment by running:"
    msg "  3x target"
    false
fi

PATH="$queueRunner/$targetType":"$PATH"
