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

#Source db2profile
    if [[ -f $HOME/sqllib/db2profile ]]; then
        . $HOME/sqllib/db2profile
    fi

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
    if [[ -f ${LOGSDIR}/${FILENAME} ]]; then
        mv -f ${LOGSDIR}/${FILENAME} ${LOGSDIR}/${FILENAME}_old.txt
        touch ${LOGSDIR}/${FILENAME}; chmod 755 ${LOGSDIR}/${FILENAME}
    else
        touch ${LOGSDIR}/${FILENAME}; chmod 755 ${LOGSDIR}/${FILENAME}
    fi
}
function cleanup {
    log_roll temp/listutl.txt
    log_roll daily_report.all
    log_roll temp/daily_report.err
    log_roll temp/daily_report.action
}

function get_bkp_inprogress {
    db2 list utilities | grep -A6 ID > ${LOGSDIR}/temp/listutl.txt
    if [[ -s ${LOGSDIR}/temp/listutl.txt ]]

    db2 "Select CURRENT SERVER , rtrim(char(TIMESTAMPDIFF(8,char(timestamp(end_time ) - timestamp(start_time))))) || ':'|| rtrim(char(mod(int(TIMESTAMPDIFF(4,char(timestamp( end_time) - timestamp(start_time)))),60))) as "Elapsed Time (hh:mm)", substr(firstlog,1,13) as "Start Log", substr(lastlog,1,13) as "End Log", num_tbsps as "Number Tbspcs" , case(operationType) when 'F' then 'Full.Offline' when 'N' then 'Full.Online' when 'I' then 'Incr.Offline' when 'O' then 'Incr.Online' when 'D' then 'Delt.Offline' when 'E' then 'Delt.Online' else '?' end as Type , start_time as "Start Time", end_time as "End Time", location as "Location", case(sqlcaid) when 'SQLCA' then 'Failure' else 'Success' end as "Status", sqlcode as "SQL Code" from table(admin_list_hist()) as lh where operation = 'B'";

Select CURRENT SERVER, rtrim(char(TIMESTAMPDIFF(8,char(timestamp(end_time ) - timestamp(start_time))))) || ':'||
rtrim(char(mod(int(TIMESTAMPDIFF(4,char(timestamp( end_time) - timestamp(start_time)))),60))) as "Elapsed Time (hh:mm)",
case(operationType) when 'F' then 'Full Offline' when 'N' then 'Full_Online' when 'I' then 'Incr_Offline' when 'O' then 'Incr_Online' when 'D' then 'Delt_Offline'
when 'E' then 'Delt Online' else '?' end as Type , start_time as "Start Time", end_time as "End Time",
case(sqlcaid) when 'SQLCA' then 'Failure' else 'Success' end as "Status", sqlcode as "SQL Code" from table(admin_list_hist()) where operation = 'B';

}

function get_backup_his {
    BCAKUPTPE=$1
    NOOFDAYS=$2
    if [[ "${BCAKUPTPE}" == "full" || "${BCAKUPTPE}" == "f" ]]; then
        db2 "SELECT CURRENT SERVER AS DBNAME,
            CASE DBH.OPERATIONTYPE
                WHEN 'D' THEN 'DELTA OFFLINE'
                WHEN 'E' THEN 'DELTA ONLINE'
                WHEN 'F' THEN 'OFFLINE FULL'
                WHEN 'I' THEN 'INCREMENTAL OFFLINE'
                WHEN 'N' THEN 'ONLINE FULL'
                WHEN 'O' THEN 'INCREMENTAL ONLINE'
            END AS BACKUP_TYPE,
            DBH.START_TIME,
            DBH.END_TIME,
            COALESCE ('Completed' ,DBH.SQLSTATE) STATUS,
            TIMESTAMPDIFF (4,CHAR(TIMESTAMP(END_TIME) - TIMESTAMP(START_TIME))) AS BACKUP_EXEC_TIME_MIN
            FROM SYSIBMADM.DB_HISTORY DBH
            WHERE DBH.OPERATION='B' AND DBH.OPERATIONTYPE in ('N','F') AND
            DBH.END_TIME > (CURRENT_TIMESTAMP - ${NOOFDAYS} DAYS)
            ORDER BY DBH.END_TIME DESC
            FETCH FIRST 7 ROWS ONLY WITH UR"
    

    elif [[ "${BCAKUPTPE}" == "incremental" || "${BCAKUPTPE}" == "i" ]]; then
        
        db2 "SELECT CURRENT SERVER AS DBNAME,
            CASE DBH.OPERATIONTYPE
                WHEN 'D' THEN 'DELTA OFFLINE'
                WHEN 'E' THEN 'DELTA ONLINE'
                WHEN 'F' THEN 'OFFLINE FULL'
                WHEN 'I' THEN 'INCREMENTAL OFFLINE'
                WHEN 'N' THEN 'ONLINE FULL'
                WHEN 'O' THEN 'INCREMENTAL ONLINE'
            END AS BACKUP_TYPE,
            DBH.START_TIME,
            DBH.END_TIME,
            COALESCE ('Completed' ,DBH.SQLSTATE) STATUS,
            TIMESTAMPDIFF (4,CHAR(TIMESTAMP(END_TIME) - TIMESTAMP(START_TIME))) AS BACKUP_EXEC_TIME_MIN
            FROM SYSIBMADM.DB_HISTORY DBH
            WHERE DBH.OPERATION='B' AND DBH.OPERATIONTYPE not in ('N','F') AND
            DBH.END_TIME > (CURRENT_TIMESTAMP - ${NOOFDAYS} DAYS)
            ORDER BY DBH.END_TIME DESC
            FETCH FIRST 7 ROWS ONLY WITH UR"

    elif [[ "${BCAKUPTPE}" == "all" || -z "${BCAKUPTPE}" ]]; then
        db2 "SELECT CURRENT SERVER AS DBNAME,
        CASE DBH.OPERATIONTYPE
            WHEN 'D' THEN 'DELTA OFFLINE'
            WHEN 'E' THEN 'DELTA ONLINE'
            WHEN 'F' THEN 'OFFLINE FULL'
            WHEN 'I' THEN 'INCREMENTAL OFFLINE'
            WHEN 'N' THEN 'ONLINE FULL'
            WHEN 'O' THEN 'INCREMENTAL ONLINE'
        END AS BACKUP_TYPE,
        DBH.START_TIME,
        DBH.END_TIME,
        COALESCE ('Completed' ,DBH.SQLSTATE) STATUS,
        TIMESTAMPDIFF (4,CHAR(TIMESTAMP(END_TIME) - TIMESTAMP(START_TIME))) AS BACKUP_EXEC_TIME_MIN
        FROM SYSIBMADM.DB_HISTORY DBH
        WHERE DBH.OPERATION='B' AND
        DBH.END_TIME > (CURRENT_TIMESTAMP - ${NOOFDAYS} DAYS)
        ORDER BY DBH.END_TIME DESC
        FETCH FIRST 7 ROWS ONLY WITH UR"

    elif [[ "${BCAKUPTPE}" == "failed" ]]; then
        db2 "SELECT CURRENT SERVER AS DBNAME,
        CASE DBH.OPERATIONTYPE
            WHEN 'D' THEN 'DELTA OFFLINE'
            WHEN 'E' THEN 'DELTA ONLINE'
            WHEN 'F' THEN 'OFFLINE FULL'
            WHEN 'I' THEN 'INCREMENTAL OFFLINE'
            WHEN 'N' THEN 'ONLINE FULL'
            WHEN 'O' THEN 'INCREMENTAL ONLINE'
        END AS BACKUP_TYPE,
        DBH.START_TIME,
        DBH.END_TIME,
        DBH.SQLCODE,
        COALESCE ('Failed' ,DBH.SQLSTATE) STATUS,
        TIMESTAMPDIFF (4,CHAR(TIMESTAMP(END_TIME) - TIMESTAMP(START_TIME))) AS BACKUP_EXEC_TIME_MIN
        FROM SYSIBMADM.DB_HISTORY DBH
        WHERE DBH.OPERATION='B' AND
        DBH.START_TIME > (CURRENT_TIMESTAMP - ${NOOFDAYS} DAYS) AND
        DBH.SQLCODE is NOT NULL
        ORDER BY DBH.END_TIME DESC
        FETCH FIRST 7 ROWS ONLY WITH UR"
    fi
}


DBNAME=$1
BCAKUPTPE=$(echo $2 | tr A-Z a-z)

if [[ ! -z ${DBNAME} && "${DBNAME}" != "all" ]]; then
    echo "${DBNAME}" > /tmp/${DB2INST}.db.lst
else
    list_dbs
fi

while read DBNAME
do

    echo "Database Name: ${DBNAME}"
    echo "------------------------"
    DBROLE=$(db2 get db cfg for ${DBNAME} | grep -i "HADR database role" | cut -d "=" -f2 | awk '{print $1}')
    if [[ "${DBROLE}" == "PRIMARY" || "${DBROLE}" == "STANDARD" ]]; then
        db2 "connect to ${DBNAME}" > /dev/null
        RC=$?
        if [[ ${RC} -eq 0 ]]; then
            echo "Backups In Progres"
            get_bkp_inprogress

            echo "Failed Backups since last 7 Days"
            get_backup_his failed 7

            echo "Full Backups Since lAst 7 Days"
            get_backup_his f 7

            echo "Incremental Backups Since last 4 Days"
            get_backup_his i 4            
        else
            echo "ERROR: Unable to connect to database - ${DBNAME}"
            exit 2
        fi
    else
        echo "${DBNAME} - Standby"
    fi
done < /tmp/${DB2INST}.db.lst
#rm -rf /tmp/${DB2INST}.db.lst