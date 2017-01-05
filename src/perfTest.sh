#!/bin/bash
#set -x

#=======================================================================================================================
# Run performance tests on a unix server
# 1) Copy a local file (/tmp) 1000 times
# 2) Copy a remote file (//saugus) 1000 times
# 3) read the clients table ~900 records
#=======================================================================================================================

count=${1-1000}

## Constants
        TOOLSPATH="/steamboat/leepfrog/docs/tools"
        tmpFile="/tmp/$LOGNAME.perfTest.sh.out"

## warhouse connection info
        warehouseDb='warehouse'
        dbAcc='Update'
        mySqlUser="leepfrog$dbAcc"
        mySqlHost='duro'
        mySqlPort=3306
        [[ -r "$TOOLSPATH/src/.pw1" ]] && mySqlPw=$(cat "$TOOLSPATH/src/.pw1")
        if [[ $mySqlPw != '' ]]; then
                unset sqlHostIP mySqlConnectString
                sqlHostIP=$(dig +short $mySqlHost.inside.leepfrog.com)
                [[ -z $sqlHostIP ]] && sqlHostIP=$(dig +short $mySqlHost.leepfrog.com)
                [[ -n $sqlHostIP ]] && mySqlConnectString="-h $sqlHostIP -port=$mySqlPort -u $mySqlUser -p$mySqlPw $warehouseDb"
        fi

## Create initial record
        sqlStmt="insert into perfTest values(NULL,\"$(cut -d'.' -f1 <<< $(hostname))\",\"$(date +'%m-%d-%y %H:%M')\",NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL)"
        result=$(mysql --skip-column-names --batch $mySqlConnectString -e "$sqlStmt";)
        sqlStmt="select max(idx) from perfTest"
        idx=$(mysql --skip-column-names --batch $mySqlConnectString -e "$sqlStmt";)

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
                result=$(mysql --skip-column-names --batch $mySqlConnectString -e "$sqlStmt";)
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
                result=$(mysql --skip-column-names --batch $mySqlConnectString -e "$sqlStmt";)
        done < $tmpFile;

## Run database tests
        table='sites'
        sqlStmt="select * from $table where name is not null order by name"
        sqlCmdString="mysql --skip-column-names --batch $mySqlConnectString -e "
        { time (
                resultStr=$($sqlCmdString "$sqlStmt" 2>&1 | tr "\t" '|')
                [[ $resultStr != '' ]] && IFS=$'\n' read -rd '' -a resultSet <<< "$resultStr"
        ); } 2> $tmpFile
        while read -r line; do
                [[ -z $line ]] && continue
                ## Parse line, convert to pure seconds
                type=$(cut -d' ' -f1 <<< $line)
                time=$(cut -d' ' -f2 <<< $line)
                timeM=${time%%m*} ; time=${time##*m} ; time=${time%s*}
                sec=$(( timeM * 60 )) ; sec=$(( sec + ${time%%.*} )) ; sec="${sec}.${time##*.}"
                sqlStmt="update perfTest set dbread$type=\"$sec\" where idx=$idx"
                result=$(mysql --skip-column-names --batch $mySqlConnectString -e "$sqlStmt";)
        done < $tmpFile;

## Cleanup
        echo
        rm -rf /steamboat/leepfrog/docs/tools/perfTest
        rm -f "$tmpFile"
## Thu Jan  5 16:36:09 CST 2017 - dscudiero - Add time stamp to the date field
