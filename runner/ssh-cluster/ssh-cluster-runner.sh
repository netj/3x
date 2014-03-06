#!/usr/bin/env bash
# ssh-cluster-runner.sh
. runner.sh
. remote-runner.sh

shopt -s extglob

export _3x=$(useTargetOrRunnerConfig 3x-path +4 "3X installation path at remote hosts:")
sharedPath=$(useTargetOrRunnerConfig shared-path +3 "shared path at remote hosts:")

pickOneRandomRemote() {
    local remote=$(
    { cat "$_3X_WORKER_DIR"/runSplit.*.remote{,.clean} ||
        "$_3X_WORKER_DIR"/remotes; } 2>/dev/null |
    shuf | head -1
    )
    if [[ -n "$remote" ]]; then
        echo $remote
    else
        false
    fi
}

getSharedRemoteURL() {
    # picking a random remote
    if remote=$(pickOneRandomRemote); then
        parseRemote $remote
        remoteRoot="$sharedPath/$_3X_WORKER_ID"
        getParsedRemoteURL
    else
        false
    fi
}

ssh-3x-remote() {
    remote=$1; shift
    parseRemote $remote
    sshRemote "$_3x" remote "$sharedPath" "$_3X_WORKER_ID" \
        "$remoteRoot" "$@"
}

lsUnfinishedRunsIn() {
    local field=$1; shift
    local fieldNoInSplits= fieldNoInFinished=
    case $field in
        serial) fieldNoInSplits=1 fieldNoInFinished=2 ;;
        runId)  fieldNoInSplits=2 fieldNoInFinished=3 ;;
        *) error "$field: unknown field"
    esac
    [[ $# -gt 0 ]] || set -- "$_3X_WORKER_DIR"/runSplit.+([^.])
    cat "$@" | awk "{print \$$fieldNoInSplits}" | sort |
    comm -13 <(cat "$_3X_WORKER_DIR"/runs.finished 2>/dev/null |
               awk "{print \$$fieldNoInFinished}" | sort) -    
}

