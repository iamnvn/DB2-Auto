#!/bin/bash
# Script Name: get-backup_his.sh
# Description: This script will list out all available backup images for database.
# Arguments: DB2INST (Run as Instance)
# Written by: Naveen Chintada

SCRIPTNAME=get-backup_his.sh
HNAME=$(hostname -s)
HVERSION=$(uname -s)
DB2INST=$(whoami)
LOGSDIR=/tmp

function profile_db2 {
    #Source db2profile
    if [[ -f $HOME/sqllib/db2profile ]]; then
        . $HOME/sqllib/db2profile
    fi
}

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

function dirsetup {
    if [[ ! -d ${LOGSDIR} ]]; then mkdir -m 777 -p ${LOGSDIR}; fi
    if [[ ! -d ${LOGSDIR}/temp ]]; then mkdir -m 777 -p ${LOGSDIR}/temp; fi
}
function log_roll {
    FILENAME=$1
    if [[ -f ${FILENAME} ]]; then
        mv -f ${FILENAME} ${FILENAME}_old.txt
        touch ${FILENAME}; chmod -f 777 ${FILENAME}
    else
        touch ${FILENAME}; chmod -f 777 ${FILENAME}
    fi
}
function cleanup {
    log_roll ${LOGSDIR}/temp/listutl.txt
    log_roll ${LOGSDIR}/daily_report.all
    log_roll ${LOGSDIR}/temp/daily_report.err
    log_roll ${LOGSDIR}/temp/daily_report.action
    log_roll ${LOGSDIR}/temp/daily_report.inprgrs
    log_roll ${LOGSDIR}/temp/daily_report_${DB2INST}.bkps
    log_roll ${LOGSDIR}/temp/daily_report.standby
}

function get_bkp_inprogress {
    db2 list utilities | grep -A6 ID > ${LOGSDIR}/temp/${DB2INST}_listutl.txt
    if [[ $(grep -c 'BACKUP' ${LOGSDIR}/temp/listutl.txt) -gt 0 ]]; then
        cat ${LOGSDIR}/temp/listutl.txt | grep -i "Database Name" | cut -d "=" -f2 | awk '{print $1}' | while read DBNAME
        do
        BKPSTARTTIME=$(cat ${LOGSDIR}/temp/listutl.txt | grep -A3 ${DBNAME} | grep -i "Start Time" | cut -d "=" -f2 | awk '{print $1}')
        echo "${HNAME}_${DB2INST}_${DBNAME} - Backup InProgress - StartTime: ${BKPSTARTTIME}" >> ${LOGSDIR}/temp/daily_report.inprgrs
        done
    fi
}

function get_backup_his {
    db2 -xtf bkp_his_db2.sql
}

function run_report {
    while read DBNAME
    do
        echo "Database Name: ${DBNAME}"
        echo "------------------------"
        DBROLE=$(db2 get db cfg for ${DBNAME} | grep -i "HADR database role" | cut -d "=" -f2 | awk '{print $1}')
        if [[ "${DBROLE}" == "PRIMARY" || "${DBROLE}" == "STANDARD" ]]; then
            db2 "connect to ${DBNAME}" > /dev/null
            RC=$?
            if [[ ${RC} -eq 0 ]]; then
                echo "Get Backups In Progress"
                get_bkp_inprogress

                echo "Run Backup Report"
                get_backup_his >> ${LOGSDIR}/temp/daily_report_${DB2INST}.bkps                      
            else
                echo "${HNAME}_${DB2INST}_${DBNAME} - ERROR: Unable to Connect" >> ${LOGSDIR}/temp/daily_report.err
            fi
        else
            echo "${HNAME}_${DB2INST}_${DBNAME} - Standby - No Backup Needed" >> ${LOGSDIR}/temp/daily_report.standby
        fi
    done < /tmp/${DB2INST}.db.lst
}

function validate_report {
    echo "Checking Failed backups"
    if [[ $(grep -c 'Failure' ${LOGSDIR}/temp/daily_report_${DB2INST}.bkps) -gt 0 ]];  
}


DBNAME=$1
BCAKUPTPE=$(echo $2 | tr A-Z a-z)

cleanup
profile_db2

if [[ ! -z ${DBNAME} && "${DBNAME}" != "all" ]]; then
    echo "${DBNAME}" > /tmp/${DB2INST}.db.lst
else
    list_dbs
fi

run_report
