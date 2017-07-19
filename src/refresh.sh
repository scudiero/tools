#!/bin/bash
#==================================================================================================
version=1.3.119 # -- dscudiero -- Wed 07/19/2017 @ 15:26:40.97
#==================================================================================================
TrapSigs 'on'
imports='GetDefaultsData ParseArgs ParseArgsStd Hello Init Goodbye'
imports="$imports SelectMenu CopyFileWithCheck BackupCourseleafFile WriteChangelogEntry"
Import "$imports"
originalArgStr="$*"
scriptDescription="Refresh courseleaf components - dispatcher"

#==================================================================================================
## Copyright ©2014 David Scudiero -- all rights reserved.
## 06-17-15 -- 	dgs - Initial coding
#==================================================================================================
#==================================================================================================
# local functions
#==================================================================================================
	#==================================================================================================
	# parse script specific arguments
	#==================================================================================================
	function parseArgs-refresh {
		# argList+=(argFlag,minLen,type,scriptVariable,exCmd,helpSet,helpText)  #type in {switch,switch#,option,help}
		myArgList+=(-action,3,option,refreshObj,,script,'The action you wish to perform')
	}

#==================================================================================================
# Declare local variables and constants
#==================================================================================================
if [[ $userName == 'dscudiero' ]]; then
	refreshObjs+=('VBA')
	refreshObjs+=('wharehouseSqliteShadow')
fi
refreshObjs+=('Courseleaf')
refreshObjs+=('CGIs')
#refreshObjs+=('CIM')
refreshObjs+=('Courseleaf_File')
refreshObjs+=('WorkflowCoreFiles')
# refreshObjs+=('Internal')
refreshObjs+=('internalContacts-dbShadow')
refreshObjs+=('clientData')


#==================================================================================================
# Map specified refreshObj to the function name
#==================================================================================================
function mapRefreshObj {
	local refreshObj="$1"
	[[ $refreshObj == "internal-$userName" ]] && echo 'internal' && return
	[[ $refreshObj == "courseleaffile" ]] && echo 'courseleaf_file' && return
	echo "$(Lower "$refreshObj")"
	return 0
}

#==============================================================================================
# Refresh functions for each object
#==============================================================================================
#==============================================================================================
# WorkWith
#==============================================================================================
function vba {
	[[ $userName != 'dscudiero' ]] && Msg2 $T "Sorry you cannot refresh objects of type $refreshObj"
	## Get the list of vba applications
		srcDir="/home/dscudiero/windowsStuff/documents/Visual Studio 2015/Projects"
		cwd=$(pwd)
		cd "$srcDir"
		SetFileExpansion 'on'; projectDirs=$(ls -d -t "./"* 2> /dev/null | tr $'\n' ' ' | tr -d '.' | tr -d '/'); SetFileExpansion
		cd "$cwd"
		unset projects
		for project in $projectDirs; do
			projects+=($project)
		done
		Msg2 "Please specify the ordinal number of the source project\n"
		SelectMenu 'projects' 'project' '\nRefresh object ordinal(or 'x' to quit) > '
		[[ $project == '' ]] && Goodbye 0

	## Get the application name
		app=${project:0:${#project}-1}

	## Make sure the user wants to continue
		unset verifyArgs
		verifyArgs+=("Source Project:$project")
		verifyArgs+=("Target Application:$app")
		VerifyContinue "You are asking to refresh an vba application:"

	Msg2 "Refreshing '$app' from $project..."
	## Copy the application files
		srcDir="$HOME/windowsStuff/documents/Visual Studio 2015/Projects/$project/$project/bin/Release"
		tgtDir=$TOOLSPATH/bin
		[[ -d $tgtDir/$app-new ]] && rm -rf $tgtDir/$app-new
		[[ ! -d $tgtDir/$app-new ]] && mkdir -p $tgtDir/$app-new
		SetFileExpansion 'on';
		cp -rfp "$srcDir/"* $tgtDir/$app-new;
		SetFileExpansion
		cd "$tgtDir/$app-new"
	## Rename / Edit the files
		for file in $(ls); do
			fileExt=${file##*.}
			if [[ $fileExt == 'config' || $fileExt == 'manifest' ]]; then
				sed -i s"/$project/$app/g" $file
			fi
			[[ $(Contains "$file" "$project") == true ]] && mv $file $(sed "s/$project/$app/g" <<< "$file")
		done
	## Set file permissions / set refresh date file
		chgrp -R leepfrog "$tgtDir/$app-new"
		chmod -R 750 "$tgtDir/$app-new"
		touch .refreshedFrom.$project
		[[ -d $tgtDir/$app ]] && mv $tgtDir/$app $tgtDir/archive/$app-$(date +"%H%M%S")
		mv -f $tgtDir/$app-new $tgtDir/$app
	cd "$cwd"
	Msg2 "Production '$app' refreshed from $project"
	return 0
}

#==============================================================================================
# wharehousesqliteshadow
#==============================================================================================
function wharehousesqliteshadow {
	if [[ ${myRhen:0:1} -gt 5 ]]; then
		buildWarehouseSqlite
		Msg2 "You need to copy the workflow.sqlite file\n\t$HOME/warehouse.sqlite\ne"
		Msg2 "to the internal-stage location:\n\t$HOME/internal/stage/db/warehouse.sqlite"
		Msg2 "From BUILD5"
	else
		Msg2 $T "This process can only be run from an rhel6 or better system"
	fi
	return 0
}

#==============================================================================================
# Refresh Courseleaf
#==============================================================================================
function courseleaf {
	$DOIT patchCourseleaf $originalArgStr -product 'cat'
	return 0
}

#==============================================================================================
# Refresh CIM
#==============================================================================================
function courseleaf {
	$DOIT patchCourseleaf $originalArgStr -product 'cim'
	return 0
}

#==============================================================================================
# Refresh a courseleaf file
#==============================================================================================
function courseleaf_file {
	$DOIT refreshCourseleafFile $originalArgStr
	return 0
}

#==============================================================================================
# Refresh a courseleaf file
#==============================================================================================
function cgis {
	Init "getClient getEnv getDirs checkEnvs"
	#dump env siteDir

	## Get the cgisDir
		courseleafCgiDirRoot="$skeletonRoot/release/web/courseleaf"
		useRhel="rhel${myRhel:0:1}"
		courseleafCgiSourceFile="$courseleafCgiDirRoot/courseleaf.cgi"
		[[ -f "$courseleafCgiDirRoot/courseleaf-$useRhel.cgi" ]] && courseleafCgiSourceFile="$courseleafCgiDirRoot/courseleaf-$useRhel.cgi"
		courseleafCgiVer="$($courseleafCgiSourceFile -v  2> /dev/null | cut -d" " -f3)"
		#dump courseleafCgiSourceFile courseleafCgiVer

		ribbitCgiDirRoot="$skeletonRoot/release/web/ribbit"
		ribbigCgiSourceFile="$ribbitCgiDirRoot/index.cgi"
		[[ -f "$ribbitCgiDirRoot/courseleaf-$useRhel.cgi" ]] && ribbigCgiSourceFile="$ribbitCgiDirRoot/index-$useRhel.cgi"
		ribbitCgiVer="$($ribbigCgiSourceFile -v  2> /dev/null | cut -d" " -f3)"
		#dump ribbigCgiSourceFile ribbitCgiVer

		result=$(CopyFileWithCheck "$courseleafCgiSourceFile" "${siteDir}/web/courseleaf/courseleaf.cgi" 'courseleaf')
		if [[ $result == true ]]; then
			Msg2 "^^Updated: '/courseleaf/courseleaf.cgi' to version $courseleafCgiVer"
		elif [[ $result == same ]]; then
			Msg2 "^^'/courseleaf/courseleaf.cgi' is current (version: $courseleafCgiVer)"
		else
			Error 0 2 "Could not copy '/courseleaf/courseleaf.cgi',\n^^$result"
		fi

		result=$(CopyFileWithCheck "$ribbigCgiSourceFile" "${siteDir}/web/ribbit/index.cgi" 'courseleaf')
		if [[ $result == true ]]; then
			Msg2 "^^Updated: '/ribbit/index.cgi' to version $ribbitCgiVer"
		elif [[ $result == same ]]; then
			Msg2 "^^'/ribbit/index.cgi' is current (version: $ribbitCgiVer)"
		else
			Error 0 2 "Could not copy '/ribbit/index.cgi',\n^^$result"
		fi

		## See if this client has the new focussearch
	 	if [[ ! -f ${tgtDir}/web/search/results.tcf ]]; then
			grepFile="${tgtDir}/web/search/index.tcf"
			if [[ -r $grepFile ]]; then
				grepStr=$(ProtectedCall "grep '^template:catsearch' $grepFile")
				if [[ -n $grepStr ]]; then
					result=$(CopyFileWithCheck "$ribbigCgiSourceFile" "${siteDir}/web/search/index.cgi" 'courseleaf')
					if [[ $result == true ]]; then
						Msg2 "^^Updated: '/ribbit/index.cgi' to version $ribbitCgiVer"
					elif [[ $result == same ]]; then
						Msg2 "^^'/search/index.cgi' is current (version: $ribbitCgiVer)"
					else
						Error 0 2 "Could not copy '/search/index.cgi',\n^^$result"
					fi
				fi
			fi
	 	fi

	return 0
}

#==============================================================================================
# Refresh the /stdhtml/workflow.atj file
#==============================================================================================
function workflowcorefiles {
	local file srcFile tgtFile result changeLogRecs
	Init 'getClient getEnv getDirs checkEnv'
	echo

	local sqlStmt="select scriptData3 from $scriptsTable where name=\"copyWorkflow\""
	RunSql2 $sqlStmt
	[[ ${#resultSet[@]} -eq 0 ]] && Terminate "Could not retrieve workflow files data (scriptData1) from the $scriptsTable.";
	local scriptData="$(cut -d':' -f2- <<< ${resultSet[0]})"

	for file in $(tr ',' ' ' <<< $scriptData); do
		[[ $file == 'roles.tcf' || ${file##*.} == 'plt' ]] && continue
		srcFile="$skeletonRoot/release/web${file}"
		tgtFile="$srcDir/web${file}"
		## Copy file if changed
			result=$(CopyFileWithCheck "$srcFile" "$tgtFile" 'backup')
			if [[ $result == true ]]; then
				changeLogRecs+=("Updated: $file")
				WriteChangelogEntry 'changeLogRecs' "$srcDir/changelog.txt"
				Msg2 "^'$file' copied"
			elif [[ $result == 'same' ]]; then
				Msg2 "^'$file' - md5's match, no changes made"
			else
				Msg2 $T "Error copying file:\n^$result"
			fi
	done
	return 0
}

#==============================================================================================
# Refresh courseleaf/stdhtml/workflow.atj
#==============================================================================================
function internalcontacts-dbshadow {
	if [[ $hostName == 'build5' ]]; then
		srcDir=/home/dscudiero/internal
		tgtDir=$TOOLSPATH/internalContactsDbShadow
		$DOIT rsync -aq $srcDir/stage/db/ $tgtDir 2>&1 | xargs -I -0 {} printf "\t%s\n" "{}"
		$DOIT cp $srcDir/contactsdb/contacts.sqlite $tgtDir
		$DOIT chmod 770 $tgtDir
		$DOIT chmod 770 $tgtDir/*
		$DOIT touch $tgtDir/.syncDate
	else
		Msg2 "${colorWarning}This action must be run on the build5 server, starting an ssh session${colorDefault}"
		$DOIT ssh $userName@build5.leepfrog.com $myPath/$myName $refreshObj
	fi
	return 0
}

#==============================================================================================
# wharehousesqliteshadow
#==============================================================================================
function clientData {
	echo; Msg2 "*** $FUNCNAME -- Starting ***"
	srcDir=$clientsTransactionalDb
	tgtDir=$internalContactsDbShadow
	SetFileExpansion 'on'
	rsync -av $srcDir/* $tgtDir > /dev/null 2>&1
	chmod 770 $tgtDir
	chmod 770 $tgtDir/*
	touch $tgtDir/.syncDate
	cwd=$(pwd); cd $tgtDir; chgrp -R leepfrog *; chgrp leepfrog .*; cd "$cwd"
	SetFileExpansion

	local file srcFile tgtFile result changeLogRecs
	Init 'getClient getEnv getDirs checkEnv'
	echo
	buildClientInfoTable $client
	buildSiteInfoTable $client

	return 0
}


#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
helpSet='script'
GetDefaultsData $myName
ParseArgsStd
Hello
echo

if [[ $refreshObj == '' ]]; then
	[[ $batchMode != true && $noClear != true && $TERM != 'dumb' ]] && clear
	echo
	Msg2 "Please specify the ordinal number of the object type you wish to refresh\n"
	SelectMenu 'refreshObjs' 'refreshObj' '\nRefresh object ordinal(or 'x' to quit) > '
	[[ $refreshObj == '' ]] && Goodbye 0
fi

#==================================================================================================
## Main
#==================================================================================================
## call function to refresh the object
	[[ $batchMode != true && $noClear != true && $TERM != 'dumb' ]] && clear && echo
	echo
	Msg2 "Starting $(mapRefreshObj "$refreshObj")..."
	echo
	eval $(mapRefreshObj "$refreshObj")

#==================================================================================================
## Done
#==================================================================================================
Goodbye 0

#==================================================================================================
## Checkin Log
#==================================================================================================
# 08-28-2015 -- dscudiero -- Script to refresh leepfrog things (1.2)
# 10-23-2015 -- dscudiero -- updated for errexit (1.3)
## Wed Apr 27 16:22:25 CDT 2016 - dscudiero - Switch to use RunSql
## Fri Apr 29 12:36:58 CDT 2016 - dscudiero - Refactored
## Thu May 12 15:52:59 CDT 2016 - dscudiero - Add Workwith
## Tue May 24 07:33:48 CDT 2016 - dscudiero - Update workwith subscript to update latest version
## Fri May 27 11:09:09 CDT 2016 - dscudiero - Total re-write of the workwith section
## Fri May 27 15:00:05 CDT 2016 - dscudiero - General syncing of dev to prod
## Thu Jun  2 15:51:44 CDT 2016 - dscudiero - Removed the comment
## Thu Jun 16 16:04:29 CDT 2016 - dscudiero - Fix problem when running from tools.git
## Fri Jun 17 09:44:54 CDT 2016 - dscudiero - Fix errant c in first line
## Tue Jul  5 07:36:40 CDT 2016 - dscudiero - Update code to get current cgi directory
## Fri Jul  8 15:33:15 CDT 2016 - dscudiero - General syncing of dev to prod
## Fri Jul  8 15:34:27 CDT 2016 - dscudiero - General syncing of dev to prod
## Wed Aug  3 16:00:01 CDT 2016 - dscudiero - Added refresh internal
## Wed Aug  3 16:07:43 CDT 2016 - dscudiero - Create test directories if testMode and target directories do not exist
## Wed Aug 31 15:48:47 CDT 2016 - dscudiero - Add file name to messages if files are the same for refreshCimCore
## Thu Sep 29 12:54:25 CDT 2016 - dscudiero - Do not clear screen if TERM=dumb
## Mon Oct 17 07:51:17 CDT 2016 - dscudiero - add testworkflow.html to refresh core workflow files
## Mon Oct 17 11:32:07 CDT 2016 - dscudiero - Updated to reflect new name for courseleafPatch
## Tue Oct 18 11:07:04 CDT 2016 - dscudiero - Fix problem loging changes to changelog.txt in core workflow files
## Wed Jan  4 10:29:52 CST 2017 - dscudiero - add missing items to imports
## Tue Jan 10 16:17:06 CST 2017 - dscudiero - Fix problem making backup in vba refresh
## Wed Feb  8 08:24:32 CST 2017 - dscudiero - Switch refresh workflowCore to pull file names from saveWorkflow defaults data
## Fri Feb 10 09:01:16 CST 2017 - dscudiero - Parse client name and env if passed in
## 03-30-2017 @ 10.08.22 - (1.3.101)   - dscudiero - Do not overwrite roles.tcf or *.plt files when refreshing workflowCoreFiles
## 04-17-2017 @ 12.30.38 - (1.3.102)   - dscudiero - add clientData
## 07-19-2017 @ 14.37.52 - (1.3.103)   - dscudiero - Remove the Internal section
## 07-19-2017 @ 14.55.27 - (1.3.105)   - dscudiero - General syncing of dev to prod
## 07-19-2017 @ 14.57.45 - (1.3.106)   - dscudiero - General syncing of dev to prod
## 07-19-2017 @ 15.02.40 - (1.3.108)   - dscudiero - General syncing of dev to prod
## 07-19-2017 @ 15.04.38 - (1.3.110)   - dscudiero - General syncing of dev to prod
## 07-19-2017 @ 15.09.47 - (1.3.112)   - dscudiero - General syncing of dev to prod
## 07-19-2017 @ 15.13.11 - (1.3.114)   - dscudiero - General syncing of dev to prod
## 07-19-2017 @ 15.16.26 - (1.3.115)   - dscudiero - General syncing of dev to prod
## 07-19-2017 @ 15.24.06 - (1.3.117)   - dscudiero - Add cgis action
## 07-19-2017 @ 15.26.58 - (1.3.119)   - dscudiero - add -action flag
