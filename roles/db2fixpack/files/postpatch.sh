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
if [[ "${DB2PRODUCT}" == "client" ]]; then
    log "Collect existing db2 client configuration and diagnostic information to - ${BACKUPSDIR}"
        db2 get dbm cfg > ${BACKUPSDIR}/dbm_cfg_after_${DB2INST}.out
        cp -R $HOME/sqllib/function ${BACKUPSDIR}/routine_backup_${DB2INST}
        db2set -all > ${BACKUPSDIR}/db2set_after_${DB2INST}.out
        set | grep DB2 > ${BACKUPSDIR}/set_env_after_${DB2INST}.out
        db2licm -l > ${BACKUPSDIR}/db2licm_after_${DB2INST}.out
        db2level > ${BACKUPSDIR}/db2level_after_${DB2INST}.out
        db2 list db directory > ${BACKUPSDIR}/listdb_after_${DB2INST}.out
        db2 list node directory > ${BACKUPSDIR}/listnode_after_${DB2INST}.out
else
  log "Collecting post update information/configuration"
  log "Outputs stored in - ${BACKUPSDIR}"

  ## Updating dbm cfg if it is AIX Server(they reset some cases)
  if [[ "${HVERSION}" == "AIX" ]]; then
	  log "Updating DBM CFG for AIX"
	  UPDATEDMBCFGLOG=${BACKUPSDIR}/update_dbm_cfg_${DB2INST}.log

	  DFT_MON_BUFPOOL=$(cat ${BACKUPSDIR}/dbm_cfg_bef_${DB2INST}.out | grep -i DFT_MON_BUFPOOL | cut -d "=" -f2 | awk '{print $1}')
	  DFT_MON_LOCK=$(cat ${BACKUPSDIR}/dbm_cfg_bef_${DB2INST}.out | grep -i DFT_MON_LOCK | cut -d "=" -f2 | awk '{print $1}')
	  DFT_MON_SORT=$(cat ${BACKUPSDIR}/dbm_cfg_bef_${DB2INST}.out | grep -i DFT_MON_SORT | cut -d "=" -f2 | awk '{print $1}')
	  DFT_MON_STMT=$(cat ${BACKUPSDIR}/dbm_cfg_bef_${DB2INST}.out | grep -i DFT_MON_STMT | cut -d "=" -f2 | awk '{print $1}')
	  DFT_MON_TABLE=$(cat ${BACKUPSDIR}/dbm_cfg_bef_${DB2INST}.out | grep -i DFT_MON_TABLE | cut -d "=" -f2 | awk '{print $1}')
	  DFT_MON_UOW=$(cat ${BACKUPSDIR}/dbm_cfg_bef_${DB2INST}.out | grep -i DFT_MON_UOW | cut -d "=" -f2 | awk '{print $1}')

	  SYSADM_GROUP=$(cat ${BACKUPSDIR}/dbm_cfg_bef_${DB2INST}.out | grep -i SYSADM_GROUP | cut -d "=" -f2 | awk '{print $1}')
	  SYSMAINT_GROUP=$(cat ${BACKUPSDIR}/dbm_cfg_bef_${DB2INST}.out | grep -i SYSMAINT_GROUP | cut -d "=" -f2 | awk '{print $1}')
	  SYSMON_GROUP=$(cat ${BACKUPSDIR}/dbm_cfg_bef_${DB2INST}.out | grep -i SYSMON_GROUP | cut -d "=" -f2 | awk '{print $1}')
	  GROUP_PLUGIN=$(cat ${BACKUPSDIR}/dbm_cfg_bef_${DB2INST}.out | grep -i GROUP_PLUGIN | cut -d "=" -f2 | awk '{print $1}')

	  SPM_NAME=$(cat ${BACKUPSDIR}/dbm_cfg_bef_${DB2INST}.out | grep -i SPM_NAME | cut -d "=" -f2 | awk '{print $1}')
	  SVCENAME=$(cat ${BACKUPSDIR}/dbm_cfg_bef_${DB2INST}.out | grep -i SVCENAME | cut -d "=" -f2 | awk '{print $1}')
	  JDK_PATH=$(cat ${BACKUPSDIR}/dbm_cfg_bef_${DB2INST}.out | grep -i JDK_PATH | cut -d "=" -f2 | awk '{print $1}')
	  DIAGPATH=$(cat ${BACKUPSDIR}/dbm_cfg_bef_${DB2INST}.out | grep -i DIAGPATH | cut -d "=" -f2 | awk '{print $1}' | head -1)


    db2 -v "update dbm cfg using DFT_MON_LOCK ${DFT_MON_LOCK}" > ${UPDATEDMBCFGLOG}
    db2 -v "update dbm cfg using DFT_MON_SORT ${DFT_MON_SORT}" >> ${UPDATEDMBCFGLOG}
    db2 -v "update dbm cfg using DFT_MON_STMT ${DFT_MON_STMT}" >> ${UPDATEDMBCFGLOG}
    db2 -v "update dbm cfg using DFT_MON_TABLE ${DFT_MON_TABLE}" >> ${UPDATEDMBCFGLOG}
    db2 -v "update dbm cfg using DFT_MON_UOW ${DFT_MON_UOW}" >> ${UPDATEDMBCFGLOG}

    db2 -v "update dbm cfg using SYSADM_GROUP ${SYSADM_GROUP}" >> ${UPDATEDMBCFGLOG}
    db2 -v "update dbm cfg using SYSMAINT_GROUP ${SYSMAINT_GROUP}" >> ${UPDATEDMBCFGLOG}
    db2 -v "update dbm cfg using SYSMON_GROUP ${SYSMON_GROUP}" >> ${UPDATEDMBCFGLOG}
    db2 -v "update dbm cfg using GROUP_PLUGIN ${GROUP_PLUGIN}" >> ${UPDATEDMBCFGLOG}

    db2 -v "update dbm cfg using SPM_NAME ${SPM_NAME}" >> ${UPDATEDMBCFGLOG}
    db2 -v "update dbm cfg using SVCENAME ${SVCENAME}" >> ${UPDATEDMBCFGLOG}
    db2 -v "update dbm cfg using JDK_PATH ${JDK_PATH}" >> ${UPDATEDMBCFGLOG}
    db2 -v "update dbm cfg using DIAGPATH ${DIAGPATH}" >> ${UPDATEDMBCFGLOG}

	  db2stop force;db2start;
	  activatedb
  fi

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