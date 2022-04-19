#!/bin/bash
# Script Name: todolist.sh
# Description: This script will create sequence of steps to run on each node.
# Arguments: NA
# Date: Apr 13, 2022
# Written by: Naveen Chintada

SCRIPTNAME=todolist.sh

## Calling comman functions and variables.
    . /tmp/include_db2

log_roll ${LOGFILE}
log "START - ${SCRIPTNAME} execution started at $(date)"

if [[ ! -f ${MAINLOG} ]]; then
	touch ${MAINLOG}
else
    log_roll ${MAINLOG}
    touch ${MAINLOG}
fi
chmod -f 777 ${MAINLOG}

log "Collecting database and role info"
    (./runasdb2.sh hadr_roles.sh > ${HADRROLES})
    chmod -f 666 ${HADRROLES}

    if [[ "$(grep -c ' ' ${HADRROLES})" == "$(grep -c 'STANDARD' ${HADRROLES})" ]]; then
      echo "CLIENT" > db2-role.txt
      log "This Server - ${HNAME} role is $(cat db2-role.txt)"
    elif [[ "$(grep -c ' ' ${HADRROLES})" == "$(grep -c 'STANDARD' ${HADRROLES})" ]]; then
      if [[ "$(grep -c 'STANDARD' ${HADRROLES})" -ne 0 ]]; then
        echo "STANDARD" > db2-role.txt
        log "This Server - ${HNAME} role is $(cat db2-role.txt)"
      fi
    else
        log "HADR Server node - ${HNAME}"
        if [[ "$(grep -c ' ' ${HADRROLES})" == "$(grep -c 'CONNECTED' ${HADRROLES})" ]]; then
            log "All databases are CONNECTED"
        else
            log "ERROR: One or more dbs are not HADR CONNECTED state, Please check"
            exit 11
        fi
        cat ${HADRROLES} | awk '{print $1}' > db2-databases.txt
        cat ${HADRROLES} | grep 'PRIMARY' | awk '{print $1}' > db2-databases-primary.txt
        cat ${HADRROLES} | grep 'STANDBY' | awk '{print $1}' > db2-databases-standby.txt

        if [[ "$(cat db2-databases-standby.txt)" == "$(cat db2-databases.txt)" ]]; then
            echo "STANDBY" > db2-role.txt
            cat ${HADRROLES} | awk '{print $6}' | awk -F. '{print $1}' | sort -u > db2-primary.txt
            cat ${HADRROLES} | awk '{print $3}' | awk -F. '{print $1}' | sort -u > db2-hadrstate.txt
            log "Target server is $(cat db2-primary.txt) and this server role is $(cat db2-role.txt)"
        elif [[ "$(cat db2-databases-primary.txt)" == "$(cat db2-databases.txt)" ]]; then
            echo "PRIMARY" > db2-role.txt
            cat ${HADRROLES} | awk '{print $5}' | awk -F. '{print $1}' | head -1 > db2-standby.txt
            cat ${HADRROLES} | awk '{print $3}' | awk -F. '{print $1}' | head -1 > db2-hadrstate.txt
            cat ${HADRROLES} | awk '{print $7}' | awk -F. '{print $1}' | head -1 > db2-standby2.txt
            cat ${HADRROLES} | awk '{print $8}' | awk -F. '{print $1}' | head -1 > db2-standby3.txt
            log "Target server is $(cat db2-standby.txt) and this server role is $(cat db2-role.txt)"
        else
            log "ERROR: It looks like HADR role(primary/standby) not same for all dbs on this server ${HNAME}, Please check!"
            cat ${HADRROLES} >> ${LOGFILE}
            exit 12
        fi
        log "This server - ${HNAME} role is $(cat db2-role.txt) and hadr state is $(cat db2-hadrstate.txt)"
    fi
chmod -f 755 *.txt

    log "Deleting to-do files if any"
    if [[ $(ls ${STEPSDIR}/STAGE*DB2STEP*.${HNAME}.* | wc -l) -gt 0 ]]; then
      rm -f $(ls ${STEPSDIR}/STAGE*DB2STEP*.${HNAME}.*)
    fi

    log "Creating to-do files"

## This block will run for client db servers.
if [[ "$(cat db2-role.txt)" == "CLIENT" ]]; then
  echo "\"${SCRIPTSDIR}/runasdb2.sh\" prepatch.sh" > ${STEPSDIR}/STAGE01.DB2STEP01.${HNAME}.PREPATCH-DB2.TODO
  echo "sudo \"${SCRIPTSDIR}/patchdb2.sh\"" > ${STEPSDIR}/STAGE01.DB2STEP03.${HNAME}.PATCH-DB2.TODO
  echo "\"${SCRIPTSDIR}/runasdb2.sh\" postpatch.sh" > ${STEPSDIR}/STAGE01.DB2STEP05.${HNAME}.POSTPATCH-DB2.TODO

## This block will run for Stand-Alone db servers.
elif [[ "$(cat db2-role.txt)" == "STANDARD" ]]; then

  echo "\"${SCRIPTSDIR}/runasdb2.sh\" prepatch.sh" > ${STEPSDIR}/STAGE01.DB2STEP01.${HNAME}.PREPATCH-DB2.TODO
  echo "\"${SCRIPTSDIR}/runasdb2.sh\" stop_db2.sh" > ${STEPSDIR}/STAGE01.DB2STEP02.${HNAME}.STOP-DB2.TODO
  echo "sudo \"${SCRIPTSDIR}/patchdb2.sh\"" > ${STEPSDIR}/STAGE01.DB2STEP03.${HNAME}.PATCH-DB2.TODO
  echo "\"${SCRIPTSDIR}/runasdb2.sh\" start_db2.sh" > ${STEPSDIR}/STAGE01.DB2STEP04.${HNAME}.START-DB2.TODO
  echo "\"${SCRIPTSDIR}/runasdb2.sh\" postpatch.sh" > ${STEPSDIR}/STAGE01.DB2STEP05.${HNAME}.POSTPATCH-DB2.TODO

## This block will run for Primary db servers.
elif [[ "$(cat db2-role.txt)" == "PRIMARY" && "$(cat db2-hadrstate.txt)" == "PEER" ]]; then

  echo "\"${SCRIPTSDIR}/runasdb2.sh\" prepatch.sh" > ${STEPSDIR}/STAGE02.DB2STEP01.${HNAME}.PREPATCH-DB2.TODO
  echo "\"${SCRIPTSDIR}/runasdb2.sh\" stop_db2.sh" > ${STEPSDIR}/STAGE02.DB2STEP02.${HNAME}.STOP-DB2.TODO
  echo "sudo \"${SCRIPTSDIR}/patchdb2.sh\"" > ${STEPSDIR}/STAGE02.DB2STEP03.${HNAME}.PATCH-DB2.TODO
  echo "\"${SCRIPTSDIR}/runasdb2.sh\" start_db2.sh" > ${STEPSDIR}/STAGE02.DB2STEP04.${HNAME}.START-DB2.TODO
  echo "\"${SCRIPTSDIR}/runasdb2.sh\" postpatch.sh" > ${STEPSDIR}/STAGE02.DB2STEP05.${HNAME}.POSTPATCH-DB2.TODO

## This block will run for Principal Standby servers.
elif [[ "$(cat db2-role.txt)" == "STANDBY" && "$(cat db2-hadrstate.txt)" == "PEER" ]]; then

  echo "\"${SCRIPTSDIR}/runasdb2.sh\" prepatch.sh" > ${STEPSDIR}/STAGE01.DB2STEP01.${HNAME}.PREPATCH-DB2.TODO
  echo "\"${SCRIPTSDIR}/runasdb2.sh\" stop_db2.sh" > ${STEPSDIR}/STAGE01.DB2STEP02.${HNAME}.STOP-DB2.TODO
  echo "sudo \"${SCRIPTSDIR}/patchdb2.sh\"" > ${STEPSDIR}/STAGE01.DB2STEP03.${HNAME}.PATCH-DB2.TODO
  echo "\"${SCRIPTSDIR}/runasdb2.sh\" start_db2.sh" > ${STEPSDIR}/STAGE01.DB2STEP04.${HNAME}.START-DB2.TODO
  echo "\"${SCRIPTSDIR}/runasdb2.sh\" postpatch.sh" > ${STEPSDIR}/STAGE01.DB2STEP05.${HNAME}.POSTPATCH-DB2.TODO
  echo "\"${SCRIPTSDIR}/runasdb2.sh\" failover.sh" > ${STEPSDIR}/STAGE01.DB2STEP06.${HNAME}.FAILOVER-DB2.TODO

## This block will run for Auxilary Standby(DR) servers.
elif [[ "$(cat db2-role.txt)" == "STANDBY" && "$(cat db2-hadrstate.txt)" == "REMOTE_CATCHUP" ]]; then

  echo "\"${SCRIPTSDIR}/runasdb2.sh\" prepatch.sh" > ${STEPSDIR}/STAGE01.DB2STEP01.${HNAME}.PREPATCH-DB2.TODO
  echo "\"${SCRIPTSDIR}/runasdb2.sh\" stop_db2.sh" > ${STEPSDIR}/STAGE01.DB2STEP02.${HNAME}.STOP-DB2.TODO
  echo "sudo \"${SCRIPTSDIR}/patchdb2.sh\"" > ${STEPSDIR}/STAGE01.DB2STEP03.${HNAME}.PATCH-DB2.TODO
  echo "\"${SCRIPTSDIR}/runasdb2.sh\" start_db2.sh" > ${STEPSDIR}/STAGE01.DB2STEP04.${HNAME}.START-DB2.TODO
  echo "\"${SCRIPTSDIR}/runasdb2.sh\" postpatch.sh" > ${STEPSDIR}/STAGE01.DB2STEP05.${HNAME}.POSTPATCH-DB2.TODO

## This block will run for Primay with DR server (SYNCMODE should be SUPERASYNC)
elif [[ "$(cat db2-role.txt)" == "PRIMARY" && "$(cat db2-hadrstate.txt)" == "REMOTE_CATCHUP" ]]; then

  echo "\"${SCRIPTSDIR}/runasdb2.sh\" prepatch.sh" > ${STEPSDIR}/STAGE02.DB2STEP01.${HNAME}.PREPATCH-DB2.TODO
  echo "\"${SCRIPTSDIR}/runasdb2.sh\" stop_db2.sh" > ${STEPSDIR}/STAGE02.DB2STEP02.${HNAME}.STOP-DB2.TODO
  echo "sudo \"${SCRIPTSDIR}/patchdb2.sh\"" > ${STEPSDIR}/STAGE02.DB2STEP03.${HNAME}.PATCH-DB2.TODO
  echo "\"${SCRIPTSDIR}/runasdb2.sh\" start_db2.sh" > ${STEPSDIR}/STAGE02.DB2STEP04.${HNAME}.START-DB2.TODO
  echo "\"${SCRIPTSDIR}/runasdb2.sh\" postpatch.sh" > ${STEPSDIR}/STAGE02.DB2STEP05.${HNAME}.POSTPATCH-DB2.TODO

fi
    log "TODOs: $(cd ${STEPSDIR} && ls STAGE*DB2STEP*.${HNAME}.*)"

    touch ${TGTDIR}/db2patch.running
    chmod 666 ${TGTDIR}/db2patch.running

    log "Adjusting file permissions"
    chmod 777 ${LOGDIR}/*.log
    chmod 755 ${STEPSDIR}/STAGE*DB2STEP*.${HNAME}.*
log "END - ${SCRIPTNAME} execution ended at $(date)"