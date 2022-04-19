#!/bin/bash
# Script Name: prepatch.sh
# Description: This script collects Db2 instance and database level information prior to patching.
# Arguments: DB2INST (Run as instance id)
# Date: Apr 13, 2022
# Written by: Naveen Chintada

SCRIPTNAME=prepatch.sh

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
        db2 get dbm cfg > ${BACKUPSDIR}/dbm_cfg_bef_${DB2INST}.out
        cp -R $HOME/sqllib/function ${BACKUPSDIR}/routine_backup_${DB2INST}
        db2set -all > ${BACKUPSDIR}/db2set_bef_${DB2INST}.out
        set | grep DB2 > ${BACKUPSDIR}/set_env_bef_${DB2INST}.out
        db2licm -l > ${BACKUPSDIR}/db2licm_bef_${DB2INST}.out
        db2level > ${BACKUPSDIR}/db2level_bef_${DB2INST}.out
        db2 list db directory > ${BACKUPSDIR}/listdb_bef_${DB2INST}.out
        db2 list node directory > ${BACKUPSDIR}/listnode_bef_${DB2INST}.out
else

    log "Collect existing db2 server configuration and diagnostic information to - ${BACKUPSDIR}"

    db2 attach to ${DB2INST} >> ${LOGFILE}
    RCD=$?
    if [[ ${RCD} -ne 0 ]]; then
	    db2start > /dev/null
	    db2 attach to ${DB2INST} >> ${LOGFILE}
	    RC1=$?
	    if [[ ${RC1} -ne 0 ]]; then
		    log "ERROR: Unable to attach Instance: ${DB2INST}, Exiting with ${RC1}"
	    	exit ${RC1};
	    fi
    fi

        db2 get dbm cfg show detail > ${BACKUPSDIR}/dbm_cfg_bef_${DB2INST}.out
        cp -R $HOME/sqllib/function ${BACKUPSDIR}/routine_backup_${DB2INST}
        db2set -all > ${BACKUPSDIR}/db2set_bef_${DB2INST}.out
        set | grep DB2 > ${BACKUPSDIR}/set_env_bef_${DB2INST}.out
        db2licm -l > ${BACKUPSDIR}/db2licm_bef_${DB2INST}.out
        db2level > ${BACKUPSDIR}/db2level_bef_${DB2INST}.out
        db2 list db directory > ${BACKUPSDIR}/listdb_bef_${DB2INST}.out
        db2 list node directory > ${BACKUPSDIR}/listnode_bef_${DB2INST}.out

    if [[ "$(cat db2-role.txt)" == "PRIMARY" || "$(cat db2-role.txt)" == "STANDARD"  ]]; then
        log "Collecting database level information"
        #log "db2support running for all databases"
        #db2support . -alldbs -s -c -H 14d -o ${BACKUPSDIR}/${HNAME}_db2support.zip

        while read DBNAME
        do
		    db2 -ec +o CONNECT TO ${DBNAME}
		    db2 LIST PACKAGES FOR ALL SHOW DETAIL > ${BACKUPSDIR}/list_pkg_${DBNAME}_${DB2INST}.out
		    db2 GET DB CFG FOR ${DBNAME} SHOW DETAIL > ${BACKUPSDIR}/db_cfg_${DBNAME}_${DB2INST}.out
		    db2look -d ${DBNAME} -e -a -l -x -o ${BACKUPSDIR}/db2look_${DBNAME}.out

		    #log "Backup running on ${DBNAME}"
		    #backupdb ${DBNAME}
        done < /tmp/${DB2INST}.db.lst
    fi
fi
log "END - ${SCRIPTNAME} execution ended at $(date)"