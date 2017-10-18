#!/bin/bash
## XO NOT AUTOVERSION
#===================================================================================================
version=2.3.82 # -- dscudiero -- Wed 10/18/2017 @ 14:20:36.94
#===================================================================================================
TrapSigs 'on'

myIncludes="RunSql2"
Import "$standardIncludes $myIncludes"

originalArgStr="$*"
scriptDescription="Insert/Update a record into the '$clientInfoTable' table in the data warehouse,\nThis script is not intended to be called stand alone."

#= Description +====================================================================================
# Sync a record in the clientInfoTable, this is a helper script for 'syncClientInfoTable' and is
# NOT MEANT TO BE CALLED STAND ALONE
# insertClientInfoRec <client>
#===================================================================================================
checkParent="buildclientinfotable.sh"; found=false
for ((i=0; i<${#BASH_SOURCE[@]}; i++)); do [[ ${BASH_SOURCE[$i]} == $checkParent ]] && found=true; done
[[ $found != true ]] && Terminate "Sorry, this script can only be called from '$checkParent',\nCurrent call parent: '$calledFrom'"

#===================================================================================================
# Copyright ©2014 David Scudiero -- all rights reserved.
# 06-17-15 -- 	dgs - Initial coding
# 07-17-15 --	dgs - Migrated to framework 5
#===================================================================================================
#===================================================================================================
# Local Subs
#===================================================================================================
function MapTtoW {
	local tName="$1"
	if [[ $tName == 'clientkey' ]]; then echo 'idx'
	elif [[ $tName == 'name' ]]; then echo 'longName'
	elif [[ $tName == 'is_private' ]]; then echo 'private'
	elif [[ $tName == 'clientcode' ]]; then echo 'name'
	elif [[ $tName == 'is_active' ]]; then echo 'recordstatus'
	elif [[ $tName == 'authenticationtype' ]]; then echo 'authentication'
	elif [[ $tName == 'authenticationtiming' ]]; then echo 'authorization'
	elif [[ $tName == 'insupport' ]]; then echo 'productsinsupport'
	elif [[ $tName == 'productsinsupport' ]]; then echo 'junk'
	else echo $tName
	fi
}

#===================================================================================================
# Declare local variables and constants
#===================================================================================================
## Variables inherited from parent: client

#===================================================================================================
# Main
#===================================================================================================
## Get the list of fields in the transactional db
	Msg2 $V1 ""
	SetFileExpansion 'off'
	sqlStmt="select * from sqlite_master where type=\"table\" and name=\"clients\""
	RunSql2 "$contactsSqliteFile" $sqlStmt
	[[ ${#resultSet[@]} -le 0 ]] && Msg2 $T "Could not retrieve clients table definition data from '$contactsSqliteFile'"
	unset tFields
	tData="$(cut -d '(' -f2 <<< ${resultSet[0]})"; tData="$(cut -d ')' -f1 <<< $tData)"
	ifsSave="$IFS"; IFS=',' read -ra tmpArray <<< "$tData"
	for token in "${tmpArray[@]}"; do
		[[ ${token:0:1} == ' ' ]] && token="${token:1}"
    	tFields="$tFields,${token%% *}"
	done
	tFields=${tFields:1}
	numTFields=${#tmpArray[@]}
	IFS="$ifsSave"; unset tmpArray
	dump -1 numTFields tFields

## Get the transactional data
	Msg2 $V1 ""
	sql="select $tFields from clients where clientcode=\"$client\" and is_active=\"Y\""
	RunSql2 "$contactsSqliteFile" $sql
	if [[ ${#resultSet[@]} -le 0 ]]; then
		Msg2 $T "Could not retrieve clients data from '$contactsSqliteFile'"
	else
		result="${resultSet[0]}"
		dump -1 result
		for ((i = 1 ; i < $numTFields+1 ; i++)); do
			field=$(cut -d',' -f$i <<< $tFields)
			fVal=$(cut -d'|' -f$i <<< $result)
			[[ $(IsNumeric "$fVal") == false ]] && fVal="\"$fVal\""
			eval $(MapTtoW "$field")="$fVal"
			dump -1 -t $(MapTtoW "$field")
		done
	fi

## If the primary contact field is blank, then build the data from the transactional db clients table data
	if [[ $primarycontact == '' ]]; then
		fields='contactrole,firstname,lastname,title,workphone,cell,fax,email'
		sqlStmt="select $fields from contacts where clientkey=\"$idx\" and contactrole like \"%primary%\" order by contactrole,lastname"
		RunSql2 "$contactsSqliteFile" $sqlStmt
		for contactRec in "${resultSet[@]}"; do
			primarycontact="$primarycontact|$(tr '|' ',' <<< $contactRec)"
		done
		primarycontact=${primarycontact:1}
		primarycontact=$(tr "'" '"' <<< $primarycontact)
		primarycontact=$(sed s'/"/\\"/'g <<< $primarycontact)
	fi

## Get the URL data from the transactional db
	Msg2 $V1 ""
	envs="dev,qa,test,next,curr,prior,preview,public"
	for env in $(tr ',' ' '<<< $envs); do
		unset ${env}URL ${env}InternalURL
		sqlStmt="select domain,internal from clientsites where clientkey=$idx and type=\"$env\""
		RunSql2 "$contactsSqliteFile" $sqlStmt
		if [[ ${#resultSet[@]} -gt 0 ]]; then
			for result in "${resultSet[@]}"; do
				domain=$(cut -d'|' -f1 <<< $result)
				internal=$(cut -d'|' -f2 <<< $result)
				#dump -n env domain internal
				if [[ $internal == 'Y' ]]; then
					eval ${env}InternalURL="$domain"
				else
					eval ${env}URL="$domain"
				fi
			done
		else
			[[ $env == 'test' || $env == 'next' || $env == 'curr' ]] && eval ${env}InternalURL="https://${client}-${env}.editcl.com/"
		fi
		dump -1 -t ${env}URL ${env}InternalURL
	done

## Get the Rep data from the transactional db
	Msg2 $V1 ""
	reps="support,catCsm,cimCsm,clssCsm,,salesRep,catEditor,catdev,cimdev,clssdev,trainer,pilotRep"
	for rep in $(tr ',' ' '<<< $reps); do
		unset $rep
		sqlStmt="select employees.db_firstname,employees.db_lastname,employees.db_email from clientroles,employees where clientroles.clientkey=$idx and role=\"$rep\" and clientroles.employeekey=employees.db_employeekey"
		RunSql2 "$contactsSqliteFile" $sqlStmt
		if [[ ${#resultSet[@]} -gt 0 ]]; then
			firstName=$(cut -d'|' -f1 <<< ${resultSet[0]})
			lastName=$(cut -d'|' -f2 <<< ${resultSet[0]})
			email=$(cut -d'|' -f3 <<< ${resultSet[0]})
			eval $rep=\"$firstName $lastName/$email\"
		fi
		dump -1 -t $rep
	done

## Build insert record
	Msg2 $V1 ""
	#sql="select column_name from information_schema.columns where table_name =\"$clientInfoTable\""
	sqlStmt="show columns from $useClientInfoTable"
	RunSql2 $sqlStmt
	unset wFields insertVals
	for result in "${resultSet[@]}"; do
		field=$(cut -d'|' -f1 <<< $result)
		fieldType=$(cut -d'|' -f2 <<< $result)
		wFields="$wFields,$field"
		fVal="${!field}"
		if [[ $field == 'recordstatus' ]]; then
			[[ $fVal == 'Y' ]] && fVal="\"A\"" || fVal="\"D\""
		elif [[ $field == 'createdBy' ]]; then fVal="\"$userName\""
		elif [[ $field == 'createdOn' ]]; then fVal='NOW()'
		elif [[ $(Trim $fVal) == '' ]]; then fVal='NULL'
		else
			[[ ${fieldType:0:1} == 'v' ]] && fVal="\"$fVal\""
			[[ ${fieldType:0:1} == 's' ]] && fVal="\"$fVal\""
		fi
		insertVals="$insertVals,$fVal"
		#dump field fVal
	done
	wFields=${wFields:1}
	insertVals=${insertVals:1}
	dump -1 -n wFields -n insertVals -n useClientInfoTable client ; dump -2 -p

## Insert record
	## Delete old data
		Msg2 $V1 ""
		sqlStmt="delete from $useClientInfoTable where name=\"$client\""
		RunSql2 $sqlStmt
	## Insert new data
		Msg2 $V1 ""
		sqlStmt="insert into $useClientInfoTable ($wFields) values($insertVals)"
		dump -1 sqlStmt -n
		if [[ $DOIT != '' || $informationOnlyMode == true ]]; then
			echo -e "\t\tsqlStmt = '>'$sqlStmt'<'"
		else
			RunSql2 $sqlStmt
			#echo "resultSet[0] = ' ${resultSet[0]}'"
		fi

#===================================================================================================
# Done
#===================================================================================================
Goodbye 'Return'
return 0

#===================================================================================================
# Check-in Log
#===================================================================================================
# 10-16-2015 -- dscudiero -- Update for framework 6 (2.1)
# 10-26-2015 -- dscudiero -- Updated for errExit (2.2)
# 11-20-2015 -- dscudiero -- Added additional fields (2.3)
## Tue Mar 22 07:59:16 CDT 2016 - dscudiero - Change message levels
## Thu Mar 31 12:59:34 CDT 2016 - dscudiero - Add progress message
## Thu Mar 31 13:52:45 CDT 2016 - dscudiero - Add status messages
## Wed Apr 27 16:26:20 CDT 2016 - dscudiero - Switch to use RunSql
## Wed Apr 27 16:28:07 CDT 2016 - dscudiero - Switch to use RunSql
## Mon Jun  6 13:11:44 CDT 2016 - dscudiero - General syncing of dev to prod
## Mon Jun  6 13:27:46 CDT 2016 - dscudiero - General syncing of dev to prod
## Thu Jun 23 06:41:03 CDT 2016 - dscudiero - Set the internal URL even if the data is not in the transactional db
## Wed Jul 27 12:44:10 CDT 2016 - dscudiero - Set primarycontact from contacts table if there is no data in the clients table
## Thu Jul 28 08:16:43 CDT 2016 - dscudiero - Change the format of the generated primarycontact field
## Mon Aug  1 07:34:31 CDT 2016 - dscudiero - Fix problem when primary contacts contain double quote chars
## Thu Oct  6 16:39:44 CDT 2016 - dscudiero - Set dbAcc level to Update for db writes
## Thu Oct  6 16:59:15 CDT 2016 - dscudiero - General syncing of dev to prod
## Fri Oct  7 08:00:18 CDT 2016 - dscudiero - Take out the dbAcc switching logic, moved to framework RunSql
## Thu Jan  5 12:38:15 CST 2017 - dscudiero - Switch to use RunSql2
## Tue Jan 17 08:58:29 CST 2017 - dscudiero - x
## Tue Jan 17 09:12:46 CST 2017 - dscudiero - remove debug statement
## Tue Jan 17 09:38:03 CST 2017 - dscudiero - misc cleanup
## Tue Feb 14 13:19:17 CST 2017 - dscudiero - Refactored to delete the client records before inserting a new one
## 04-28-2017 @ 08.26.21 - (2.3.73)    - dscudiero - use Goodbye 'return'
## 05-03-2017 @ 11.40.59 - (2.3.79)    - dscudiero - Refactore parsing of the fields from the transactional database
## 10-18-2017 @ 14.16.20 - (2.3.81)    - dscudiero - Make the 'called from' logic more robust
## 10-18-2017 @ 14.20.50 - (2.3.82)    - dscudiero - Cosmetic/minor change
