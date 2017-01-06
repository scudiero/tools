## XO NOT AUTOVERSION
#===================================================================================================
# version="1.0.10" # -- dscudiero -- 01/06/2017 @ 16:38:16.08
#===================================================================================================
# Write out / update a start record into the process log database
#===================================================================================================
# Copyright 2017 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function ProcessLogger {
	[[ $logInDb == false ]] && return 0
	local mode=$(Lower ${1:0:1}); shift || true
	local myName argString epochTime sqlStmt epochTime epochStime epochEtime eHr eMin eSec elapSeconds elapTime

	case $mode in
	    s)	# START
			myName=$1; shift || true
			argString="$*"
			[[ $informationOnlyMode == true ]] && argString="${argString}, informationOnlyMode"
			[[ -n $allItems && $(Contains "$argString" 'allItems') != true ]] && argString="${argString}, AllItems"
			epochTime=$(date +%s)
			sqlStmt="insert into $processLogTable (idx,name,hostName,userName,viaScripts,startTime,startEtime,endTime,endEtime,elapsedTime,exitCode,argString,data) \
					values(NULL,\"$myName\",\"$hostName\",\"$userName\",\"$calledViaScripts\",\"$startTime\",$(date +%s),NULL,NULL,NULL,NULL,\"$argString\",NULL)"
			RunSql2 $sqlStmt
			## Get the inserted record id
			sqlStmt="select max(idx) from $processLogTable"
			RunSql2 $sqlStmt
			echo ${resultSet[0]}
			;;
	    e)	# END
			idx=$1
			[[ -z $idx ]] && return 0
			sqlStmt="select startEtime from $processLogTable where idx=$idx"
			epochStime=${resultSet[0]}
			epochEtime=$(date +%s)
			endTime=$(date '+%Y-%m-%d %H:%M:%S')
			elapSeconds=$(( epochEtime - epochStime ))
			eHr=$(( elapSeconds / 3600 ))
			elapSeconds=$(( elapSeconds - eHr * 3600 ))
			eMin=$(( elapSeconds / 60 ))
			elapSeconds=$(( elapSeconds - eMin * 60 ))
			eSec=$elapSeconds
			elapTime=$(printf "%02dh %02dm %02ds" $eHr $eMin $eSec)
			sqlStmt="update $processLogTable set endTime=\"$endTime\",endEtime=\"$epochEtime\",elapsedTime=\"$elapTime\" where idx=$idx"
			RunSql2 $sqlStmt
	        ;;
	    x)	# SET EXIT CODE
			idx=$1; shift || true
			[[ -z $idx ]] && return 0
			argString="$*"
			sqlStmt="update $processLogTable set exitCode=\"$argString\" where idx=$idx"
			RunSql2 $sqlStmt
	        ;;
	    d)	# UPDATE DATA FIELD
			idx=$1; shift || true
			[[ -z $idx ]] && return 0
			argString="$*"
			[[ $informationOnlyMode == true ]] && argString="${argString}, informationOnlyMode"
			[[ $allItems != '' && $(Contains "$argString" 'allItems') != true ]] && argString="${argString}, AllItems"
			sqlStmt="update $processLogTable set data=\"$argString\" where idx=$idx"
			RunSql2 $sqlStmt
	        ;;
	    u)	# UPDATE DATA FIELD, The second token is the name of the field to update
			idx=$1; shift || true
			local field=$1; shift || true
			argString="$*"
			sqlStmt="update $processLogTable set $field=\"$argString\" where idx=$idx"
			RunSql2 $sqlStmt
	        ;;
	    r)	# REMOVE
			idx=$1; shift || true
			[[ -z $idx ]] && return 0
			sqlStmt="delete from $processLogTable where idx=$idx"
			RunSql2 $sqlStmt
	        ;;
	    *)
	esac

	return 0
} #ProcessLogger
export -f ProcessLogger

#===================================================================================================
# Check-in Log
#===================================================================================================
