#!/bin/bash
#XO NOT AUTOVERSION
#====================================================================================================
version=2.8.75 # -- dscudiero -- Tue 04/04/2017 @  8:16:32.44
#====================================================================================================
TrapSigs 'on'
Import ParseArgs ParseArgsStd Hello Init Goodbye BackupCourseleafFile ParseCourseleafFile WriteChangelogEntry
originalArgStr="$*"
scriptDescription="Copy workflow files"

#====================================================================================================
# Copy workflow files
#====================================================================================================
# Copyright ©2015 David Scudiero -- all rights reserved.
# 09-03-14 -- dgs - Initial coding
# 07-17-15 -- dgs - Migrated to framework 5
# 01-06=15 -- dgs - change '*optional*' to 'optional' if target env is next
#====================================================================================================
#==================================================================================================
# Standard call back functions
#==================================================================================================
	function parseArgs-copyWorkflow  { # or parseArgs-local
		#argList+=(-optionArg,1,option,scriptVar,,script,'Help text')
		#argList+=(-flagArg,2,switch,scriptVar,,script,'Help text')
		argList+=(-allCims,3,switch,allCims,,script,'Process all CIM instances present')
	}
	function Goodbye-copyWorkflow  { # or Goodbye-local
		rm -rf $tmpRoot > /dev/null 2>&1
		return 0
	}
	function testMode-copyWorkflow  { # or testMode-local
		scriptData1="requiredInstanceFiles:workflow.tcf,cimconfig.cfg,custom.atj"
		scriptData2="optionalInstanceFiles:workflow.cfg,workflowFuncs.atj,custom-workflow.atj,workflowFunctions.atj,workflowHelperFunctions.atj,triggers.atj"
		scriptData3="requiredGlobalFiles:/courseleaf/cim/triggers.atj,/courseleaf/stdhtml/workflow.atj"
		scriptData4="optionalGlobalFiles:/courseleaf/locallibs/workflowLib.atj,/courseleaf/localsteps/workflowLib.atj"
		return 0
	}

#==================================================================================================
# Local Subs
#==================================================================================================
#==============================================================================================
# Edit cimconfig.cfg
#==============================================================================================
function EditCimconfigCfg {
	Msg2 $V1 "*** Starting $FUNCNAME ***"
	local editFile="$1"
	local searchStr grepStr fromStr toStr
	[[ ! -f "$editFile" ]] && Error "Edit file '$editFile' not found, skipping" && return 0

	BackupCourseleafFile $editFile
	Msg2 $I "Converting 'cimconfig.cfg' file structure to match the source file structure"

	fromStr='wfrules:'
	toStr='// Moved to ./workflow.cfg -- wfrules:'
	sed -i s"_^${fromStr}_${toStr}_" $editFile
	fromStr='wforder:'
	toStr='// Moved to ./workflow.cfg -- wforder:'
	sed -i s"_^${fromStr}_${toStr}_" $editFile
	searchStr='%import %pagebasedir%/workflow.cfg'
	unset grepStr; grepStr=$(grep "^$searchStr" $editFile)
	if [[ $grepStr == '' ]]; then
		unset grepStr; grepStr=$(grep "//$searchStr" $editFile)
		if [[ $grepStr == '' ]]; then
			echo >> $editFile
			echo '//=================================================================================================' >> $editFile
			echo '//Worfklow configuraton in ./workflow.cfg' >> $editFile
			echo "//Added by $userName via $myName on $(date)" >> $editFile
			echo $searchStr >> $editFile
			echo '//=================================================================================================' >> $editFile
			echo >> $editFile
		else
			fromStr="//$searchStr"
			toStr="$searchStr"
			sed -i s"_^${fromStr}_${toStr}_" $editFile
		fi
	fi
	return 0
} #EditCimconfig.cfg

#==============================================================================================
# Edit cusom.atj
#==============================================================================================
function EditCustomAtj {
	Msg2 $V1 "*** Starting $FUNCNAME ***"
	local editFile="$1"
	local searchStr grepStr fromStr toStr
	[[ ! -f "$editFile" ]] && Error "Edit file '$editFile' not found, skipping" && return 0

	BackupCourseleafFile $editFile
	Msg2 $I "Converting 'custom.atj' file structure to match the source file structure"

	searchStr="%import /$(basename $tgtDir)/workflowFunctions.atj:atj"
	unset grepStr; grepStr=$(grep "^$searchStr" $editFile)
	if [[ $grepStr == '' ]]; then
		searchStr="%import %progdir%/localsteps/workflowLib.atj:atj"
		unset grepStr; grepStr=$(grep "^$searchStr" $editFile)
	fi
	if [[ $grepStr == '' ]]; then
		unset grepStr; grepStr=$(grep "//$searchStr" $editFile)
		if [[ $grepStr == '' ]]; then
			echo >> $editFile
			echo '//=================================================================================================' >> $editFile
			echo "//Added by $userName via $myName on $(date)" >> $editFile
			echo '// Import workflow functions' >> $editFile
			echo $searchStr >> $editFile
			echo '//=================================================================================================' >> $editFile
			echo >> $editFile
		else
			fromStr="//$searchStr"
			toStr="$searchStr"
			sed -i s"_^${fromStr}_${toStr}_" $editFile
		fi
	fi
	return 0
} #Editcustom.atj

#==============================================================================================
# Do the copy, backup old copies to attic
#==============================================================================================
function DoCopy {
	eval $errSigOn
	local rawFile=$1; shift
	local cpyFile=$1; shift
	local srcDir=$1; shift
	local srcDirStruct=$1; shift
	local tgtDir=$1; shift
	local tgtDirStruct=$1; shift
	local srcFile tgtFile fromStr toStr ans verb

	srcFile=${srcDir}${cpyFile}
	tgtFile=${tgtDir}${cpyFile}
	#dump -p cpyFile srcEnv srcDir srcDirStruct srcFile tgtEnv tgtDir tgtDirStruct  tgtFile

	## Check the file structure of the target file, update if necessary
		[[ $(basename $cpyFile) == cimconfig.cfg && $srcDirStruct == new && $tgtDirStruct == old ]] && $DOIT EditCimconfigCfg "$tgtFile"
		[[ $(basename $cpyFile) == custom.atj && $srcDirStruct == new && $tgtDirStruct == old ]] && $DOIT EditCustomAtj "$tgtFile"
		if [[ $(basename $cpyFile) == workflow.cfg && $tgtEnv == 'next' ]]; then
			fromStr='wfStatus:has not been signed off yet'
			toStr="wfStatus:Released to next via $myName by $userName on $(date)"
			$DOIT sed -i s"_^${fromStr}_${toStr}_" $srcFile
		fi

	## If the target file does not exist then do not prompt, otherwise do diff and prompt
		[[ $(Contains "$ignoreList" "$cpyFile") == true ]] && return 0
		if [[ ! -f $tgtFile ]]; then
			copyFileList+=("${srcFile}|${tgtFile}")
			Msg2 "^^Target file does not exist, it will be copied"
		else
			[[ $batchMode != true && $noClear != true && $TERM != 'dumb' ]] && clear
			Msg2
			Msg2 "$(ColorK "Target File: $tgtFile")"
			Msg2 "\n\n* * * DIFF Output start * * *"
			Msg2 "${colorRed}< is ${srcFile}${colorDefault}"
			Msg2 "${colorBlue}> is ${tgtFile}${colorDefault}"
			printf '=%.0s' {1..120}
			Msg2
			ProtectedCall "colordiff $srcFile $tgtFile | Indent"
			Msg2 "$colorDefault"
			printf '=%.0s' {1..120}
			Msg2 "\n* * * DIFF Output end * * *\n\n"

			[[ $(Contains ",$setDefaultYesFiles," ",$(basename $cpyFile),") == true ]] && defVals='Yes' || unset defVals
			unset ans; Prompt ans "Yes to copy $cpyFile, eXit to stop" 'Yes No' "$defVals"; ans=$(Lower ${ans:0:1});
			[[ $ans != 'y' ]] && filesNotCopied+=($cpyFile) && return 0
			copyFileList+=("${srcFile}|${tgtFile}")
		fi

	return 0
} #DoCopy

#==============================================================================================
#  Cleanup any old backup workflow files (xxxx.yyyy, xxxx-yyyy, or ' - Copy.') in the source or target
#==============================================================================================
function CleanupOldFiles {

		local cpyFile="$1"
		local tmpArray copyOfFile
		## Get old file list
			unset oldFiles
			SetFileExpansion 'off'
			## Files that contain cars in the igoreList
			for token in $(tr ',' ' ' <<< $ignoreList); do
				SetFileExpansion 'on'
				unset tmpArray; tmpArray=($srcDir${cpyFile}${token})
				[[ ${tmpArray[@]} != "$srcDir${cpyFile}${token}" ]] && oldFiles+=($srcDir${cpyFile}${token})
				unset tmpArray; tmpArray=($tgtDir${cpyFile}${token})
				[[ ${tmpArray[@]} != "$tgtDir${cpyFile}${token}" ]] && oldFiles+=($tgtDir${cpyFile}${token})
				SetFileExpansion
			done
			## 'Copy of' files
			SetFileExpansion
			copyOfFile="$(dirname $cpyFile)/$(cut -d '.' -f1 <<< $(basename $cpyFile)) - Copy.$(cut -d '.' -f2- <<< $(basename $cpyFile))"
			[[ -f "$srcDir${copyOfFile}" ]] && oldFiles+=("$srcDir${copyOfFile}")
			[[ -f "$tgtDir${copyOfFile}" ]] && oldFiles+=("$tgtDir${copyOfFile}")

		## Baclup/Delete Files
			for ((i = 0; i < ${#oldFiles[@]}; i++)); do
			    Msg2 "^^^Backing up & Removeing: ${oldFiles[$i]}"
				$DOIT BackupCourseleafFile ${oldFiles[$i]}
				$DOIT rm -f ${oldFiles[$i]}
			done
	return 0
}

#====================================================================================================
# Declare local variables and constants
#====================================================================================================
unset copyFileList filesUpdated filesNotCopied setDefaultYesFiles
checkFileNew=workflow.cfg
fileSuffix="$(date +%s)"

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
GetDefaultsData $myName
ParseArgsStd
[[ $verbose == true ]] && verboseArg='-v' || unset verboseArg
[[ $env != '' ]] && srcEnv=$env
Hello

## Get the files to act on from the database
	unset requiredInstanceFiles optionalInstanceFiles requiredGlobalFiles optionalGlobalFiles ifThenDelete
	[[ $scriptData1 == '' ]] && Msg2 $T "'scriptData1 (requiredInstanceFiles)' is null, please check script configuration data"
	requiredInstanceFiles="$(cut -d':' -f2- <<< $scriptData1)"

	[[ $scriptData2 == '' ]] && Msg2 $T "'scriptData2 (optionalInstanceFiles)' is null, please check script configuration data"
	optionalInstanceFiles="$(cut -d':' -f2- <<< $scriptData2)"

	[[ $scriptData3 == '' ]] && Msg2 $T "'scriptData3 (requiredGlobalFiles)' is null, please check script configuration data"
	requiredGlobalFiles="$(cut -d':' -f2- <<< $scriptData3)"

	[[ $scriptData4 == '' ]] && Msg2 $T "'scriptData4 (optionalGlobalFiles)' is null, please check script configuration data"
	optionalGlobalFiles="$(cut -d':' -f2- <<< $scriptData4)"

	if [[ $scriptData5 ]]; then
		ifThenDelete="$(cut -d':' -f2- <<< $scriptData5)"
		deleteThenIf=$(tr ',' ';' <<< $deleteThenIf)
		deleteThenIf=$(tr ' ' ',' <<< $deleteThenIf)
		deleteThenIf=$(tr ';' ' ' <<< $deleteThenIf)
	fi

	[[ $allowList != '' ]] && setDefaultYesFiles="$(cut -d':' -f2- <<< $allowList)"

	dump -1 requiredInstanceFiles optionalInstanceFiles requiredGlobalFiles optionalGlobalFiles setDefaultYesFiles ifThenDelete

# Initialize instance variables
	Init 'getClient getSrcEnv getTgtEnv getDirs checkEnvs getCims'
	dump -1 client env srcEnv srcDir tgtEnv tgtDir cimStr


## If pvtDir exists and src is not pvt make sure that this is what the user really wants to to
	if [[ -d "$pvtDir" && $srcEnv != 'pvt' && $tgtEnv != 'pvt' ]]; then
		verify=true
		Msg2
		Msg2 $W "You are asking to source the copy from the $(ColorW $(Upper $srcEnv)) environment but a private site ($client-$userName) was detected"
		unset ans; Prompt ans "Are you sure" "Yes No";
		ans=$(Lower ${ans:0:1})
		[[ $ans != 'y' ]] && Goodbye -1
	fi

## Get update comment
	unset updateComment
	[[ $verify == true ]] && echo
	Prompt jalotTask "Please enter the jalot task number:" "*optional*"
	if [[ $verify == true ]]; then
		Msg2 "Please enter the business reason for making this update:"
		Prompt updateComment "^" "*any*"
		[[ -n $jalotTask ]] && updateComment="(Task:$jalotTask) $updateComment"
	fi

## Verify continue
	unset verifyArgs
	verifyArgs+=("Client:$client")
	verifyArgs+=("Source Env:$(TitleCase $srcEnv) ($srcDir)")
	verifyArgs+=("Target Env:$(TitleCase $tgtEnv) ($tgtDir)")
	verifyArgs+=("Update comment:$updateComment")
	verifyArgs+=("CIM(s):$cimStr")
	VerifyContinue "You are copying CIM workflow files for:"
	dump -1 client srcEnv tgtEnv srcDir tgtDir cimStr

## Log execution
	myData="Client: '$client', srcEnv: '$srcEnv', tgtEnv: '$tgtEnv'"
	[[ $logInDb != false && $myLogRecordIdx != "" && $testMode != true ]] && dbLog 'data' $myLogRecordIdx "$myData"

#====================================================================================================
## Main
#====================================================================================================
## Loop through CIMs
 	Msg2 "Checking CIM instances ..."
	for cim in $(echo $cimStr | tr ',' ' '); do
		Msg2 "^$cim:"
		[[ ! -d $tgtDir/web/$cim ]] && Msg2 "^Target CIM instance ($cim) does not exist, skipping" && continue

		## Determin what structure the src and tgt have
		[[ -f $srcDir/web/$cim/$checkFileNew ]] && srcStructure='new' || srcStructure='old'
		[[ -f $tgtDir/web/$cim/$checkFileNew ]] && tgtStructure='new' || tgtStructure='old'
		[[ $srcStructure == old && $tgtStructure == new ]] && Msg2 $T "The source file structure is OLD and the target structure is NEW, cannot continue"
		dump -1 -t srcStructure tgtStructure

		## Loop through the instance files
		for file in $(echo "$requiredInstanceFiles $optionalInstanceFiles" | tr ',' ' '); do
			cpyFile=/web/$cim/$file
			dump -1 -t -t -t file cpyFile
			if [[ ! -f $srcDir/$cpyFile ]]; then
				[[ $(Contains "$requiredInstanceFiles" "$file") == true ]] && Msg2 $T "Could not locate required source file: '$srcDir/$cpyFile'"
				continue
			fi
			Msg2 "^^$file"
			##  Cleanup any old backup workflow files (xxxx.yyyy, xxxx-yyyy, or ' - Copy.') in the source or target
				[[ $srcEnv != 'pvt' && $srcEnv != 'dev' ]] && CleanupOldFiles "$cpyFile"
			## Copy files
				if [[ -f $srcDir/$cpyFile ]]; then
					srcMd5=$(md5sum $srcDir/$cpyFile | cut -f1 -d" ")
					[[ -r  $tgtDir/$cpyFile ]] && tgtMd5=$(md5sum $tgtDir/$cpyFile | cut -f1 -d" ") || unset tgtMd5
					# echo -e "\n\t\t $srcDir/$cpyFile : $srcMd5\n\t\t $tgtDir/$cpyFile : $tgtMd5"
					if [[ $srcMd5 != $tgtMd5 ]]; then
						$DOIT DoCopy $file $cpyFile $srcDir $srcStructure $tgtDir $tgtStructure
					else
						Msg2 "^^^File MD5's match"
					fi
				fi
		done #file
	done #Cims

## Global files
	echo; Msg2 "Checking global/system workflow files..."
	for file in $(echo "$requiredGlobalFiles $optionalGlobalFiles" | tr ',' ' '); do
		Msg2 "^$file"
		cpyFile="/web$file"
		##  Cleanup any old backup workflow files (xxxx.yyyy, xxxx-yyyy, or ' - Copy.') in the source or target
			[[ $srcEnv != 'pvt' && $srcEnv != 'dev' ]] && CleanupOldFiles "$cpyFile"

		## Copy Filescou
			if [[ -f $srcDir/$cpyFile ]]; then
				srcMd5=$(md5sum $srcDir/$cpyFile | cut -f1 -d" ")
				[[ -f $tgtDir/$cpyFile ]] && tgtMd5=$(md5sum $tgtDir/$cpyFile | cut -f1 -d" ") || unset tgtMd5
				if [[ $srcMd5 != $tgtMd5 ]]; then
					$DOIT DoCopy $file $cpyFile $srcDir 'n/a' $tgtDir 'n/a';
				else
					Msg2 "^^File MD5's match"
				fi
			fi
	done #System files

[[ $batchMode != true && $noClear != true && $TERM != 'dumb' ]] && clear
Msg2
## Copy the files
	## If some files were not selected for update then as the user if they really want to copy the files
	if [[ ${#filesNotCopied[@]} -gt 0 ]]; then
		Msg2 $W "You asked that some changed files NOT be updated: "
		for file in "${filesNotCopied[@]}"; do
			Msg2 "^$file"
		done
		Msg2
		unset ans; Prompt ans "Do you wish to perform a partial update to the site" 'Yes No' 'No'; ans=$(Lower ${ans:0:1});
		[[ $ans != 'y' ]] && Msg2 $W "No files have been updated" && Goodbye 1
	fi

	if [[ ${#copyFileList[@]} -gt 0 ]]; then
		## Save old workflow files
		Msg2
		Msg2 "Saving target ($tgtEnv) workflow files (before updates)..."
		$DOIT saveWorkflow --quiet $client -$tgtEnv -cims "$(echo $cimStr | tr -d ' ')" -suffix "beforeCopy-$fileSuffix" -nop -quiet $verboseArg
		## Copy files
		Msg2 "Updating files:"
		for filePair in "${copyFileList[@]}"; do
			srcFile=$(cut -d'|' -f1 <<< $filePair)
			tgtFile=$(cut -d'|' -f2 <<< $filePair)
			Msg2 "^$(basename $srcFile)"
			[[ -f $tgtFile ]] && BackupCourseleafFile $tgtFile && rm -f $tgtFile
			$DOIT cp -fp $srcFile $tgtFile
			[[ $(basename $srcFile) == 'workflow.tcf' && $tgtEnv == 'next' ]] && $DOIT sed -i s'_*optional*_optional_' $tgtFile
			filesUpdated+=(${tgtFile##*$tgtDir})
		done
	else
		## Nothing to do
		echo; Msg2 $WT1 "No files required updating, nothing changed"
	fi

	if [[ ${#filesNotCopied[@]} -gt 0 ]]; then
		echo; Msg2 $W "The following changed files were NOT updated:"
		for file in "${filesNotCopied[@]}"; do
			Msg2 "^$file"
		done
	fi

## Delete obsolete files
	for cim in $(echo $cimStr | tr ',' ' '); do
		for filePair in $deleteThenIf; do
			checkSrcFile=$(cut -d ',' -f1 <<< $filePair); checkTgtFile=$(cut -d ',' -f2 <<< $filePair)
			[[ ${checkSrcFile:0:1} == '/' ]] && checkSrcFile="$srcDir/web${checkSrcFile}" || checkSrcFile="$srcDir/web/$cim/${checkSrcFile}"
			[[ ${checkTgtFile:0:1} == '/' ]] && checkTgtFile="$tgtDir/web${checkTgtFile}" || checkTgtFile="$tgtDir/web/$cim/${checkTgtFile}"
			if [[ -f $checkSrcFile && -f $checkTgtFile ]]; then
				Msg2 "^^^Backing up & Removeing: $checkTgtFile"
				$DOIT BackupCourseleafFile $checkTgtFile
				$DOIT rm -f $checkTgtFile
			fi
		done
	done

## Write out change log entries
	if [[ ${#copyFileList} -gt 0 && $DOIT == '' ]]; then
		## Log changes
		[[ -n $updateComment ]] && changeLogLines=("$updateComment")
		changeLogLines+=("Files updated from: '$srcDir'")
		for file in "${filesUpdated[@]}"; do
			changeLogLines+=("${tabStr}${file}")
		done
		env=$tgtEnv
		WriteChangelogEntry 'changeLogLines' "$tgtDir/changelog.txt" "$myName"

		echo; Msg2 "Saving target workflow files (after updates)..."
		$DOIT saveWorkflow $client -$tgtEnv -cims "$(echo $cimStr | tr -d ' ')" -suffix "afterCopy-$fileSuffix" -nop -quiet $verboseArg
	fi

#====================================================================================================
## Bye-bye
Goodbye 0 "$(ColorK $(Upper $client/$srcEnv)) to $(ColorK $(Upper $client/$tgtEnv))"

#====================================================================================================
# Check-in Log
#====================================================================================================
## Fri Apr  1 13:30:01 CDT 2016 - dscudiero - Switch --useLocal to $useLocal
## Wed Apr  6 16:08:53 CDT 2016 - dscudiero - switch for
## Tue Apr 12 09:12:43 CDT 2016 - dscudiero - Add changing the wfStatus if copying to next
## Thu Apr 14 13:16:10 CDT 2016 - dscudiero - Tweak message colors
## Fri Jun 24 09:14:01 CDT 2016 - dscudiero - Fix problem showing data in VerifyContinue, switch to new way
## Fri Jun 24 09:53:00 CDT 2016 - dscudiero - Added auto copy feature
## Tue Jul  5 16:35:09 CDT 2016 - dscudiero - Remove debug messages
## Fri Jul  8 09:16:21 CDT 2016 - dscudiero - Updates for cim cims
## Thu Jul 14 12:06:49 CDT 2016 - dscudiero - Put checks in if target is next or Curr, or src not pvt and pvt site was detected
## Fri Jul 15 10:31:48 CDT 2016 - dscudiero - Removed the No Backups done comment
## Thu Aug 11 13:00:40 CDT 2016 - dscudiero - Re factored to pull files from db
## Fri Aug 12 08:02:49 CDT 2016 - dscudiero - Add -allCims flag
## Mon Sep 19 09:27:44 CDT 2016 - dscudiero - Add code to cleanup obsolete files
## Fri Sep 23 11:41:01 CDT 2016 - dscudiero - Only save workflows if we are going to actually change something
## Thu Sep 29 12:54:00 CDT 2016 - dscudiero - Do not clear screen if TERM=dumb
## Tue Oct 11 14:30:29 CDT 2016 - dscudiero - Cosmetic internal changes
## Wed Oct 12 09:15:53 CDT 2016 - dscudiero - Tweak messages
## Tue Oct 25 15:45:15 CDT 2016 - dscudiero - Added logging of actions to transaction log in the clientsData folder
## Tue Oct 25 15:48:12 CDT 2016 - dscudiero - Only write out change log if the clientDataRoot folder exists
## Mon Jan  9 16:16:53 CST 2017 - dscudiero - Fixed problem where the changelog.txt records were all the same file
## Fri Jan 13 15:45:44 CST 2017 - dscudiero - testing
## Thu Jan 19 12:49:39 CST 2017 - dscudiero - Fix writing to the changelog.txt file
## Wed Jan 25 12:45:17 CST 2017 - dscudiero - Added debug statements
## Thu Jan 26 12:26:41 CST 2017 - dscudiero - Fix file logging issue
## Thu Jan 26 12:30:37 CST 2017 - dscudiero - General syncing of dev to prod
## Thu Jan 26 12:53:17 CST 2017 - dscudiero - General syncing of dev to prod
## Thu Feb  9 08:06:38 CST 2017 - dscudiero - make sure we are using our own tmpFile
## Tue Feb 14 12:24:17 CST 2017 - dscudiero - Tweak messaging format
## Tue Feb 14 12:29:28 CST 2017 - dscudiero - Tweaked messaging
## Mon Feb 20 09:26:45 CST 2017 - dscudiero - Do not clean up source directories if pvt or dev
## Mon Mar  6 12:07:10 CST 2017 - dscudiero - added update comment for the log
## Tue Mar  7 14:45:49 CST 2017 - dscudiero - add jalot task to the update comment
## Fri Mar 17 16:40:36 CDT 2017 - dscudiero - remove errant t from logged lines
## 04-04-2017 @ 09.08.22 - (2.8.75)    - dscudiero - Fix issue where it wasa still prompting for jalot and reason when noPrompt was active
