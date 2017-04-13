## XO NOT AUTOVERSION
#===================================================================================================
# version="1.0.18" # -- dscudiero -- Thu 04/13/2017 @  8:10:16.73
#===================================================================================================
# Write out / update a start record into the process log database
# Called as 'mode' 'token' 'data'
# mode in {'start','end','update','remoge'}
# token = name if mode = start, otherwise it is the db key to update
#===================================================================================================
# Copyright 2017 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function ProcessLogger {
	[[ $logInDb == false ]] && return 0
	local mode="$1"; shift || true
	local myName argString epochTime sqlStmt epochTime epochStime epochEtime eHr eMin eSec elapSeconds elapTime

	case $(Lower ${mode:0:1}) in
	    s)	# START
			myName=$1; shift || true
			argString="$*"
			[[ $informationOnlyMode == true ]] && argString="${argString}, informationOnlyMode"
			[[ -n $allItems && $(Contains "$argString" 'allItems') != true ]] && argString="${argString}, AllItems"
			epochTime=$(date +%s)
			sqlStmt="insert into $processLogTable (idx,name,hostName,userName,viaScripts,startTime,startEtime,endTime,endEtime,elapsedTime,exitCode,argString,data) \
					values(NULL,\"$myName\",\"$hostName\",\"$userName\",\"$calledViaScripts\",\"$startTime\",$(date +%s),NULL,NULL,NULL,NULL,\"$argString\",NULL)"
			RunSql2 $sqlStmt
			## Get newly inserted record Id
			[[ ${#resultSet[@]} -eq 0 ]] && Terminate "Could not insert record into $processLogTable"
			echo ${resultSet[0]}
			;;
	    e)	# END
			idx=$1
			[[ -z $idx ]] && return 0
			sqlStmt="select startEtime from $processLogTable where idx=$idx"
			RunSql2 $sqlStmt
			epochStime=${resultSet[0]}
			epochEtime=$(date +%s)
			endTime=$(date '+%Y-%m-%d %H:%M:%S')
			if [[ -z $epochStime ]]; then
				elapTime="N/A"
			else
				elapSeconds=$(( epochEtime - epochStime ))
				eHr=$(( elapSeconds / 3600 ))
				elapSeconds=$(( elapSeconds - eHr * 3600 ))
				eMin=$(( elapSeconds / 60 ))
				elapSeconds=$(( elapSeconds - eMin * 60 ))
				eSec=$elapSeconds
				elapTime=$(printf "%02dh %02dm %02ds" $eHr $eMin $eSec)
			fi
			sqlStmt="update $processLogTable set endTime=\"$endTime\",endEtime=\"$epochEtime\",elapsedTime=\"$elapTime\" where idx=$idx"
			RunSql2 $sqlStmt
	        ;;
	    u)	# UPDATE DATA FIELD, The second token is the name of the field to update
			idx=$1; shift || true
			[[ -z $idx ]] && return 0
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
## Wed Jan 11 07:51:24 CST 2017 - dscudiero - Streamlined
## 04-13-2017 @ 08.13.02 - ("1.0.18")  - dscudiero - add usage information
