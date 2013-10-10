#!/usr/bin/env bash
# Usage: cd runnable; ./execute.sh
set -eu

[ -x workdir/run -a -r env -a -r args -a -r stdin -a -w . ] ||
    { echo >&2 "$PWD: not a runnable"; exit 127; }
: $_3X_ROOT $_3X_RUN

# prepare to forward signal to the child process group
for sig in HUP INT QUIT ABRT USR1 USR2 TERM
do trap '[ -z "${pid:-}" ] || { kill -'"$sig"' -$pid; wait $pid; } 2>/dev/null' $sig
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
                exec "$gnutimepath" -o rusage -f "\
User time (seconds): %U
System time (seconds): %S
Percent of CPU this job got: %P
Elapsed (wall clock) time (seconds): %e
Elapsed (wall clock) time (h:mm:ss or m:ss): %E
Average shared text size (kbytes): %X
Average unshared data size (kbytes): %D
Average stack size (kbytes): %p
Average total size (kbytes): %K
Maximum resident set size (kbytes): %M
Average resident set size (kbytes): %t
Major (requiring I/O) page faults: %F
Minor (reclaiming a frame) page faults: %R
Voluntary context switches: %w
Involuntary context switches: %c
Swaps: %W
File system inputs: %I
File system outputs: %O
Socket messages sent: %s
Socket messages received: %r
Signals delivered: %k
Page size (bytes): %Z" \
    "$@"
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
code=$?
echo $code >exitstatus

# turn itself off
chmod -x "$0"

# finally, preserve the exit code
exit $code
