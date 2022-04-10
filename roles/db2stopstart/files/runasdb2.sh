#!/bin/bash
# Script Name: runasdb2.sh
# Description: This script will run script as instance user from root user.
# Arguments: Script to run
# Date: Feb 15, 2022
# Written by: Naveen Chintada

SCRIPTNAME=runasdb2.sh

## Call commanly used functions and variables
. /tmp/include_db2

LOGFILE=${LOGDIR}/${SCRIPTNAME}.log
log_roll ${LOGFILE}

if [[ -f ${MAINLOG} ]]; then 
        chmod -f 777 ${MAINLOG}
else
        touch ${MAINLOG}; chmod 777 ${MAINLOG}
fi

SCRIPTTORUN=$1
DBINST=$2
        
        su ${DBINST} -c "${SCRIPTSDIR}/${SCRIPTTORUN} ${DBINST}"

        RCD=$?
        if [[ ${RCD} -ne 0 ]]; then
                log "${SCRIPTTORUN} did not run using ${DBINST}, Please check !!"
                exit ${RCD}
        fi