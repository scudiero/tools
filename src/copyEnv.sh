#!/bin/bash
#DX NOT AUTOVERSION
#==================================================================================================
version=4.11.81 # -- dscudiero -- Sat 07/29/2017 @ 10:20:29.81
#==================================================================================================
TrapSigs 'on'
imports='GetDefaultsData ParseArgs ParseArgsStd Hello Init Goodbye' #
imports="$imports GetSiteDirNoCheck"
Import "$imports"
[[ $1 == $myName ]] && shift
originalArgStr="$*"
scriptDescription="Create a cloned private dev site"

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
# parse script specific arguments
#==================================================================================================
function parseArgs-copyEnv {
	# argList+=(argFlag,minLen,type,scriptVariable,extraToken/exCmd,helpSet,helpText)  #type in {switch,switch#,option,help}
	argList+=(-manifest,1,switch,manifest,true,'script',"Create a CourseLeaf Manifest after copies")
	argList+=(-noManifest,3,switch,manifest,manifest=false,'script',"Do not create a CourseLeaf Manifest after copies")
	argList+=(-overlay,5,switch,overlay,true,'script',"Overlay/Replace any existing target directories")
	argList+=(-refresh,5,switch,refresh,true,'script',"Refresh any existing target directories")
	argList+=(-overrideTarget,5,option,overrideTarget,,'script',"Override the default target location, full file spec to where the site root should be located. e.g. /mnt/dev7/web")
	argList+=(-fullCopy,4,switch,fullCopy,,'script',"Do a full copy, including all log and request files")
	argList+=(-forUser,7,option,forUser,,'script',"Name the resulting site for the specified userid")
	argList+=(-suffix,6,option,suffix,,'script',"Suffix text to be append to the resultant site name, e.g. -luc")
	argList+=(-emailAddress,1,option,emailAddress,,'script',"The email address for CourseLeaf email notifications")
	argList+=(-asSite,2,option,asSite,,script,'The name to give the new site)')
	argList+=(-skipCat,6,switch,skipCat,,script,'Skip client CAT directories, i.e. web directories not in the skeleton)')
	argList+=(-skipCim,6,switch,skipCim,,script,'Skip CIM and CIM instance files)')
	argList+=(-skipClss,6,switch,skipClss,,script,'Skip CLASS instance files)')
	argList+=(-skipWen,6,switch,skipClss,,script,'Skip CLASS instance files)')
	argList+=(-skipAlso,6,option,skipAlso,,script,'Additional directories and or files to ignore, comma separated list)')
	argList+=(-wizDebug,3,switch,startWizdebug,,script,'Automatically start a wizDebug session after the copy)')
}
function Goodbye-copyEnv {
	SetFileExpansion 'on' ; rm -rf $tmpRoot/${myName}* >& /dev/null ; SetFileExpansion
}

#==================================================================================================
# Declare local variables and constants
#==================================================================================================
rsyncFilters=$(mkTmpFile 'rsyncFilters')
manifest=false
refresh=false
overlay=false
specialSource=false
fullCopy=false
unset suffix emailAddress clientHost remoteCopy
progDir='courseleaf'
haveCims=false
haveClss=false

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
helpSet='client,script,env'
helpNotes+=("If only a single environment is specified (i.e. -t, -n, -c, ...) then the target environment will be set to 'pvt'")
helpNotes+=("If target env is not 'pvt' or 'dev' then a full copy will be done and auth, publising and email will NOT be changed")
helpNotes+=("The 'forUser' and 'suffix' options are mutually exclusive.")

GetDefaultsData $myName
ParseArgsStd

[[ -n $env && -z $srcEnv ]] && srcEnv="$env"

[[ $allItems == true || $fullCopy == true ]] && cim='Yes' && overlay=false && manifest=false
dump -2 -n client env cim cat clss fullCopy manifest overlay suffix emailAddress

Hello
addPvt=true
[[ $cat == true ]] && skipCat=false && skipCim=true && skipClss=true && unset skipAlso
[[ $cim == true ]] && skipCat=true && skipCim=false && skipClss=true && unset skipAlso
[[ $clss == true ]] && skipCat=true && skipCim=true && skipClss=false && unset skipAlso

## Resolve data based on passed in client, handle special cases
	if [[ $(Lower "${client:0:5}") == 'luc20' && ${srcEnv:0:1} == 'p' && ${tgtEnv:0:1} == 'p' ]]; then
		srcEnv='pvt'
		srcDir="/mnt/dev7/web/lilypadu-$userName"
		[[ ! -d "$srcDir" ]] && srcEnv='next' && srcDir='/mnt/lilypadu/site/next'
		tgtEnv='pvt'
		tgtDir="/mnt/dev7/web/luc$(date "+%Y")"
		[[ -n $asSite ]] && tgtDir="$tgtDir-$asSite"
		emailAddress='disabled'
	elif [[ $client == 'lilypadu' ]]; then
		srcEnv='next'
		srcDir='/mnt/lilypadu/site/next'
		tgtEnv='pvt'
		tgtDir="/mnt/dev7/web/lilypadu-$userName"
		emailAddress='disabled'
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
			Init 'getTgtEnv getDirs'
		else
			Init 'getSrcEnv getTgtEnv getDirs'
			env="$srcEnv"
		fi
	fi
	dump -1 client env srcEnv srcDir tgtEnv tgtDir

ignoreList=$(sed "s/<progDir>/$progDir/g" <<< $ignoreList)
mustHaveDirs=$(sed "s/<progDir>/$progDir/g" <<< $(cut -d":" -f2 <<< $scriptData1))
mustHaveFiles=$(sed "s/<progDir>/$progDir/g" <<< $(cut -d":" -f2 <<< $scriptData2))
dump -1 ignoreList mustHaveDirs mustHaveFiles

## check to see if this client is remote or on another host
	if [[ $client != 'internal' && $client != 'lilypadu' && $noCheck != true ]]; then
		sqlStmt="select hosting from $clientInfoTable where name=\"$client\""
		RunSql2 $sqlStmt
		clientHosting=${resultSet[0]}
		if [[ $clientHosting == 'leepfrog' ]]; then
			## check to see if this client is on another host
			[[ $env == 'test' ]] && tempClient="${client}-test" || tempClient="${client}"
			sqlStmt="select host,share,redhatVer from $siteInfoTable where name=\"$tempClient\" and env=\"$env\""
			RunSql2 $sqlStmt
			if [[ ${#resultSet[@]} -gt 0 ]]; then
			 	clientHost=$(cut -d'|' -f1 <<< "${resultSet[0]}")
				clientShare=$(cut -d'|' -f2 <<< "${resultSet[0]}")
				clientRhel=$(cut -d'|' -f3 <<< "${resultSet[0]}")
			else
				Terminate "Could not retrieve data for client ($tempClient), env ($env) from $workflowDb.$siteInfoTable"
			fi
			[[ $clientHost != $hostName ]] && srcDir="ssh $userName@$clientHost.leepfrog.com:$srcDir" && remoteCopy=true
			dump -2 -t clientHost clientShare clientRhel srcDir
		else
			Terminate "Copying of remote client sites not supported at this time"
			#[[ -f /home/$userName/.remoteSites ]] && remoteSitesDataFile=/home/$userName/.remoteSites || remoteSitesDataFile=$TOOLSPATH/.remoteSites
			#unset pwRec
			#[[ ! -r $remoteSitesDataFile ]] && Msg "T Could not read remote site data file: '$remoteSitesDataFile'.";
			#$trapErrexitOff
			#
			#pwRec=$(grep "^$client" $remoteSitesDataFile)
			#$trapErrexitOn
			#[[ -z $pwRec ]] && Msg "T Could not retrieve remote site login data for '$client' from file: '$remoteSitesDataFile'.";
			#remoteUser=$(echo $pwRec | cut -d ' ' -f1)
			#remotePw=$(echo $pwRec | cut -d ' ' -f2)
			#remoteHost=$(echo $pwRec | cut -d ' ' -f3)
			#remoteNext=$(echo $pwRec | cut -d ' ' -f4)
			#remoteCurr=$(echo $pwRec | cut -d ' ' -f5)
			#dump pwRec remoteUser remotePw remoteHost remoteNext remoteCurr
			#remoteCopy=true
		fi
	else
		clientHost=$hostName
		clientRhel=$myRhel
	fi
	dump -2 -t srcDir devDir pvtDir remoteCopy

	if [[ -n $overrideTarget ]]; then
		[[ ${overrideTarget:(-1)} == '/' ]] && overrideTarget="${overrideTarget:0:${#overrideTarget}-1}"
		[[ ! -d $overrideTarget ]] && Msg2 && Terminate "Could not locate override target diectory: '$overrideTarget'"
		tgtDir="$overrideTarget/$client-$userName"
	fi
	if [[ -n $forUser ]]; then
		[[ -n $suffix ]] && Msg2 && Terminate "Cannot specify both 'forUser' and 'suffix'."
		userAccount="${forUser%%/*}"
		userPassword="${forUser##*/}"
		[[ -z $asSite ]] && tgtDir=$(sed "s/$userName/$forUser/g" <<< $tgtDir)
	fi
	[[ -n $suffix ]] && tgtDir=$(sed "s/$userName/$suffix/g" <<< $tgtDir)

## if target is not pvt or dev then do a full copy
	[[ $tgtEnv != 'pvt' && $tgtEnv != 'dev' ]] && fullCopy=true
	[[ $overlay == true && $refresh == true ]] && Terminate "Cannot specify both the -overlay and -refresh flags at the same time"
	[[ $overlay == true ]] && cloneMode='Replace' || cloneMode='Refresh'

#==================================================================================================
## Check to see if all dirs exist
	[[ -z $srcDir ]] && Terminate "No Source directory was specified"
	if [[ -d $tgtDir && $overlay == false  && $refresh == false ]]; then
		Msg2
		unset ans
		WarningMsg "Target site ($tgtDir) already existes."
		Prompt ans "Do you wish to $(ColorK 'overwrite') the existing site (Yes) or $(ColorK 'refresh') files in the existing sites site (No) ?" 'Yes No' 'Yes' ; ans=$(Lower ${ans:0:1})
		[[ $ans == 'y' ]] && cloneMode='Replace' || cloneMode='Refresh'
	fi

## See if we have any CIMs
	allCims=true; unset cimStr
	GetCims "$srcDir"
	unset allCims
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
if [[ $verify == true ]]; then
	echo
	if [[ -z $skipCat ]]; then
		unset ans; Prompt ans "Do you wish to $(ColorK 'EXCLUDE') Client CAT files" 'No,Yes,Select' 'No' '6'; ans="$(Lower "${ans:0:1}")"
		[[ $ans == 'y' || $ans == 's' ]] && skipCat=true
	fi
	if [[ -z $skipCim && $haveCims == true ]]; then
		unset ans; Prompt ans "Do you wish to $(ColorK 'EXCLUDE') CIM & CIM instances" 'No,Yes,Select' 'No' '6'; ans="$(Lower "${ans:0:1}")"
		[[ $ans == 'y' || $ans == 's' ]] && skipCim=true
	fi
	if [[ -z $skipClss && $haveClss == true ]]; then
		unset ans; Prompt ans "Do you wish to $(ColorK 'EXCLUDE') CLSS/WEN" 'No,Yes' 'No' '6'; ans="$(Lower "${ans:0:1}")"
		[[ $ans == 'y' || $ans == 's' ]] && skipClss=true
	fi

	if [[ -z $skipAlso && $cat != true && $cim != true && $clss != true ]]; then
		echo
		unset ans; Prompt ans "Do you wish to $(ColorK 'EXCLUDE') additional directories/files from the copy operation" 'No,Yes' 'No' '6'; ans="$(Lower "${ans:0:1}")"
		if [[ $ans == 'y' ]]; then
			SetFileExpansion 'off'
			Msg2 "^Please specify the directories/files you wish to exclude, use '*' as a the wild card,"
			Msg2 "^specifications are relative to siteDir, e.g. '/web/wen' without the quotes."
			Msg2 "^To stop the prompt loop, just enter no data"
			while true; do
				MsgNoCRLF "^^==> "
				read ignore
				[[ -z $ignore || $(Lower "$ignore") == 'x' ]] && break
				ignoreList="$ignoreList,$ignore"
				unset ignore
			done
			SetFileExpansion
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
		ignoreList="$ignoreList,/production-shared,/web/shared"
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
	unset verifyArgs
	verifyArgs+=("Client:$client")
	verifyArgs+=("Source Env:$(TitleCase $srcEnv)\t($srcDir)")
	verifyArgs+=("Target Env:$(TitleCase $tgtEnv)\t($tgtDir)")
	tmpStr=$(sed "s/,/, /g" <<< $ignoreList)
	[[ -n $forUser ]] && verifyArgs+=("For User:$forUser")
	[[ $skipCat == true && $fullCopy != true ]] && verifyArgs+=("Skip Cat:$skipCat")
	[[ $skipCim == true && $fullCopy != true ]] && verifyArgs+=("Skip CIM:$skipCim")
	[[ $skipClss == true && $fullCopy != true ]] && verifyArgs+=("Skip CLSS:$skipClss")
	[[ $fullCopy != true ]] && verifyArgs+=("Exclude List:$tmpStr")
	[[ $startWizdebug == true  ]] && verifyArgs+=("Auto start wizDebug:$startWizdebug")
	[[ -z $onlyProduct ]] && verifyArgs+=("Full Copy:$fullCopy")

	[[ $manifest == true ]] && verifyArgs+=("Courseleaf manifest:$manifest")
	VerifyContinue "You are asking to clone/copy a CourseLeaf site:"

#==================================================================================================
## Check to see if the source is readable
	if [[ $client == 'internal' && ! -r $srcDir/pagewiz.cfg ]] || [[ $client != 'internal' && ! -r $srcDir/courseleaf.cfg ]]; then
		Msg2 $T "Sorry you do not have read access to the source ($srcDir), please contact system admins"
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
			[[ -d $tgtDir.bak ]] && Msg2 "Old target directory renamed to $tgtDir.bak" || Msg2 $T "Target directory exists and could not be renamed"
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
	if [[ -f $rsyncFilters ]]; then rm $rsyncFilters; fi
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
	if [[ $fullCopy = true ]]; then
		rsyncOpts="-a$rsyncVerbose $listOnly"
		Msg2 "Performing a FULL copy..."
	else
		rsyncOpts="-a$rsyncVerbose --prune-empty-dirs $listOnly --include-from $rsyncFilters"
		# Msg2 "Excluding the following from the copy:"
		# oldIFS=$IFS; IFS='';
		# SetIndent '+1';
		# while read line; do Msg2 "^$line"; done < $rsyncFilters
		# SetIndent '-1'
		# IFS=$oldIFS;
		# printf "\n"
	fi
	if [[ $remoteCopy == true ]]; then
		Msg2 "Calling rsync to copy the files, when prompted for password, please enter your password on '$clientHost' ..."
		rsyncOpts="${rsyncOpts} -e"
	else
		Msg2 "Calling rsync to copy the files ..."
	fi

	previousTrapERR=$(cut -d ' ' -f3- <<< $(trap -p ERR))
	trap - ERR
	rsync $rsyncOpts $srcDir/ $tgtDir
	eval "trap $previousTrapERR"

	[[ -f $rsyncFilters ]] && rm $rsyncFilters

# #==================================================================================================
# # Check RHEL versions
# 	if [[ ${clientRhel:0:1} != ${myRhel:0:1} ]]; then
# 		Msg2 "\nRhel versions do not match, updating cgis to current..."
# 		cgisDirRoot=$cgisRoot/rhel${myRhel:0:1}
# 		[[ ! -d $cgisDirRoot ]] && Terminate "Could not locate cgi source directory:\n\t$cgiRoot"
# 		if [[ -d $cgisDirRoot/release ]]; then
# 			cgisDir=$cgisDirRoot/release
# 		else
# 			cwd=$(pwd)
# 			cd $cgisDirRoot
# 			cgisDir=$(ls -t | tr "\n" ' ' | cut -d ' ' -f1)
# 			WarningMsg "^TCould not find the 'release' directory in the cgi root directory, using '$cgisDir'"
# 			cgisDir=${cgisDirRoot}/$cgisDir
# 			cd $cwd
# 		fi
# 		unset cgisUpdated
# 		## /courseleaf/courseleaf.cgi
# 			if [[ -f $cgisDir/courseleaf.cgi ]]; then
# 				result=$(CopyFileWithCheck "$cgisDir/$progDir.cgi" "$tgtDir/web/$progDir/$progDir.cgi" 'courseleaf')
# 				if [[ $result == true ]]; then
# 					chmod 755 $tgtDir/web/$progDir/$progDir.cgi
# 					Msg2 "^Upated: $progDir.cgi"
# 					cgisUpdated=true
# 				elif [[ $result == 'same' ]]; then
# 					Msg2 "^'$progDir.cgi' is current"
# 				else
# 					Msg2 "TT Could not copy $progDir.cgi.\n\t$result"
# 				fi
# 			else
# 				Terminate "^Could not locate source $progDir.cgi in \n\t\t'$cgisDir'."
# 			fi

# 		## /ribbit/index.cgi
# 			if [[ -f $cgisDir/index.cgi ]]; then
# 				result=$(CopyFileWithCheck "$cgisDir/index.cgi" "$tgtDir/web/ribbit/index.cgi" 'courseleaf')
# 				if [[ $result == true ]]; then
# 					chmod 755 $tgtDir/web/ribbit/index.cgi
# 					Msg2 "^index.cgi copied"
# 					cgisUpdated=true
# 				elif [[ $result == 'same' ]]; then
# 					Msg2 "^'index.cgi' is current"
# 				else
# 					Error "^Could not copy index.cgi.\n\t$result"
# 				fi
# 			elif [[ -f $cgisDir/ribbit.cgi ]]; then
# 				result=$(CopyFileWithCheck "$cgisDir/ribbit.cgi" "$tgtDir/web/ribbit/index.cgi" 'courseleaf')
# 				if [[ $result == true ]]; then
# 					chmod 755 $tgtDir/web/ribbit/index.cgi
# 					Msg2 "^ribbit.cgi copied as index.cgi"
# 					cgisUpdated=true
# 				elif [[ $result == 'same' ]]; then
# 					Msg2 "^'tribbit.cgi' is current"
# 				else
# 					Terminate"^Could not copy ribbit.cgi as index.cgi.\n\t$result"
# 				fi
# 			else
# 				Terminate "^Could not locate source ribbit.cgi or index.cgi, ribbit cgi not refreshed."
# 			fi
# 	fi

if [[ $tgtEnv != 'next' && $tgtEnv != 'curr' ]]; then
		# Turn off publishing
		Msg2 "\nTurn off Publishing..."
		editFile="$tgtDir/$progDir.cfg"
		$DOIT sed -i s'_^mapfile:production_//mapfile:production_'g "$editFile"
		$DOIT sed -i s'_^mapfile:/navbar/production_//mapfile:/navbar/production_'g "$editFile"
		$DOIT sed -i s'_^//mapfile:production/|/dev/null_mapfile:production/|/dev/null_' "$editFile"
		$DOIT sed -i s'_^//mapfile:production|/dev/null_mapfile:production|/dev/null_' "$editFile"
		grepStr=$(ProtectedCall "grep '^mapfile:production.*/dev/null' $editFile")
		[[ -z $grepStr ]] && Warning "Could not locate a publishing mapfile record pointing to /dev/null, publising may still be active, please check before using clone site"
fi

if [[ $tgtEnv == 'pvt' || $tgtEnv == 'dev' ]]; then
	# Turn off remote authenticaton
		Msg2 "Turn off Authentication..."
		$DOIT sed -i s'_^authuser:true_//authuser:true_' $tgtDir/$progDir.cfg
		for file in default.tcf localsteps/default.tcf; do
			$DOIT sed -i s'_^authuser:true_//authuser:true_' $tgtDir/web/$progDir/$file
			$DOIT sed -i s'_^casurl:_//casurl:_' $tgtDir/web/$progDir/$file
			$DOIT sed -i s'_^loginurl:_//loginurl:_' $tgtDir/web/$progDir/$file
			$DOIT sed -i s'_^logouturl:_//logouturl:_' $tgtDir/web/$progDir/$file
		done

	# Turn off PDF generationw
		Msg2 "Turn off PDF generation..."
		$DOIT sed -i s'_^pdfeverypage:true$_//pdfeverypage:true_' $tgtDir/web/$progDir/localsteps/default.tcf

	# leepfrog user account
		Msg2 "Adding user-ids to $progDir.cfg file..."
		$DOIT echo "user:$leepfrogUserId|$leepfrogPw||admin" >> $tgtDir/$progDir.cfg
		Msg2 "^'$leepfrogUserId' added as an admin with pw: '<normal pw>'"
		$DOIT echo "user:test|test||" >> $tgtDir/$progDir.cfg
		Msg2 "^'test' added as a normal user with pw: 'test'"
		[[ $(Lower "${client:0:5}") != 'luc20' ]] && $DOIT echo "user:$client|$client||admin" >> $tgtDir/$progDir.cfg
		$DOIT echo "user:$client|$client||admin" >> $tgtDir/$progDir.cfg
		[[ -n $forUser ]] && $DOIT echo "user:$userAccount|$userPassword||admin" >> $tgtDir/$progDir.cfg

	# Set nexturl so wf emails point to local instance
		Msg2 "Changing 'nexturl' to point to local instance..."
		editFile="$tgtDir/web/courseleaf/localsteps/default.tcf"
		clientToken=$(cut -d'/' -f5 <<< $tgtDir)
		toStr="nexturl:https://$clientToken/$(cut -d '/' -f3 <<< $tgtDir).leepfrog.com"
		unset grepStr; grepStr=$(ProtectedCall "grep "^$toStr" $editFile")
		if [[ -z $grepStr ]]; then
			unset fromStr; fromStr=$(ProtectedCall "grep '^nexturl:' $editFile")
			fromStr=$(CleanString "$fromStr")
			[[ -n $fromStr ]] && $DOIT sed -i s"!${fromStr}!${toStr}!" $editFile || Msg2 $WT1 "Could not set nexturl"
		fi

	## email override
		Msg2 "Override email routing..."
		[[ -z $emailAddress ]] && emailAddress=$userName@leepfrog.com
		editFile=$tgtDir/email/sendnow.atj
		unset grepStr; grepStr=$(ProtectedCall "grep ^'// DO NOT MODIFY THIS FILE' $editFile");
		if [[ -n $grepStr ]]; then
			## New format file
			if [[ -d $tgtDir/web/admin/wfemail ]]; then
				editFile=$tgtDir/web/admin/wfemail/index.tcf
			else
				editFile=$tgtDir/web/$progDir/localsteps/default.tcf
			fi
			toStr="wfemail_testaddress:$emailAddress"
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
			toStr="var testaddress = \"$emailAddress\""
			unset grepStr; grepStr=$(ProtectedCall "grep '"$toStr"' $editFile")
			if [[ -z $grepStr ]]; then
				unset checkStr; checkStr=$(ProtectedCall "grep 'var type = \"cat\";' $editFile")
				fromStr=$checkStr
				$DOIT sed -i s"!${fromStr}!${toStr}\n\n${fromStr}!" $editFile
			fi
		fi

	## generate a manifest
		if [[ "$manifest" == true ]]; then
			if [[ $quiet != true ]]; then Msg2 "Creating manifest..."; fi
			cd $tgtDir/web/$progDir
			./$progDir.cgi --manifest
		fi

	## Make sure we have the required directories and files
		for dir in $(tr ',' ' ' <<< $mustHaveDirs); do
			[[ ! -d ${tgtDir}${dir} ]] && $DOIT mkdir ${tgtDir}${dir}
		done
		for file in $(tr ',' ' ' <<< $mustHaveFiles); do
			[[ ! -d ${tgtDir}${file} ]] && $DOIT touch ${tgtDir}${file}
		done

	## touch clone data and source file in root
		$DOIT rm -f $tgtDir/.clonedFrom-* > /dev/null 2>&1
		$DOIT touch $tgtDir/.clonedFrom-$env
fi

## If we have cims and user is 'dscudiero' and env = 'pvt' and onlyProduct='cim' then turn on debugging
	if [[  -n $cimStr && $userName == 'dscudiero' && $tgtEnv == 'pvt' &&  onlyProduct == 'cim' ]]; then
		for cim in $(tr ',' ' ' <<< "$cimStr"); do
			editFile="$tgtDir/web/$cim/workflow.cfg"
			[[ ! -f $editFile ]] && continue
			unset grepStr; grepStr=$(ProtectedCall "grep '^wfDebugLevel:' $editFile")
			if [[ -n $grepStr ]]; then
				fromStr="$grepStr"
				toStr="wfDebugLevel:2"
				$DOIT sed -i s"_^${fromStr}_${toStr}_" $editFile
			fi
		done
	fi
## If running for another user, then send an email to that user
	if [[ -n $forUser ]]; then
		Msg2 > $tmpFile
		Msg2 "A cloned site for '$client' was created for you by $userName, the site is located at:" >> $tmpFile
		Msg2 "^$tgtDir" >> $tmpFile
		Msg2 >> $tmpFile
		Msg2 "\nEmail sent to: ${forUser}@leepfrog.com" 
		#$DOIT mail -s "$myName found discrepancies" $emailAddrs < $tmpFile
		$DOIT mutt -s "$myName '$client' site created - $(date +"%m-%d-%Y")" -- ${forUser}@leepfrog.com < $tmpFile
	fi
#==================================================================================================
## Bye-bye
#printf "0: noDbLog = '$noDbLog', myLogRecordIdx = '$myLogRecordIdx'\n" >> ~/stdout.txt
#[[ $quiet == true || $quiet == 1 ]] && quiet=0 || Alert
Msg2
Info "Remember you can use the 'cleanDev' script to easily remove private dev sites."
[[ -n $asSite ]] && msgText="$(ColorK "$(Upper $asSite)")" || msgText="$(ColorK "$(Upper $client)")"

[[ $startWizdebug == true ]] && Call 'wizdebug' 'bash:sh' "$client" "-${tgtEnv}"

Goodbye 0 'alert' "$msgText clone from $(ColorK "$(Upper $env)")"

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
