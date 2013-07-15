#!/usr/bin/env bash
# remote-runner.sh -- common vocabularies for remote runners
# Usage:
# > . remote-runner.sh
#
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2013-07-13
shopt -s extglob

# parse remote specification
parseRemote() {
    [ -n "${1:-}" -o -z "${remoteHost:-}" ] || return 0
    remote=${1:-$(cat "$_3X_TARGET_DIR"/remote 2>/dev/null ||
        error "$_3X_TARGET: target has no remote defined")}
    case $remote in
        ssh://?(+([^@:/])@)+([^@:/])?(:+([0-9]))/*)
            local remoteUserHostPortRoot=${remote#ssh://}
            remoteRoot=${remoteUserHostPortRoot#*/}
            case $remoteRoot in
                "~"*) ;;
                *) remoteRoot="/$remoteRoot" ;;
            esac

            local remoteUserHostPort=${remoteUserHostPortRoot%/$remoteRoot}
            local remoteHostPort=${remoteUserHostPort#*@}
            remoteUser=${remoteUserHostPort%$remoteHostPort}
            remoteUser=${remoteUser%@}
            remoteHost=${remoteHostPort%:*}
            remotePort=${remoteHostPort#$remoteHost}
            remotePort=${remotePort#:}
            return 0
            ;;
        +([^:])://*) # other URLs are not allowed
            ;;
        ?(+([^@:])@)+(+([^@:]))?(:*))
            local remoteUserHost=${remote%%:*}
            remoteRoot=${remote#$remoteUserHost}
            remoteRoot=${remoteRoot#:}
            remoteRoot=${remoteRoot:-.}
            remoteHost=${remoteUserHost#*@}
            remoteUser=${remoteUserHost%$remoteHost}
            remoteUser=${remoteUser%@}
            remotePort= # no port can be specified in this syntax
            return 0
            ;;
    esac
    error "$remote: malformed REMOTE_URL"
}

# TODO see if ssh supports Control{Master,Persist}
remoteSSHCommand=$(escape-args-for-shell \
    ssh \
    -o BatchMode=yes \
    -o ControlMaster=auto -o ControlPersist=60 \
    -o ControlPath="$_3X_WORKER_DIR"/ssh-master \
    #
)

sshRemote() {
    parseRemote
    # TODO use ControlMaster ControlPersist
    $remoteSSHCommand ${remotePort:+-p $remotePort} \
        ${remoteUser:+$remoteUser@}$remoteHost \
        "$@"
}

rsyncToRemote() {
    local remotePath=$1; shift
    parseRemote
    local verboseOpt=; be-quiet +2 || verboseOpt=-v
    set -- \
    rsync --rsh="$remoteSSHCommand ${remotePort:+-p $remotePort}" $verboseOpt \
        "$@" \
        "${remoteUser:+$remoteUser@}$remoteHost":"$(escape-args-for-shell "$remoteRoot/$remotePath")" \
        #
    msg +2 " $*"
    "$@"
}

rsyncFromRemote() {
    local remotePath=$1; shift
    parseRemote
    local verboseOpt=; be-quiet +2 || verboseOpt=-v
    set -- \
    rsync --rsh="$remoteSSHCommand ${remotePort:+-p $remotePort}" $verboseOpt \
        "${remoteUser:+$remoteUser@}$remoteHost":"$(escape-args-for-shell "$remoteRoot/$remotePath")" \
        "$@" \
        #
    msg +2 " $*"
    "$@"
}
