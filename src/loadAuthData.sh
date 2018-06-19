#!/bin/bash
#DO NOT AUTOVERSION
#=======================================================================================================================
version=1.0.-1 # -- dscudiero -- 10/20/2016 @ 14:58:14.98
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
		Prompt ans "You are asking to reload the tools 'Auth' data for '$client', do you wish to continue" 'Yes No';
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

## Build a list of the users of interest
	sqlStmt="select distinct empKey,substr(email,1,instr(email,'@')-1) from $auth2userTable,$employeeTable where $whereClause"
	RunSql $sqlStmt
	for result in "${resultSet[@]}"; do 
		users+=("$result")
	done

## Build the user/authgroup map
	Verbose 1 "\nBuilding the authGroup data map..."
	## Get the list of auth groups
	sqlStmt="select code,groupId from $authGroupTable"
	RunSql $sqlStmt
	for result in "${resultSet[@]}"; do 
		groupCode="${result%%|*}"
		groupId="${result##*|}"
		Verbose 1 "^$groupCode"
		Dump 2 groupCode groupId
		## Get the users in this group
		sqlStmt="select empKey,userid from $auth2userTable where authKey=$groupId"
		RunSql $sqlStmt
		for result in "${resultSet[@]}"; do 
			userid="${result%%|*}|${result##*|}"
			[[ ${userData["$userid.authGroups"]+abc} ]] && userData["$userid.authGroups"]="${userData["$userid.authGroups"]},$groupId|$groupCode" || \
														userData["$userid.authGroups"]="$groupId|$groupCode"
		done
	done

## build the user/scripts map
	Verbose 1 "\nBuilding the user/scripts data map..."
	## Get the script data
	fields="keyId,name,restrictToUsers,restrictToGroups,author,shortDescription,showInScripts"
	sqlStmt="select $fields from $scriptsTable where active=\"Yes\" order by name"
	RunSql $sqlStmt
	for result in "${resultSet[@]}"; do 
		result="${result//NULL/}"; result="${result//null/}";
		Dump 2 -n result
		scriptId="${result%%|*}"; result="${result#*|}"
		scriptName="${result%%|*}"; result="${result#*|}"
		restrictToUsers="${result%%|*}"; result="${result#*|}"
		restrictToGroups="${result%%|*}"; result="${result#*|}"
		author="${result%%|*}"; result="${result#*|}"
		showInScripts="${result%%|*}"; result="${result#*|}"
		shortDesc="${result%%|*}"; result="${result#*|}"
		Dump 2 -t scriptId scriptName restrictToUsers restrictToGroups author showInScripts shortDesc
		recData="${scriptId}|${scriptName}|${showInScripts}|${shortDesc}"
		scriptsData["$scriptName"]="$recData"

		## Add script to authors script list
		for user in "${users[@]}"; do
			if [[ ${user#*|} == $author ]]; then
				[[ ${userData["$user.scripts"]+abc} ]] && \
					userData["$user.scripts"]="${userData["$user.scripts"]},$scriptName" || \
					userData["$user.scripts"]="$scriptName"
				break
			fi
		done	

		## Process scripts with no restrictTo data
		if [[ -z $restrictToUsers && -z $restrictToGroups ]]; then
			for user in "${users[@]}"; do
				[[ ${userData["$user.scripts"]+abc} ]] && \
					userData["$user.scripts"]="${userData["$user.scripts"]},$scriptName" || \
					userData["$user.scripts"]="$scriptName"
			done
		## Process restrictToUsers information
		elif [[ -n $restrictToUsers ]]; then
			for user in ${restrictToUsers//,/ }; do
				user="${user#*|}"
				[[ -z $user ]] && continue
				[[ ${userData["$user.scripts"]+abc} ]] && \
					userData["$user.scripts"]="${userData["$user.scripts"]},$scriptName" || \
					userData["$user.scripts"]="$scriptName"
			done
		## Process restricToGroups information			
		elif [[ -n $restrictToGroups ]]; then
			for group in ${restrictToGroups//,/ }; do
				[[ -z $group ]] && continue
				## OK loop through the userData array and find users in this group
				for user in "${users[@]}"; do
					if [[ ${userData["$user.authGroups"]+abc} ]]; then
						data="${userData["$user.authGroups"]}"
						for token in ${data//,/ }; do
							token="${token#*|}"
							if [[ ${token#*|} == $group ]]; then
								[[ ${userData["$user.scripts"]+abc} ]] && \
										userData["$user.scripts"]="${userData["$user.scripts"]},$scriptName" || \
										userData["$user.scripts"]="$scriptName"
							fi
						done ## Users groups
					fi
				done ## User in the group
			done ## group in restrictToGroups
		fi
	done ## All scripts

## Write out the auth files
	Verbose 1 "\nWriting out the auth shadow files..."
	for user in "${users[@]}"; do
		if [[ ${userData["$user.authGroups"]+abc} ]]; then
			Verbose 1 "^$user"
			unset authGroups userScripts
			aData="${userData["$user.authGroups"]}"
			aData="$(printf '%s\n' ${aData//,/ } | sort -u)"
			sData="${userData["$user.scripts"]}"
			sData="$(printf '%s\n' ${sData//,/ } | sort -u)"
			user="${user#*|}";
			Verbose 1 "^$user"
			for token in ${aData//,/ }; do
				authGroups="$authGroups,${token#*|}"
			done
			authGroups="${authGroups:1}"
			for token in ${sData//,/ }; do
				userScripts="$userScripts,${token#*|}"
			done
			userScripts="${userScripts:1}"
		 	outFile="${authShadowDir}/${user}"
		 	[[ -f $outFile ]] && cp -fp "$outFile" "${outFile}.bak"
		 	## Header
		 	echo "## DO NOT EDIT VALUES IN THIS FILE, THE FILE IS AUTOMATICALLY GENERATED ($(date)) FROM THE CLIENTS/SITES TABLES IN THE DATA WAREHOUSE" > "${outFile}.new"
		 	## list of groups
		 	echo "${authGroups}" >> "${outFile}.new"
		 	## List of scripts
		 	echo "${userScripts}" >> "${outFile}.new"
		 	## Scripts details
		 	for scriptName in ${userScripts//,/ }; do
		 		echo "${scriptsData["$scriptName"]}" >> "${outFile}.new"
		 	done
		 	## Cleanup and set ownership/permissions
		 	rm -f "$outFile"
		 	mv -f "${outFile}.new" "$outFile"
			chmod 640 "$outFile"
			chown "$userName:leepfrog" "$outFile"
		fi
		Dump 2 -t authGroups userScripts
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
