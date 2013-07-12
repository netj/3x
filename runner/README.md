# 3X Runners for Various Execution Environments

3X allows a computational experiment to have multiple *target execution
environment*s, or *target*s in short.  A target defines how an experimental
run is executed, e.g., executed locally, remotely, or via a job scheduler of a
compute cluster.  Since there can be various configurations even for a single
type of target, 3X allows users to define multiple targets of the same type.
For example, when executing locally, user may want to use different sets of
environment variables that aren't considered as an input.  3X lets the user
manage multiple environment configuration as different targets with mnemonic
names.

A 3X *runner* consists of a set of handlers to define a type of target
execution environment.  3X invokes the handlers of a runner through a clearly
defined command-line interface.  In this note, the necessary handlers 3X
expects from a runner and their invocations are described.


## 3X Runner Interface

### Handlers for Target Definition

First, every runner must provide handlers to define a new target, and display
information about already defined ones.

When 3X invokes these handler commands, the following assertions are guaranteed
to hold:

* Environment variable `_3X_ROOT` is set to the path to the root of the 3X
  experiment repository.
* The first command-line argument `TARGET` is the name of the target.

#### target-define

    target-define TARGET [ARG]...

This handler is used for defining a new target.  A case this handler is invoked
is when the user runs the following 3X command:

    3x target TARGET define TYPE [ARG]...

Any additional command-line arguments (`ARG`) user provides are passed down to
it, following the target's name.

Every defined target in an experiment repository has its directory at path
`run/target/TARGET/` where `TARGET` is the name of the target.  This command
must make sure the target directory exists, and populate it with files
containing relevant information necessary for execution.


#### target-info

    target-info TARGET [ARG]...

This handler is used for displaying detailed information of a defined target.
A case this handler is invoked is when the user runs the following 3X command:

    3x target TARGET info [ARG]...

Within `target-info`, information that resides in the target's directory can be
easily accessed as done in the following shell script:

    Target=$1
    cd "$_3X_ROOT"/run/target/"$Target"
    cat ...



### Handlers for Queue Management

Second, every runner must provide commands to handle execution of runs within a
queue.  In 3X, groups of experimental runs are organized as queues, and each
queue has an associated target execution environment that determines how new
runs will be executed.  The associated target determines which runner is used
for planned runs in the queue.

When 3X invokes these handler commands, the following assertions are guaranteed
to hold:

* The following environment variables are set:
    * `_3X_QUEUE` is set to the queue's simple name, e.g., `name`.
    * `_3X_QUEUE_ID` is set to the queue's qualified name, e.g., `run/queue/main`
    * `_3X_QUEUE_DIR` is set to the absolute path to the queue.
    * `_3X_TARGET` is set to the target's name.
    * `_3X_TARGET_DIR` is set to the absolute path to the target.
        (exceptions: `queue-refresh`, `queue-sync`)
    * `_3X_RUNNER` is set to the runner's name.
* The current working directory is set to the queue directory, i.e., `$_3X_QUEUE_DIR`.

All handlers must function robustly even in the case where the queue and/or
intermediate data used by previously executing runs are incomplete or stale.


#### queue-start

    queue-start [ARG]...

This handler is used for starting the execution of runs in the queue.  One case
it is invoked is when the following 3X user command is run:

    3x start [ARG]...

Any additional command-line arguments (`ARG`) provided by the user are passed
down.

When this handler is interrupted (with signal `INT`), it may or may not invoke
the `queue-stop` handler to take the queue back to its stopped state, depending
on which approach makes more pragmatic sense for the target execution
environment.  For example, the local runner will mark the queue as stopped if
it's there are no active workers, but not clean up the intermediate data, so
that the interrupted runs can be examined easily.  A subsequent invocation of
`queue-stop` will clean up the intermediate data as well.


#### queue-stop

    queue-stop [ARG]...

This handler is used for stopping the executions previously started.  It is
invoked when the following 3X user command is run:

    3x stop

The handler must stop any running executions of its type.  It should move back
all the runs that it has stopped to the `plan` list and clean up their
intermediate data using the `queue-sync` handler.

This handler should not assume the environment variables `$_3X_TARGET_DIR` and
`$_3X_TARGET` will be defined as it is invoked, and they must be inferred by the
handler itself from its intermediate data when necessary.


#### queue-refresh

    queue-refresh [ARG]...

This handler is used for reflecting the execution status of the queue.
However, it is not supposed to reflect current intermediate data of the runs
that are marked as `running`.  That should be handled by the `queue-sync`
handler.

This handler should not assume the environment variables `$_3X_TARGET_DIR` and
`$_3X_TARGET` will be defined as it is invoked, and they must be inferred by the
handler itself from its intermediate data when necessary.


#### queue-sync

    queue-sync [ARG]...

This handler is used for synchronizing the repository data with the current
data for the runs that are listed in the `running` list.  When there are runs
that are in fact not executing but marked as so, it must move them back to the
`plan` list and clean up their intermediate data.  Otherwise, for executing
runs, it must update the intermediate data of their run directories with
current data.

This handler should not assume the environment variables `$_3X_TARGET_DIR` and
`$_3X_TARGET` will be defined as it is invoked, and they must be inferred by the
handler itself from its intermediate data when necessary.


#### queue-changed

    queue-changed [ARG]...

This handler is used to notify the runner about modifications to the queue made
by other 3X commands.  For example, when `3x-plan` modifies the planned runs
for a queue, it will invoke this command to let them be executed at the target.






## Extensible Base Runner Implementation

### Creating New 3X Runners by Extension

In order to reduce the amount of code required to add a new runner, 3X base
runner was carefully designed to provide decent extensibility.  New runners
can reuse most of the base runner's code and define only the essential
parts.  This is done by exploiting Unix's and bash's file search mechanism
based on the `PATH` environment.

An extending runner:

* Has its directory under `$_3X_RUNNER_HOME`, e.g., `$TOOLSDIR/runner/local/`.
* Can have executable commands and scripts (`*.sh`) that are extending or
  overriding those of the base runner.
* Can extend a runner other than the base runner, and have that runner's
  name in a file named `parent`.  This can be done recursively as long as
  there's no cycle in the extension chain.

There are two important rules to which every extending runner MUST conform,
in order to make the extension mechanism function properly:

* It MUST start with `. runner.sh` if it's implemented in bash and uses any
  of the scripts explained below.
* It MUST NOT have a file named `runner.sh` in its directory.

A command named `super` is provided by 3X to substantially simplify the
extension process.  It invokes the same command provided by one of the parent
runners.  An equivalent bash function is defined in `runner.sh` that does the
same thing for scripts.  Extending runners can use these facilities as follows,
when the behavior of the parent runner's command or script is needed:

    super "$0" "$@"            # when it's a command

Or:

    super "$BASH_SOURCE" "$@"  # when it's a script

All runner commands and scripts may assume it is always invoked by 3X after
setting up the environment with `find-runner.sh`.  In fact, that script is the
one who sets up the PATH environment for the whole extension mechanism
described above to work.  The following environment variables are set by
`find-runner.sh`, so it is safe to use them within runners:

* `_3X_RUNNER`
* `_3X_RUNNER_HOME`
* `_3X_QUEUE`
* `_3X_QUEUE_ID`
* `_3X_QUEUE_DIR`

Following variables are set when available:

* `_3X_TARGET`
* `_3X_TARGET_DIR`



### 3X Runner Extension Points

Behavior of the base runner can be extended or overridden at multiple
levels.  By simply placing an executable in the runner's directory with one
of the following names will override the default behavior at the desired
level:


#### dequeue
This command handles execution of a series of planned runs.  It is invoked
each time the queue receives new runs in its plan.  When it's desirable for
the runner to handle multiple runs at a time, this is the right command to
override.  Otherwise, run command or more finer-grained levels are the
places to extend.  The default behavior is to dequeue a single run from the
queue:

  1. Pick the first run of the `plan` list,
  2. Assign a serial number (`$serial`) and a new run identifier (`$runId`),
  3. Create a `running.$serial/` directory (`$runDir`) that contains the
     necessary info to execute the run (cmdln, serial, run symlink, etc.),
  3. Add the run to the `running` list,
  4. Invoke `run` command to handle actual assembly and execution of the run,
  5. Clean up the intermediate run directory (`$runDir`).

The runner would probably want to override `queue-sync` handler as well to
match the altered behavior of this command.


#### run
This command handles execution of a single run.  It is invoked for each run
from base runner's `dequeue` implementation.  The default behavior is to:

  1. Assemble the run with `run.assemble` command.
  2. Execute the run with `run.execute` command.
  3. Store the run with `run.store` command.

Unless the runner needs to perform above three steps all together
differently, extending individual commands instead is advised.


#### run.assemble
This command handles assembly of a run.  All input parameters are supplied to
it as command-line arguments in the form of `NAME=VALUE`.  The default
behavior is to assemble the run in the repository at the path specified as the
run identifier, i.e., `$_3X_ROOT/$_3X_RUN/`.


#### run.execute
This command handles the actual execution of a run.  No default implementation
is provided by the base runner for this command.  Every runner MUST provide one
unless it overrides `run` or `dequeue` command, and does not rely on this one.


#### run.store
This command handles storage of an executed run.  It MUST make sure that:

1. the run after execution is stored at `$_3X_ROOT/$_3X_RUN/`,
2. output values are extracted and indexed,
3. archived (de-duplicated) into `$_3X_ROOT/.3x/files/`.

The default behavior performs necessary tasks assuming the run is located
at: `$_3X_ROOT/$_3X_RUN/`.
