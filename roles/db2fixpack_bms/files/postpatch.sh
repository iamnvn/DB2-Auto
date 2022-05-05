#!/bin/bash
# Script Name: postupgrade.sh
# Description: This script will run post upgrade activities and take backup of post upgrade configuration.
# Arguments: DB2INST (Run as Instance)
# Date: Apr 13, 2022
# Written by: Naveen Chintada

SCRIPTNAME=postupgrade.sh

## Calling comman functions and variables.
    . /tmp/include_db2

DB2INST=$1
## Get Instance home directory
    get_inst_home

#Source db2profile
    if [[ -f ${INSTHOME}/sqllib/db2profile ]]; then
        . ${INSTHOME}/sqllib/db2profile
    fi

log_roll ${LOGFILE}
log "START - ${SCRIPTNAME} execution started at $(date)"
log "Collecting post update information/configuration"
log "Outputs stored in - ${BACKUPSDIR}"

  db2 attach to ${DB2INST} >> /dev/null
  RCD=$?
  if [[ ${RCD} -ne 0 ]]; then
    db2start > /dev/null
    db2 attach to ${DB2INST} >> /dev/null
    RCD1=$?
    if [[ ${RCD1} -ne 0 ]]; then
      log "ERROR: Unable to attach Instance: ${DB2INST}, Exiting with ${RCD1}"
      exit ${RC1};
    fi
  fi

  log "Collecting instance level information after upgrade"
    db2 get dbm cfg show detail > ${BACKUPSDIR}/dbm_cfg_after_${DB2INST}.out
    db2set -all > ${BACKUPSDIR}/db2set_after_${DB2INST}.out
    set | grep DB2 > ${BACKUPSDIR}/set_env_after_${DB2INST}.out
    db2licm -l > ${BACKUPSDIR}/db2licm_after_${DB2INST}.out
    db2level > ${BACKUPSDIR}/db2level_after_${DB2INST}.out
    db2 list db directory > ${BACKUPSDIR}/listdb_after_${DB2INST}.out
    db2 list node directory > ${BACKUPSDIR}/listnode_after_${DB2INST}.out

    if [[ "$(cat db2-role.txt)" == "PRIMARY" || "$(cat db2-role.txt)" == "STANDARD" ]]; then
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
    else
        while read DBNAME
        do
            log "Running post upgrade for database - ${DBNAME}"
            db2 GET DB CFG FOR ${DBNAME} > ${BACKUPSDIR}/db_cfg_after_${DBNAME}_${DB2INST}.out
        done < /tmp/${DB2INST}.db.lst
    fi
fi
log "END - ${SCRIPTNAME} execution ended at $(date)"