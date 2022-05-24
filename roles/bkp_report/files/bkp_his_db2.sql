select CURRENT SERVER, rtrim(char(TIMESTAMPDIFF(8,char(timestamp(end_time ) - timestamp(start_time))))) || ':'||
rtrim(char(mod(int(TIMESTAMPDIFF(4,char(timestamp( end_time) - timestamp(start_time)))),60))) as "Elapsed Time (hh:mm)",
case(operationType) when 'F' then 'Full_Offline' when 'N' then 'Full_Online' when 'I' then 'Incr_Offline' when 'O' then 'Incr_Online' when 'D' then 'Delt_Offline'
when 'E' then 'Delt Online' else '?' end as Type , start_time as "Start Time", end_time as "End Time",
case(sqlcaid) when 'SQLCA' then 'Failure' else 'Success' end as "Status", sqlcode as "SQL Code" from table(admin_list_hist()) where operation = 'B' and END_TIME > (CURRENT_TIMESTAMP - 7 DAYS)
ORDER BY END_TIME DESC FETCH FIRST 7 ROWS ONLY WITH UR;