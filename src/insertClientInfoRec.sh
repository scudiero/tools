#!/bin/bash
## XO NOT AUTOVERSION
#===================================================================================================
version=2.3.111 # -- dscudiero -- Fri 10/27/2017 @ 15:53:26.04
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
checkParent="buildClientInfoTable"; found=false
for ((i=0; i<${#BASH_SOURCE[@]}; i++)); do [[ "$(basename "${BASH_SOURCE[$i]}")" == "${checkParent}.sh" ]] && found=true; done
[[ $found != true ]] && Terminate "Sorry, this script can only be called from '$checkParent'"

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
Dump -1 -n client

#===================================================================================================
# Main
#===================================================================================================
## Get the list of fields in the transactional db
	Verbose 1 "^Getting transactional field names"
	SetFileExpansion 'off'
	sqlStmt="select * from sqlite_master where type=\"table\" and name=\"clients\""
	SetFileExpansion
	RunSql2 "$contactsSqliteFile" $sqlStmt
	[[ ${#resultSet[@]} -le 0 ]] && Terminate "Could not retrieve clients table definition data from '$contactsSqliteFile'"
	unset tFields
	tData="${resultSet[0]#*(}"; tData="${tData%)*}"
	ifsSave="$IFS"; IFS=',' read -ra tmpArray <<< "$tData"
	for token in "${tmpArray[@]}"; do
		[[ ${token:0:1} == ' ' ]] && token="${token:1}"
    	tFields="$tFields,${token%% *}"
	done
	tFields=${tFields:1}
	numTFields=${#tmpArray[@]}
	IFS="$ifsSave"; unset tmpArray
	Dump -2 numTFields tFields

## Get the transactional data
	Verbose 1 "^Getting transactional data"
	sql="select $tFields from clients where clientcode=\"$client\" and is_active=\"Y\""
	RunSql2 "$contactsSqliteFile" $sql
	if [[ ${#resultSet[@]} -le 0 ]]; then
		Terminate "Could not retrieve clients data from '$contactsSqliteFile'"
	else
		result="${resultSet[0]}"
		Dump -2 result
		for ((cntr = 1 ; cntr < $numTFields+1 ; cntr++)); do
			field=$(cut -d',' -f$cntr <<< $tFields)
			fVal=$(cut -d'|' -f$cntr <<< $result)
			#Dump -2 -t2 cntr field fVal
			[[ $(IsNumeric "$fVal") == false ]] && fVal="\"$fVal\""
			#Dump -2 -t2 $(MapTtoW "$field")
			eval $(MapTtoW "$field")="$fVal"
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
	Verbose 1 "^Getting url data"
	envs="dev,qa,test,next,curr,prior,preview,public"
	for env in $(tr ',' ' '<<< $envs); do unset ${env}url ${env}internalurl; done
	sqlStmt=" select type,domain,internal from clientsites where clientkey=$idx"
	RunSql2 "$contactsSqliteFile" $sqlStmt
	if [[ ${#resultSet[@]} -gt 0 ]]; then
		for ((cntr=0; cntr<${#resultSet[@]}; cntr++)); do
			result="${resultSet[$cntr]}"
			env="${result%%|*}"; result="${result#*|}"
			domain="${result%%|*}"; result="${result#*|}"
			Dump -2 -t2 env domain result
			[[ $result == 'Y' ]] && eval ${env}internalurl="${domain// /}" || eval ${env}url="${domain// /}" 
		done
	fi

## Get the Rep data from the transactional db
	Verbose 1 "^Getting reps data"
	reps="support,catcsm,cimcsm,clsscsm,salesrep,cateditor,catdev,cimdev,clssdev,trainer,pilotrep"
	for rep in $(tr ',' ' '<<< $reps); do unset $rep; done
	fields="LOWER(clientroles.role),employees.db_firstname || ' ' || employees.db_lastname || '/' || employees.db_email"
	dbs="clientroles,employees"
	whereClause="clientroles.employeekey=employees.db_employeekey and clientroles.clientkey=$idx"
	sqlStmt="select $fields from $dbs where $whereClause"
	RunSql2 "$contactsSqliteFile" $sqlStmt
	if [[ ${#resultSet[@]} -gt 0 ]]; then
		for ((cntr=0; cntr<${#resultSet[@]}; cntr++)); do
			[[ $verboseLevel -gt 1 ]] && echo "resultSet[$ij] = >${resultSet[$ij]}<"
			repName="${resultSet[$cntr]%%|*}"
			repVal="${resultSet[$cntr]##*|}"
			Dump -2 -t2 repName repVal
			eval $repName=\"$repVal\"
		done
	fi

## Build insert record
	Verbose 1 "^Building sql statement"
	sqlStmt="select lower(column_name),lower(column_type) from information_schema.columns where table_name=\"$useClientInfoTable\""
	RunSql2 $sqlStmt
	unset wFields insertVals
	for result in "${resultSet[@]}"; do
		#dump -n result
		field="${result%%|*}"
		fieldType="${result##*|}"
		wFields="$wFields,$field"
		fieldVal="${!field}"
		#dump -t field fieldType fieldVal wFields
		if [[ $field == 'recordstatus' ]]; 	then [[ $fieldVal == 'Y' ]] && fieldVal="\"A\"" || fieldVal="\"D\""
		elif [[ $field == 'createdby' ]]; 	then fieldVal="\"$userName\""
		elif [[ $field == 'createdon' ]]; 	then fieldVal='NOW()'
		elif [[ $(Trim $fieldVal) == '' ]]; then fieldVal='NULL'
		else
			[[ ${fieldType:0:1} == 'v' ]] && fieldVal="\"$fieldVal\""
			[[ ${fieldType:0:1} == 's' ]] && fieldVal="\"$fieldVal\""
		fi
		#dump -t fieldVal
		insertVals="$insertVals,$fieldVal"
	done
	#dump -n insertVals

## Insert record
	Verbose 1 "^Inserting data"
	## Delete old data
		sqlStmt="delete from $useClientInfoTable where name=\"$client\""
		RunSql2 $sqlStmt
	## Insert new data
		sqlStmt="insert into $useClientInfoTable ($wFields) values($insertVals)"
		Dump -2 -t2 sqlStmt -n
		[[ $DOIT != '' || $informationOnlyMode == true ]] && Dump sqlStmt || RunSql2 $sqlStmt

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
## 10-18-2017 @ 14.30.29 - (2.3.83)    - dscudiero - Fix who called check
## 10-19-2017 @ 07.32.06 - (2.3.84)    - dscudiero - Add debug state,=ments
## 10-19-2017 @ 07.53.54 - (2.3.86)    - dscudiero - Comment out caller check
## 10-20-2017 @ 09.01.51 - (2.3.87)    - dscudiero - Fix problem in the caller check code
## 10-24-2017 @ 10.08.54 - (2.3.91)    - dscudiero - Refactord most sections to make more efficient
## 10-27-2017 @ 13.37.44 - (2.3.92)    - dscudiero - Remove errant fi statement
## 10-27-2017 @ 15.28.58 - (2.3.105)   - dscudiero - Cosmetic/minor change
