#!/bin/bash
# Script Name: start_db2.sh
# Description: This script will start db2 instance and activate dbs.
# Arguments: DB2INST (Run as Instance)
# Written by: Jay Thangavelu

SCRIPTNAME=start_db2.sh

## Calling comman functions and variables.
    . /tmp/include_db2

if [[ -z ${DB2INST} ]]; then
    DB2INST=$(whoami)
fi

DB2INST=$1
## Get Instance home directory
    get_inst_home

#Source db2profile
    if [[ -f ${INSTHOME}/sqllib/db2profile ]]; then
        . ${INSTHOME}/sqllib/db2profile
    fi
log_roll ${LOGFILE}
log "START - ${SCRIPTNAME} execution started for Instance - ${DB2INST} at $(date)"

log "${HNAME}:${DB2INST} preparing to start"
  db2start > ${LOGDIR}/${DB2INST}.db2start.out 2>&1
  DB2STARTRC=$?

	if [[ "${DB2STARTRC}" -eq 0 || "${DB2STARTRC}" -eq 1 ]]; then
		log "Db2 Instance - ${HNAME}:${DB2INST} Started successfully"

    activatedb
    sleep 5
    tsacluster
    if [[ "${CLUSTER}" == "TSAMP" ]]; then
      log "Preparing to start tsamp"
      yes 1 | db2haicu >> ${LOGDIR}/start_tsamp_${HNAME}.out
      RCD=$?
      if [[ ${RCD} -ne 0 ]]; then
        log "WARNING: Not able to enable tsamp, Please check!"
        cat ${LOGDIR}/start_tsamp_${HNAME}.out >> ${LOGFILE}
      fi
    fi
	else
		log "ERROR: Unable to start Db2 Instance - ${HNAME}:${DB2INST}"
    cat ${LOGDIR}${DB2INST}.db2start.out
    exit 11
	fi

    log "Running DB2UPDV(Upgrade db) and Binds on each Database"
    db2updv_binds
  
log "END - ${SCRIPTNAME} execution ended for Instance - ${DB2INST} at $(date)"