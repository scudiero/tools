## XO NOT AUTOVERSION
#===================================================================================================
# version="1.0.28" # -- dscudiero -- Fri 06/23/2017 @ 16:02:45.79
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
[[ $userName == 'dscudiero' ]] && echo -e  "\nmyName= '$myName'" >> $stdout && echo "mode = '$mode'" >> $stdout && echo "\$* = '$*'" >> $stdout
	local myName argString epochTime sqlStmt epochTime epochStime epochEtime eHr eMin eSec elapSeconds elapTime

	case $(Lower ${mode:0:1}) in
	    s)	# START
			myName=$1; shift || true
			argString="$*"
			[[ $informationOnlyMode == true ]] && argString="${argString}, informationOnlyMode"
			[[ -n $allItems && $(Contains "$argString" 'allItems') != true ]] && argString="${argString}, AllItems"
			epochTime=$(date +%s)
			sqlStmt="insert into $processLogTable (idx,name,version,hostName,userName,viaScripts,startTime,startEtime,endTime,endEtime,elapsedTime,exitCode,argString,data) \
					values(NULL,\"$myName\",\"$version\",\"$hostName\",\"$userName\",\"$calledViaScripts\",\"$startTime\",$(date +%s),NULL,NULL,NULL,NULL,\"$argString\",NULL)"
			RunSql2 $sqlStmt
			## Get newly inserted record Id
			[[ ${#resultSet[@]} -eq 0 ]] && Terminate "Could not insert record into $processLogTable"
			echo ${resultSet[0]}
			;;
	    e)	# END
			idx=$1
			[[ -z $idx ]] && return 0
			sqlStmt="select startEtime from $processLogTable where idx=$idx"
[[ $userName == 'dscudiero' ]] && echo "\$sqlStmt 1 = '$sqlStmt'" >> $stdout
			RunSql2 $sqlStmt
[[ $userName == 'dscudiero' ]] && echo "HERE 1" >> $stdout

			epochStime=${resultSet[0]}
			epochEtime=$(date +%s)
			endTime=$(date '+%Y-%m-%d %H:%M:%S')
[[ $userName == 'dscudiero' ]] && echo "HERE 2" >> $stdout
			if [[ -z $epochStime ]]; then
				elapTime="N/A"
[[ $userName == 'dscudiero' ]] && echo "HERE 3a" >> $stdout
			else
[[ $userName == 'dscudiero' ]] && echo "HERE 3b" >> $stdout
				elapSeconds=$(( epochEtime - epochStime ))
				eHr=$(( elapSeconds / 3600 ))
[[ $userName == 'dscudiero' ]] && echo "HERE 3c" >> $stdout
				elapSeconds=$(( elapSeconds - eHr * 3600 ))
				eMin=$(( elapSeconds / 60 ))
[[ $userName == 'dscudiero' ]] && echo "HERE 3d" >> $stdout
				elapSeconds=$(( elapSeconds - eMin * 60 ))
				eSec=$elapSeconds
				elapTime=$(printf "%02dh %02dm %02ds" $eHr $eMin $eSec)
			fi
[[ $userName == 'dscudiero' ]] && echo "HERE 4" >> $stdout
			sqlStmt="update $processLogTable set endTime=\"$endTime\",endEtime=\"$epochEtime\",elapsedTime=\"$elapTime\" where idx=$idx"
[[ $userName == 'dscudiero' ]] && echo "\$sqlStmt 2 = '$sqlStmt'" >> $stdout
			RunSql2 $sqlStmt
[[ $userName == 'dscudiero' ]] && echo "HERE 5" >> $stdout
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
## 05-31-2017 @ 15.38.24 - ("1.0.19")  - dscudiero - Add the script version to the log record
## 05-31-2017 @ 15.47.28 - ("1.0.20")  - dscudiero - General syncing of dev to prod
## 06-23-2017 @ 16.05.51 - ("1.0.28")  - dscudiero - add debug statements
