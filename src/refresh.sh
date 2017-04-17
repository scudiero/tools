#!/bin/bash
#==================================================================================================
version=1.3.102 # -- dscudiero -- Mon 04/17/2017 @ 12:29:46.01
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
		#argList+=(-listOnly,1,switch,listOnly,,script,"Do not do copy, only list out files that would be copied")
		:
	}

#==================================================================================================
# Declare local variables and constants
#==================================================================================================
ParseArgsStd
if [[ $userName == 'dscudiero' ]]; then
	refreshObjs+=('VBA')
	refreshObjs+=('wharehouseSqliteShadow')
fi
refreshObjs+=('Courseleaf')
refreshObjs+=('CIM')
refreshObjs+=('Courseleaf_File')
refreshObjs+=('WorkflowCoreFiles')
refreshObjs+=('Internal')
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
# Refresh the users private dev internal site (internal-$userName) from shadow
#==============================================================================================
function internal {
	srcDir=$gitRepoShadow/courseleaf/master
	tgtDir="/mnt/internal/site/stage"
	if [[ $testMode == true ]]; then
		tgtDir="$HOME/internal/site/stage"
		[[ ! -d $tgtDir ]] && mkdir -p $tgtDir $tgtDir/web  $tgtDir/web/pagewiz $tgtDir/ribbit
	fi
	backupDir="$tgtDir/attic/web/pagewiz"

	[[ ! -d $srcDir ]] && Msg2 $T "Could not locate srcDir: $srcDir"
	[[ ! -f $srcDir/.syncDate ]] && Msg2 $T "Git repository is being updated, please try again later"
	[[ ! -d $tgtDir ]] && Msg2 $T "Could not locate tgtDir: $tgtDir"

	## Make sure the user wants to continue
		unset verifyArgs
		verifyArgs+=("Source Dir:$srcDir")
		verifyArgs+=("Target Dir:$tgtDir")
		VerifyContinue "You are asking to refresh the internal site:"

	## Copy files using rsync
		[[ $quiet == true || $quiet == 1 ]] && rsyncVerbose='' || rsyncVerbose='v'
		[[ $listOnly == true ]] && rsyncListonly="--dry-run" || unset rsyncListonly
		## Setup copy
			rsyncFilters=/tmp/$userName.rsyncFilters.txt
			printf "%s\n" '- *.git*' > $rsyncFilters
			printf "%s\n" '+ *.*' >> $rsyncFilters
			rsyncOpts="-rptb$rsyncVerbose --backup-dir $backupDir --prune-empty-dirs $rsyncListonly --include-from $rsyncFilters"
		## Do Copy
			Msg2 "^Syncing directories..."
			tmpErr=/tmp/$userName.$myName.rsyncErr.out
			$DOIT rsync $rsyncOpts "$srcDir/courseleaf/" $tgtDir/web/pagewiz 2>$tmpErr | xargs -I{} printf "\\t%s\\n" "{}"
			[[ $(cat $tmpErr | wc -l) -gt 0 ]] && Msg2 $T "rsync process failed, please review messages:\n$(cat $tmpErr)\n" || rm -f $tmpErr
			rm -f $rsyncFilters
		## Make sure permissions on the directory are correct
			$DOIT chmod 755 $tgtDir/web/pagewiz
		## Make sure we have a clver.txt file
			#if [[ ! -f $(dirname $tgtDir/web/${productDir}/$verFile) ]]; then
			#	[[ $product == 'cat' ]] && cp -fp $skeletonRoot/release/web/courseleaf/$verFile $(dirname $tgtDir/web/${productDir}/$verFile)
			#fi

	## Copy correct cgis
		Msg2; Msg2 "^Checking cgis..."
		unset pageleafCgiVer ribbitCgiVer
		## Get cgi source dir
			cgisDirRoot=$cgisRoot/rhel${myRhel:0:1}
			[[ ! -d $cgisDirRoot ]] && Msg2 $T "Could not locate cgi source directory:\n\t$cgiRoot"
			cwd=$(pwd)
			cd $cgisDirRoot
			cgisDir=$(ls -t | tr "\n" ' ' | cut -d ' ' -f1)
			cgisDir=${cgisDirRoot}/$cgisDir
			cd $cwd
		## Copy pagewiz.cgi
			unset srcFile srcMd5 tgtFile tgtMd5
			[[ -f $cgisDir/pagewiz.cgi ]] && srcFile="$cgisDir/pagewiz.cgi" || srcFile="$cgisDir/courseleaf.cgi"
			srcMd5=$(md5sum $srcFile | cut -f1 -d" ")
			tgtFile="$tgtDir/web/pagewiz/pagewiz.cgi"
			[[ -f $tgtFile ]] && tgtMd5=$(md5sum $tgtFile | cut -f1 -d" ")
			if [[ $srcMd5 != $tgtMd5 ]]; then
				$DOIT cp -bf "$srcFile" "$tgtFile"
				pageleafCgiVer=$($tgtDir/web/pagewiz/pagewiz.cgi -v | cut -d" " -f 3)
				Msg2 "^^pagwiz.cgi refreshed: $pageleafCgiVer"
			fi
		## Copy ribbit/index.cgi
			unset srcFile srcMd5 tgtFile tgtMd5
			srcFile="$cgisDir/ribbit.cgi"
			srcMd5=$(md5sum $srcFile | cut -f1 -d" ")
			tgtFile="$tgtDir/web/ribbit/index.cgi"
			[[ -f $tgtFile ]] && tgtMd5=$(md5sum $tgtFile | cut -f1 -d" ")
			if [[ $srcMd5 != $tgtMd5 ]]; then
				$DOIT cp -bf "$srcFile" "$tgtFile"
				ribbitCgiVer=$($tgtDir/web/ribbit/index.cgi -v | cut -d" " -f 3)
				Msg2 "^^ribbit/index.cgi refreshed: $ribbitCgiVer"
			fi
		## Make sure file permissions are set properly
			cgiFiles=($(find $tgtDir/web/pagewiz -name \*.cgi) $(find $tgtDir/web/ribbit -name \*.cgi))
			for file in "${cgiFiles[@]}"; do
				$DOIT chmod 755 $file
				$DOIT chmod 755 $(dirname $file)
			done
	## log updates in changelog.txt
		unset changeLogRecs
		changeLogRecs+=("Updated product: 'CAT' (to Master)")
		[[ $pageleafCgiVer != '' ]] && changeLogRecs+=("pagewiz cgi updated (to $pageleafCgiVer)")
		[[ $ribbitCgiVer != '' ]] && changeLogRecs+=("ribbit cgi updated (to $ribbitCgiVer)")
		WriteChangelogEntry 'changeLogRecs' "$tgtDir/changelog.txt"

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
