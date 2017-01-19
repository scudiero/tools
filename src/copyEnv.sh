#!/bin/bash
#==================================================================================================
version=4.10.1 # -- dscudiero -- 01/19/2017 @ 10:31:17.21
#==================================================================================================
TrapSigs 'on'
imports='GetDefaultsData ParseArgs ParseArgsStd Hello Init Goodbye' #imports="$imports "
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
	argList+=(-overrideTarget,5,option,overrideTarget,,'script',"Override the default target location, full file spec to where the site root should be located. e.g. /mnt/dev7/web")
	argList+=(-fullCopy,4,switch,fullCopy,,'script',"Do a full copy, including all log and request files")
	argList+=(-forUser,7,option,forUser,,'script',"Name the resulting site for the specified userid")
	argList+=(-suffix,6,option,suffix,,'script',"Suffix text to be append to the resultant site name, e.g. -luc")
	argList+=(-emailAddress,1,option,emailAddress,,'script',"The email address for CourseLeaf email notifications")
}
function Goodbye-copyEnv {
	[[ -d $tmpRoot ]] && rm -rf $tmpRoot
}

#==================================================================================================
# Declare local variables and constants
#==================================================================================================
rsyncFilters=$(mkTmpFile 'rsyncFilters')
manifest=false
overlay=false
specialSource=false
fullCopy=false
unset suffix emailAddress clientHost remoteCopy
progDir='courseleaf'

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
helpSet='client,script,env'
helpNotes+=("If only a single environment is specified (i.e. -t, -n, -c, ...) then the target environment will be set to 'pvt'")
helpNotes+=("If target env is not 'pvt' or 'dev' then a full copy will be done and auth, publising and email will NOT be changed")
helpNotes+=("The 'forUser' and 'suffix' options are mutually exclusive.")

dump originalArgStr

GetDefaultsData $myName
ParseArgsStd
[[ -n $env && -z $srcEnv ]] && srcEnv="$env"

[[ $allItems == true || $fullCopy == true ]] && cim='Yes' && overlay=false && manifest=false
dump -2 -n client env cim cat fullCopy manifest overlay suffix emailAddress

Hello
addPvt=true
[[ -z $env ]] && srcEnv=$env && tgtEnv='pvt'
Init 'getClient'
[[ $client != 'internal' ]] && Init 'getSrcEnv getTgtEnv getDirs' || Init 'getEnv getDirs'

[[ -z $env && -n $srcEnv ]] && env=$srcEnv
dump -2 client env srcEnv srcDir tgtEnv tgtDir

[[ $client == internal ]] && progDir='pagewiz'
ignoreList=$(sed "s/<progDir>/$progDir/g" <<< $ignoreList)
mustHaveDirs=$(sed "s/<progDir>/$progDir/g" <<< $(cut -d":" -f2 <<< $scriptData1))
mustHaveFiles=$(sed "s/<progDir>/$progDir/g" <<< $(cut -d":" -f2 <<< $scriptData2))
dump -1 ignoreList mustHaveDirs mustHaveFiles

## check to see if this client is remote or on another host
	if [[ $client != 'internal' && $noCheck != true ]]; then
		sqlStmt="select hosting from $clientInfoTable where name=\"$client\""
		RunSql2 $sqlStmt
		clientHosting=${resultSet[0]}
		if [[ $clientHosting == 'leepfrog' ]]; then
			## check to see if this client is on another host
			[[ $env == 'test' ]] && tempClient="${client}-test" || tempClient="${client}"
			sqlStmt="select host,share,redhatVer from $siteInfoTable where name=\"$tempClient\" and env=\"$env\""
			RunSql2 $sqlStmt
			if [[ ${#resultSet[@]} -gt 0 ]]; then
			 	resultString=${resultSet[0]}; resultString=$(echo "$resultString" | tr "\t" "|" )
				clientHost=$(echo $resultString | cut -d'|' -f1)
				clientShare=$(echo $resultString | cut -d'|' -f2)
				clientRhel=$(echo $resultString | cut -d'|' -f3)
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
	fi
	dump -2 -t srcDir devDir pvtDir remoteCopy

	if [[ -n $overrideTarget ]]; then
		[[ ${overrideTarget:(-1)} == '/' ]] && overrideTarget="${overrideTarget:0:${#overrideTarget}-1}"
		[[ ! -d $overrideTarget ]] && Msg2 && Terminate "Could not locate override target diectory: '$overrideTarget'"
		tgtDir="$overrideTarget/$client-$userName"
	fi
	[[ -n $forUser && -x $suffix ]] && Msg2 && Terminate "Cannot specify both 'forUser' and 'suffix'."
	[[ -n $forUser ]] && tgtDir=$(sed "s/$userName/$forUser/g" <<< $tgtDir) && emailAddress="$forUser@leepfrog.com"
	[[ -n $suffix ]] && tgtDir=$(sed "s/$userName/$suffix/g" <<< $tgtDir)

## if target is not pvt or dev then do a full copy
	[[ $tgtEnv != 'pvt' && $tgtEnv != 'dev' ]] && fullCopy=true
	[[ $overlay == true ]] && cloneMode='Replace' || cloneMode='Refresh'

#==================================================================================================
## Check to see if all dirs exist
	[[ -z $srcDir ]] && Terminate "No Source directory was specified"
	if [[ -d $tgtDir && $overlay == false ]]; then
		unset ans
		WarningMsg "Target site ($tgtDir) already existes."
		Prompt ans "Do you wish to $(ColorK 'overwrite') the existing site (Yes) or $(ColorK 'refresh') files in the existing sites site (No) ?" 'Yes No' 'Yes'; ans=$(Lower ${ans:0:1})
		if [[ $ans == 'y' ]]; then
			cloneMode='Replace'
		else
			cloneMode='Refresh'
		fi
	fi

## Make sure the user really wants to do this
	unset verifyArgs
	verifyArgs+=("Client:$client")
	[[ $client != 'internal' ]] && verifyArgs+=("Source Env:$(TitleCase $srcEnv)\t($srcDir)") || verifyArgs+=("Source Dir:$srcDir")
	[[ $client != 'internal' ]] && verifyArgs+=("Target Env:$(TitleCase $tgtEnv)\t($tgtDir)") || verifyArgs+=("Target Dir:$tgtDir")
	verifyArgs+=("Copy Mode:$cloneMode")
	tmpStr=$(sed "s/,/, /g" <<< $ignoreList)
	[[ $fullCopy != true ]] && verifyArgs+=("Ignore List:$tmpStr")
	verifyArgs+=("Full Copy:$fullCopy")

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
	## Build rrsync control file of excluded items
		for token in $(tr ',' ' ' <<< $ignoreList); do
			echo "- ${token}" >> $rsyncFilters
		done

	[[ $remoteCopy != true ]] && cd $srcDir
	[[ -z $DOIT ]] && listOnly='' || listOnly='--list-only'
	[[ $quiet == true || $quiet == 1 ]] && rsyncVerbose='' || rsyncVerbose='vh'
	if [[ $fullCopy = true ]]; then
		rsyncOpts="-a$rsyncVerbose $listOnly"
		Msg2 "Performing a FULL copy..."
	else
		rsyncOpts="-a$rsyncVerbose --prune-empty-dirs $listOnly --include-from $rsyncFilters"
		Msg2 "Excluding the following from the copy..."
		oldIFS=$IFS; IFS='';
		while read line; do
			line=$(echo $line | tr -cd "[:print:]" | echo ${line:1})
			Msg2 "^$line"
		done < $rsyncFilters
		IFS=$oldIFS;
		printf "\n"
	fi

	if [[ $remoteCopy == true ]]; then
		Msg2 "Calling rsync to copy the files, when prompted for password, please enter your password on '$clientHost' ..."
		rsyncOpts="${rsyncOpts} -e"
	else
		Msg2 "Calling rsync to copy the files ..."
	fi

	previousTrapERR=$(echo $(trap -p ERR) | cut -d ' ' -f3-)
	trap - ERR
	rsync $rsyncOpts $srcDir/ $tgtDir
	eval "trap $previousTrapERR"

	[[ -f $rsyncFilters ]] && rm $rsyncFilters

#==================================================================================================
# Check RHEL versions
	if [[ ${clientRhel:0:1} != ${myRhel:0:1} ]]; then
		Msg2 "Rhel versions do not match, updating cgis..."
		cgisDirRoot=$cgisRoot/rhel${myRhel:0:1}
		[[ ! -d $cgisDirRoot ]] && Terminate "Could not locate cgi source directory:\n\t$cgiRoot"
		if [[ -d $cgisDirRoot/release ]]; then
			cgisDir=$cgisDirRoot/release
		else
			cwd=$(pwd)
			cd $cgisDirRoot
			cgisDir=$(ls -t | tr "\n" ' ' | cut -d ' ' -f1)
			WarningMsg "^TCould not find the 'release' directory in the cgi root directory, using '$cgisDir'"
			cgisDir=${cgisDirRoot}/$cgisDir
			cd $cwd
		fi
		unset cgisUpdated
		## /courseleaf/courseleaf.cgi
			if [[ -f $cgisDir/courseleaf.cgi ]]; then
				result=$(CopyFileWithCheck "$cgisDir/$progDir.cgi" "$tgtDir/web/$progDir/$progDir.cgi" 'courseleaf')
				if [[ $result == true ]]; then
					chmod 755 $tgtDir/web/$progDir/$progDir.cgi
					Msg2 "^Upated: $progDir.cgi"
					cgisUpdated=true
				elif [[ $result == 'same' ]]; then
					Msg2 "^'$progDir.cgi' is current"
				else
					Msg2 "TT Could not copy $progDir.cgi.\n\t$result"
				fi
			else
				Terminate "^Could not locate source $progDir.cgi in \n\t\t'$cgisDir'."
			fi

		## /ribbit/index.cgi
			if [[ -f $cgisDir/index.cgi ]]; then
				result=$(CopyFileWithCheck "$cgisDir/index.cgi" "$tgtDir/web/ribbit/index.cgi" 'courseleaf')
				if [[ $result == true ]]; then
					chmod 755 $tgtDir/web/ribbit/index.cgi
					Msg2 "^index.cgi copied"
					cgisUpdated=true
				elif [[ $result == 'same' ]]; then
					Msg2 "^'index.cgi' is current"
				else
					Error "^Could not copy index.cgi.\n\t$result"
				fi
			elif [[ -f $cgisDir/ribbit.cgi ]]; then
				result=$(CopyFileWithCheck "$cgisDir/ribbit.cgi" "$tgtDir/web/ribbit/index.cgi" 'courseleaf')
				if [[ $result == true ]]; then
					chmod 755 $tgtDir/web/ribbit/index.cgi
					Msg2 "^ribbit.cgi copied as index.cgi"
					cgisUpdated=true
				elif [[ $result == 'same' ]]; then
					Msg2 "^'tribbit.cgi' is current"
				else
					Terminate"^Could not copy ribbit.cgi as index.cgi.\n\t$result"
				fi
			else
				Terminate "^Could not locate source ribbit.cgi or index.cgi, ribbit cgi not refreshed."
			fi
	fi

if [[ $tgtEnv == 'pvt' || $tgtEnv == 'dev' ]]; then
	#==================================================================================================
	# Turn off publishing
		[[ $quiet == false || $quiet == 0 ]] && Msg2 "Turn off Publishing..."
		$DOIT sed -i '1i mapfile:production/|/dev/null' $tgtDir/$progDir.cfg
		#$DOIT sed -i s'_^//mapfile:production/|/dev/null_mapfile:production/|/dev/null_' $tgtDir/courseleaf.cfg
		#$DOIT sed -i s'_^//mapfile:production|/dev/null_mapfile:production|/dev/null_' $tgtDir/courseleaf.cfg
		#$DOIT sed -i s'_^mapfile:production/|../../../public/web_//mapfile:production/|../../../public/web_' $tgtDir/courseleaf.cfg
		#$DOIT sed -i s'_^mapfile:production|../../../public/web_//mapfile:production|../../../public/web_' $tgtDir/courseleaf.cfg

	# Turn off remote authenticaton
		[[ $quiet == false || $quiet == 0 ]] && Msg2 "Turn off Authentication..."
		$DOIT sed -i s'_^authuser:true_//authuser:true_' $tgtDir/$progDir.cfg
		for file in default.tcf localsteps/default.tcf; do
			$DOIT sed -i s'_^authuser:true_//authuser:true_' $tgtDir/web/$progDir/$file
			$DOIT sed -i s'_^casurl:_//casurl:_' $tgtDir/web/$progDir/$file
			$DOIT sed -i s'_^loginurl:_//loginurl:_' $tgtDir/web/$progDir/$file
			$DOIT sed -i s'_^logouturl:_//logouturl:_' $tgtDir/web/$progDir/$file
		done

	# Turn off PDF generationw
		[[ $quiet == false || $quiet == 0 ]] && Msg2 "Turn off PDF generation..."
		$DOIT sed -i s'_^pdfeverypage:true$_//pdfeverypage:true_' $tgtDir/web/$progDir/localsteps/default.tcf

	# leepfrog user account
		[[ $quiet == false || $quiet == 0 ]] && Msg2 "Adding the 'leepfrog' & 'test' userids are in the $progDir.cfg file..."
		$DOIT echo "user:$leepfrogUserId|$leepfrogPw||admin" >> $tgtDir/$progDir.cfg
		Msg2 "^'$leepfrogUserId' added as an admin with pw: '<normal pw>'"
		$DOIT echo "user:test|test||" >> $tgtDir/$progDir.cfg
		Msg2 "^'test' added as a normal user with pw: 'test'"
		$DOIT echo "user:$client|$client||admin" >> $tgtDir/$progDir.cfg
		Msg2 "^'$client' added as an admin with pw: '$client'"

	## email override
		[[ $quiet == false || $quiet == 0 ]] && Msg2 "Override email routing..."
		[[ $emailAddress == "" ]] && emailAddress=$userName@leepfrog.com
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

#==================================================================================================
## Bye-bye
#printf "0: noDbLog = '$noDbLog', myLogRecordIdx = '$myLogRecordIdx'\n" >> ~/stdout.txt
#[[ $quiet == true || $quiet == 1 ]] && quiet=0 || Alert
Msg2
Msg2 "I Remember you can use the 'cleanDev' script to easily remove private dev sites."
Goodbye 0 'alert' "$(ColorK "$(Upper $client)") clone from $(ColorK "$(Upper $env)")"

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
