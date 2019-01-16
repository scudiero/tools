#!/bin/bash
#XO NOT AUTOVERSION
#=======================================================================================================================
version="1.0.15" # -- dscudiero -- Wed 01/16/2019 @ 16:45:16
#=======================================================================================================================
#= Description #========================================================================================================
#
#
#=======================================================================================================================
TrapSigs 'on'
myIncludes="Msg ProtectedCall StringFunctions RunSql"
Import "$standardInteractiveIncludes $myIncludes"

originalArgStr="$*"
scriptDescription=""

#=======================================================================================================================
# Standard call back functions
#=======================================================================================================================
	function loadAuthData-ParseArgsStd  {
		#myArgs+=("shortToken|longToken|type|scriptVariableName|<command to run>|help group|help textHelp")
		return 0
	}

	function loadAuthData-Goodbye  {
		SetFileExpansion 'on' ; rm -rf $tmpRoot/${myName}* >& /dev/null ; SetFileExpansion
		return 0
	}

	function loadAuthData-Help  {
		helpSet='client,env' # can also include any of {env,src,tgt,prod,cim,cat,clss}, 'script' and 'common' automatically addeed
		[[ $1 == 'setVarsOnly' ]] && return 0
		[[ -z $* ]] && return 0
		echo -e "This script can be used to refresh the tools 'auth' data shadow ($authShadowDir) from the database data."
		return 0
	}

	function loadAuthData-testMode  { # or testMode-local
		return 0
	}

#=======================================================================================================================
# local functions
#=======================================================================================================================

#=======================================================================================================================
# Declare local variables and constants
#=======================================================================================================================
tmpFile=$(mkTmpFile)
trueVars=''
falseVars=''
for var in $trueVars; do eval $var=true; done
for var in $falseVars; do eval $var=false; done
declare -A userData scriptsData

#=======================================================================================================================
# Standard arg parsing and initialization
#=======================================================================================================================
GetDefaultsData -f $myName
ParseArgsStd $originalArgStr
Hello
user="$client"

if [[ $batchMode != true ]]; then
	unset ans
	if [[ -n $client ]] ; then
		Prompt ans "You are asking to reload the tools 'Auth' data for '$client', do you wish to continue" 'Yes No' 'Yes';
	else
		Prompt ans "You are asking to reload the tools 'Auth', do you wish to continue" 'Yes No';
	fi
	ans="${ans:0:1}"; ans="${ans,,[a-z]}"
	[[ $ans != 'y' ]] && Goodbye 3
fi

#============================================================================================================================================
# Main
#============================================================================================================================================
if [[ -n $client ]] ; then
	Verbose 1 "\nProcessing user '$client'..."
	whereClause="$auth2userTable.empKey=$employeeTable.employeekey and substr(email,1,instr(email,'@')-1) = \"$client\""
else
	Verbose 1 "\nProcessing all users..."
	whereClause="$auth2userTable.empKey=$employeeTable.employeekey"
fi


## Get a list of users
	Verbose 1 "\nBuilding the users list..."
	sqlStmt="select distinct employeekey,substr(email,1,instr(email,'@')-1) from $auth2userTable,$employeeTable where $whereClause order by employeekey"
	RunSql $sqlStmt
	if [[ ${#resultSet[@]} -eq 0 || ${resultSet[0]} == "" ]]; then
		## Get the employeeId
		Terminate "User '$client' has not auth data"
		sqlStmt="select distinct employeekey from $employeeTable where substr(email,1,instr(email,'@')-1) = \"$client\"" 
		RunSql $sqlStmt
		employeekey="${resultSet[0]}"
		dump employeekey
	fi
	unset userList; for rec in "${resultSet[@]}"; do userList+=("$rec"); done

## Loop through the user list
Verbose 1 "\nProcessing users..."
for userRec in "${userList[@]}"; do
	empKey="${userRec%|*}"
	user="${userRec#*|}"
	Verbose 1 "^$user ($empKey)..."
	outFile="${authShadowDir}/${user#*|}"
	
	## Get the list of groups this user is in
		sqlStmt="select groupId,code from $authGroupTable where groupId in (select authKey from auth2user where empKey=$empKey)"
		RunSql $sqlStmt
		unset groupListStr
		for result in "${resultSet[@]}"; do groupListStr="$groupListStr,$result"; done
		groupListStr="${groupListStr:1}"
		[[ -z $groupListStr ]] && continue
		Verbose 1 "^^Groups: ${groupListStr//,/, }"

	## Write out initial records to the outFile
		[[ -f $outFile ]] && cp -fp "$outFile" "${outFile}.bak"
		echo "## DO NOT EDIT VALUES IN THIS FILE, THE FILE IS AUTOMATICALLY GENERATED ($(date)) FROM THE AUTH TABLES IN THE DATA WAREHOUSE" > "${outFile}.new"
		echo "groups:$groupListStr" >> "${outFile}.new"
	
	## Get the list of scripts this user has access to, add them to the file
		# 1) Scripts authorized to a group that the user is a member of (auth2user, auth2script)
		# 2) Scripts where the user has specifically been granted access to (user2scripts)
		# 2) Unrestricted scripts
		sqlStmt="select distinct keyId,name,description,shortDescription,showInScripts from $scriptsTable where (keyId in \
		((select scriptKey from auth2script where groupKey in \
		(select authKey from auth2user where empKey in \
		(select employeekey from employee where substr(email,1,instr(email,'@')-1)=\"$user\"))))\
		or \
		(keyId in (select scriptKey from user2script where empKey in \
		(select employeekey from employee where substr(email,1,instr(email,'@')-1)=\"$user\")))) \
		or \
		(keyId not in (select scriptKey from auth2script) and keyId not in  (select scriptKey from user2script))
		and \
		name not in (\"loader\",\"dispatcher\")
		order by name"
		RunSql $sqlStmt

		## Generate a comma separated list of script names
		Verbose 1 "^^Found ${#resultSet[@]} script records..."
		[[ ${#resultSet[@]} -eq 0 || ${resultSet[0]} == "" ]] && continue
		unset scriptListStr
		for result in "${resultSet[@]}"; do
			scriptId="${result%%|*}"
			result="${result#*|}"; result="${result%%|*}";
			Verbose 1 "^^^$result"
			scriptListStr="${scriptListStr},${scriptId}|${result}"
		done
		scriptListStr="${scriptListStr:1}"
		scriptListStr="$(printf '%s\n' ${scriptListStr//,/ } | sort -u | tr "\n" ',')"
		echo "scripts:${scriptListStr:0:${#scriptListStr}-1}" >> "${outFile}.new"
		## Write out the script detail information
		[[ ${#resultSet[@]} -eq 0 || ${resultSet[0]} == "" ]] && continue
		for result in "${resultSet[@]}"; do
			echo "$result" >> "${outFile}.new"
		done
		#echo;echo "Pause...";read junk

 	## Cleanup and set ownership/permissions
	 	rm -f "$outFile"
	 	mv -f "${outFile}.new" "$outFile"
		chmod 640 "$outFile"
		chown "$userName:leepfrog" "$outFile"

done

#============================================================================================================================================
## Done
#============================================================================================================================================
Goodbye 0 #'alert'

#============================================================================================================================================
## Check-in log
#============================================================================================================================================
## 06-18-2018 @ 10:49:14 - 1.0.-1 - dscudiero - Allow passing in a userid name to update
## 06-19-2018 @ 07:06:58 - 1.0.-1 - dscudiero - Make sure the whereClause is set when running in batchmode
## 06-19-2018 @ 15:33:10 - 1.0.-1 - dscudiero - Re-factor how we set the whereClause to work with the workwith tool
## 06-19-2018 @ 15:39:24 - 1.0.-1 - dscudiero - Tweak messaging
## 06-19-2018 @ 15:42:50 - 1.0.-1 - dscudiero - Cosmetic/minor change/Sync
## 06-19-2018 @ 15:45:50 - 1.0.-1 - dscudiero - Cosmetic/minor change/Sync
## 06-19-2018 @ 16:26:18 - 1.0.-1 - dscudiero - Comment out debug
## 06-20-2018 @ 15:59:26 - 1.0.-1 - dscudiero - Re-factored to use the warehouse auth tables
## 06-20-2018 @ 16:03:49 - 1.0.-1 - dscudiero - Comment out script
## 06-20-2018 @ 16:32:08 - 1.0.-1 - dscudiero - Add section to write out the scriptname string
## 06-20-2018 @ 16:35:53 - 1.0.-1 - dscudiero - Strip off trailing comma from scriptsListStr
## 06-26-2018 @ 16:04:44 - 1.0.-1 - dscudiero - Update the sql to find the users scripts
## 06-27-2018 @ 07:15:24 - 1.0.-1 - dscudiero - Take out overrided to scriptsNew
## 06-27-2018 @ 07:17:27 - 1.0.-1 - dscudiero - Cosmetic/minor change/Sync
## 06-27-2018 @ 07:58:41 - 1.0.-1 - dscudiero - Cosmetic/minor change/Sync
## 06-27-2018 @ 12:41:28 - 1.0.-1 - dscudiero - Update to include the unsrestricted scripts
## 07-12-2018 @ 11:41:29 - 1.0.-1 - dscudiero - Add building the authGroups file
## 07-12-2018 @ 12:26:26 - 1.0.-1 - dscudiero - Add groupIds to the users group list
## 07-12-2018 @ 13:10:30 - 1.0.-1 - dscudiero - Update the UserScriptsStr to include the script id
## 07-12-2018 @ 13:40:31 - 1.0.-1 - dscudiero - Add shortDescription to the script detals lines
## 07-12-2018 @ 16:11:25 - 1.0.-1 - dscudiero - Remove building the authgroups file
## 07-13-2018 @ 09:13:26 - 1.0.-1 - dscudiero - Add the group: and script: prefixes to the output data
## 07-16-2018 @ 13:46:44 - 1.0.-1 - dscudiero - Put a check in to makesure the user has auth records before we continue
