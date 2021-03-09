#!/bin/sh

# Docker specific
alias de="docker-enter "
alias den='de $(docker container ls --filter="label=com.docker.compose.service=node-manager" -q)'
alias der='de `docker container ls --filter="label=com.docker.compose.service=routing-engine" -q` "ip netns exec vrfns_default bash"'
alias dem='de `docker container ls --filter="label=com.docker.compose.service=management-engine" -q`'
alias dps="docker-ps"
alias ccon="clear_containers"
