#!/bin/bash
# XO NOT AUTOVERSION
#==================================================================================================
version="4.14.59" # -- dscudiero -- Tue 06/11/2019 @ 12:13:04
#==================================================================================================
TrapSigs 'on'
myIncludes="GetSiteDirNoCheck ProtectedCall RunCourseLeafCgi PushPop GetCims StringFunctions SetSiteDirsNew"
Import "$standardInteractiveIncludes $myIncludes"
[[ $1 == $myName ]] && shift
originalArgStr="$*"
scriptDescription="Copy a CourseLeaf site from one env to another"

#==================================================================================================
# Make a copy of the next environment in a dev site (a new developer named site or overlay real dev site)
# Turns off authentication in the resulting site
#==================================================================================================
# Copyright ©2015 David Scudiero -- all rights reserved.
# 04-24-13 -- 	dgs - Initial coding
# 05-01-13 -- 	dgs - Added code to stop and then resume after an external republish is done
#							Added make bubble step
#							Started undo -- not quite finished
# 05-14-13 -- dgs - Check for host = host in sendnow.atj. apparent change in skeleton
# 05-23-13 -- dgs - pulled undo -- major cleanup
# 01-02-14 -- dgs - fixed auth edits
# 02-04-14 -- dgs - Added roles.tcf to CIM sync.
# 03-11-14 -- dgs - Edit the sendnow.atj to set testaddder email address to current user
# 05-15-14 -- dgs -	Convert to use Prompt
# 06-23-14 -- dgs -	Added manifest creation
# 06-23-14 -- dgs -	Added private devs from a dev site
# 01-04-15 -- dgs - turn off manifests unless secified on command line
# 02-26-15 -- dgs - Add quiet mode to support cloneSites
# 07-17-15 -- dgs - Migrated to framework 5
# 09-30-15 -- dgs - Migrated to framework 6
#                   Added ability to clone a client hosted on another server
#                   Removed options to copy cim or cat, now we copy entire site
#==================================================================================================

#==================================================================================================
# local functions
#==================================================================================================
#==================================================================================================
# Standard call back functions
#==================================================================================================
	# function copyEnv-ParseArgsStd {
	# 	#myArgs+=("shortToken|longToken|type|scriptVariableName|<command to run>|help group|help textHelp")
	# 	myArgs+=('overl|overlay|switch|overlay||script|Overlay/Replace any existing target directories')
	# 	myArgs+=('refre|refresh|switch|refresh||script|Refresh any existing target directories')
	# 	myArgs+=('overr|overrideTarget|option|overrideTarget||script|Override the default target location, full file spec to where the site root should be located. e.g. /mnt/dev7/web')
	# 	myArgs+=('full|fullcopy|switch|fullCopy||script|Do a full copy, including all log and request files')
	# 	myArgs+=('suffix|suffix|option|suffix||script|Suffix text to be append to the resultant site name, e.g. -lu')
	# 	myArgs+=('skipca|skipcat|switch|skipCat||script|Skip clients CAT directories, i.e. web directories not in the skeleton')
	# 	myArgs+=('skipci|skipcim|switch|skipCim||script|Skip CIM and CIM instance files')
	# 	myArgs+=('skipcl|skipclss|switch|skipClss||script|Skip CLSS/WEN instance files')
	# 	myArgs+=('skipwe|skipwen|switch|skipClss||script|Skip CLSS/WEN instance files')
	# 	myArgs+=('skipal|skipalso|switch|skipClss||script|Additional directories and or files to ignore| comma separated list')
	# 	myArgs+=('debug|debug|switch|startWizdebug||script|Automatically start a wizDebug session after the copy')
	# 	myArgs+=('lock|lock|option|lockWorkflows||script|Lock the specified workflow(s) in the source environment')
	# 	myArgs+=('as|asSite|option|asSite||script|The name to give the new site, i.e. tgtDir-asSite')
	# }

	function copyEnv-Goodbye {
		SetFileExpansion 'on' ; rm -rf $tmpRoot/${myName}* >& /dev/null ; SetFileExpansion
		return 0
	}

	function copyEnv-testMode  { # or testMode-local
		[[ $hostName == 'mojave' ]] && client='worcester' || client='apus'
		env='next'
		srcDir="$HOME/testData/next"
		srcEnv="next"
		tgtDir="$HOME/testData/test"
		tgtEnv="test"
		return 0
	}

	function copyEnv-Help  {
		helpSet='client,src,tgt' # can also include any of {env,src,tgt,prod,cim,cat,clss}, 'script' and 'common' automatically addeed

		[[ -z $* ]] && return 0
		echo -e "This script can be used to refresh a CourseLeaf site from another one"
		echo -e "\nThe actions performed are:"
		bullet=1; echo -e "\t$bullet) Refreshes the target site from the source based on the options supplied by the user, if the target site already exists then the user is prompted to see if they want to refresh or overwrite"
		(( bullet++ ))
		echo -e "\nIf the target site is a 'dev' or 'pvt' site then the following modifications are done on the target site"

		bullet=1; echo -e "\t$bullet) External authentication is turned off"
		(( bullet++ )); echo -e "\t$bullet) Publishing is turned off"
		(( bullet++ )); echo -e "\t$bullet) PDF Generation is turned off"
		(( bullet++ )); echo -e "\t$bullet) A default 'leepfrog' admin account is created, a default user non-admin account is created with a name the same as the client code"
		(( bullet++ )); echo -e "\t$bullet) The 'nexturl' tcfdata value is updates to point to the target instance"
		(( bullet++ )); echo -e "\t$bullet) CourseLeaf emailing is overridden with a testaddder for '$userName'"
		echo -e "\nTarget site data files potentially modified:"
		echo -e "\t- All site files on the target site"
		echo -e "\t If target is a dev or pvt site then specifically:"
		echo -e "\t\t.../courseleaf.cfg"
		echo -e "\t\t.../web/courseleaf/localsteps/defaults.tcf"
		echo -e "\t\t.../web/admin/wfemail/index.tcf -- if new email"
		echo -e "\t\t.../email/sendnow.atj -- if old email"
		return 0
	}

#==================================================================================================
# Script specific argument definitions for parseArgs
#==================================================================================================
myArgs="overl|overlay|switch|overlay|;"
myArgs+="refre|refresh|switch|refresh|;"
myArgs+="overr|overrideTarget|option|overrideTarget|;"
myArgs+="full|fullcopy|switch|fullCopy|;"
myArgs+="suffix|suffix|option|suffix|;"
myArgs+="skipca|skipcat|switch|skipCat|;"
myArgs+="skipci|skipcim|skipCim|scriptVar3|;"
myArgs+="skipcl|skipclss|switch|skipClss|;"
myArgs+="skipwe|skipwen|switch|skipClss|;"
myArgs+="skipal|skipalso|switch|skipAlso|;"
myArgs+="debug|debug|switch|startWizdebug|;"
myArgs+="lock|lock|switch|lockWorkflows|;"
myArgs+="as|asSite|option|asSite|;"
myArgs+="rsync|rsyncSrcDir|option|rsyncSrcDir|;"
export myArgs="$myArgs"

#==================================================================================================
# Declare local variables and constants
#==================================================================================================
rsyncFilters=$(mkTmpFile 'rsyncFilters')
refresh=false
overlay=false
specialSource=false
fullCopy=false
unset suffix email clientHost remoteCopy
progDir='courseleaf'
haveCims=false
haveClss=false
lockWorkflow=false

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
SetDefaults $myName
ParseArgs $originalArgStr
Hello

[[ -n $envs && -z $srcEnv ]] && srcEnv="$env"
[[ $allItems == true || $fullCopy == true ]] && overlay=false

addPvt=true

if [[ -n $products ]]; then
	skipCat=true; skipCim=true; skipClss=true; unset skipAlso;
	[[ $(Contains "$products" 'cat') == true ]] && skipCat=false
	[[ $(Contains "$products" 'cim') == true ]] && skipCim=false
	[[ $(Contains "$products" 'clss') == true ]] && skipClss=false
fi
dump 2 -n client env envs product products fullCopy overlay suffix email skipCat skipCim skipClss skipAlso srcEnv tgtEnv rsyncSrcDir altEnv -p

## Resolve data based on passed in client, handle special cases
	tmpStr="${client:0:5}"; tmpStr=${tmpStr,,[a-z]}
	if [[ $tmpStr == 'luc20' && ${srcEnv:0:1} == 'p' && ${tgtEnv:0:1} == 'p' ]]; then
		srcEnv='pvt'
		srcDir="/mnt/dev7/web/lilypadu-$userName"
		[[ ! -d "$srcDir" ]] && srcEnv='next' && srcDir='/mnt/lilypadu/site/next'
		tgtEnv='pvt'
		tgtDir="/mnt/dev7/web/luc$(date "+%Y")"
		[[ -n $asSite ]] && tgtDir="$tgtDir-$asSite"
		email='disabled'
	elif [[ $client == 'lilypadu' ]]; then
		srcEnv='next'
		srcDir='/mnt/lilypadu/site/next'
		tgtEnv='pvt'
		tgtDir="/mnt/dev7/web/lilypadu-$userName"
		email='disabled'
	elif [[ $client == 'internal' ]]; then
		srcEnv='next'
		srcDir='/mnt/internal/site/stage'
		tgtEnv='pvt'
		tgtDir="/mnt/dev11/web/internal-$userName"
		progDir='pagewiz'
	else
		Init 'getClient'
		
		if [[ $noCheck == true ]]; then
			GetSiteDirNoCheck $client "For the $(ColorK 'Source'), do you want to work with '$client's development or production env"
			srcEnv="$env"; srcDir="$siteDir"; unset env
			Init 'getTgtEnv getDirs addPvt'
		else
			if [[ -z $rsyncSrcDir ]]; then
				if [[ $srcEnv == "alt" ]]; then
					srcDir="$altEnv"
					Init 'getTgtEnv getDirs'
				else
					Init 'getSrcEnv getTgtEnv getDirs addPvt'
				fi
				env="$srcEnv"
			else
				[[ ${rsyncSrcDir:0:2} == "//" ]] && srcDir="/mnt/${rsyncSrcDir:2}"
				tgtEnv="pvt"
				SetSiteDirs 'setDefault'
				tgtDir="$pvtDir"
			fi
		fi
	fi
dump 1 client env srcEnv srcDir tgtEnv tgtDir rsyncSrcDir -p

ignoreList=$(sed "s/<progDir>/$progDir/g" <<< $ignoreList)
mustHaveDirs=$(sed "s/<progDir>/$progDir/g" <<< $(cut -d":" -f2 <<< $scriptData1))
mustHaveFiles=$(sed "s/<progDir>/$progDir/g" <<< $(cut -d":" -f2 <<< $scriptData2))
dump -1 ignoreList mustHaveDirs mustHaveFiles

[[ $srcEnv == $tgtEnv ]] && Terminate "Source environment and target environment are the same"

## check to see if this client is remote or on another host
	Verbose 1 "\${clientData["${client}.code"]} = '${clientData["${client}.code"]}'"
	if [[ $client != 'internal' && $client != 'lilypadu' && $noCheck != true ]]; then
		if [[ ${clientData["${client}.code"]+abc} ]]; then
			clientHost="${clientData["${client}.host"]}"
			clientHosting="${clientData["${client}.hosting"]}"
			[[ $clientHosting != 'leepfrog' ]] && Terminate 'Copying of remotely hosted sites is not supported at this time'
		else
			sqlStmt="select distinct $siteInfoTable.host from $clientInfoTable,$siteInfoTable \
					 where $clientInfoTable.name = \"$client\" and $clientInfoTable.name = $siteInfoTable.name"
					 # where $clientInfoTable.name = \"$client\" and $clientInfoTable.name = $siteInfoTable.name and hosting = \"leepfrog\""
			RunSql $sqlStmt
			[[ ${#resultSet} -eq 0 ]] && Terminate "Could not retrieve data for client ($client), env ($env) from the clientData hash table"
			clientHost="${resultSet[0]}"
		fi
		if [[ $clientHost != $hostName ]]; then
			Terminate "The client specified, '$client', is hosted on '$clientHost'.  Please start a session on that host and try again."
			# Msg "^Copying remote directory on '$clientHost', you will be prompted for your password on that server."
			# srcDir="ssh $userName@$clientHost.leepfrog.com:$srcDir"
			# remoteCopy=true
		fi
		dump -2 -t clientHost clientShare clientRhel srcDir
	else
		clientHost=$hostName
		clientRhel=$myRhel
	fi
	dump -2 -t srcDir devDir pvtDir remoteCopy -p

	if [[ -n $overrideTarget ]]; then
		[[ ${overrideTarget:(-1)} == '/' ]] && overrideTarget="${overrideTarget:0:${#overrideTarget}-1}"
		[[ ! -d $overrideTarget ]] && Msg && Terminate "Could not locate override target diectory: '$overrideTarget'"
		tgtDir="$overrideTarget/$client-$userName"
	fi
	if [[ -n $forUser ]]; then
		[[ -n $suffix ]] && Msg && Terminate "Cannot specify both 'forUser' and 'suffix'."
		userAccount="${forUser%%/*}"
		userPassword="${forUser##*/}"
		[[ -z $asSite ]] && tgtDir=$(sed "s/$userName/$forUser/g" <<< $tgtDir)
	fi
	[[ -n $suffix ]] && tgtDir=$(sed "s/$userName/$suffix/g" <<< $tgtDir)

## if target is not pvt or dev then do a full copy
	[[ $tgtEnv != 'pvt' && $tgtEnv != 'dev' ]] && { Info 0 1 "You are targeting a production environment, a full copy will be done"; fullCopy=true; }
	[[ $overlay == true && $refresh == true ]] && Terminate "Cannot specify both the -overlay and -refresh flags at the same time"
	[[ $overlay == true ]] && cloneMode='Replace' || cloneMode='Refresh'

#==================================================================================================
## Check to see if all dirs exist
	[[ -z $srcDir ]] && Terminate "Could not resolve the source directory ('$srcDir'), you may not have access."
	if [[ -d $tgtDir && $overlay == false  && $refresh == false ]]; then
		Msg
		unset ans
		Warning "Target site ($tgtDir) already existes."
		Prompt ans "Do you wish to $(ColorK 'overwrite') the existing site (Yes) or $(ColorK 'refresh') files in the existing sites site (No) ?" 'Yes No' 'Yes' 
		ans=${ans:0:1}; ans=${ans,,[a-z]}
		[[ $ans == 'y' ]] && cloneMode='Replace' || cloneMode='Refresh'
	fi

## See if we have any CIMs
	unset cimStr
	GetCims "$srcDir" -all
	[[ -n $cimStr ]] && haveCims=true

## See if we have CLSS
	[[ -d $srcDir/web/wen ]] && haveClss=true

## If full copy then skip all of the product prompts
 if [[ $fullCopy == true ]]; then
	skipCim=false
	skipCat=false
	skipClss=false
	skipAlso=false
 fi

#==================================================================================================
## See if there are any additional directories the user wants to skip
if [[ $verify == true && $fullCopy != true && -z $products ]]; then
	echo
	unset ans; Prompt ans "Do you wish to specify which file sets to EXCLUDE" 'No Yes' 'No'; ans=${ans:0:1}; ans=${ans,,[a-z]}
	if [[ $ans == 'y' ]]; then
		if [[ -z $skipCat ]]; then
			echo
			unset ans; Prompt ans "Do you wish to $(ColorK 'EXCLUDE') Client CAT files" 'No,Yes' 'No' '3'; ans=${ans:0:1}; ans=${ans,,[a-z]}
			[[ $ans == 'y' ]] && skipCat=true
		fi
		if [[ -z $skipCim && $haveCims == true ]]; then
			echo
			unset ans; Prompt ans "Do you wish to $(ColorK 'EXCLUDE') CIM & CIM instances" 'No,Yes' 'No' '3'; ans=${ans:0:1}; ans=${ans,,[a-z]}
			[[ $ans == 'y' ]] && skipCim=true
		fi
		if [[ -z $skipClss && $haveClss == true ]]; then
			echo
			unset ans; Prompt ans "Do you wish to $(ColorK 'EXCLUDE') CLSS/WEN" 'No,Yes' 'No' '3'; ans=${ans:0:1}; ans=${ans,,[a-z]}
			[[ $ans == 'y' ]] && skipClss=true
		fi

		if [[ -z $skipAlso && $cat != true && $cim != true && $clss != true ]]; then
			echo
			unset ans; Prompt ans "Do you wish to $(ColorK 'EXCLUDE') additional directories/files from the copy operation" 'No,Yes' 'No' '3'
			ans=${ans:0:1}; ans=${ans,,[a-z]}
			if [[ $ans == 'y' ]]; then
				SetFileExpansion 'off'
				Msg "^Please specify the directories/files you wish to exclude, use '*' as a the wild card,"
				Msg "^specifications are relative to siteDir, e.g. '/web/wen' without the quotes."
				Msg "^To stop the prompt loop, just enter no data"
				while true; do
					MsgNoCRLF "^^==> "
					read ignore
					[[ -z $ignore || ${ignore,,[a-z]} == 'x' ]] && break
					ignoreList="$ignoreList,$ignore"
					unset ignore
				done
				SetFileExpansion
			fi
		fi
	fi
fi

dump -1 skipCim skipCat skipClss skipAlso
## Skip files as indicated
	if [[ $skipCat == true ]]; then
		SetFileExpansion 'off'
		declare -A keepDirsHash
		keepDirs=($(find $skeletonRoot/release/web -mindepth 1 -maxdepth 1 -type d ! -path $skeletonRoot/release/web/$progDir))
		for keepDir in ${keepDirs[@]}; do
			keepDirsHash["${keepDir##$skeletonRoot/release}"]=true
		done
		keepDirsHash["/web/$progDir"]=true
		if [[ $skipCim != true && -n "$cimStr" ]]; then
			for cim in $(tr ',' ' ' <<< "$cimStr" ); do
				keepDirsHash["/web/$cim"]=true
			done
		fi
		dirs=($(find $srcDir/web -mindepth 1 -maxdepth 1 -type d))
		for dir in ${dirs[@]}; do
			dir="${dir##$srcDir}"
			[[ ${keepDirsHash["$dir"]+abc} ]] && continue
			ignoreList="$ignoreList,$dir"
		done
		ignoreList="$ignoreList,/production-shared,/web/shared,/web/$progDir/production/,/web/gallery"
		SetFileExpansion
	fi

	if [[ $skipCim == true ]]; then
		SetFileExpansion 'off'
		for cim in $(tr ',' ' ' <<< $cimStr); do
			ignoreList="$ignoreList,/web/$cim/"
		done
		ignoreList="$ignoreList,/web/$progDir/cim/"
		SetFileExpansion
	fi

	if [[ $skipClss == true ]]; then
		SetFileExpansion 'off'
		ignoreList="$ignoreList,/db/clwen*"
		ignoreList="$ignoreList,/bin/clssimport-log-archive/"
		ignoreList="$ignoreList,/web/$progDir/wen/"
		ignoreList="$ignoreList,/web/wen/"
		ignoreList="$ignoreList,/web/gallery"
		SetFileExpansion
	fi

	if [[ -n $skipAlso ]]; then
		SetFileExpansion 'off'
		for token in $(tr ',' ' ' <<< $skipAlso); do
			ignoreList="$ignoreList,$token"
		done
		SetFileExpansion
	fi

#==================================================================================================
## Make sure the user really wants to do this
[[ -n $rsyncSrcDir ]] && unset noPrompt
	unset verifyArgs
	verifyArgs+=("Client:$client")
	if [[ -n $rsyncSrcDir ]]; then
		verifyArgs+=("Source Env:N/A   $(ColorI "($srcDir)")")
	else
		verifyArgs+=("Source Env:$(TitleCase $srcEnv)   $(ColorV "($srcDir)")")
	fi
	verifyArgs+=("Target Env:$(TitleCase $tgtEnv)   $(ColorV "($tgtDir)")")
	tmpStr=$(sed "s/,/\n\t\t /g" <<< $ignoreList)
	[[ -n $forUser ]] && verifyArgs+=("For User:$forUser")
	[[ $skipCat == true && $fullCopy != true ]] && verifyArgs+=("Skip Cat:$skipCat")
	[[ $skipCim == true && $fullCopy != true ]] && verifyArgs+=("Skip CIM:$skipCim")
	[[ $skipClss == true && $fullCopy != true ]] && verifyArgs+=("Skip CLSS:$skipClss")
	[[ $fullCopy != true ]] && verifyArgs+=("Exclude List:$tmpStr") || verifyArgs+=("Full copy:$fullCopy")
	[[ -n $lockWorkflows ]] && verifyArgs+=("Lock workflow in target:$lockWorkflows")
	[[ $startWizdebug == true  ]] && verifyArgs+=("Auto start wizDebug:$startWizdebug")

	VerifyContinue "You are asking to clone/copy a CourseLeaf site:"

#==================================================================================================
## Check to see if the source is readable
	if [[ $client == 'internal' && ! -r $srcDir/pagewiz.cfg ]] || [[ $client != 'internal' && ! -r $srcDir/courseleaf.cfg ]]; then
		Terminate "Sorry you do not have read access to the source ($srcDir), please contact system admins"
	fi

#==================================================================================================
## Check to see if all dirs exist, if replace mode then delete if pvt otherwise rename
	if [[ -d $tgtDir && $cloneMode == 'Replace' ]]; then
		if [[ $tgtEnv == 'pvt' ]]; then
			mv -f $tgtDir $tgtDir.DELETE
			rm -rf $tgtDir.DELETE &
			forkedProcesses+=($!)
		else
			mv -f $tgtDir $tgtDir.bak
			[[ -d $tgtDir.bak ]] && Msg "Old target directory renamed to $tgtDir.bak" || Terminate "Target directory exists and could not be renamed"
		fi
	fi

#==================================================================================================
## Make sure targets exist
	if [[ ! -d $tgtDir ]]; then
		mkdir -p $tgtDir;
		chmod 777 $tgtDir;
	fi

#==================================================================================================
## Main
#==================================================================================================
#==================================================================================================
# Do the copy using rsync, including or excluding dirs as required
	if [[ -f $rsyncFilters ]]; then echo > $rsyncFilters; fi
	## Build rsync control file of excluded items
	SetFileExpansion 'off'
	for token in $(tr ',' ' ' <<< $ignoreList); do
		[[ -d $srcDir/$token && ${token: -1} != / ]] && token="${token}/"
		echo "- ${token}" >> $rsyncFilters
	done
	SetFileExpansion

	[[ $remoteCopy != true ]] && cd $srcDir
	[[ -z $DOIT ]] && listOnly='' || listOnly='--list-only'
	[[ $quiet == true || $quiet == 1 ]] && rsyncVerbose='' || rsyncVerbose='vh'
	if [[ $fullCopy == true ]]; then
		rsyncOpts="-a$rsyncVerbose $listOnly"
		Msg "Performing a FULL copy..."
	else
		rsyncOpts="-a$rsyncVerbose --prune-empty-dirs $listOnly --include-from $rsyncFilters"
	fi
	if [[ $remoteCopy == true ]]; then
		Msg "Calling rsync to copy the files, when prompted for password, please enter your password on '$clientHost' ..."
		rsyncOpts="${rsyncOpts} -e"
	else
		Msg "Calling rsync to copy the files ..."
	fi

	previousTrapERR=$(cut -d ' ' -f3- <<< $(trap -p ERR))
	trap - ERR
	Msg "\nrsync $rsyncOpts $srcDir/ $tgtDir\n" >> $logFile
	cat "$rsyncFilters" >> "$logFile"
	Indent ++; rsync $rsyncOpts $srcDir/ $tgtDir | Indent; Indent --
	eval "trap $previousTrapERR"
	[[ -f $rsyncFilters ]] && rm $rsyncFilters

if [[ $tgtEnv == 'pvt' || $tgtEnv == 'dev' ]]; then
	# Find the localsteps directory
	unset localstepsDir
	localstepsDir=$(ParseMapFile "$tgtDir" 'localsteps')
	[[ -z $localstepsDir ]] && localstepsDir="$tgtDir/web/courseleaf/localsteps"
	[[ ! -d $localstepsDir && -z $DOIT ]] && Terminate "Could not locate the localsteps directory ('$localstepsDir')"

	# Turn off publishing
		Msg "\nTurn off Publishing..."
		editFile="$tgtDir/$progDir.cfg"
		$DOIT sed -i s'_^mapfile:production_//mapfile:production_'g "$editFile"
		$DOIT sed -i s'_^mapfile:/navbar/production_//mapfile:/navbar/production_'g "$editFile"
		$DOIT sed -i s'_^//mapfile:production/|/dev/null_mapfile:production/|/dev/null_' "$editFile"
		$DOIT sed -i s'_^//mapfile:production|/dev/null_mapfile:production|/dev/null_' "$editFile"
		grepStr=$(ProtectedCall "grep '^mapfile:production.*/dev/null' $editFile")
		[[ -z $grepStr ]] && Warning "Could not locate a publishing mapfile record pointing to /dev/null, publising may still be active, please check before using clone site"

	# Turn off remote authenticaton
		Msg "Turn off Authentication..."
		editFile="$tgtDir/$progDir.cfg"
		$DOIT sed -i s'_^authuser:true_//authuser:true_' "$editFile"
		editFile="$tgtDir/web/$progDir/default.tcf"
		$DOIT sed -i s'_^authuser:true_//authuser:true_' "$editFile"
		$DOIT sed -i s'_^casurl:_//casurl:_' "$editFile"
		$DOIT sed -i s'_^loginurl:_//loginurl:_' "$editFile"
		$DOIT sed -i s'_^logouturl:_//logouturl:_' "$editFile"

		editFile="$localstepsDir/default.tcf"
		$DOIT sed -i s'_^authuser:true_//authuser:true_' "$editFile"
		$DOIT sed -i s'_^casurl:_//casurl:_' "$editFile"
		$DOIT sed -i s'_^loginurl:_//loginurl:_' "$editFile"
		$DOIT sed -i s'_^logouturl:_//logouturl:_' "$editFile"

	# Turn off PDF generation
		Msg "Turn off PDF generation..."
		$DOIT sed -i s'_^pdfeverypage:true$_//pdfeverypage:true_' "$editFile"

	# leepfrog user account
		Msg "Adding user-ids to $progDir.cfg file..."
		editFile="$tgtDir/$progDir.cfg"
		$DOIT echo "user:$leepfrogUserId|$leepfrogPw||admin" >> "$editFile"
		Msg "^'$leepfrogUserId' added as an admin with pw: '<normal pw>'"
		$DOIT echo "user:test|test||" >> "$editFile"
		Msg "^'test' added as a normal user with pw: 'test'"
		[[ $tmpStr != 'luc20' ]] && $DOIT echo "user:$client|$client||admin" >> "$editFile"
		$DOIT echo "user:$client|$client||admin" >> "$editFile"
		[[ -n $forUser ]] && $DOIT echo "user:$userAccount|$userPassword||admin" >> "$editFile"

	# Set nexturl so wf emails point to local instance
		Msg "Changing 'nexturl' to point to local instance..."
		editFile="$localstepsDir/default.tcf"
		clientToken=$(cut -d'/' -f5 <<< $tgtDir)
		toStr="nexturl:https://$clientToken.$(cut -d '/' -f3 <<< $tgtDir).leepfrog.com"
		unset grepStr; grepStr=$(ProtectedCall "grep "^$toStr" $editFile")
		if [[ -z $grepStr ]]; then
			unset fromStr; fromStr=$(ProtectedCall "grep '^nexturl:' $editFile")
			fromStr=$(CleanString "$fromStr")
			[[ -n $fromStr ]] && $DOIT sed -i s"!${fromStr}!${toStr}!" $editFile || Msg $WT1 "Could not set nexturl"
		fi

	## email override
		Msg "Override email routing..."
		[[ -z $email ]] && email=$userName@leepfrog.com
		editFile=$tgtDir/email/sendnow.atj
		unset grepStr; grepStr=$(ProtectedCall "grep ^'// DO NOT MODIFY THIS FILE' $editFile");
		if [[ -n $grepStr ]]; then
			## New format file
			if [[ -d $tgtDir/web/admin/wfemail ]]; then
				editFile=$tgtDir/web/admin/wfemail/index.tcf
			else
				editFile=$localstepsDir/default.tcf
			fi
			toStr="wfemail_testaddress:$email"
			unset fromStr; fromStr=$(ProtectedCall "grep ^'wfemail_testaddress:' $editFile")
			## Do we have multiples?
			if [[ -z $fromStr ]]; then
				echo $toStr >> $editFile
			else
				count=$(grep -o "wfemail_testaddress:" <<< $fromStr | wc -l)
				[[ $count -eq 1 ]] && $DOIT sed -i s"!${fromStr}!${toStr}!" $editFile || echo $toStr >> $editFile
			fi
		else
			## old format file
			toStr="var testaddress = \"$email\""
			unset grepStr; grepStr=$(ProtectedCall "grep '"$toStr"' $editFile")
			if [[ -z $grepStr ]]; then
				unset checkStr; checkStr=$(ProtectedCall "grep 'var type = \"cat\";' $editFile")
				fromStr=$checkStr
				$DOIT sed -i s"!${fromStr}!${toStr}\n\n${fromStr}!" $editFile
			fi
		fi

	## Make sure we have the required directories and files
		for dir in $(tr ',' ' ' <<< $mustHaveDirs); do
			[[ ! -d ${tgtDir}${dir} ]] && $DOIT mkdir ${tgtDir}${dir}
		done
		for file in $(tr ',' ' ' <<< $mustHaveFiles); do
			[[ ! -d ${tgtDir}${file} ]] && $DOIT touch ${tgtDir}${file}
		done

	## touch clone data and source file in root
		if [[ $tgtEnv == 'pvt' ]]; then
			$DOIT rm -f $tgtDir/.clonedFrom-* > /dev/null 2>&1
			$DOIT echo $srcEnv > $tgtDir/.clonedFrom
			echo
			Info "To act on private dev sites within the 'scripts' family of scripts you should specify 'pvt' as the environment name."
			Info "Remember you can use the 'cleanDev' script to easily remove private dev sites."
		fi
else
	echo
	Warning "Target of copy is '$tgtEnv', you should manually check the publishing settings in $progDir.cfg"
	echo
fi

## If are copying dev or pvt to test or next or curr then make sure the leepfrog user account has been removed
	if [[ $srcEnv == 'pvt' || $srcEnv == 'dev' ]] && [[ $tgtEnv == 'next' || $tgtEnv == 'test' || $tgtEnv == 'curr' ]]; then
		editFile="$tgtDir/courseleaf.cfg"
		unset grepStr; grepStr=$(ProtectedCall "grep '^user:leepfrog|0scys,btdeL||admin$' $editFile")
		if [[ -n $grepStr ]]; then
			fromStr="^user:leepfrog|0scys,btdeL||admin$"
			toStr="//user:leepfrog|0scys,btdeL||admin"
			$DOIT sed -i "s_${fromStr}_${toStr}_g" $editFile
		fi		
	fi

## If we have cims and user is 'dscudiero' and env = 'pvt' and onlyProduct='cim' then turn on debugging
	if [[  -n $cimStr && $userName == 'dscudiero' && $tgtEnv == 'pvt' && $skipCat == true && $skipClss == true ]]; then
		for cim in $(tr ',' ' ' <<< "$cimStr"); do
			editFile="$tgtDir/web/$cim/workflow.cfg"
			[[ ! -f $editFile ]] && continue
			unset grepStr; grepStr=$(ProtectedCall "grep '^wfDebugLevel:' $editFile")
			if [[ -n $grepStr ]]; then
				fromStr="$grepStr"
				toStr="wfDebugLevel:3"
				$DOIT sed -i s"_^${fromStr}_${toStr}_" $editFile
			fi
		done
	fi

## If we have cims and copying from test or next and lock is on then comment out workflow mgmt records on the console
	if [[ $srcEnv == 'next' || $srcEnv == 'test' ]] && [[ -n $lockWorkflows ]] && [[ $userName == 'dscudiero' ]]; then
		Warning "Disabling workflow modifications in the '${srcEnv^^[a-z]}' environment"
		editFile="$srcDir/web/courseleaf/index.tcf"
		for cim in $(tr ',' ' ' <<< "$lockWorkflows"); do
			[[ $(Contains "$cim" 'admin') != true ]] && cim="${cim}admin"
			unset grepStr; grepStr=$(ProtectedCall "grep "/$cim/workflow.html" "$editFile"")
			if [[ -n $grepStr  && ${grepStr:0:2} != '//' ]]; then
				fromStr="$grepStr"
				toStr="//$grepStr"
				$DOIT sed -i s"_^${fromStr}_${toStr}_" $editFile
				Msg "^CIM instance '$cim' Workflow Management record commented out"
			fi
		done
		RunCourseLeafCgi "$srcEnv" "-r /courseleaf/index.tcf"
	fi

#==================================================================================================
## Bye-bye
[[ -n $asSite ]] && msgText="$(ColorK "${aaSite^^[a-z]}")" || msgText="$(ColorK "${client^^[a-z]}")"

if [[ $startWizdebug == true ]]; then
	myIncludes="GetCourseleafPgm PrintBanner PushPop"
	Import "$standardInteractiveIncludes $myIncludes"
	Pushd "$tgtDir/web/courseleaf"
	clear
	echo -e "$colorKey"
	PrintBanner "tail wizdebug.out, Ctrl-C to stop"
	echo -e "$colorDefault"
	Alert 3
	tail -n 15 -f wizdebug.out
fi

Goodbye 0 'alert' "$msgText clone from $(ColorK "${env^^[a-z]}")"

# 10-16-2015 -- dscudiero -- Update for framework 6 (4.1)
# 10-21-2015 -- dscudiero -- Updated for Framework 6, errexit (4.4)
# 10-21-2015 -- dscudiero -- Update for framework 6 (4.5)
# 10-21-2015 -- dscudiero -- sync (4.6)
# 10-21-2015 -- dscudiero -- Update for errexit (4.7)
# 10-23-2015 -- dscudiero -- Use ProtectedCall function (4.8)
# 12-30-2015 -- dscudiero -- Added 'internal' site support (4.9.0)
## Mon Mar 28 10:51:42 CDT 2016 - dscudiero - General syncing of dev to prod
## Tue Apr  5 14:36:05 CDT 2016 - dscudiero - Remove protectedCall on the rsync call so rsync messages display realtime
## Mon Apr 11 08:34:13 CDT 2016 - dscudiero - Updated to handle an result of same from copywithcheck
## Wed Apr 13 11:01:00 CDT 2016 - dscudiero - Set emailaddress if -forUser is specified
## Thu Apr 14 13:08:13 CDT 2016 - dscudiero - Update some things if client is internal
## Thu Apr 14 16:23:33 CDT 2016 - dscudiero - Fix error processing arround rsync, make all edits based on progDir
## Mon Apr 18 11:15:24 CDT 2016 - dscudiero - seperated one liner for better error messaging
## Wed Apr 27 16:16:08 CDT 2016 - dscudiero - Switch to use RunSql
## Tue Jun 14 15:33:36 CDT 2016 - dscudiero - Generalized cloneEnv to allow env to env copies
## Fri Jul  8 16:49:30 CDT 2016 - dscudiero - Refactored the ignore list stuff
## Mon Jul 11 12:07:12 CDT 2016 - dscudiero - Make sure that there is a clienttransfers directory
## Mon Jul 11 12:33:39 CDT 2016 - dscudiero - refactor musthave directories and files to pul data from db
## Wed Jul 13 09:54:39 CDT 2016 - dscudiero - Fix bug setting script specific arguments
## Thu Jul 14 11:37:17 CDT 2016 - dscudiero - Add a prompt if the target environment is next or curr
## Thu Jul 14 13:29:10 CDT 2016 - dscudiero - General syncing of dev to prod
## Fri Jul 15 13:13:11 CDT 2016 - dscudiero - General syncing of dev to prod
## Thu Jul 21 09:34:03 CDT 2016 - dscudiero - Pull all exclude data from the database
## Fri Aug  5 14:34:25 CDT 2016 - dscudiero - Fix problem with multiple wfemail_testaddress in the file
## Fri Aug 26 09:02:07 CDT 2016 - dscudiero - Check to make sure the user can read the source diectories
## Tue Sep  6 08:35:14 CDT 2016 - dscudiero - Do not display the ignore list if -fullCopy specified
## Tue Sep  6 15:34:14 CDT 2016 - dscudiero - Update to check for site name validity -- removed anyClient on Init call
## Thu Sep 29 15:08:45 CDT 2016 - dscudiero - Add -debug option to automatically start wizdebug
## Wed Oct  5 09:46:57 CDT 2016 - dscudiero - Make the leepfrog userid and password varibles pulled from defaults
## Tue Oct 18 09:28:04 CDT 2016 - dscudiero - Fix problem where nocheck was still checking the client in the db
## Thu Jan 12 11:31:24 CST 2017 - dscudiero - Change overwrite prompt
## Thu Jan 19 10:25:30 CST 2017 - dscudiero - misc cleanup
## Thu Jan 19 10:38:39 CST 2017 - dscudiero - fixed problem with trying to use override target dir
## Fri Jan 20 12:48:30 CST 2017 - dscudiero - Add -nocheck support
## Tue Jan 24 16:21:14 CST 2017 - dscudiero - unset scriptArgs befor starting script
## Wed Jan 25 09:34:55 CST 2017 - dscudiero - x
## Wed Jan 25 10:13:47 CST 2017 - dscudiero - Fix problem where env was not set if nocheck was not active
## Wed Jan 25 12:45:03 CST 2017 - dscudiero - Added updating the nexturl variable in localsteps/default.tcf to match the local instance
## Thu Jan 26 13:39:37 CST 2017 - dscudiero - Fix problem setting nexturl value for pvt sites
## Fri Jan 27 07:56:11 CST 2017 - dscudiero - Fix problem for lilypadu
## Tue Feb 21 13:32:38 CST 2017 - dscudiero - add code for asSite and expand code for forUser
## Tue Feb 21 13:46:08 CST 2017 - dscudiero - General syncing of dev to prod
## Wed Feb 22 12:14:10 CST 2017 - dscudiero - Force emailaddress to disabled for LUC sites
## Wed Feb 22 15:35:25 CST 2017 - dscudiero - Tweak ending message if asSite is active
## Thu Feb 23 09:13:18 CST 2017 - dscudiero - Added ability for the user to exclude additional directories
## Thu Feb 23 10:08:24 CST 2017 - dscudiero - Fixed spelling error and tweaked messaging
## Fri Mar 10 10:31:17 CST 2017 - dscudiero - Added a timeout value to the exclued other prompt
## Tue Mar 14 14:48:56 CDT 2017 - dscudiero - add a timer on the exclude others prompt
## Thu Mar 16 09:39:01 CDT 2017 - dscudiero - Added new options to skip cims and clss files
## Fri Mar 17 10:46:03 CDT 2017 - dscudiero - Optional ask to skip cim or clss only if the site has those products present
## Fri Mar 17 14:53:53 CDT 2017 - dscudiero - Added ablity to skip client catalog files
## Tue Mar 21 10:42:22 CDT 2017 - dscudiero - Added -cat, -cim, and -clss options
## Wed Mar 22 11:23:42 CDT 2017 - dscudiero - Remove debug statements
## Thu Mar 23 08:25:28 CDT 2017 - dscudiero - Do not ask for exclude products if onlyProduct is set
## 03-23-2017 @ 14.16.30 - (4.11.46)   - dscudiero - Added the -cim -cat -clss flags as short-cuts to only copy said product data
## 03-23-2017 @ 14.17.29 - (4.11.46)   - dscudiero - General syncing of dev to prod
## 03-23-2017 @ 14.32.38 - (4.11.47)   - dscudiero - General syncing of dev to prod
## 03-31-2017 @ 07.27.40 - (4.11.48)   - dscudiero - Remove extra blank lines in prompting
## 04-06-2017 @ 14.53.46 - (4.11.48)   - dscudiero - Fix sed statement for turning off publising
## 06-07-2017 @ 09.35.06 - (4.11.64)   - dscudiero - add debug option
## 06-08-2017 @ 11.40.21 - (4.11.65)   - dscudiero - add wizdebug option
## 06-08-2017 @ 12.02.24 - (4.11.17)   - dscudiero - remove extra code
## 06-08-2017 @ 12.11.04 - (4.11.19)   - dscudiero - Fix syntax error
## 06-08-2017 @ 12.14.13 - (4.11.20)   - dscudiero - General syncing of dev to prod
## 06-08-2017 @ 12.17.04 - (4.11.21)   - dscudiero - General syncing of dev to prod
## 06-08-2017 @ 16.27.41 - (4.11.62)   - dscudiero - refactored the skip logic
## 06-09-2017 @ 12.07.57 - (4.11.63)   - dscudiero - Fix problem where we did not clear variable ans befor using it in a prompt
## 06-09-2017 @ 16.17.40 - (4.11.65)   - dscudiero - Fix problem of skipping cims and courseleaf if skipCat is active
## 06-12-2017 @ 06.57.07 - (4.11.66)   - dscudiero - Fix skipcat
## 07-17-2017 @ 14.48.17 - (4.11.68)   - dscudiero - Fix problem with goodbye cleanup removing all of tmpRoot
## 07-18-2017 @ 07.17.23 - (4.11.71)   - dscudiero - Fix problem in setting nexturl if multiple records exists in default.tcf file
## 07-18-2017 @ 08.05.12 - (4.11.72)   - dscudiero - General syncing of dev to prod
## 07-19-2017 @ 14.37.14 - (4.11.73)   - dscudiero - Remove code that updates the cgis
## 07-26-2017 @ 12.51.16 - (4.11.74)   - dscudiero - Make sure we have a value for nexturl befor calling sed
## 07-26-2017 @ 14.36.26 - (4.11.75)   - dscudiero - turn off publising for any env other than next or curr
## 07-26-2017 @ 14.42.41 - (4.11.76)   - dscudiero - Tweak messaging for nexturl
## 07-29-2017 @ 10.04.01 - (4.11.77)   - dscudiero - set skipXXX to false if -fullcopy specified
## 07-29-2017 @ 10.21.03 - (4.11.81)   - dscudiero - Add emailing foruser
## 07-29-2017 @ 12.27.37 - (4.11.83)   - dscudiero - Added -lite option
## 07-29-2017 @ 12.35.22 - (4.11.86)   - dscudiero - Check to see if lite and fullcopy were both specified
## 08-01-2017 @ 08.08.17 - (4.11.87)   - dscudiero - remove emailing to the foruser, moved to Goodbye
## 08-30-2017 @ 13.53.18 - (4.11.90)   - dscudiero - Added help text
## 08-30-2017 @ 16.10.04 - (4.11.91)   - dscudiero - Send the rsync command to the logFile
## 08-30-2017 @ 16.26.18 - (4.11.92)   - dscudiero - Dump the rsyncCtrl file to the logFile
## 08-31-2017 @ 16.04.18 - (4.11.100)  - dscudiero - Tweak messaging
## 09-05-2017 @ 12.09.32 - (4.11.101)  - dscudiero - make sure the debug items go out to the logfile
## 09-21-2017 @ 14.50.54 - (4.12.2)    - dscudiero - Fix bug where parseArgsStd was the wrong case
## 09-27-2017 @ 14.21.20 - (4.12.3)    - dscudiero - Switch to Msg
## 09-27-2017 @ 14.53.58 - (4.12.10)   - dscudiero - Tweak messaging
## 09-29-2017 @ 12.57.50 - (4.12.19)   - dscudiero - update imports
## 09-29-2017 @ 14.27.45 - (4.12.10)   - dscudiero - Add debug statements
## 09-29-2017 @ 15.22.30 - (4.12.10)   - dscudiero - General syncing of dev to prod
## 09-29-2017 @ 15.30.15 - (4.12.10)   - dscudiero - Add debug stuff
## 09-29-2017 @ 15.35.35 - (4.12.10)   - dscudiero - remove debug stuff
## 09-29-2017 @ 16.18.38 - (4.12.10)   - dscudiero - Use GatDefaults -fromFile if useLocal and me
## 10-02-2017 @ 14.22.11 - (4.12.10)   - dscudiero - General syncing of dev to prod
## 10-02-2017 @ 15.32.10 - (4.12.10)   - dscudiero - General syncing of dev to prod
## 10-02-2017 @ 16.25.05 - (4.12.10)   - dscudiero - General syncing of dev to prod
## 10-05-2017 @ 07.15.23 - (4.12.10)   - dscudiero - Remove debug statements
## 10-11-2017 @ 12.51.54 - (4.12.10)   - dscudiero - Add -debug option
## 10-11-2017 @ 13.05.41 - (4.12.10)   - dscudiero - Fix usage of Call to be FindExecutabl
## 10-16-2017 @ 12.57.09 - (4.12.10)   - dscudiero - Add -lock option to lock workflow files
## 10-16-2017 @ 14.17.22 - (4.12.10)   - dscudiero - fix locking code
## 10-17-2017 @ 14.08.56 - (4.12.10)   - dscudiero - Added -lock option
## 10-19-2017 @ 10.34.19 - (4.12.10)   - dscudiero - Add PushPop to the include list
## 11-01-2017 @ 09.55.06 - (4.13.-1)   - dscudiero - Switched to ParseArgsStd
## 11-02-2017 @ 11.01.58 - (4.13.-1)   - dscudiero - Add addPvt to the init call
## 11-06-2017 @ 13.32.24 - (4.13.-1)   - dscudiero - Fix setting nexturl url syntax
## 11-30-2017 @ 13.26.27 - (4.13.-1)   - dscudiero - Switch to use the -all flag on the GetCims call
## 12-01-2017 @ 09.15.07 - (4.13.1)    - dscudiero - Remove check for remotely hosted clients
## 12-06-2017 @ 10.29.03 - (4.13.2)    - dscudiero - Add GetCims to imports list
## 12-18-2017 @ 08.03.32 - (4.13.6)    - dscudiero - Fix issue processing the product codes properly
## 12-18-2017 @ 09.45.02 - (4.13.7)    - dscudiero - Cosmetic/minor change
## 01-26-2018 @ 10.42.43 - 4.13.30 - dscudiero - Tweak messaging if we cannot find the srcDir
## 01-26-2018 @ 10.43.36 - 4.13.31 - dscudiero - Cosmetic/minor change/Sync
## 03-13-2018 @ 07:20:18 - 4.13.32 - dscudiero - Tweak messaging
## 03-13-2018 @ 09:51:05 - 4.13.33 - dscudiero - Cosmetic/minor change/Sync
## 03-21-2018 @ 16:33:25 - 4.13.35 - dscudiero - If copying to test, next, or curr then make sure the leepfrog account is comment out
## 03-22-2018 @ 14:06:14 - 4.13.36 - dscudiero - Updated for Msg3/Msg, RunSql2/RunSql, ParseArgStd/ParseArgStd2
## 03-23-2018 @ 15:33:18 - 4.13.37 - dscudiero - D
## 04-03-2018 @ 16:30:39 - 4.13.38 - dscudiero - Add production to the ignore list for cat
## 04-05-2018 @ 15:24:56 - 4.13.48 - dscudiero - Make full copy more obvious, fixed issue detecting remote hosting
## 04-09-2018 @ 15:16:30 - 4.13.49 - dscudiero - Make the default for fullcopy be false again
## 04-09-2018 @ 16:41:39 - 4.13.50 - dscudiero - Remove debug statements
## 04-13-2018 @ 09:58:16 - 4.13.51 - dscudiero - Change short abbrevition for the debug option to be debug
## 04-23-2018 @ 11:30:00 - 4.13.52 - dscudiero - Write the env data out to the .clonedFrom file
## 04-24-2018 @ 13:06:12 - 4.13.53 - dscudiero - Fix echo statement for env to .clonedFrom, missing the $
## 05-08-2018 @ 13:49:15 - 4.13.55 - dscudiero - Indent the output from rsync
## 05-25-2018 @ 16:39:22 - 4.13.62 - dscudiero - Change debug levels on messages
## 06-01-2018 @ 11:00:32 - 4.13.78 - dscudiero - Use the clientData hash to get the client data
## 06-13-2018 @ 13:52:33 - 4.13.79 - dscudiero - Cosmetic/minor change/Sync
## 06-27-2018 @ 15:21:16 - 4.13.79 - dscudiero - Cleaned up logic that examines the products string
## 08-14-2018 @ 07:25:38 - 4.13.83 - dscudiero - Update tocheck if there is a localsteps mapfile record in courseleaf.cfg
## 08-15-2018 @ 13:29:23 - 4.13.89 - dscudiero - Updated code that updates localsteps/default.tcf
## 11-05-2018 @ 12:18:12 - 4.14.4 - dscudiero - Remove dependency on the clientData hash table
## 11-05-2018 @ 14:45:26 - 4.14.5 - dscudiero - Removed debug statement
## 11-06-2018 @ 07:51:54 - 4.14.6 - dscudiero - Terminate if client is not hosted on the current host
## 11-07-2018 @ 14:33:53 - 4.14.7 - dscudiero - Remove -fromFiles from GetDefaultsData call
## 12-03-2018 @ 07:53:04 - 4.14.9 - dscudiero - Update to use the new argument parser
## 12-05-2018 @ 12:44:16 - 4.14.10 - dscudiero - Comment out the parsargstd call back function
## 12-07-2018 @ 07:24:00 - 4.14.11 - dscudiero - Switch to use toolsSetDefaults module
## 12-18-2018 @ 08:38:23 - 4.14.12 - dscudiero - Switch to use ParseArgs function
## 12-27-2018 @ 07:22:00 - 4.14.14 - dscudiero - Switch to use the SetDefaults function
## 12-28-2018 @ 08:23:06 - 4.14.23 - dscudiero - Pass scriptname to SetDefaults
## 02-19-2019 @ 13:02:26 - 4.14.26 - dscudiero - Comment out the checks to prevent processing remote clients
## 02-22-2019 @ 08:02:54 - 4.14.27 - dscudiero - Tweak messaging
## 03-05-2019 @ 16:04:42 - 4.14.27 - dscudiero - 
## 04-11-2019 @ 08:08:14 - 4.14.43 - dscudiero -  Change the color of the source directory if using a passed in rsyncSrcDir
## 04-11-2019 @ 08:13:04 - 4.14.44 - dscudiero - Tweak messaging
## 04-16-2019 @ 14:45:25 - 4.14.48 - dscudiero -  Add code to deal with alt directories as the source directory
## 04-25-2019 @ 15:45:49 - 4.14.55 - dscudiero -  Force setting of the targetDir, switch back to origional SetSiteDirs
## 05-07-2019 @ 06:51:15 - 4.14.56 - dscudiero -  Fix problem with the debug option going to the wrong env
## 05-23-2019 @ 13:20:35 - 4.14.57 - dscudiero -  Add alert if -debug option was specified
## 06-11-2019 @ 12:13:08 - 4.14.59 - dscudiero -  Added /web/gallery to the ignore list if skipCat = true
