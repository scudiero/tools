#!/bin/bash
#set -x

#=======================================================================================================================
# Run performance tests on a unix server
# 1) Copy a local file (/tmp) 1000 times
# 2) Copy a remote file (//saugus) 1000 times
# 3) read the clients table ~900 records
#=======================================================================================================================

mode=${1-'test'}; shift || true
count=${1-1000}; shift || true
tmpFile="/tmp/$LOGNAME.perfTest.sh.out"

echo "mode = '$mode'"

if [[ $mode == 'summary' ]]; then
        SetFileExpansion 'off'
        sqlStmt="select * from perftest where date like \"%$(date +%H):00%\""
        RunSql2 $sqlStmt
        SetFileExpansion
        if [[ ${#resultSet[@]} -eq 2 ]]; then
                unset valuesStr
                # fields='localfsreal localfsuser localfssys remotefsreal remotefsuser remotefssys dbreadreal dbreaduser dbreadsys'
                for ((i=4; i<13; i++)); do
                        unset int1 int2 real1 real2 percent
                        real1="$(cut -d'|' -f$i <<< ${resultSet[0]})"
                        int1="$(tr -d '.' <<< $real1)"
                        real2="$(cut -d'|' -f$i <<< ${resultSet[1]})"
                        int2="$(tr -d '.' <<< $real2)"
                        let delta=$int2-$int1
                        percent=$((200*$delta/$int2 % 2 + 100*$delta/$int2))
        dump -n field -t real1 int1 real2 int2 delta percent
                        valuesStr="$valuesStr,\"${percent}%\""
                done
                valuesStr="NULL,\"\",\"$(date +'%m-%d-%y %H:%M')\"$valuesStr"
        dump valuesStr
                sqlStmt="insert into perftest values($valuesStr)"
                RunSql2 $sqlStmt
        fi
else
        ## Create initial record
        sqlStmt="insert into perfTest values(NULL,\"$(cut -d'.' -f1 <<< $(hostname))\",\"$(date +'%m-%d-%y %H:%M')\",NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL)"
        RunSql2 $sqlStmt
        idx=${resultSet[0]}
        [[ -z $idx ]] && Terminate "Could not insert record into the '$warehouseDb.perfTest' table"

        ## Run test using local file systems
        unset localFSreal localFSuser localFSsys
        { time (
                        cd /tmp
                        [[ -d ./$(hostname) ]] && rm -rf ./$(hostname)
                        mkdir -p ./$(hostname)
                        cd ./$(hostname)
                        #Create, stat, delete 1000 files
                        cntr=1
                        until [[ $cntr -gt $count ]]; do
                                        touch ./$cntr
                                        stat ./$cntr > /dev/null
                                        rm -f ./$cntr
                                        ((cntr += 1))
                        done
                        cd ..
                        rm -rf $(hostname)
        ); } 2> $tmpFile
        while read -r line; do
                [[ -z $line ]] && continue
                ## Parse line, convert to pure seconds
                type=$(cut -d' ' -f1 <<< $line)
                time=$(cut -d' ' -f2 <<< $line)
                timeM=${time%%m*} ; time=${time##*m} ; time=${time%s*}
                sec=$(( timeM * 60 )) ; sec=$(( sec + ${time%%.*} )) ; sec="${sec}.${time##*.}"
                sqlStmt="update perfTest set localFs$type=\"$sec\" where idx=$idx"
                RunSql2 $sqlStmt
        done < $tmpFile;

        ## Run test using remote file systems
        mkdir -p /steamboat/leepfrog/docs/tools/perfTest
        { time (
                        cd /steamboat/leepfrog/docs/tools/perfTest
                        [[ -d ./$(hostname) ]] && rm -rf ./$(hostname)
                        mkdir -p ./$(hostname)
                        cd ./$(hostname)
                        #Create, stat, delete 1000 files
                        cntr=1
                        until [[ $cntr -gt $count ]]; do
                                        touch ./$cntr
                                        stat ./$cntr > /dev/null
                                        rm -f ./$cntr
                                        ((cntr += 1))
                        done
                        cd ..
                        rm -rf $(hostname)
        ); } 2> $tmpFile
        while read -r line; do
                [[ -z $line ]] && continue
                ## Parse line, convert to pure seconds
                type=$(cut -d' ' -f1 <<< $line)
                time=$(cut -d' ' -f2 <<< $line)
                timeM=${time%%m*} ; time=${time##*m} ; time=${time%s*}
                sec=$(( timeM * 60 )) ; sec=$(( sec + ${time%%.*} )) ; sec="${sec}.${time##*.}"
                sqlStmt="update perfTest set remoteFs$type=\"$sec\" where idx=$idx"
                RunSql2 $sqlStmt
        done < $tmpFile;

        ## Run database tests
        set -f
        sqlStmt="select * from sites where name is not null order by name"
        { time (
                RunSql2 $sqlStmt
        ); } 2> $tmpFile
        while read -r line; do
                [[ -z $line ]] && continue
                ## Parse line, convert to pure seconds
                type=$(cut -d' ' -f1 <<< $line)
                time=$(cut -d' ' -f2 <<< $line)
                timeM=${time%%m*} ; time=${time##*m} ; time=${time%s*}
                sec=$(( timeM * 60 )) ; sec=$(( sec + ${time%%.*} )) ; sec="${sec}.${time##*.}"
                sqlStmt="update perfTest set dbread$type=\"$sec\" where idx=$idx"
                RunSql2 $sqlStmt
        done < $tmpFile;

        ## Cleanup
        echo
        [[ -f "/steamboat/leepfrog/docs/tools/perfTest" ]] && rm -rf "/steamboat/leepfrog/docs/tools/perfTest"
        [[ -f "$tmpFile" ]] && rm -f "$tmpFile"
fi


## Thu Jan  5 16:36:09 CST 2017 - dscudiero - Add time stamp to the date field
## Thu Jan 12 12:41:53 CST 2017 - dscudiero - Switch to use RunSql2
## Fri Jan 27 14:30:03 CST 2017 - dscudiero - Add summary mode
## Fri Jan 27 15:16:37 CST 2017 - dscudiero - Add debug messages
