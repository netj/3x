#!/usr/bin/env bash
# find-queue.sh -- Find current queue based on $_3X_QUEUE
# Usage: . find-queue.sh; echo "$queue"
#        . find-queue.sh; cd "$queueDir"
#
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2013-06-24

_3X_ROOT=$(3x-findroot)
export _3X_ROOT

# determine the current queue
: ${_3X_QUEUE:=main}
case $_3X_QUEUE in
    run/queue/*)
        _3X_QUEUE=${_3X_QUEUE#run/queue/}
        ;;
    */*)
        error "$_3X_QUEUE: Invalid queue name"
        ;;
esac
export _3X_QUEUE
queue="run/queue/$_3X_QUEUE"
queueDir="$_3X_ROOT/$queue"
#[ -d "$queue" ] || error "$_3X_QUEUE: No such queue"
