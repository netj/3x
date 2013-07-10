#!/usr/bin/env bash
# Usage: ./execute.sh
set -eu

trap 'chmod -x "$0"' EXIT  # turn itself off after execution

# prepare to forward signal to the child process group
for sig in HUP INT QUIT ABRT USR1 USR2 TERM
do trap "kill -$sig "'-$pid; wait $pid' $sig
done

# execute this run in a clean environment and its own process group
set -m  # job control is needed to isolate the run in a process group
set +e  # from now on, we should keep going, even on errors
measuring-rusage() {
    # look for GNU time
    local gnutimepath=
    for gnutimepath in $(type -p -a gtime time); do
        case $("$gnutimepath" --version 2>&1) in
            "GNU time "*)
                # and record times and resource usage with it
                exec "$gnutimepath" -v -o rusage "$@"
                ;;
        esac
    done
    # skip recording rusage unless GNU time is available
    echo >&2 "3x: rusage disabled (GNU time not found)"
    exec "$@"
}
measuring-rusage  env - bash -c "
$(
{
    echo _3X_ROOT="$_3X_ROOT"
    echo _3X_RUN="$_3X_RUN"
    cat env
} | sed "s/'/'\\\\''/g; s/^/export '/; s/$/'/"
)
args=(
$(cat args)
)"'
cd workdir
exec ./run "${args[@]}" <../stdin >../stdout 2>../stderr
' &
pid=$!

# wait for the execution to end and record result
set +m  # need to disable job control to suppress ugly status reporting on aborts
wait $pid
echo $? >exitcode
