#!/bin/bash
# Script Name: failover.sh
# Description: This script will takeover databases to principal standby server.
# Arguments: DB2INST (Run as Instance)
# Date: Apr 14, 2022
# Written by: Naveen Chintada

SCRIPTNAME=failover.sh
LOGDIR=/tmp
DB2INST=$1
LOGFILE=${LOGDIR}/${DB2INST}_${SCRIPTNAME}.log
HVERSION=$(uname -s)
HNAME=$(hostname -s)

if [[ -z ${DB2INST} ]]; then
    DB2INST=$(whoami)
fi

## Comman functions
function log {
    echo "" | tee -a ${LOGFILE}
    echo "@ $(date +"%Y-%m-%d %H:%M:%S") - "$1 | tee -a ${LOGFILE}
}

function db2profile {
    #Get the $HOME of the Db2 LUW Instance and Run db2profile
    if [[ "${HVERSION}" == "AIX" ]]; then
	    INSTHOME=$(lsuser -f ${DB2INST} | grep home | sed "s/^......//g")
    elif [[ "${HVERSION}" == "Linux" ]]; then
	    INSTHOME=$(echo  $(cat /etc/passwd | grep ${DB2INST}) | cut -d: -f6)
    fi
    if [[ -f ${INSTHOME}/sqllib/db2profile ]]; then
        . ${INSTHOME}/sqllib/db2profile
    fi
}

find ${LOGDIR}/* -name "${LOGFILE}*" -type f -mtime +15 -exec rm -f {} \;

function list_dbs {

	if [[ -f /tmp/${DB2INST}.db.lst ]]; then
		rm -rf /tmp/${DB2INST}.db.lst
	fi

    if [[ "${HVERSION}" == "AIX" ]]; then
        db2 list db directory | grep -ip indirect | grep -i "database name" | awk '{print $4}' | sort -u > /tmp/${DB2INST}.db.lst
    elif [[ "${HVERSION}" == "Linux" ]]; then
        db2 list db directory | grep -B6 -i indirect | grep -i "database name" | awk '{print $4}' | sort -u > /tmp/${DB2INST}.db.lst
    fi

    chmod 666 /tmp/${DB2INST}.db.lst
}

function db_hadr {
		DBROLE=$(db2pd -db ${DBNAME} -hadr | grep HADR_ROLE | awk '{print $3}' | head -1)
		DBHADRSTATE=$(db2pd -db ${DBNAME} -hadr | grep HADR_STATE | awk '{print $3}' | head -1)
		DBHADRCONNSTATUS=$(db2pd -db ${DBNAME} -hadr | grep HADR_CONNECT_STATUS  | awk '{print $3}' | head -1)
}

function takeoverdb {
  while read DBNAME
  do
    db_hadr
    if [[ "${DBROLE}" == "STANDBY"  && "${DBHADRSTATE}" == "PEER" && "${DBHADRCONNSTATUS}" == "CONNECTED"  ]]; then
      log "Attempting TAKEOVER HADR on ${DBNAME} in ${HNAME}:${DBINST}"
      db2 -v "TAKEOVER HADR ON DB ${DBNAME}" >> ${LOGFILE}
      RCD=$?
      if [[ ${RCD} -eq 0 || ${RCD} -eq 4 ]]; then
        log "TAKEOVER HADR on ${DBNAME} in ${HNAME} Completed successfully"
      else
        log "ERROR: Failed to TAKEOVER HADR on ${DBNAME} in ${HNAME}, Please check log ${LOGFILE}"
        exit 12
      fi
    else
      log "Database - ${DBNAME} Already Primary or Standard in ${HNAME}, Instance - ${DB2INST}"
    fi
  done < /tmp/${DB2INST}.db.lst
}

log "START - ${SCRIPTNAME} execution started for Instance - ${DB2INST} at $(date)"

  db2profile
  list_dbs
  takeoverdb
  sleep 30

log "END - ${SCRIPTNAME} execution ended for Instance - ${DB2INST} at $(date)"