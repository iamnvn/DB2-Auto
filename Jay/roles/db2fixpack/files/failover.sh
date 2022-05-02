#!/bin/bash
# Script Name: failover.sh
# Description: This script will takeover databases to principal standby server.
# Arguments: DB2INST (Run as Instance)
# Date: Apr 13, 2022
# Written by: Naveen Chintada

SCRIPTNAME=failover.sh

## Call commanly used functions and variables
    . /tmp/include_db2

DB2INST=$1
## Get Instance home directory
    get_inst_home

#Source db2profile
    if [ -f ${INSTHOME}/sqllib/db2profile ]; then
        . ${INSTHOME}/sqllib/db2profile
    fi

log_roll ${LOGFILE}
log "START - ${SCRIPTNAME} execution started at $(date)"

  takeoverdb
  sleep 30

#if [[ "$(cat db2-role.txt)" == "PRIMARY" ]]; then
  DB2VERSN=$(db2licm -l | grep 'Version information'  | head -1 | awk '{print $3}' | sed "s/.$//g" | sed "s/^.//g")
    while read DBNAME
    do
      if [[ "${DB2VERSN}" == "11.1" ]]; then
        DB2UPDB=db2updv111
      elif [[ "${DB2VERSN}" == "11.5" ]]; then
        DB2UPDB=db2updv115
      else
        DB2UPDB=db2updv10
      fi
        log "Running post upgrade for database - ${DBNAME}"
        log "Running - ${DB2UPDB} -d ${DBNAME}"
        ${DB2UPDB} -d ${DBNAME} > ${LOGDIR}/db2updv_${DBNAME}.log 2>&1
        db2 terminate
        log "Running - binds on ${DBNAME}"
        db2 -ec +o connect to ${DBNAME}
        db2 GET DB CFG FOR ${DBNAME} SHOW DETAIL > ${BACKUPSDIR}/db_cfg_after_${DBNAME}_${DB2INST}.out
        db2 BIND ${INSTHOME}/sqllib/bnd/db2schema.bnd BLOCKING ALL GRANT PUBLIC SQLERROR CONTINUE > ${BACKUPSDIR}/BIND_${DBNAME}.log
        db2 BIND ${INSTHOME}/sqllib/bnd/@db2ubind.lst BLOCKING ALL GRANT PUBLIC ACTION ADD >> ${BACKUPSDIR}/BIND_${DBNAME}.log
        db2 BIND ${INSTHOME}/sqllib/bnd/@db2cli.lst BLOCKING ALL GRANT PUBLIC ACTION ADD >> ${BACKUPSDIR}/BIND_${DBNAME}.log
        db2 terminate
        db2rbind ${DBNAME} -l ${BACKUPSDIR}/db2rbind_${DBNAME}.log all
    done < /tmp/${DB2INST}.db.lst
#fi

log "END - ${SCRIPTNAME} execution ended at $(date)"