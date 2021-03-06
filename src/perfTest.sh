#!/bin/bash
#set -x

#=======================================================================================================================
# Run performance tests on a unix server
# 1) Copy a local file (/tmp) 1000 times
# 2) Copy a remote file (//saugus) 1000 times
# 3) read the clients table ~900 records
#=======================================================================================================================

myIncludes="SetFileExpansion RunSql"
Import "$standardInteractiveIncludes $myIncludes"

mode=${1-'test'}; shift || true
count=${1-1000}; shift || true
tmpFile="/tmp/$LOGNAME.perftest.sh.out"
[[ ${mode:0:1} == '-' ]] && mode="${mode:1}"
#echo "mode = '$mode'"
#Msg "$myName starting, mode=$mode, count=$count"
if [[ $mode == 'summary' ]]; then
        SetFileExpansion 'off'
        sqlStmt="select * from perftest where date like \"%$(date "+%m-%d-%y %H")%\" order by idx"
        RunSql $sqlStmt
        SetFileExpansion
        #echo "\${#resultSet[@]} = '${#resultSet[@]}'"
        #echo "\${resultSet[0]} = '${resultSet[0]}'"
        #echo "\${resultSet[1]} = '${resultSet[1]}'"
        ## resultSet[0] = mojave, resultSet[1] = build7
        if [[ ${#resultSet[@]} -eq 2 ]]; then
                unset valuesStr
                # fields='localfsreal localfsuser localfssys remotefsreal remotefsuser remotefssys dbreadreal dbreaduser dbreadsys'
                for ((i=4; i<13; i++)); do
                        unset int1 int2 real1 real2 percent
                        real1="$(cut -d'|' -f$i <<< ${resultSet[0]})"
                        int1="$(tr -d '.' <<< $real1)"  ## Remove decimal point
                        shopt -s extglob; int1=${int1##+(0)}; shopt -u extglob
                        real2="$(cut -d'|' -f$i <<< ${resultSet[1]})"
                        int2="$(tr -d '.' <<< $real2)"  ## Remove decimal point
                        shopt -s extglob; int2=${int2##+(0)}; shopt -u extglob
                        let delta=$int2-$int1
                        percent=$((200*$delta/$int1 % 2 + 100*$delta/$int1))
                        #dump -n field -t real1 int1 real2 int2 delta percent
                        valuesStr="$valuesStr,\"${percent}%\""
                done
                valuesStr="NULL,\"\",\"$(date +'%m-%d-%y %H:%M')\"$valuesStr"
                #dump valuesStr
                sqlStmt="insert into perftest values($valuesStr)"
                RunSql $sqlStmt
        fi
else
        ## Create initial record
        sqlStmt="insert into perftest values(NULL,\"$(cut -d'.' -f1 <<< $(hostname))\",\"$(date +'%m-%d-%y %H:%M')\",NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL)"
        RunSql $sqlStmt
        idx=${resultSet[0]}
        [[ -z $idx ]] && Terminate "Could not insert record into the '$warehouseDb.perftest' table"

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
                sqlStmt="update perftest set localFs$type=\"$sec\" where idx=$idx"
                RunSql $sqlStmt
        done < $tmpFile;

        ## Run test using remote file systems
        mkdir -p /steamboat/leepfrog/docs/tools/perftest
        { time (
                        cd /steamboat/leepfrog/docs/tools/perftest
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
                sqlStmt="update perftest set remoteFs$type=\"$sec\" where idx=$idx"
                RunSql $sqlStmt
        done < $tmpFile;

        ## Run database tests
        set -f
        sqlStmt="select * from sites where name is not null order by name"
        { time (
                RunSql $sqlStmt
        ); } 2> $tmpFile
        while read -r line; do
                [[ -z $line ]] && continue
                ## Parse line, convert to pure seconds
                type=$(cut -d' ' -f1 <<< $line)
                time=$(cut -d' ' -f2 <<< $line)
                timeM=${time%%m*} ; time=${time##*m} ; time=${time%s*}
                sec=$(( timeM * 60 )) ; sec=$(( sec + ${time%%.*} )) ; sec="${sec}.${time##*.}"
                sqlStmt="update perftest set dbread$type=\"$sec\" where idx=$idx"
                RunSql $sqlStmt
        done < $tmpFile;

        ## Cleanup
        [[ -f "/steamboat/leepfrog/docs/tools/perftest" ]] && rm -rf "/steamboat/leepfrog/docs/tools/perftest"
        [[ -f "$tmpFile" ]] && rm -f "$tmpFile"
fi
#Msg "$myName done"


## Thu Jan  5 16:36:09 CST 2017 - dscudiero - Add time stamp to the date field
## Thu Jan 12 12:41:53 CST 2017 - dscudiero - Switch to use RunSql
## Fri Jan 27 14:30:03 CST 2017 - dscudiero - Add summary mode
## Fri Jan 27 15:16:37 CST 2017 - dscudiero - Add debug messages
## Fri Feb  3 11:28:48 CST 2017 - dscudiero - Remove debug statements
## Fri Feb  3 14:13:39 CST 2017 - dscudiero - Remove leading zeros from integers befor calculating the percentage
## Tue Feb  7 07:54:23 CST 2017 - dscudiero - add debug messaging
## Wed Feb  8 08:39:26 CST 2017 - dscudiero - Remove debug statements
## Wed Feb 22 14:39:21 CST 2017 - dscudiero - switch percentage to be based on delta/mojave
## Fri Feb 24 08:30:51 CST 2017 - dscudiero - Add debug messages
## Fri Feb 24 08:32:06 CST 2017 - dscudiero - more debug stuff
## Fri Feb 24 09:47:44 CST 2017 - dscudiero - remove debug statements
## 07-18-2017 @ 13.16.11 - dscudiero - Add start/end messages
## 10-11-2017 @ 10.38.57 - dscudiero - switch Msg2 for Msg
## 10-19-2017 @ 10.32.43 - dscudiero - Change the way we strip off leading zeros from the int strings
## 10-24-2017 @ 10.58.43 - dscudiero - Remove extra blank line in outout
## 10-25-2017 @ 09.14.28 - dscudiero - Turn off messages
