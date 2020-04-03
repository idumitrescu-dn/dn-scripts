#!/bin/bash

function __dnconfig_ac()
{
    local cur
    local flds=$(/bin/ls ${_DNCONFIG_DIR})

    cur=${COMP_WORDS[COMP_CWORD]}

    COMPREPLY=( $(compgen -W "$flds" -- ${cur}) )

    return 0
}
complete -F __dnconfig_ac -o filenames dnconfig
