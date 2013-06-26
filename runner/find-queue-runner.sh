#!/usr/bin/env bash
# find-queue-runner.sh -- Find the runner for the current queue
# Usage: . find-queue-runner.sh; echo "$target"
#        . find-queue-runner.sh; queue-start
#        . find-queue-runner.sh; queue-stop
#        . find-queue-runner.sh; queue-refresh
#
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2013-06-24

. "$TOOLSDIR"/find-queue.sh

if [ -L "$queueDir"/target ]; then
    targetDir=$(readlink -f "$queueDir"/target)
    target=${targetDir##*/}
    targetType=$(cat "$queueDir"/target/type 2>/dev/null) ||
        error "$target: No type defined for target execution environment"
else
    error "No target execution environment asscoaited with $queue" || true
    msg "Associate a target environment by running:"
    msg "  3x target"
    false
fi

PATH="$TOOLSDIR"/runner/"$targetType":"$PATH"
