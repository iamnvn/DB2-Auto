$BASE='/igs_swdepot/igs/MidrangeDBAServices/DB2/db2info';
open(ERR,'>',"$BASE/reports/db2_daily_report.err");
open(ALLBKUPS, '>', "$BASE/reports/all.db2bkup");
open(ACTIONS,'>',"$BASE/reports/db2_daily_report.actions");

##
## Purge old temp files
##
while(<$BASE/servers/*.db2bkup>) {
  chomp;
  `rm -f $_`;
}
while(<$BASE/servers/*.utilities>) {
  chomp;
  `rm -f $_`;
}
while(<$BASE/servers/*.db2set.prev>) {
  chomp;
  `rm -f $_`;
}
while(<$BASE/servers/*.db2set>) {
  chomp;
  `mv $_ $_.prev`;
}
while(<$BASE/servers/*.dbdir.prev>) {
  chomp;
  `rm -f $_`;
}
while(<$BASE/servers/*.dbdir>) {
  chomp;
  `mv $_ $_.prev`;
}
##
while(<$BASE/servers/*.maxlog>) {
  chomp;
  `rm -f $_`;
}
while(<$BASE/servers/*.dbcfg.prev>) {
  chomp;
  `rm -f $_`;
}
while(<$BASE/servers/*.dbcfg>) {
  chomp;
  `mv $_ $_.prev`;
}
while(<$BASE/servers/*.dbmcfg.prev>) {
  chomp;
  `rm -f $_`;
}
while(<$BASE/servers/*.dbmcfg>) {
  chomp;
  `mv $_ $_.prev`;
}
while(<$BASE/servers/*.dbsize>) {
  chomp;
  `rm -f $_`;
}
while(<$BASE/servers/*.db2level>) {
  chomp;
  `rm -f $_`;
}
while(<$BASE/servers/*.global.reg.prev>) {
  chomp;
  `rm -f $_`;
}
while(<$BASE/servers/*.global.reg>) {
  chomp;
  `mv $_ $_.prev`;
}
##
##
## Rename prev DB2 files
##
while(<$BASE/reports/all.db2*.prev>) {
  chomp;
  `rm -f $_`;
}
while(<$BASE/reports/all.db2*>) {
  chomp;
  `mv $_ $_.prev`;
}
##
## Build DB2 Server Exclude List
##

%DB2SVREXCL;
open(E,"$BASE/config/db2.server.exclude");
while(<E>) {
  chomp;
  $DB2SVREXCL{$_}=1;
}
close(E);

foreach $server (keys %DB2SVREXCL) {
  print "Excluding Server $server\n";
  print ERR "Excluding Server: $server\n";
}

##
## Build Active DB2 Server List
##

%DB2SVRS;
open(C,"$BASE/config/db2.servers");
while(<C>) {
  chomp;
  $DB2SVRS{$_}=1;
}
close(C);

foreach $server (keys %DB2SVRS) {
  print "Active DB2 Server: $server\n";
}


%SOFTW;
%ACTIVE;
%ALLDBS;
%INACTIVE;
%CLIENT;
%DAS;
%LEVEL;
%LICM;
%DATE;
%SET;
#%LICMAUDIT;

foreach $server (keys %DB2SVRS) {
  print "testing $server\n";

  ##
  ## Get Global Registry for Information
  ##

  $res=`ssh -q $server ls -1 /opt/IBM/db2/V*/*/bin/db2greg | head -1`;
  if($res eq '') {
    print "V9 + GREG not found on $server, trying V8\n";
    $res=`ssh -q $server ls -1 /usr/opt/db2*/bin/db2greg | head -1`;
  }
  if($res eq '') {
    print "DB2 Global Registry not found for V8 or V9+ on $server\n";
    print ERR "Unable to find db2greg on server $server\n";
    print ACTIONS "db2_daily_report.pl cannot find db2greg on $server\n";
    print ACTIONS "investigate. check for issues. its possible DB2 has been retired or not planned for this server\n";
    print ACTIONS "if not needed, remove server from ftwaxdsep002:/igs_swdepot/igs/MidrangeDBAServices/DB2/db2info/config/db2.servers\n\n";
    next;
  } else {
    chomp($res);
    $DB2GREG=$res;
    print "DB2GREG for $server = $DB2GREG\n";
    `ssh -q $server "$DB2GREG -dump" > $BASE/servers/$server.global.reg`;
  }
  #$res=`scp get_db2_backup_info.sql $server:~/.`;
  open(F, "$BASE/servers/$server.global.reg");
  $sysc=`ssh -q $server "ps -ef | grep sysc | grep -v grep"`;
  if($sysc=~/db2sysc/) {
    ##
    ## If sysc process on server, push files for queries
    ##
    `scp $BASE/dev/get_db2_backup_info.sql $server:~/.`;
    `scp $BASE/dev/get_db2_max_logs.sql $server:~/.`;
    `scp $BASE/dev/get_db2_max_logs_v8v91.sql $server:~/.`;
  }
  while(<F>) {
    chomp;
    if(/^I/) {
      #print "Found Instance: $_\n";
      @TMP=split /,/,$_;
      $ver=@TMP[2];
      $inst=@TMP[3];
      $home=@TMP[4];
      $sw=@TMP[8];
      if($inst=~/db2das/) {
        $res2=`ssh -q $server "ps -ef | grep db2das | grep -v grep"`;
        $DAS{"$server_$inst"}="$ver:$home:$sw";
        $res3=`ssh -q $server 'export LIBPATH=.; . $home/dasprofile; db2daslevel'`;
        $LEVEL{"$server\_$inst"}=$res3;
        if($res2=~/db2das/) {
          print "DB2DAS is running\n";
        } else {
          print "DB2DAS is NOT running\n";
          #print ERR "DB2DAS NOT running on $server\n";
        }
      } elsif($inst=~/db2clnt/) {
        $CLIENT{"$server\_$inst"}="$ver:$home:$sw";
        $res3=`ssh -q $server 'export LIBPATH=.; . $home/db2profile; db2level'`;
        $LEVEL{"$server\_$inst"}=$res3;
      } else {
        if($sysc=~/$inst/) {
          print "Instance $inst is running\n";
          $ACTIVE{"$server\_$inst"}="$ver:$home:$sw";
          print "Checking for DBs on $inst\n";
          `ssh -q $server 'cat ~$inst/cron_sched' > $BASE/servers/temp.db2.cron_sched`;
          if(`wc -l $BASE/servers/temp.db2.cron_sched` > 0) {
            `mv $BASE/servers/temp.db2.cron_sched $BASE/servers/$server.$inst.cron_sched`;
          } else {
            print ERR "Cannot Access cron_sched for $server.$inst\n";
            print ACTIONS "logon to $server; sudo su - $inst; chmod g+r cron_sched\n";
            print ACTIONS "exit back to your ID and check with: cat ~$inst/cron_sched\n\n";
          }
          `ssh -q $server 'cat ~$inst/.profile' > $BASE/servers/temp.db2.profile`;
          if(`wc -l $BASE/servers/temp.db2.profile` > 0) {
            `mv $BASE/servers/temp.db2.profile $BASE/servers/$server.$inst.profile`;
          } else {
            print ERR "Unable to get .profile for $server.$inst\n";
            print ACTIONS "logon to $server; sudo su - $inst; chmod g+r .profile\n";
            print ACTIONS "exit back to your ID and check with: cat ~$inst/.profile\n\n";
          }
          `ssh -q $server 'export LIBPATH=.; . $home/db2profile; db2set' > $BASE/servers/temp.db2.db2set`;
          if( `wc -l $BASE/servers/temp.db2.db2set` > 0 ) {
            `mv $BASE/servers/temp.db2.db2set $BASE/servers/$server.$inst.db2set`;
          } else {
            print ERR "Unable to get db2set for $server.$inst\n";
            print ACTIONS "logon to server $server; \n";
            print ACTIONS "next, try getting dbset for $server.$inst from your ID with the following:\n";
            print ACTIONS "\t. ~$inst/sqllib/db2profile; db2set\n";
            print ACTIONS "Determine why this failed and correct\n\n";
          }
          `ssh -q $server 'export LIBPATH=.; . $home/db2profile; db2 get dbm cfg' > $BASE/servers/temp.db2.dbmcfg`;
          if( `wc -l $BASE/servers/temp.db2.dbmcfg` > 0 ) {
            `mv $BASE/servers/temp.db2.dbmcfg $BASE/servers/$server.$inst.dbmcfg`;
          } else {
            print ERR "Unable to get dbmcfg for $server.$inst\n";
            print ACTIONS "logon to server $server; \n";
            print ACTIONS "next, try getting dbmcfg for $server.$inst from your ID with the following:\n";
            print ACTIONS "\t. ~$inst/sqllib/db2profile; db2 get dbm cfg\n";
            print ACTIONS "Determine why this failed and correct\n\n";
          }
          `ssh -q $server 'export LIBPATH=.; . $home/db2profile; db2 list utilities show detail | grep -v SQL1611W ' > $BASE/servers/temp.db2.utilities`;
          if(`wc -l $BASE/servers/temp.db2.utilities` > 0) {
            `mv $BASE/servers/temp.db2.utilities $BASE/servers/$server.$inst.utilities`;
          }
          ## the below command only works on AIX (grep -p), so, need to save this on AIX then perform the grep.
          ##@TMP2=`ssh -q $server 'export LIBPATH=.; . $home/db2profile ; db2 list db directory | grep -vp Remote | grep "Database name" | sort -u'`;
          `ssh -q $server 'export LIBPATH=.; . $home/db2profile ; db2 list db directory' > $BASE/servers/$server.$inst.dbdir`;
          @TMP2=`grep -vp Remote $BASE/servers/$server.$inst.dbdir | grep "Database name" | sort -u`;
          foreach $line (@TMP2) {
            (undef,$db)=split /=\s+/,$line;
            chomp($db);
            $db=lc($db);
            $ALLDBS{$server . '_' . $inst . '_' . $db}=1;
            $res3=`ssh -q $server 'export LIBPATH=.; . $home/db2profile; db2level'`;
            $LEVEL{"$server\_$inst"}=$res3;
##
            `ssh -q $server 'export LIBPATH=.; . $home/db2profile; db2 get db cfg for $db'  > $BASE/servers/temp.db2.dbcfg`;
            if(`wc -l $BASE/servers/temp.db2.dbcfg` > 0) {
              if(`grep -c SQL1013N $BASE/servers/temp.db2.dbcfg` > 0) {
                print ERR "DB $db is cataloged locally but doesn't exist on $server.$inst\n";
                print ACTIONS "logon to $server; sudo su - $inst; try to determine why $db is cataloged locally\n";
                print ACTIONS "may need to ask BNSF DBA's to check why cataloged incorrectly\n";
              } else {
                `mv $BASE/servers/temp.db2.dbcfg $BASE/servers/$server.$inst.$db.dbcfg`;

                if(`grep -c STANDBY $BASE/servers/$server.$inst.$db.dbcfg` > 0) {
                  print ERR "Skipping queries for Standby Database $server.$inst.$db\n";
                } else {
                  ## Connect to the DB and get Info
                  `ssh -q $server 'export LIBPATH=.; . $home/db2profile; db2 connect to $db; db2 "call get_dbsize_info(?,?,?,-1)"; db2 terminate;' > $BASE/servers/temp.db2.dbsize`;
                  if(`wc -l $BASE/servers/temp.db2.dbsize` > 0) {
                    `mv $BASE/servers/temp.db2.dbsize $BASE/servers/$server.$inst.$db.dbsize`;
                  } else {
                    print ERR "Unable to get dbsize for $server.$inst.$db\n";
                    print ACTIONS "logon to server $server; \n";
                    print ACTIONS "next, try running get_dbsize_info for $server.$inst.$db from your ID with the following:\n";
                    print ACTIONS "\t. ~$inst/sqllib/db2profile; db2 connect to $db; db2 \"call get_dbsize_info(?,?,?,-1)\"\n";
                    print ACTIONS "determine why the above command is not working and attempt to fix.\n\n";
                  }

                  if($ver=~/^8/ or $ver=~/^9\.1/) {
                    print "V8 or V9.1 instance - running get_db2_max_logs_v8v91.sql\n";
                    `ssh -q $server 'export LIBPATH=.; . $home/db2profile; db2 connect to $db; db2 -txf get_db2_max_logs_v8v91.sql; db2 terminate;' 2> $BASE/servers/temp.db2.maxlog.err > $BASE/servers/temp.db2.maxlog`;
                    if(`wc -l $BASE/servers/temp.db2.maxlog` > 0) {
                      `mv $BASE/servers/temp.db2.maxlog $BASE/servers/$server.$inst.$db.maxlog`;
                    } else {
                      print ERR "Unable to run get_db2_max_logs_v8v91.sql  for $server.$inst.$db\n";
                      print ACTIONS "logon to server $server; \n";
                      print ACTIONS "copy get_db2_max_logs_v8v91.sql to your home directory:\n";
                      print ACTIONS "\tscp ftwaxdsep002:/igs_swdepot/igs/MidrangeDBAServices/DB2/db2info/dev/get_db2_max_logs_v8v91.sql .\n";
                      print ACTIONS "next, try running the script from your ID connecting to the database by the following:\n";
                      print ACTIONS "\t. ~$inst/sqllib/db2profile; db2 connect to $db; db2 -tvf get_db2_max_logs_v8v91.sql\n";
                      print ACTIONS "determine why the above command is not working and attempt to fix.\n\n";
                    }
                  } else {
                    print "V9.5 or higher instance - running get_db2_max_logs.sql\n";
                    `ssh -q $server 'export LIBPATH=.; . $home/db2profile; db2 connect to $db; db2 -txf get_db2_max_logs.sql; db2 terminate;' 2> $BASE/servers/temp.db2.maxlog.err > $BASE/servers/temp.db2.maxlog`;
                    if(`wc -l $BASE/servers/temp.db2.maxlog` > 0) {
                      `mv $BASE/servers/temp.db2.maxlog $BASE/servers/$server.$inst.$db.maxlog`;
                    } else {
                      print ERR "Unable to run get_db2_max_logs.sql  for $server.$inst.$db\n";
                      print ACTIONS "logon to server $server; \n";
                      print ACTIONS "copy get_db2_max_logs.sql to your home directory:\n";
                      print ACTIONS "\tscp ftwaxdsep002:/igs_swdepot/igs/MidrangeDBAServices/DB2/db2info/dev/get_db2_max_logs.sql .\n";
                      print ACTIONS "next, try running the script from your ID connecting to the database by the following:\n";
                      print ACTIONS "\t. ~$inst/sqllib/db2profile; db2 connect to $db; db2 -tvf get_db2_max_logs.sql\n";
                      print ACTIONS "determine why the above command is not working and attempt to fix.\n\n";
                    }
                  }

                  print "Eval backups for $server.$inst.$db\n";
                  `ssh -q $server 'export LIBPATH=.; . $home/db2profile; db2 connect to $db; db2 -txf get_db2_backup_info.sql; db2 terminate;' 2> $BASE/servers/temp.db2.bkup.err | egrep 'Success|Failure' > $BASE/servers/temp.db2.bkup`;
                  if(`wc -l $BASE/servers/temp.db2.bkup` > 0) {
                    `mv $BASE/servers/temp.db2.bkup $BASE/servers/$server.$inst.$db.db2bkup`;
                  } else {
                    print ERR "Error running get_db2_backup_info.sql on $server.$inst.$db : \n";
                    print ACTIONS "logon to server $server; \n";
                    print ACTIONS "copy get_db2_backup_info.sql to your home directory:\n";
                    print ACTIONS "\tscp ftwaxdsep002:/igs_swdepot/igs/MidrangeDBAServices/DB2/db2info/dev/get_db2_backup_info.sql .\n";
                    print ACTIONS "next, try running the script from your ID connecting to the database by the following:\n";
                    print ACTIONS "\t. ~$inst/sqllib/db2profile; db2 connect to $db; db2 -tvf get_db2_backup_info.sql\n";
                    print ACTIONS "determine why the above command is not working and attempt to fix.\n\n";

                    if(`wc -l $BASE/servers/temp.db2.bkup.err` > 0) {
                      `cat $BASE/servers/temp.db2.bkup.err >> $BASE/reports/db2_daily_report.err`;
                    }
                  }
                }
              }
            } else {
              print ERR "Unable to get dbcfg for $server.$inst.$db\n";
              print ACTIONS "logon to server $server; \n";
              print ACTIONS "next, try getting dbcfg for $server.$inst.$db from your ID with the following:\n";
              print ACTIONS "\t. ~$inst/sqllib/db2profile; db2 get db cfg for $db\n";
              print ACTIONS "Determine why this failed and correct\n\n";
            }
          }
        } else {
          print "Instance $inst is NOT running\n";
          $INACTIVE{"$server\_$inst"}="$ver:$home:$sw";
          $res3=`ssh -q $server 'export LIBPATH=.; . $home/db2profile; db2level'`;
          $LEVEL{"$server\_$inst"}=$res3;
        }
        #$res4=`ssh -q $server 'export LIBPATH=.; . $home/db2profile; db2licm -l'`;
        #$LICM{"$server\_$inst"}=$res4;
        #`ssh -q $server \'export LIBPATH=.; . $home/db2profile; db2licm -g /tmp/db2licm.out\'`;
        #$res3=`ssh -q $server cat /tmp/db2licm.out`;
        #$LICMAUDIT{"$server\_$inst"}=$res3;
      }
      print "Ver @TMP[2], Instance @TMP[3], Home @TMP[4], SW @TMP[8]\n";
      $res=`ssh -q $server ls -ld $home/bin`;
      chomp($res);
      (undef,$date)=split /dba\s+/,$res;
      ($date)=split /\s+\//,$date;
      $DATE{"$server\_$inst"}=$date;
    }
    #if(/^S/) {
    #  print "Found Software: $_\n";
    #}
    #print "Eval $_\n";
  }
  close(F);
}
open(R,'>',"$BASE/reports/all.db2client");
foreach $server_inst (keys %CLIENT) {
  print "Client Instance $server_inst\n";
  if(exists $DATE{$server_inst}) {
    $date=$DATE{$server_inst};
  } else {
    $date='unknown';
  }
  print R "$server_inst:$CLIENT{$server_inst}:$date:\n";
}
close(R);
open(R,'>',"$BASE/reports/all.db2das");
foreach $server_inst (keys %DAS) {
  if(exists $DATE{$server_inst}) {
    $date=$DATE{$server_inst};
  } else {
    $date='unknown';
  }
  print R "$server_inst:$DAS{$server_inst}:$date:\n";
}
close(R);
open(R,'>',"$BASE/reports/all.db2active");
foreach $server_inst (keys %ACTIVE) {
  print "Active Instance $server_inst\n";
  if(exists $DATE{$server_inst}) {
    $date=$DATE{$server_inst};
  } else {
    $date='unknown';
  }
  print R "$server_inst:$ACTIVE{$server_inst}:$date:\n";
}
close(R);
open(R,'>',"$BASE/reports/all.db2inactive");
foreach $server_inst (keys %INACTIVE) {
  print "Inactive Instance $server_inst\n";
  if(exists $DATE{$server_inst}) {
    $date=$DATE{$server_inst};
  } else {
    $date='unknown';
  }
  print R "$server_inst:$INACTIVE{$server_inst}:$date:\n";
}
close(R);
open(R,'>',"$BASE/reports/all.db2level");
foreach $server_inst (keys %LEVEL) {
  print R "DB2LEVEL: $server_inst $LEVEL{$server_inst}\n";
  my $server;
  my $inst;
  ($server,$inst)=split /_/,$server_inst;
  open(D,'>',"$BASE/servers/$server\.$inst\.db2level");
  print D $LEVEL{$server_inst};
  close(D);
}
close(R);
open(R,'>',"$BASE/reports/all.db2licm");
foreach $server_inst (keys %LICM) {
  print R "DB2LICM: $server_inst $LICM{$server_inst}\n";
}
close(R);
open(R,'>',"$BASE/reports/all.db2dbs");
foreach $db (sort (keys %ALLDBS)) {
  print R "$db\n";
}
close(R);
close(ERR);
close(ALLBACKUPS);
`rm $BASE/servers/temp.db2.utilities`;