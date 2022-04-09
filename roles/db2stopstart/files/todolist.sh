#!/bin/bash
# Script Name: todolist.sh
# Description: This script will create sequence of steps to run on each node.
# Arguments: NA
# Date: Feb 14, 2022
# Written by: Naveen Chintada

SCRIPTNAME=todolist.sh
#DB2INST=$1

## Calling comman functions and variables.
    . /tmp/include_db2

log_roll ${LOGFILE}
log_roll ${MAINLOG}
log "START - ${SCRIPTNAME} execution started at $(date)"

if [[ ! -f ${STEPSDIR}/STAGE01.DB2STEP01.${HNAME} ]]; then touch ${STEPSDIR}/STAGE01.DB2STEP01.${HNAME}; fi
    log "Deleting to-do files if any"
    if [[ $(ls ${STEPSDIR}/STAGE*DB2STEP*.${HNAME}* | wc -l) -gt 0 ]]; then
      rm -f $(ls ${STEPSDIR}/STAGE*DB2STEP*.${HNAME}*)
    fi
    log "Creating to-do files"

cat /tmp/db2ilist.lst | while read DB2INST
do
## This block will run for Stand-Alone db servers.
if [[ "$(cat /tmp/db2-role_${DB2INST}.txt)" == "STANDARD" ]]; then

  if [[ "$(cat /tmp/dbaction.txt | tr A-Z a-z)" == "stop" ]]; then
    echo "\"${SCRIPTSDIR}/runasdb2.sh\" stop_db2.sh ${DB2INST}" > ${STEPSDIR}/STAGE01.DB2STEP01.${HNAME}_${DB2INST}_STOP-DB2.TODO
  elif [[ "$(cat /tmp/dbaction.txt | tr A-Z a-z)" == "start" ]]; then
    echo "\"${SCRIPTSDIR}/runasdb2.sh\" start_db2.sh ${DB2INST}" > ${STEPSDIR}/STAGE01.DB2STEP01.${HNAME}_${DB2INST}_START-DB2.TODO
  fi

## This block will run for Primary db servers.
elif [[ "$(cat /tmp/db2-role_${DB2INST}.txt)" == "PRIMARY" && "$(cat /tmp/db2-hadrstate_${DB2INST}.txt)" == "PEER" ]]; then

  if [[ "$(cat /tmp/dbaction.txt | tr A-Z a-z)" == "stop" && "$(cat /tmp/actionon.txt | tr A-Z a-z)" == "primary" ]]; then
    echo "\"${SCRIPTSDIR}/runasdb2.sh\" stop_db2.sh ${DB2INST}" > ${STEPSDIR}/STAGE02.DB2STEP02.${HNAME}_${DB2INST}_STOP-DB2.TODO
  elif [[ "$(cat /tmp/dbaction.txt | tr A-Z a-z)" == "start" && "$(cat /tmp/actionon.txt | tr A-Z a-z)" == "primary" ]]; then
    echo "\"${SCRIPTSDIR}/runasdb2.sh\" start_db2.sh ${DB2INST}" > ${STEPSDIR}/STAGE02.DB2STEP01.${HNAME}_${DB2INST}_START-DB2.TODO
  fi

## This block will run for Principal Standby servers.
elif [[ "$(cat /tmp/db2-role_${DB2INST}.txt)" == "STANDBY" && "$(cat /tmp/db2-hadrstate_${DB2INST}.txt)" == "PEER" ]]; then
  
  if [[ "$(cat /tmp/dbaction.txt | tr A-Z a-z)" == "stop" && "$(cat /tmp/actionon.txt | tr A-Z a-z)" == "primary" ]]; then
    echo "\"${SCRIPTSDIR}/runasdb2.sh\" failover.sh ${DB2INST}" > ${STEPSDIR}/STAGE01.DB2STEP01.${HNAME}_${DB2INST}_FAILOVER-DB2.TODO
  elif [[ "$(cat /tmp/dbaction.txt | tr A-Z a-z)" == "stop" && "$(cat /tmp/actionon.txt | tr A-Z a-z)" == "standby" ]]; then
    echo "\"${SCRIPTSDIR}/runasdb2.sh\" stop_db2.sh ${DB2INST}" > ${STEPSDIR}/STAGE01.DB2STEP01.${HNAME}_${DB2INST}_STOP-DB2.TODO
  elif [[ "$(cat /tmp/dbaction.txt | tr A-Z a-z)" == "start" && "$(cat /tmp/actionon.txt | tr A-Z a-z)" == "standby" ]]; then
    echo "\"${SCRIPTSDIR}/runasdb2.sh\" start_db2.sh ${DB2INST}" > ${STEPSDIR}/STAGE01.DB2STEP01.${HNAME}_${DB2INST}_START-DB2.TODO
  fi
  
## This block will run for Auxilary Standby(DR) servers.
elif [[ "$(cat cat /tmp/db2-role_${DB2INST}.txt)" == "STANDBY" && "$(cat /tmp/db2-hadrstate_${DB2INST}.txt)" == "REMOTE_CATCHUP" ]]; then

  if [[ "$(cat /tmp/dbaction.txt | tr A-Z a-z)" == "stop" ]]; then
    echo "\"${SCRIPTSDIR}/runasdb2.sh\" stop_db2.sh ${DB2INST}" > ${STEPSDIR}/STAGE01.DB2STEP01.${HNAME}_${DB2INST}_STOP-DB2.TODO
  elif [[ "$(cat /tmp/dbaction.txt | tr A-Z a-z)" == "start" ]]; then
    echo "\"${SCRIPTSDIR}/runasdb2.sh\" start_db2.sh ${DB2INST}" > ${STEPSDIR}/STAGE01.DB2STEP01.${HNAME}_${DB2INST}_START-DB2.TODO
  fi

## This block will run for Primay with DR server (SYNCMODE should be SUPERASYNC)
elif [[ "$(cat /tmp/db2-role_${DB2INST}.txt)" == "PRIMARY" && "$(cat /tmp/db2-hadrstate_${DB2INST}.txt)" == "REMOTE_CATCHUP" ]]; then

  if [[ "$(cat /tmp/dbaction.txt | tr A-Z a-z)" == "stop" ]]; then
    echo "\"${SCRIPTSDIR}/runasdb2.sh\" stop_db2.sh ${DB2INST}" > ${STEPSDIR}/STAGE01.DB2STEP01.${HNAME}_${DB2INST}_STOP-DB2.TODO
  elif [[ "$(cat /tmp/dbaction.txt | tr A-Z a-z)" == "start" ]]; then
    echo "\"${SCRIPTSDIR}/runasdb2.sh\" start_db2.sh ${DB2INST}" > ${STEPSDIR}/STAGE01.DB2STEP01.${HNAME}_${DB2INST}_START-DB2.TODO
  fi

fi
done
    log "TODOs: $(cd ${STEPSDIR} && ls STAGE*DB2STEP*.${HNAME}_${DB2INST}_*)"

    touch ${TGTDIR}/db2.running
    chmod 666 ${TGTDIR}/db2.running

    log "Adjusting file permissions"
    chmod 777 ${LOGDIR}/*.log
    chmod 755 ${STEPSDIR}/STAGE*DB2STEP*.${HNAME}_${DB2INST}_*
log "END - ${SCRIPTNAME} execution ended at $(date)"