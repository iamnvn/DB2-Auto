#!/bin/bash
# Script Name: failover.sh
# Description: This script will takeover databases to principal standby server.
# Arguments: DB2INST (Run as Instance)
# Written by: Jay Thangavelu

SCRIPTNAME=failover.sh

## Call commanly used functions and variables
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

  takeoverdb
  sleep 30

  log "Running Binds and Upgrade Database"
  DB2VR=$(db2level | grep -i "Informational tokens" | awk '{print $5}')
  if [[ "${DB2VR:0:5}" == "v11.1" ]]; then
    DB2UPDB=db2updv111
  elif [[ "${DB2VR:0:5}" == "v11.5" ]]; then
    DB2UPDB=db2updv115
  else
    DB2UPDB=db2updv10
  fi
      
    while read DBNAME
    do
      DBROLE=$(db2 get db cfg for ${DBNAME} | grep -i "HADR database role" | cut -d "=" -f2 | awk '{print $1}')
      if [[ "${DBROLE}" == "PRIMARY" || "${DBROLE}" == "STANDARD" ]]; then
        log "Running upgrade DB for database - ${DBNAME}"
        log "Running - ${DB2UPDB} -d ${DBNAME}"
          ${DB2UPDB} -d ${DBNAME} > ${LOGDIR}/db2updv_${DBNAME}.log 2>&1
          db2 terminate
        log "Running - binds on ${DBNAME}"
          db2 -ec +o connect to ${DBNAME}
          db2 BIND ${INSTHOME}/sqllib/bnd/db2schema.bnd BLOCKING ALL GRANT PUBLIC SQLERROR CONTINUE > ${BACKUPSDIR}/BIND_${DBNAME}.log
          db2 BIND ${INSTHOME}/sqllib/bnd/@db2ubind.lst BLOCKING ALL GRANT PUBLIC ACTION ADD >> ${BACKUPSDIR}/BIND_${DBNAME}.log
          db2 BIND ${INSTHOME}/sqllib/bnd/@db2cli.lst BLOCKING ALL GRANT PUBLIC ACTION ADD >> ${BACKUPSDIR}/BIND_${DBNAME}.log
          db2 terminate
          db2rbind ${DBNAME} -l ${BACKUPSDIR}/db2rbind_${DBNAME}.log all > /dev/null
      else
        log "Standby Database skipping binds and upgradedb"
      fi
    done < /tmp/${DB2INST}.db.lst

log "END - ${SCRIPTNAME} execution ended for Instance - ${DB2INST} at $(date)"