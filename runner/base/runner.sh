#!/usr/bin/env bash
# runner.sh -- common vocabularies for all (bash-based) 3X runners
# Usage:
# > . runner.sh
# 
### Creating New 3X Runners by Extension
# 
# In order to reduce the amount of code required to add a new runner, 3X base
# runner was carefully designed to provide decent extensibility.  New runners
# can reuse most of the base runner's code and define only the essential
# parts.  This is done by exploiting Unix's and bash's file search mechanism
# based on the $PATH environment.
# 
# An extending runner:
# - Has its directory under $_3X_RUNNER_HOME, e.g., $TOOLSDIR/runner/local/.
# - Can have executables and scripts (*.sh) that are extending or overriding
#   those of the base runner.
# - Can extend a runner other than the base runner, and have that runner's
#   name in a file named: parent.  This can be done recursively as long as
#   there's no cycle in the extension chain.
# 
# There are two important rules to which every extending runner MUST conform,
# in order to make the extension mechanism to function properly:
# - It MUST start with `. runner.sh` if it's implemented in bash and uses any
#   of the scripts explained below.
# - It MUST NOT have runner.sh in its directory.
# 
# A command named "super" is provided to substantially simplify the extension
# process.  It invokes the same command provided by one of the parent runners.
# An equivalent bash function is defined in runner.sh that does the same thing
# for scripts.  Extending runners can use these facilities as follows, when
# the behavior of the parent runner's command or script is needed:
# > super "$0" "$@"            # when it's a command
# Or:
# > super "$BASH_SOURCE" "$@"  # when it's a script
# 
# All runner commands and scripts may assume it is always invoked by 3X after
# setting up the environment with find-runner.sh.  In fact, that script is the
# one who sets up the PATH environment for the whole extension mechanism
# described above to work.  The following environment variables are set by
# find-runner.sh, so it is safe to use them within runners:
# - $_3X_RUNNER
# - $_3X_RUNNER_HOME
# - $_3X_QUEUE
# - $_3X_QUEUE_ID
# - $_3X_QUEUE_DIR
# Following variables are set when available:
# - $_3X_TARGET
# - $_3X_TARGET_DIR
# 
### 3X Runner Extension Points
# 
# Behavior of the base runner can be extended or overridden at multiple
# levels.  By simply placing an executable in the runner's directory with one
# of the following names will override the default behavior at the desired
# level:
# 
# 
## dequeue
# This command handles execution of a series of planned runs.  It is invoked
# each time the queue receives new runs in its plan.  When it's desirable for
# the runner to handle multiple runs at a time, this is the right command to
# override.  Otherwise, run command or more finer-grained levels are the
# places to extend.  The default behavior is to:
#   1. Pick the first run of the plan,
#   2. Assign a serial number ($serial) and a new run ID ($runId),
#   3. Create a running.$serial/ directory ($runDir) that contains the
#      necessary info to execute the run (cmdln, serial, run symlink, etc.),
#   3. Add the run to the running list,
#   4. Invoke run command to handle actual assembly and execution of the run,
# 
# The runner would probably want to override queue-sync as well to match the
# altered behavior of this command.
# 
# 
## run
# This command handles execution of a single run.  It is invoked for each run
# from base runner's process-plan.sh.  The default behavior is to:
#   1. Assemble the run with run.assemble command.
#   2. Execute the run with run.execute command.
#   3. Store the run with run.store command.
# Unless the runner needs to perform above three steps all together
# differently, extending individual commands instead is advised.
# 
# 
## run.assemble
# This command handles assembly of a run.  All input parameters are supplied to
# it as command-line arguments in the form of NAME=VALUE.  The default
# behavior is to assemble the run in the repository with the run ID, i.e.,
# $_3X_RUN.
# 
# 
## run.execute
# This command handles execution of a run.  No default implementation is
# provided by the base runner for this command.  Every runner MUST provide one
# unless it overrides run or dequeue command, and does not rely on this one.
# 
# 
## run.store
# This command handles storage of an executed run.  It MUST make sure that:
# - the run after execution is stored at $_3X_ROOT/$_3X_RUN/,
# - output values are extracted and indexed,
# - archived (de-duplicated) into $_3X_ROOT/.3x/files/.
# The default behavior performs necessary tasks assuming the run is located
# at: $_3X_ROOT/$_3X_RUN/.
# 
#
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2013-06-25
set -eu

# make sure runner handler is invoked after . find-runner.sh
: $_3X_RUNNER $_3X_QUEUE_ID $_3X_QUEUE_DIR $_3X_QUEUE $_3X_ROOT

ACTIVE_FLAG=.is-active.$_3X_RUNNER
SERIAL_COUNTER=.count
RUNDIR_PREFIX=running.$_3X_RUNNER.
WORKER_LOCK_PREFIX=.worker.$_3X_RUNNER.
WORKER_WAITING_SUFFIX=.waiting
WORKER_WAITING_SIGNAL=USR1
WORKER_WAITING_TIMEOUT=600 #secs

WORKER_ID=
runner-msg()   { msg   "$_3X_QUEUE_ID $_3X_TARGET${WORKER_ID:+[$WORKER_ID]}: $*"; }
runner-error() { error "$_3X_QUEUE_ID $_3X_TARGET${WORKER_ID:+[$WORKER_ID]}: $*"; }

synchronized() {
    local Lock=$1; shift
    until lockproc $Lock grab; do sleep 1; done
    "$@"
    lockproc $Lock release
}

# source the parent script overriden by the current one
# Example usage: super "$0" "$@"
super() {
    local this=$1; shift
    case $this in
        *.sh)
            local super=$(
                cmd=${this##*/} lastWasThis=false
                IFS=:
                for dir in $PATH; do
                    s="$dir/$cmd"
                    [ -e "$s" ] || continue
                    if [ x"$s" = x"$this" ]; then
                        lastWasThis=true
                    elif $lastWasThis; then
                        echo "$s"
                        break
                    fi
                done
            )
            if [ -e "$super" ]; then
                set -- "$super" "$@"; unset this super
                . "$@"
            else
                error "$this: No overriden script found"
            fi
            ;;
        *)
            command super "$this" "$@"
            ;;
    esac
}

# allow actual runner to override/extend
! type runner-config.sh &>/dev/null ||
. runner-config.sh
# TODO source all from base to parents, then self
