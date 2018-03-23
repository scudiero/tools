#!/bin/bash
#==================================================================================================
version=1.0.17 # -- dscudiero -- Fri 03/23/2018 @ 14:42:38.70
#==================================================================================================
TrapSigs 'on'
myIncludes=""
Import "$standardInteractiveIncludes $myIncludes"

originalArgStr="$*"
scriptDescription="Check the roles to ensure that all role members are in user provsioning"

#==================================================================================================
# Interogate the roles file and verify that all the users listed in roles are in provsioning
# (in the clusers database)
#==================================================================================================
#==================================================================================================
# Copyright ©2014 David Scudiero -- all rights reserved.
# 06-17-15 -- 	dgs - Initial coding
# 07-17-15 -- dgs - Migrated to framework 5
#==================================================================================================

#==================================================================================================
# local functions
#==================================================================================================

#==================================================================================================
# Declare local variables and constants
#==================================================================================================

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
helpSet='script,client,env'
GetDefaultsData $myName
ParseArgsStd $originalArgStr
Hello
Init 'getClient getEnv getDirs checkEnvs'

## Set outfile -- look for std locations
outFileName=$client-$env-$myName.txt
if [[ -d $localClientWorkFolder ]]; then
	if [[ ! -d $localClientWorkFolder/$client ]]; then mkdir $localClientWorkFolder/$client; fi
	outFile=$localClientWorkFolder/$client/$outFileName
else
	outFile=/home/$userName/$outFileName
fi

verifyArgs+=("Client:$client")
verifyArgs+=("Env:$(TitleCase $env)")
verifyArgs+=("Output File:$outFile")
verifyContinueDefault='Yes'
VerifyContinue "You are asking to check role data for client:$client\n\tEnv: $env\n"
Msg

#==================================================================================================
## Main
#==================================================================================================
## check outfile
	if [[ -f $outFile ]]; then
		Warning "Output file already exists, renaming to\n\t$outFile.$backupSuffix\n"
		mv $outFile $outFile.$backupSuffix
	fi

## Get members roles file
	unset numFound
	unset users
	Msg "Processing Roles file..."
	while IFS='' read -r line || [[ -n $line ]]; do
		#role:AABS Approver|JB_Ashorn|all
		if [[ ${line:0:5} == 'role:' ]]; then
	    	role=$(echo $(echo $line | cut -d ':' -f 2) | cut -d '|' -f 1)
	    	members=$(echo $(echo $line | cut -d '|' -f 2) | tr ',' ' ')
	      	#Verbose 1 1 "Role: $role\n^Members: >$members<"
	      	IFSsave=$IFS; IFS=' '
		    for user in $members; do
		    	#Verbose 1 2 "user = >$user<"
				users+=($user)
		    done
		    IFS=$IFSsave
		fi
	done < "$srcDir/web/courseleaf/roles.tcf"

## Sort the list, through away duplicates
	usersSorted=($(for user in "${users[@]}"; do echo "$user"; done | sort))
	unset users
	unset prevUser
	for user in "${usersSorted[@]}"; do
		if [[ $user != $prevUser ]]; then
			users+=($user)
			(( numFound +=1 ))
		fi
		prevUser=$user
	done
	Msg "^Found $numFound unique userids"

## Process the user list
	printedHeader=false
	unset numFound
	Msg "Processing User list..."
	for user in "${users[@]}"; do
		sqlStmt="select count(*) from users where userid=\"$user\";"
		results=$(sqlite3 /$srcDir/db/clusers.sqlite "$sqlStmt")
		#Verbose "\nUser: '$user'\n\t\tsqlStmt = >$sqlStmt<\n\t\tresults=>$results<"
		if [[ $results -eq 0 ]]; then
			grep -q "user\:$user\|" "$srcDir/courseleaf.cfg"; rc=$?
			if [[ $rc -ne 0 ]]; then
				[[ $printedHeader == false ]] && Msg "The following users were not found in User Provisioning:"
				printedHeader=true
				Msg "^$user" | tee -a $outFile
				(( numFound +=1 ))
			fi
		fi
	done
## Print summary
	echo
	if [[ $numFound -eq 0 ]]; then
		Msg "^All role members are provisioned or listed on a courseleaf.cfg user record"
		rm -f "$outFile" >& /dev/null
	else
		Msg "^Found $numFound users in roles that are not known"
		Msg "\nOutput file: $outFile"
	fi

#==================================================================================================
## Done
#==================================================================================================
Goodbye 0 #'alert'

#==================================================================================================
## Check-In Log
#==================================================================================================
## Fri Oct 14 13:37:34 CDT 2016 - dscudiero - Fix spelling problem
## 06-19-2017 @ 07.07.26 - (1.0.12)    - dscudiero - Update to check courseleaf.cfg user records also
## 03-22-2018 @ 12:35:44 - 1.0.16 - dscudiero - Updated for Msg3/Msg, RunSql2/RunSql, ParseArgStd/ParseArgStd2
## 03-23-2018 @ 15:32:32 - 1.0.17 - dscudiero - D
