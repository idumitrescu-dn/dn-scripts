#!/bin/bash

echo "Sourcing Bash Functions"

alias rgrep='rgrep --color=auto'

_WORKDIR=${HOME}/git
_SCRIPTS_FOLDER=$(dirname ${BASH_SOURCE[0]})

function cdw()
{
    cd $_WORKDIR/$1
}

function __cdw_ac()
{
    local cur
    local flds=$(/bin/ls $_WORKDIR/)

    cur=${COMP_WORDS[COMP_CWORD]}

    COMPREPLY=( $(compgen -W "$flds" -- ${cur}) )

    return 0
}

complete -F __cdw_ac -o nospace  cdw

function cdc()
{
    if [ `pwd` != "${_WORKDIR}/cheetah" ]; then
        cd ${_WORKDIR}/cheetah
    fi
}

# Git scripts

function __git_PS()
{
    [[ "${PS1}" == *"__git_ps1"* ]] && return
    function __apply_PS()
    {
        export PS1="${PS1}"'$(__git_ps1 "(%.16s) ")'
    }

    type __git_ps1 > /dev/null 2>&1
    [ $? == 0 ] && __apply_PS && return

    if [[ -r /usr/lib/git-core/git-sh-prompt ]]; then
        source /usr/lib/git-core/git-sh-prompt
        __apply_PS && return
    fi

    if [[ -r /usr/local/opt/git/etc/bash_completion.d/git-prompt.sh ]]; then
        source /usr/local/opt/git/etc/bash_completion.d/git-prompt.sh
        __apply_PS && return
    fi
}

#__git_PS

function cdr()
{
    local top_level=$(git rev-parse --show-toplevel 2> /dev/null)
    if [[ "$top_level" != "" ]]; then
        cd $top_level
    fi
}


# SSH logging

mkdir -p ~/logs/ 2> /dev/null
function slog()
{
    if [[ "$#" != "2" ]] ; then
        echo "Usage: slog USER HOST"
        return
    fi
    local USER=$1
    local HOST=$2
    local TIMESTAMP=$( date +"%Y%m%d.%H%m" )

    ssh -X ${USER}@${HOST} 2>&1 | tee ~/logs/ssh.${USER}_${HOST}_${TIMESTAMP}.log
}


# Build functions

function mclean()
{
    cdc
    make clean
    make orm build-infra-in-docker -j2 && make start_mgmt_env
}

# Utility functions

function openNS ()
{
    if [ "$#" -gt 2 ] || [ "$#" -lt 1 ]; then
        echo "Usage: openNS PROGRAM [PORT]"
        return 1
    fi
    local PROG_NAME=$1
    local PORT=514
    if [ "$#" == 2 ]; then
        PORT=$2
    fi
    sudo ln -sfT /proc/`pgrep -fu root ${PROG_NAME}`/ns/net /var/run/netns/${PROG_NAME}
    sudo ip netns exec ${PROG_NAME} socat UDP-RECV:${PORT} STDOUT
}

# vim: set expandtab ts=4:
