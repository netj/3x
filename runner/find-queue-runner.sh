#!/usr/bin/env bash
# find-queue-runner.sh -- Find the runner for the current queue
# Usage: . find-queue-runner.sh; echo "$target"
#        . find-queue-runner.sh; queue-start
#        . find-queue-runner.sh; queue-poll
#        . find-queue-runner.sh; queue-stop
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
    error "No target execution environment assigned for $queue"
fi

PATH="$TOOLSDIR"/runner/"$targetType":"$PATH"
