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


## Target Definition

First, every runner must provide handlers to define a new target, and display
information about already defined ones.

When 3X invokes these handler commands, the following assertions are guaranteed
to hold:

* Environment variable `_3X_ROOT` is set to the path to the root of the 3X
  experiment repository.
* The first command-line argument `TARGET` is the name of the target.

### target-define

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


### target-info

    target-info TARGET [ARG]...

This handler is used for displaying detailed information of a defined target.
A case this handler is invoked is when the user runs the following 3X command:

    3x target TARGET info [ARG]...

Within `target-info`, information that resides in the target's directory can be
easily accessed as done in the following shell script:

    Target=$1
    cd "$_3X_ROOT"/run/target/"$Target"
    cat ...



## Execution at Target

Second, every runner must provide commands to handle execution of runs within a
queue.  In 3X, groups of experimental runs are organized as queues, and each
queue has an associated target execution environment that determines how new
runs will be executed.  The associated target determines which runner is used
for planned runs in the queue.

When 3X invokes these handler commands, the following assertions are guaranteed
to hold:

* Environment variable `queueDir` is set to the path to the queue.

All handlers must function robustly even in the case where the queue and/or
intermediate data used by previously executing runs are incomplete or stale.


### queue-start

    queue-start [ARG]...

This handler is used for starting the execution of runs in the queue.  One case
it is invoked is when the following 3X user command is run:

    3x start [ARG]...

Any additional command-line arguments (`ARG`) provided by the user are passed
down.

When this handler is interrupted (with signal `INT`), it may or may not invoke
the queue-stop handler to take the queue back to its stopped state, depending
on which approach makes more pragmatic sense for the target execution
environment.  For example, the local runner will mark the queue as stopped if
it's there are no active workers, but not clean up the intermediate data, so
that the interrupted runs can be examined easily.  A subsequent invocation of
queue-stop will clean up the intermediate data as well.


### queue-stop

    queue-stop [ARG]...

This handler is used for stopping the executions previously started.  It is
invoked when the following 3X user command is run:

    3x stop

The handler must stop any running executions of its type.  It should move back
all the runs that it has stopped to the `plan` list and clean up their
intermediate data using the queue-sync handler.


### queue-refresh

    queue-refresh [ARG]...

This handler is used for reflecting the execution status of the queue.
However, it is not supposed to reflect current intermediate data of the runs
that are marked as `running`.  That should be handled by the queue-sync
handler.


### queue-sync

    queue-sync [ARG]...

This handler is used for synchronizing the repository data with the current
data for the runs that are listed in the `running` list.  When there are runs
that are in fact not executing but marked as so, it must move them back to the
`plan` list and clean up their intermediate data.  Otherwise, for executing
runs, it must update the intermediate data of their run directories with
current data.


### queue-changed

    queue-changed [ARG]...

This handler is used to notify the runner about modifications to the queue made
by other 3X commands.  For example, when `3x-plan` modifies the planned runs
for a queue, it will invoke this command to let them be executed at the target.

