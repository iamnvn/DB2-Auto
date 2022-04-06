#!/bin/bash
# Script Name: failover.sh
# Description: This script will takeover databases to principal standby server.
# Arguments: DB2INST (Run as Instance)
# Date: Feb 14, 2022
# Written by: Naveen Chintada

SCRIPTNAME=failover.sh

## Call commanly used functions and variables
    . /tmp/include_db2

DB2INST=$1
LOGFILE=${LOGFILE}_${DB2INST}
log_roll ${LOGFILE}

## Get Instance home directory
    get_inst_home

#Source db2profile
    if [ -f ${INSTHOME}/sqllib/db2profile ]; then
        . ${INSTHOME}/sqllib/db2profile
    fi

log "START - ${SCRIPTNAME} execution started at $(date)"

  takeoverdb
  sleep 30

log "END - ${SCRIPTNAME} execution ended at $(date)"
