#!/bin/bash

: << 'INTRO'

This file defines functions that can be used to start jenkins jobs either as a
one shot, or as persistent job that can be added to a cron-like utility.

To setup the environment you will need to call 'add_jenkins_host' to define a
new jenkins service.
For each service defined you will also need a user and token that you will get
from the jenkins user settings page. These two need to defined in two variables:

JENKINS_${_SERVICE}_USERID
JENKINS_${_SERVICE}_TOKEN

They will be used when a job is run.

The 'process_job' can be used to run a job once.
The 'add_job' function can be used to define a job with a name that can be
easily called with the 'run_job' function.

It is advised to not add any settings to this file.

Example for external jenkins file:

source ~/.dn_scripts/scripts/40_jenkins.sh

export JENKINS_OFFICE_USERID="james-dn"
export JENKINS_OFFICE_TOKEN="abcd1234"

add_jenkins_host "OFFICE" "jenkins.dev.drivenets.net"
add_jenkins_host "RO" "jenkins-ro.dev.drivenets.net"
add_jenkins_host "AWS" "jenkins-aws.dev.drivenets.net"

TESTS_ALL=TESTS_BASEOS,TESTS_BGP,TESTS_BGP_MGMT,TESTS_CLI,TESTS_CMC,TESTS_COUNTERS,TESTS_COUNTERS_V2,TESTS_DEVOPS,TESTS_DNOS,TESTS_E2E,TESTS_EM,TESTS_FIB_MANAGER,TESTS_ISIS,TESTS_ISIS_MGMT,TESTS_LDP,TESTS_LDP_MGMT,TESTS_MGMT,TESTS_MGMT_INFRA,TESTS_MGMT_SWARM,TESTS_MW,TESTS_NCM,TESTS_NEIGHBOUR_MANAGER,TESTS_NETCONF,TESTS_NODE_MANAGER,TESTS_OAM,TESTS_OAM_MGMT,TESTS_PCEP,TESTS_PCEP_MGMT,TESTS_PIM,TESTS_PIM_MGMT,TESTS_QUAGGA,TESTS_QUAGGA_E2E,TESTS_QUAGGA_MULTICAST,TESTS_QUAGGA_PCEP,TESTS_RE_IFACES,TESTS_ROUTING,TESTS_ROUTING_MGMT,TESTS_RSVP,TESTS_RSVP_MGMT,TESTS_SERVICE_DISPATCHER,TESTS_SIM,TESTS_SMALL_CLUSTER,TESTS_TACACS,TESTS_TWAMP,TESTS_UPGRADE,TESTS_WBOX,TESTS_WBOX_DEV,TESTS_WBOX_DNI,TESTS_WBOX_FE_AGENT,TESTS_ZEBRA
TEST_DEFAULT=TESTS_CMC,TESTS_E2E,TESTS_EM,TESTS_MGMT,TESTS_SMALL_CLUSTER

add_job 1 OFFICE jst/test BUILD_ALL TESTS_QUAGGA,TESTS_BGP_MGMT
add_job 2 OFFICE,AWS jst/test BUILD_ALL ${TESTS_ALL}

< END EXAMPLE

The above can be added in a file, and later a cronjob can be created.
Example:

# Run every weekday, a nightly build of job 2 as defined in the settings file. Log output and stderr
30 20 * * 1-5 export JOB=2; source ${HOME}/.cron/init; run_job ${JOB} >> ${HOME}/.cron/logs/${JOB}.log  2>&1

< END EXAMPLE

INTRO


function __debug()
{
    [ "${_JOB_DEBUG}" == "1" ] && echo -e "$1"
}


JENKINS_ALL_HOSTS=

################################################################################
# Configure a jenkins host.
# Input: NAME HOSTNAME
function add_jenkins_host()
{
    if [ "$#" -ne "2" ]; then
        echo "Usage: add_jenkins_host NAME HOSTNAME"
        return 1
    fi
    local _NAME=$1
    local _HOSTNAME=$2
    JENKINS_ALL_HOSTS="${JENKINS_ALL_HOSTS:+${JENKINS_ALL_HOSTS} }""${_NAME}"
    eval export JENKINS_${_NAME}_HOSTNAME="${_HOSTNAME}"
}

################################################################################
# Start a job on the given host with the exact URL.
# The URL must include everything from http, user and password, to what options
# to run.
# Input: HOSTNAME URL
# Example: start_job ${JENKINS_OFFICE_HOSTNAME} ....
function start_job
{
    if [ "$#" -ne "2" ]; then
        echo "Usage: start_job HOSTNAME URL"
        return 1
    fi

    local HOSTNAME=$1
    local URL=$2
    local CRUMB_OFF=$(curl --silent "http://${HOSTNAME}/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,\":\",//crumb)")

    __debug "Starting job with URL:\n${URL}"

    curl --silent -X POST \
        -H "$CRUMB_OFF"\
        "${URL}"
}

################################################################################
# Creates a Cheetah build URL based on a service and a branch.
# Input: SERVICE BRANCH [OPTIONS]
function _create_build_url
{
    if [ "$#" -lt "2" ]; then
        echo "Required params: SERVICE BRANCH [OPTIONS]"
        return 1
    fi
    local _SERVICE=$1
    local BRANCH=$2
    local BRANCH_PROC=$(_process_branch ${BRANCH})
    local OPTIONS=$3

    eval export _HOST='$'JENKINS_${_SERVICE}_HOSTNAME
    eval export _USERID='$'JENKINS_${_SERVICE}_USERID
    eval export _TOKEN='$'JENKINS_${_SERVICE}_TOKEN

    echo "http://${_USERID}:${_TOKEN}@${_HOST}/job/drivenets/job/cheetah/job/${BRANCH_PROC}/buildWithParameters?delay=0sec${OPTIONS:+&${OPTIONS}}"
    unset _HOST _USERID _TOKEN
}

################################################################################
function _process_branch
{
    if [ "$#" -ne "1" ]; then
        echo "Usage: _process_branch BRANCH"
        return
    fi
    echo $1 | sed  -e 's/\//%2F/g'
}

################################################################################
# Will take a list of comma separated parameters and convert output a part of a
# jenkins URL that handles those tests
# Input: TEST_ABCD,TEST_XYZ
function _compose_tests_params_URL
{
    if [ "$#" -ne "1" ]; then
        echo "Usage _compose_tests_params_URL <params>"
        return 1
    fi
    [ -z "$1" ] && return
    echo "TESTS_TO_RUN=Let%20me%20choose%20what%20tests%20to%20run&DISPLAY_TEST_NAMES=true&TEST_NAMES="$1
}

################################################################################
# Starts a job using the specified parameters.
# Input: <OFFICE/AWS/RO/ALL> <BRANCH> [<BUILD_ALL> <TESTS_TO_ENABLE>]
# process_job AWS branch BUILD_ALL TESTS_QUAGGA,TESTS_BGP_MGMT ""
# process_job AWS branch BUILD_ALL "" TEST_DEFAULT
function process_job
{
    if [ "$#" -lt "2" ] || [ "$#" -gt "4" ]; then
        echo "Usage: process_job <OFFICE/AWS/RO/ALL> <BRANCH> [<BUILD_ALL> <TESTS_TO_ENABLE>]"
        return
    fi

    if [ "$#" -ge "4" ]; then
        local _ALL_TESTS=$(_compose_tests_params_URL "$4")
    fi

    local _SERVICE
    local _SERVICES=$1
    local _BRANCH=$2

    for _SERVICE in ${JENKINS_ALL_HOSTS}; do
        if [[ "${_SERVICES}" == *"${_SERVICE}"* || "${_SERVICES}" == *"ALL"* ]]; then

            eval export _USERID='$'JENKINS_${_SERVICE}_USERID
            eval export _TOKEN='$'JENKINS_${_SERVICE}_TOKEN
            if [ -z "${_USERID}" ] || [ -z "${_TOKEN}" ]; then
                echo "Warning! Userid or token not defined for ${_SERVICE}"
                continue
            fi

            eval export _HOST='$'JENKINS_${_SERVICE}_HOSTNAME
            local _URL
            _URL=$(_create_build_url "${_SERVICE}" "${_BRANCH}" "${_ALL_TESTS}")
            start_job "${_HOST}" "${_URL}"
        fi
    done

    unset _HOST _USERID _TOKEN
}

################################################################################
# Localy record a job that can later be run with 'run_job'.
# Input: <NAME> <OFFICE/AWS/RO/ALL> <branch> <BUILD_ALL> <TESTS_TO_ENABLE>
# Example:
# add_job 1 OFFICE jst/test BUILD_ALL TESTS_QUAGGA,TESTS_BGP_MGMT
# add_job 2 OFFICE,AWS jst/test BUILD_ALL ${TESTS_ALL}
function add_job
{
    if [ "$#" -ne "5" ]; then
        echo "Usage: add_job <NAME> <OFFICE/AWS/RO/ALL> <BRANCH> <BUILD_ALL> <TESTS_TO_ENABLE>"
        return 1
    fi

    local NAME=$1
    eval export JOB_SERVICE_${NAME}=$2
    eval export JOB_BRANCH_${NAME}=$3
    eval export JOB_BUILD_${NAME}=$4
    eval export JOB_TESTS_${NAME}=$5
}

################################################################################
# Run a a job that was added with 'add_job'.
# Input: <NAME>
# run_job 1
# run_job 2
function run_job
{
    if [ "$#" -ne "1" ]; then
        echo "Usage: run_job <NAME>"
        return 1
    fi

    local NAME=$1
    eval export SERVICES='$'JOB_SERVICE_${NAME}
    if [ -z "${SERVICES}" ]; then
        echo "Job ${NAME} was not found. Please use add_job to define it."
        unset SERVICES
        return 1
    fi

    eval export BRANCH='$'JOB_BRANCH_${NAME}
    eval export BUILD='$'JOB_BUILD_${NAME} # currently unused
    eval export TESTS='$'JOB_TESTS_${NAME}

    echo "#####################################################################"
    echo "Running job ${NAME} on branch ${BRANCH}"
    date

    process_job "${SERVICES}" "${BRANCH}" "${BUILD}" "${TESTS}"

    unset SERVICES BRANCH BUILD TESTS
}

################################################################################
# List one or all jobs stored
# Input: <NAME>
# Example:
# list_job 1
function list_job
{
    if [ "$#" != "1" ]; then
        echo "Usage: list_job <NAME>"
        return 1
    fi
    local NAME=$1

    eval export SERVICES='$'JOB_SERVICE_${NAME}
    if [ -z "${SERVICES}" ]; then
        echo "Job ${NAME} does not exist"
        unset SERVICES
        return 1
    fi

    eval export BRANCH='$'JOB_BRANCH_${NAME}
    eval export BUILD='$'JOB_BUILD_${NAME}
    eval export TESTS='$'JOB_TESTS_${NAME}

    echo "Job ${NAME}:"
    echo "Service ${SERVICES}"
    echo "Branch ${BRANCH}"
    echo "Build ${BUILD}"
    echo "Tests ${TESTS}"

    unset SERVICES BRANCH BUILD TESTS
}

################################################################################
# List all jobs stored
# Input: [short]
# Example:
# list_jobs
# list_jobs short
function list_jobs
{
    local func='eval echo ; list_job'
    if [ "$#" == "1" ] && [[ "$1" =~ "s"* ]]; then
        func="echo Job "
    fi
    for job in $(env | grep "^JOB_SERVICE_[^=]" -o | cut -f 3- -d '_'); do
        ${func} ${job}
    done
}
