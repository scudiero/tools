#!/bin/bash
#XO NOT AUTOVERSION
#====================================================================================================
version="2.11.53" # -- dscudiero -- Wed 05/01/2019 @ 16:04:55
#====================================================================================================
TrapSigs 'on'
myIncludes="StringFunctions ProtectedCall WriteChangelogEntry BackupCourseleafFile ParseCourseleafFile RunCourseLeafCgi SetSiteDirs"
myIncludes="$myIncludes SetSiteDirsNew"
Import "$standardInteractiveIncludes $myIncludes"

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
	function copyWorkflow-ParseArgsStd  {
		#myArgs+=("shortToken|longToken|type|scriptVariableName|<command to run>|help group|help textHelp")
		myArgs+=("jal|jalot|option|jalot||script|Jalot task number")
		myArgs+=("comment|comment|option|comment||script|Comment describing the reason for the update")
		myArgs+=("roles|roles|switch|roles||script|Also copy the '/courseleaf/roles.tcf' file")
		myArgs+=("users|users|switch|users||script|Also copy the '/db/clusers.sqlite' file")
		myArgs+=("cims|cimstr|option|cimStr||script|Comma separated list of cims to copy")
		myArgs+=("sitedir|sitedir|option|siteDir||script|The absolute path to the site root directory")
	}

	function copyWorkflow-Goodbye  {
		SetFileExpansion 'on' ; rm -rf $tmpRoot/${myName}* >& /dev/null ; SetFileExpansion
		return 0
	}

	function copyWorkflow-testMode  {
		scriptData1="requiredInstanceFiles:workflow.tcf,cimconfig.cfg,custom.atj"
		scriptData2="optionalInstanceFiles:workflow.cfg,workflowFuncs.atj,custom-workflow.atj,workflowFunctions.atj,workflowHelperFunctions.atj,triggers.atj"
		scriptData3="requiredGlobalFiles:/courseleaf/cim/triggers.atj,/courseleaf/stdhtml/workflow.atj"
		scriptData4="optionalGlobalFiles:/courseleaf/locallibs/workflowLib.atj,/courseleaf/localsteps/workflowLib.atj"
		return 0
	}

	function copyWorkflow-Help  {
		helpSet='client,src,tgt' # can also include any of {env,cim,cat,clss}, 'script' and 'common' automatically addeed
		[[ $1 == 'setVarsOnly' ]] && return 0

		[[ -z $* ]] && return 0
		bullet=1
		echo -e "This script can be used to copy workflow related files from one environment to another."
		echo -e "The actions performed are:"
		echo -e "\t$bullet) Copies CIM instance files:"
		if [[ -n "$requiredInstanceFiles$optionalInstanceFiles" ]]; then
			for file in $(tr ',' ' ' <<< $requiredInstanceFiles) $(tr ',' ' ' <<< $optionalInstanceFiles); do
				echo -e "\t\t- $file"
			done
		fi
		if [[ -n "$optionalGlobalFiles" ]]; then
			(( bullet++ ))
			echo -e "\t$bullet)  Copies CIM instance shared files: "
			for file in $(tr ',' ' ' <<< $optionalGlobalFiles); do
				echo -e "\t\t- $file"
			done
		fi
		if [[ -n "$requiredGlobalFiles" ]]; then
			(( bullet++ ))
			echo -e "\t$bullet)  Copies/refreshes CourseLeaf core files: "
			for file in $(tr ',' ' ' <<< $requiredGlobalFiles); do
				echo -e "\t\t- $file"
			done
		fi
		echo -e "\tEach source file is compared to the target file (using md5's) and if different the differences are displayed in a 'diff' format and the user is asked to confirm or reject the copy."
		echo -e "\tAll copied files are backed up to '$backupFolder', an entry in the changelog.txt file is made what, why, when, and who."
		(( bullet++ ))
		echo -e "\t$bullet) Performs workflow data checks:"
		(( bullet++ ))
		echo -e "\t\t- Checks to see of the target file structure is old (just cimconfig.cfg etc.) and the source target file structure is new (workflow.cfg etc.) and if different then it comments out the 'old' workflow elements in the target before copying files."
		echo -e "\t\t- Sets the debug level to 0."
		echo -e "\t\t- Checks for the presence of an active debug workflow (workflow:standard|START), if found the debug workflow is commented out."
		echo -e "\t\t- Checks for the presence of a TODO step in any workflow, if found and the target is NEXT then the script terminates, otherwise a warning message is displayed."
		(( bullet++ ))
		if [[ -n "$ifThenDelete" ]]; then
			echo -e "\t$bullet) Deletes old structure files in the target if not present in the source"
			for filePair in $ifThenDelete; do
				checkSrcFile=$(cut -d ',' -f1 <<< $filePair); checkTgtFile=$(cut -d ',' -f2 <<< $filePair)
				echo -e "\t\t- Delete file '$checkTgtFile' if found in target and '$checkSrcFile' exists in source"
			done
		fi
		return 0
	}


#==================================================================================================
# Local Subs
#==================================================================================================
#==============================================================================================
# Edit cimconfig.cfg
#==============================================================================================
function EditCimconfigCfg {
	[[ $informationOnly == true ]] && return 0
	local editFile="$1"
	local searchStr grepStr fromStr toStr
	[[ ! -f "$editFile" ]] && Error "Edit file '$editFile' not found, skipping" && return 0

	BackupCourseleafFile $editFile
	Info "Converting 'cimconfig.cfg' file structure to match the source file structure"

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
	[[ $informationOnly == true ]] && return 0
	local editFile="$1"
	local searchStr grepStr fromStr toStr
	[[ ! -f "$editFile" ]] && Error "Edit file '$editFile' not found, skipping" && return 0

	BackupCourseleafFile $editFile
	Info "Converting 'custom.atj' file structure to match the source file structure"

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
# Check the files to see if they should be copied, backup old copies to attic
#==============================================================================================
function CheckFilesForCopy {
	eval $errSigOn
	local rawFile=$1; shift
	local cpyFile=$1; shift
	local srcDir=$1; shift
	local srcDirStruct=$1; shift
	local tgtDir=$1; shift
	local tgtDirStruct=$1; shift
	local srcFile tgtFile fromStr toStr ans verb grepStr

	srcFile=${srcDir}${cpyFile}
	tgtFile=${tgtDir}${cpyFile}
	#dump -p cpyFile srcEnv srcDir srcDirStruct srcFile tgtEnv tgtDir tgtDirStruct  tgtFile

	## Check the file structure of the target file, update if necessary
		# [[ $(basename $cpyFile) == cimconfig.cfg && $srcDirStruct == new && $tgtDirStruct == old ]] && $DOIT EditCimconfigCfg "$tgtFile"
		# [[ $(basename $cpyFile) == custom.atj && $srcDirStruct == new && $tgtDirStruct == old ]] && $DOIT EditCustomAtj "$tgtFile"
		# if [[ $(basename $cpyFile) == workflow.cfg && $tgtEnv == 'next' ]]; then
		# 	fromStr='wfStatus:has not been signed off yet'
		# 	toStr="wfStatus:Released to next via $myName by $userName on $(date)"
		# 	$DOIT sed -i s"_^${fromStr}_${toStr}_" $srcFile
		# fi

	## If the target file does not exist then do not prompt, otherwise do diff and prompt
		[[ $(Contains "$ignoreList" "$cpyFile") == true ]] && return 0
		if [[ ! -f $tgtFile ]]; then
			copyFileList+=("${srcFile}|${tgtFile}|${cpyFile}")
			Msg "^^Target file does not exist, it will be copied"
		else
			[[ $batchMode != true && $noClear != true && $TERM != 'dumb' ]] && clear

			## If this is a workflow.tcf file, check to make sure we do not have a 'debug' workflow definition active
			if [[ $(Contains "$cpyFile" 'workflow.tcf') == true ]]; then			
				unset grepStr; grepStr=$(ProtectedCall "grep '^wfDebugLevel:' $srcFile")
				if [[ -n $grepStr ]]; then
					fromStr="$grepStr"
					toStr="wfDebugLevel:0"
					$DOIT sed -i s"_^${fromStr}_${toStr}_" $srcFile
				fi
			fi

			Msg
			Msg "$(ColorK "Target File: $tgtFile")"
			Msg "\n\n* * * DIFF Output start * * *"
			Msg "${colorRed}< is ${srcFile}${colorDefault}"
			Msg "${colorBlue}> is ${tgtFile}${colorDefault}"
			printf '=%.0s' {1..120}
			Msg
			ProtectedCall "colordiff $srcFile $tgtFile | Indent"
			Msg "${colorDefault}"
			printf '=%.0s' {1..120}
			Msg "\n* * * DIFF Output end * * *\n\n"

			[[ $(Contains ",$setDefaultYesFiles," ",$(basename $cpyFile),") == true ]] && defVals='Yes' || defVals='No'
			unset ans; Prompt ans "Yes to copy $cpyFile, eXit to stop" 'Yes No' "$defVals"; ans=$(Lower ${ans:0:1});
			[[ $ans != 'y' ]] && filesNotCopied+=("$(basename $(dirname $srcFile))/$(basename $srcFile)") && return 0
			## If workflow.cfg then chec specific conditions
			if [[ $(Contains "$cpyFile" 'workflow.cfg') == true ]]; then
				unset grepStr; grepStr=$(ProtectedCall "grep '^wfDebugLevel:' $srcFile")
				if [[ -n $grepStr ]]; then
					fromStr="$grepStr"
					toStr="wfDebugLevel:0"
					$DOIT sed -i s"_^${fromStr}_${toStr}_" $srcFile
				fi
				for searchStr in skiploadsync:true wforder:wfDumpVars wfrules:WhatsChanged wforder:WhatsChanged ; do
					unset grepStr; grepStr=$(ProtectedCall "grep ^$searchStr $srcFile")
					if [[ -n $grepStr ]]; then
						fromStr="$grepStr"
						toStr="//$grepStr"
						$DOIT sed -i s"_^${fromStr}_${toStr}_" $srcFile
					fi
				done
			fi
			## If workflow.tcf then make sure the test workflow is commented out
			if [[ $(Contains "$cpyFile" 'workflow.tcf') == true ]]; then
				unset grepStr; grepStr=$(ProtectedCall "grep ^workflow\:.\*\|START, $srcFile")
				if [[ ${grepStr:0:1} != '#' ]]; then
					[[ -n $grepStr ]] && [[ $tgtEnv == 'test' || $tgtEnv == 'next' ]] && Terminate "Source 'workflow.tcf' file contained an active DEBUG workflow definition"
					[[ -n $grepStr && $tgtEnv == 'test' ]] && Warning 0 1 "Source 'workflow.tcf' file contained an 'TODO' step in the workflow definitions"
					unset grepStr; grepStr=$(ProtectedCall "grep '^workflow:standard|START' $srcFile")
					if [[ -n $grepStr ]]; then
						$DOIT sed -i s"_^workflow:standard|START_//workflow:standard|START_" $srcFile
						Warning "Workflow.tcf file contained an uncommented test workflow definition, it will be commented out"
					fi
				fi
			fi
			copyFileList+=("${srcFile}|${tgtFile}|${cpyFile}")
		fi

	return 0
} #CheckFilesForCopy

#==============================================================================================
#  Cleanup any old backup workflow files (xxxx.yyyy, xxxx-yyyy, or ' - Copy.') in the source or target
#==============================================================================================
# function CleanupOldFiles {
# 	local cpyFile="$1"
# 	local tmpArray copyOfFile
# 	## Get old file list
# 		unset oldFiles
# 		## 'Copy of' files
# 		SetFileExpansion
# 		copyOfFile="$(dirname $cpyFile)/$(cut -d '.' -f1 <<< $(basename $cpyFile)) - Copy.$(cut -d '.' -f2- <<< $(basename $cpyFile))"
# 		[[ -f "$srcDir${copyOfFile}" ]] && oldFiles+=("$srcDir${copyOfFile}")
# 		[[ -f "$tgtDir${copyOfFile}" ]] && oldFiles+=("$tgtDir${copyOfFile}")

# 	## Baclup/Delete Files
# 		for ((i = 0; i < ${#oldFiles[@]}; i++)); do
# 		    Msg "^^^Backing up & Removeing: ${oldFiles[$i]}"
# 			$DOIT BackupCourseleafFile ${oldFiles[$i]}
# 			$DOIT rm -f ${oldFiles[$i]}
# 		done
# 	return 0
# }

#====================================================================================================
# Declare local variables and constants
#====================================================================================================
unset copyFileList filesUpdated filesNotCopied setDefaultYesFiles
checkFileNew=workflow.cfg
fileSuffix="$(date +%s)"

Hello
GetDefaultsData $myName

## Get the files to act on from the database
	unset requiredInstanceFiles optionalInstanceFiles requiredGlobalFiles optionalGlobalFiles ifThenDelete
	[[ -z $scriptData1 ]] && Terminate "'scriptData1 (requiredInstanceFiles)' is null, please check script configuration data"
	requiredInstanceFiles="$(cut -d':' -f2- <<< $scriptData1)"

	[[ -z $scriptData2 ]] && Terminate "'scriptData2 (optionalInstanceFiles)' is null, please check script configuration data"
	optionalInstanceFiles="$(cut -d':' -f2- <<< $scriptData2)"

	[[ -z $scriptData3 ]] && Terminate "'scriptData3 (requiredGlobalFiles)' is null, please check script configuration data"
	requiredGlobalFiles="$(cut -d':' -f2- <<< $scriptData3)"

	[[ -z $scriptData4 ]] && Terminate "'scriptData4 (optionalGlobalFiles)' is null, please check script configuration data"
	optionalGlobalFiles="$(cut -d':' -f2- <<< $scriptData4)"

	if [[ -n $scriptData5 ]]; then
		ifThenDelete="$(cut -d':' -f2- <<< $scriptData5)"
		ifThenDelete=$(tr ',' ';' <<< $ifThenDelete)
		ifThenDelete=$(tr ' ' ',' <<< $ifThenDelete)
		ifThenDelete=$(tr ';' ' ' <<< $ifThenDelete)
	fi
	[[ $allowList != '' ]] && setDefaultYesFiles="$(cut -d':' -f2- <<< $allowList)"

## Hack to turn off system files
## TODO
	unset requiredGlobalFiles

	dump -1 requiredInstanceFiles optionalInstanceFiles requiredGlobalFiles optionalGlobalFiles setDefaultYesFiles ifThenDelete

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
[[ $verbose == true ]] && verboseArg='-v' || unset verboseArg
[[ $env != '' ]] && srcEnv=$env

ParseArgs $originalArgStr

[[ -n $unknowArgs ]] && cimStr="$unknowArgs"

[[ $srcEnv == 'alt' ]] && srcDir="$altEnv"
[[ $tgtEnv == 'p' ]] && tgtEnv='pvt'
[[ $tgtEnv == 't' ]] && tgtEnv='test'
[[ $tgtEnv == 'n' ]] && tgtEnv='next'

# Initialize instance variables
	if [[ $fastInit == true ]]; then
		if [[ -n $fromDir && -n $toDir ]]; then
			srcEnv="N/A"
			srcDir="$fromDir"
			tgtEnv="N/A"
			tgtDir="$toDir"
		else
			SetSiteDirsNew $client
			tmpStr="${srcEnv}Dir"; srcDir="${!tmpStr}"
			tmpStr="${tgtEnv}Dir"; tgtDir="${!tmpStr}"
		fi
		[[ $srcEnv == "alt" ]] && srcDir="$altEnv"
	else
		Init 'getClient getSrcEnv getTgtEnv getDirs checkEnvs getCims'
	fi
	dump -1 client env envs srcEnv srcDir tgtEnv tgtDir cimStr -p

# If target is NEXT checks
	if [[ $tgtEnv == 'next' ]]; then
		[[ $srcEnv != 'test' ]] && Terminate "The NEXT site may only be updated from the TEST environment, please push your changes in '$srcEnv' to TEST."
		[[ $verify == false ]] && Msg "Target is NEXT and verify was off, this is not allowed, setting verify to true" && verify=true
		## Get update comment
		[[ $verify == true ]] && echo
		Prompt jalot "Please enter the jalot task number:" "*any*"
		Prompt comment "Please enter the business reason for making this update:\n^" "*any*"
		[[ $jalot -eq 0 ]] && jalot='N/A'
		comment="(Task:$jalot) $comment"
		## Get update comment
		if [[ -z $refreshSystem && -n "$requiredGlobalFiles" ]]; then
			[[ $verify == true ]] && echo
			defVals='Yes'
			Msg "Do you wish to refresh the system level files from the skeleton or use those found in the source"
			unset ans ; Prompt ans "'Yes' to refresh, 'No' to use those from the source" 'Yes No' 'Yes'; ans=$(Lower ${ans:0:1})
			unset defVals
			[[ $ans == 'y' ]] && refreshSystem=true || refreshSystem=false
		fi		
	fi
## If pvtDir exists and src is not pvt make sure that this is what the user really wants to to
	# if [[ -d "$pvtDir" && $srcEnv != 'pvt' && $tgtEnv != 'pvt' ]]; then
	# 	verify=true
	# 	Msg
	# 	Warning "You are asking to source the copy from the $(ColorW $(Upper $srcEnv)) environment but a private site ($client-$userName) was detected"
	# 	unset ans; Prompt ans "Are you sure" "Yes No" "Yes";
	# 	ans=$(Lower ${ans:0:1})
	# 	[[ $ans != 'y' ]] && Goodbye -1
	# fi

## check cim and courseleaf versions
	unset srcClVer srcCimVer tgtClVer tgtCimVer
	[[ -r "$srcDir/web/courseleaf/clver.txt" ]] && srcClVer=$(cat "$srcDir/web/courseleaf/clver.txt")
	[[ -r "$srcDir/web/courseleaf/cim/clver.txt" ]] && srcCimVer=$(cat "$srcDir/web/courseleaf/cim/clver.txt")
	[[ -r "$tgtDir/web/courseleaf/clver.txt" ]] && tgtClVer=$(cat "$tgtDir/web/courseleaf/clver.txt")
	[[ -r "$tgtDir/web/courseleaf/cim/clver.txt" ]] && tgtCimVer=$(cat "$tgtDir/web/courseleaf/cim/clver.txt")

	if [[ $srcClVer != $tgtClVer || $srcCimVer != $tgtCimVer ]] && [[ $tgtEnv == 'next' ]]; then
		verify=true;
		[[ $srcClVer != $tgtClVer ]] && Warning "CourseLeaf version for source ($srcClVer) not the same as target ($tgtClVer)"
		[[ $srcCimVer != $tgtCimVer ]] && [[ $tgtEnv == 'next' ]] && Warning "CIM version for source ($srcCimVer) not the same as target ($tgtCimVer)"
		unset ans; Prompt ans "Do you wish to continue" "Yes No" "No"; ans="$(Lower ${ans:0:1})"
		[[ $ans != 'y' ]] && Terminate "Stopping"
	fi
## check the courseleaf revision levels in the workflow.tcf file
for cim in ${cimStr//,/ }; do
	srcFile="$srcDir/web/$cim/workflow.tcf"
	tgtFile="$tgtDir/web/$cim/workflow.tcf"
	srcRevhistorytca="$(ProtectedCall "grep 'revhistorytca:' $srcDir/web/$cim/workflow.tcf | tail -1 ")"
	tgtRevhistorytca="$(ProtectedCall "grep 'revhistorytca:' $tgtDir/web/$cim/workflow.tcf | tail -1 ")"
	if [[ $srcRevhistorytca != $tgtRevhistorytca ]]; then
		Warning "The base revision history tag's for the source and target are different in cim instance '$cim'"
		Msg "^^ The workflow.tcf file has been modified since the source was cloned."
		Msg "^^^ Source revhistorytca: $srcRevhistorytca"
		Msg "^^^ Target revhistorytca: $tgtRevhistorytca"
		unset ans; Prompt ans "Do you wish to continue" "Yes No" "No"; ans="$(Lower ${ans:0:1})"
	fi
done

## Verify continue
	verify=true
	unset verifyArgs
	verifyArgs+=("Client:$client")
	verifyArgs+=("Source Env:$(TitleCase $srcEnv) ($srcDir)")
	verifyArgs+=("Target Env:$(TitleCase $tgtEnv) ($tgtDir)")
	[[ -n $roles ]] && verifyArgs+=("/courseleaf/roles.tcf:$roles")
	[[ -n $users ]] && verifyArgs+=("/db/clusers.sqlite:$roles")
	verifyArgs+=("Update comment:$comment")
	verifyArgs+=("CIM(s):$cimStr")
	[[ $srcClVer != $tgtClVer ]] && verifyArgs+=("Warning:CourseLeaf version for source ($srcClVer) not the same as target ($tgtClVer)")
	[[ $srcCimVer != $tgtCimVer ]] && verifyArgs+=("Warning:CIM version for source ($srcCimVer) not the same as target ($tgtCimVer)")
	[[ $srcRevhistorytca != $tgtRevhistorytca ]] && verifyArgs+=("Warning:Courseleaf revision base's are not the same (see above))")
	[[ $refreshSystem == true ]] && verifyArgs+=("Refresh system files:$refreshSystem")
	VerifyContinue "You are copying CIM workflow files for:"
	dump -1 client srcEnv tgtEnv srcDir tgtDir cimStr

## Log execution
	myData="Client: '$client', srcEnv: '$srcEnv', tgtEnv: '$tgtEnv'"
	[[ $logInDb != false && $myLogRecordIdx != "" && $testMode != true ]] && dbLog 'data' $myLogRecordIdx "$myData"

#====================================================================================================
## Main
#====================================================================================================
## Loop through CIMs
	[[ $informationOnly == true ]] && DOIT='echo'
	## Force verify to on
	verify=true
 	Msg "Checking CIM instances ..."
	for cim in $(echo $cimStr | tr ',' ' '); do
		Msg "^$cim:"
		[[ ! -d $tgtDir/web/$cim ]] && Msg "^Target CIM instance ($cim) does not exist, skipping" && continue

		## Determin what structure the src and tgt have
		[[ -f $srcDir/web/$cim/$checkFileNew ]] && srcStructure='new' || srcStructure='old'
		[[ -f $tgtDir/web/$cim/$checkFileNew ]] && tgtStructure='new' || tgtStructure='old'
		[[ $srcStructure == 'old' && $tgtStructure == 'new' ]] && Terminate "The source file structure is OLD and the target structure is NEW, cannot continue"
		[[ $srcStructure == 'new' && $tgtStructure == 'old' ]] && Warning "The source file structure is NEW and the target structure is OLD, manual intervantion will probably be required"
		dump -1 -t srcStructure tgtStructure

		## If the target env is NEXT and there is a TODO step coded then skip
		if [[ $tgtEnv == next ]]; then
			grepStr=$(ProtectedCall "grep 'TODO' $srcDir/web/$cim/workflow.tcf")
			[[ -n $grepStr ]] && { Error "Target environment is NEXT and found a 'TODO' step coded, skipping cim instance: $cim"; continue; }
		fi

		## Loop through the instance files
		for file in $(echo "$requiredInstanceFiles $optionalInstanceFiles" | tr ',' ' '); do
			cpyFile=/web/$cim/$file
			dump -1 -t -t -t file cpyFile
			if [[ ! -f $srcDir/$cpyFile ]]; then
				[[ $(Contains "$requiredInstanceFiles" "$file") == true ]] && Terminate "Could not locate required source file: '$srcDir/$cpyFile'"
				continue
			fi
			Msg "^^$file"
			##  Cleanup any old backup workflow files (xxxx.yyyy, xxxx-yyyy, or ' - Copy.') in the source or target
				#[[ $srcEnv != 'pvt' && $srcEnv != 'dev' ]] && CleanupOldFiles "$cpyFile"
			## Copy files
				if [[ -f $srcDir/$cpyFile ]]; then
					srcMd5=$(md5sum $srcDir/$cpyFile | cut -f1 -d" ")
					[[ -r  $tgtDir/$cpyFile ]] && tgtMd5=$(md5sum $tgtDir/$cpyFile | cut -f1 -d" ") || unset tgtMd5
					# echo -e "\n\t\t $srcDir/$cpyFile : $srcMd5\n\t\t $tgtDir/$cpyFile : $tgtMd5"
					if [[ $srcMd5 != $tgtMd5 ]]; then
						$DOIT CheckFilesForCopy $file $cpyFile $srcDir $srcStructure $tgtDir $tgtStructure
					else
						Msg "^^^File MD5's match"
					fi
				fi
		done #file
	done #Cims

## Global files
	[[ $roles == true ]] && optionalGlobalFiles="$optionalGlobalFiles /courseleaf/roles.tcf"
	[[ $users == true ]] && optionalGlobalFiles="$optionalGlobalFiles ../db/clusers.sqlite"
	echo; Msg "Checking global/system workflow files..."
	for file in $(echo "$requiredGlobalFiles $optionalGlobalFiles" | tr ',' ' '); do
		Msg "^$file"
		cpyFile="/web$file"
		##  Cleanup any old backup workflow files (xxxx.yyyy, xxxx-yyyy, or ' - Copy.') in the source or target
			#[[ $srcEnv != 'pvt' && $srcEnv != 'dev' ]] && CleanupOldFiles "$cpyFile"

		## Copy Files
			[[ $refreshSystem == true ]] && srcDir="$skeletonRoot/release"
			if [[ -f $srcDir/$cpyFile ]]; then
				srcMd5=$(md5sum $srcDir/$cpyFile | cut -f1 -d" ")
				[[ -f $tgtDir/$cpyFile ]] && tgtMd5=$(md5sum $tgtDir/$cpyFile | cut -f1 -d" ") || unset tgtMd5
				if [[ $srcMd5 != $tgtMd5 ]]; then
					$DOIT CheckFilesForCopy $file $cpyFile $srcDir 'n/a' $tgtDir 'n/a';
				else
					Msg "^^File MD5's match"
				fi
			fi
	done #System files

[[ $batchMode != true && $noClear != true && $TERM != 'dumb' ]] && clear
Msg
## Copy the files
	if [[ $verify == true ]]; then
		Msg "The following files will be copied:"
		for fileSpec in "${copyFileList[@]}"; do
			Msg "^$(cut -d'|' -f3 <<< $fileSpec)"
		done
	fi

	## If some files were not selected for update then as the user if they really want to copy the files
	if [[ ${#filesNotCopied[@]} -gt 0 ]]; then
		Msg
		Warning "The following files $(ColorW "NOT") be updated: "
		for file in "${filesNotCopied[@]}"; do
			Msg "^$file"
		done
		Msg
		unset ans defVals; Prompt ans "Do you wish to perform a partial update to the site" 'Yes No' 'No'; ans=$(Lower ${ans:0:1});
		[[ $ans != 'y' ]] && Warning "No files have been updated" && Goodbye 1
	else
		Msg
		unset ans defVals; Prompt ans "Do you wish to update to the '$tgtEnv' site" 'Yes No'; ans=$(Lower ${ans:0:1});
	fi

	if [[ ${#copyFileList[@]} -gt 0 ]]; then
		## Save old workflow files
		backupFolder=$tmpRoot/$myName-$client-$tgtEnv
		[[ -d $backupFolder ]] && $DOIT rm -rf $backupFolder
		$DOIT mkdir -p ${backupFolder}/${tgtEnv}BeforeCopy
		$DOIT mkdir -p ${backupFolder}/${tgtEnv}AfterCopy
		## Copy files
		Msg "\nUpdating files:"
		for fileSpec in "${copyFileList[@]}"; do
			srcFile="$(cut -d'|' -f1 <<< $fileSpec)"
			tgtFile="$(cut -d'|' -f2 <<< $fileSpec)"
			cpyFile="$(cut -d'|' -f3 <<< $fileSpec)"
			## Make a copy of the before and after in the temp area
			$DOIT mkdir -p "$backupFolder/${tgtEnv}BeforeCopy$(dirname $cpyFile)"
			$DOIT mkdir -p "$backupFolder/${tgtEnv}AfterCopy$(dirname $cpyFile)"
			[[ -f "$tgtFile" ]] && cp -fp "$tgtFile" "$backupFolder/${tgtEnv}BeforeCopy${cpyFile}"
			$DOIT cp -fp "$srcFile" "$backupFolder/${tgtEnv}AfterCopy${cpyFile}"
			## Copy
			Msg "^$(basename $(dirname $srcFile))/$(basename $srcFile)"
			[[ -f $tgtFile ]] && BackupCourseleafFile $tgtFile && $DOIT rm -f $tgtFile
			[[ ! -d $(dirname "$tgtFile") ]] && $DOIT mkdir -p "$(dirname "$tgtFile")"
			$DOIT cp -fp $srcFile $tgtFile
			[[ $(basename $srcFile) == 'workflow.tcf' && $tgtEnv == 'next' ]] && $DOIT sed -i s'_*optional*_optional_' $tgtFile
			filesUpdated+=(${tgtFile##*$tgtDir})
		done
		## Tar up the before and after folders
		pushd "$backupFolder" >& /dev/null
		tarDir=$localClientWorkFolder/$client/workflowBackups
		[[ ! -d $tarDir ]] && mkdir -p $tarDir
		tarFile="$tarDir/${srcEnv}-2-${tgtEnv}--$backupSuffix.tar.gz"
		$DOIT ProtectedCall "tar -cpzf \"$tarFile\" ./*"; rc=$?
		[[ $rc -ne 0 ]] && Error "Non-zero return code from tar"
		cd ..
		[[ ! -d "$tgtDir/attic" ]] && mkdir -p "$tgtDir/attic"
		cp -f "$tarFile" "$tgtDir/attic"
		$DOIT rm -rf "/${backupFolder#*/}"
		popd >& /dev/null
		Msg "Backup files located at: '$tarFile'"

		## Check the courseleaf console page
		if [[ $tgtEnv == 'next' || $tgtEnv == 'test' ]]; then
			updatedFile=false
			Msg "Checking console workflow management entries"
			editFile="$tgtDir/web/courseleaf/index.tcf"
			## Make sure we have an active sectionlinks:CIM on the console
			unset grepStr; grepStr=$(ProtectedCall "grep "^sectionlinks:CIM" "$editFile"")
			if [[ -z $grepStr ]]; then
				unset grepStr; grepStr=$(ProtectedCall "grep "^//sectionlinks:CIM" "$editFile"")
				if [[ -n $grepStr ]]; then
					fromStr="$grepStr"
					toStr="${grepStr:2}"
					$DOIT sed -i s"_^${fromStr}_${toStr}_" $editFile
					Msg "^Activating CIM 'section'"
					updatedFile=true
				else
					Warning "Could not locate the 'sectionlinks:CIM' record in\n^ '$editFile'"
				fi
			fi

			# ## Make sure that we have active workflow management on the console
			# for cim in $(tr ',' ' ' <<< "$cimStr"); do
			# 	unset grepStr; grepStr=$(ProtectedCall "grep '^navlinks:CIM|Course Workflow Management|workflow^/$cim/workflow.html' "$editFile"")
			# 	if [[ -z $grepStr ]]; then
			# 		unset grepStr; grepStr=$(ProtectedCall "grep '^//navlinks:CIM|Course Workflow Management|workflow^/$cim/workflow.html' "$editFile"")
			# 		if [[ -n $grepStr ]]; then
			# 			fromStr="$grepStr"
			# 			toStr="${grepStr:2}"
			# 			Msg "^Activating Workflow Management for '$cim'"
			# 			$DOIT sed -i s"_^${fromStr}_${toStr}_" $editFile
			# 			updatedFile=true
			# 		else
			# 			Warning "Could not locate a 'workflow management' record for '$cim' in \n^'$editFile'"
			# 		fi
			# 	fi
			# done
			# [[ $updatedFile == true ]] && RunCourseLeafCgi "$tgtDir" "-r /courseleaf/index.tcf"
		fi
	else
		## Nothing to do
		echo; Msg W 0 1 "No files required updating, nothing changed"
	fi

	if [[ ${#filesNotCopied[@]} -gt 0 ]]; then
		echo; Warning "The following changed files were NOT updated:"
		for file in "${filesNotCopied[@]}"; do
			Msg "^$file"
		done
	fi

## Delete obsolete files
	Msg "Cleaning up obsolete files"
	for cim in $(echo $cimStr | tr ',' ' '); do
		for filePair in $ifThenDelete; do
			checkSrcFile=$(cut -d ',' -f1 <<< $filePair); checkTgtFile=$(cut -d ',' -f2 <<< $filePair)
			[[ ${checkSrcFile:0:1} == '/' ]] && checkSrcFile="$srcDir/web${checkSrcFile}" || checkSrcFile="$srcDir/web/$cim/${checkSrcFile}"
			[[ ${checkTgtFile:0:1} == '/' ]] && checkTgtFile="$tgtDir/web${checkTgtFile}" || checkTgtFile="$tgtDir/web/$cim/${checkTgtFile}"
			if [[ -f $checkSrcFile && -f $checkTgtFile ]]; then
				Msg "^^^Backing up & Removeing: $checkTgtFile"
				$DOIT BackupCourseleafFile $checkTgtFile
				$DOIT rm -f $checkTgtFile
			fi
		done
	done

## Write out change log entries
	if [[ ${#copyFileList} -gt 0 ]]; then
		Msg "Writing changelog.txt records..."
		## Log changes
		[[ -n $comment ]] && changeLogLines=("$comment")
		changeLogLines+=("Files updated from: '$srcDir'")
		for file in "${filesUpdated[@]}"; do
			changeLogLines+=("${tabStr}${file}")
		done
		env=$tgtEnv
		if [[ $DOIT == '' ]]; then
			WriteChangelogEntry 'changeLogLines' "$tgtDir/changelog.txt" "$myName"
		else
			for ((i=0; i<${#changeLogLines[@]}; i++)); do
				echo -e "\t${changeLogLines[$i]}"
			done
		fi
		Msg "Logging done"
	fi

[[ -x $HOME/bin/logit ]] && $HOME/bin/logit -cl "${client:--}" -e "${tgtEnv:--}" -ca 'workflow' -j "$jalot" "$myName - Copied workflow data"


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
## 04-04-2017 @ 09.08.22 - 2.8.75 - dscudiero - Fix issue where it wasa still prompting for jalot and reason when noPrompt was active
## 05-12-2017 @ 11.10.41 - 2.8.76 - dscudiero - Added -jalot and -changeComment as options to the command line call
## 05-16-2017 @ 08.23.15 - 2.8.88 - dscudiero - Incorporate save workflow functionality into the script proper
## 05-16-2017 @ 10.30.20 - 2.8.89 - dscudiero - only delete the created tmp directory, not all of tmpRoot
## 05-19-2017 @ 14.08.07 - 2.8.90 - dscudiero - Turn off debugging messages when copy a workflow
## 05-22-2017 @ 11.12.35 - 2.8.10 - dscudiero - Make check for jalot number isNumeric
## 05-24-2017 @ 08.11.15 - 2.9.9  - dscudiero - Put in checks to make sure there is not a debug standard workflow active
## 05-24-2017 @ 12.22.33 - 2.9.19 - dscudiero - Fix problem when the target file/directory does not exist
## 05-26-2017 @ 09.41.06 - 2.9.22 - dscudiero - Make sure that cimsync is not commentd out
## 07-21-2017 @ 13.15.56 - 2.9.23 - dscudiero - Add more records in the workflow.cfg record checking/commenting logic
## 08-08-2017 @ 16.56.10 - 2.9.24 - dscudiero - Display the directory with the file when updating files
## 08-08-2017 @ 16.58.02 - 2.9.25 - dscudiero - General syncing of dev to prod
## 08-17-2017 @ 15.56.56 - 2.9.26 - dscudiero - set DOIT to echo if informationMode
## 08-22-2017 @ 14.16.02 - 2.9.31 - dscudiero - Fix syntax error
## 08-28-2017 @ 11.37.12 - 2.9.32 - dscudiero - Add checking for TODO step if target env is NEXT
## 08-28-2017 @ 14.29.02 - 2.9.37 - dscudiero - Fixed check for TODO in workflow.tcf
## 08-29-2017 @ 13.12.12 - 2.9.38 - dscudiero - Add warning message if a workflow contains the TODO step
## 08-30-2017 @ 09.37.22 - 2.9.45 - dscudiero - Hack to turn off requiredGlobalFiles
## 08-30-2017 @ 09.38.48 - 2.9.46 - dscudiero - Commented out the 'refreshSystem' option
## 08-30-2017 @ 13.55.26 - 2.9.72 - dscudiero - Add help text
## 08-30-2017 @ 14.07.46 - 2.9.73 - dscudiero - move name and version to the Help file
## 08-30-2017 @ 15.16.12 - 2.9.75 - dscudiero - Add a check to make sure the courseleaf or cim versions are the same from src to target
## 08-31-2017 @ 07.54.14 - 2.9.77 - dscudiero - If clver or cimver differ and target is next then terminaete
## 08-31-2017 @ 09.57.31 - 2.9.79 - dscudiero - add -norefresh optiona
## 08-31-2017 @ 10.06.22 - 2.9.80 - dscudiero - remove debug stuff
## 09-01-2017 @ 09.28.41 - 2.9.93 - dscudiero - g
## 09-01-2017 @ 09.33.30 - 2.9.95 - dscudiero - move helpSet to new help function
## 09-01-2017 @ 10.00.11 - 2.9.98 - dscudiero - Commented out CleanupOldFiles
## 09-01-2017 @ 10.05.31 - 2.10.0 - dscudiero - Change format of help
## 09-01-2017 @ 13.44.38 - 2.10.3 - dscudiero - run the previously named local function if found
## 09-01-2017 @ 14.12.22 - 2.10.4 - dscudiero - put
## 09-05-2017 @ 08.56.49 - 2.10.5 - dscudiero - Tweaked format of warning message
## 09-20-2017 @ 15.31.04 - 2.10.25 - dscudiero - Updated how it handles the situation where cl or cim versions are different and copying to next
## 09-21-2017 @ 09.34.06 - 2.10.26 - dscudiero - UPdated includes
## 09-27-2017 @ 14.21.34 - 2.10.27 - dscudiero - Switch to Msg
## 10-04-2017 @ 11.29.57 - 2.10.28 - dscudiero - Do not update target file stuctures if different from source, just print a message
## 10-04-2017 @ 16.12.32 - 2.10.29 - dscudiero - Tweak the names of the workflow backup files
## 10-09-2017 @ 16.53.42 - 2.10.34 - dscudiero - Fix problem setting backup directory names
## 10-10-2017 @ 13.33.45 - 2.10.35 - dscudiero - Take the restriction for the jalot data to be only numeric away
## 10-10-2017 @ 13.44.43 - 2.10.36 - dscudiero - Add default values for some questions
## 10-20-2017 @ 16.33.02 - 2.10.40 - dscudiero - Added code to check to make sure there is a workflow management record for the cim instance
## 11-02-2017 @ 15.54.32 - 2.10.41 - dscudiero - Switch to ParseArgsStd
## 11-06-2017 @ 16.44.08 - 2.10.42 - dscudiero - Add runCourseleafCgi to the includes list
## 12-11-2017 @ 13.51.57 - 2.10.56 - dscudiero - Add a check of the workflow.tcf revhistorytca data between source and target
## 12-13-2017 @ 14.21.18 - 2.10.59 - dscudiero - Write out the backup file to the target sites attic directory
## 12-13-2017 @ 14.25.14 - 2.10.60 - dscudiero - Cosmetic/minor change
## 12-27-2017 @ 10.07.04 - 2.10.61 - dscudiero - Cosmetic/minor change
## 01-24-2018 @ 10.46.36 - 2.10.65 - dscudiero - Added additional messaging
## 01-24-2018 @ 10.54.40 - 2.10.66 - dscudiero - Cosmetic/minor change/Sync
## 01-24-2018 @ 10.55.12 - 2.10.67 - dscudiero - Cosmetic/minor change/Sync
## 03-13-2018 @ 08:29:19 - 2.10.67 - dscudiero - Add a check for TODO workflow steps if target is NEXT
## 03-15-2018 @ 12:59:42 - 2.10.68 - dscudiero - Allow specifying cimstr as extra arguments
## 03-20-2018 @ 09:20:20 - 2.10.71 - dscudiero - Check that verify is on if target is NEXT
## 03-23-2018 @ 15:33:27 - 2.10.72 - dscudiero - D
## 03-23-2018 @ 16:57:38 - 2.10.73 - dscudiero - Msg3 -> Msg
## 03-29-2018 @ 12:57:45 - 2.10.75 - dscudiero - Only gather jalot stuff for next env
## 04-04-2018 @ 07:17:42 - 2.10.76 - dscudiero - Fix problem not prompting for jalot task number if target is test
## 05-16-2018 @ 15:45:31 - 2.10.77 - dscudiero - Added activityLog logging
## 05-16-2018 @ 16:01:27 - 2.10.78 - dscudiero - Add jalot to local logging
## 11-09-2018 @ 14:39:45 - 2.11.0 - dscudiero - Add special logic for fastInit when called from workwith
## 11-20-2018 @ 09:42:05 - 2.11.1 - dscudiero - Comment out the code checkign of there is a console listing for workflow management
## 01-30-2019 @ 11:19:30 - 2.11.2 - dscudiero - Change default target from a pvt site to dev
## 03-06-2019 @ 08:40:00 - 2.11.15 - dscudiero - Re-factor how initialization is done for fastInit
## 03-12-2019 @ 15:37:27 - 2.11.18 - dscudiero - Fix problem putting the workflow.cfg file when commenting out the wfDump wfrule
## 03-22-2019 @ 10:27:59 - 2.11.19 - dscudiero - Put in a check to make sure that we are not pushing a workflow.tcf file with an active debug workflow
## 03-27-2019 @ 13:46:45 - 2.11.22 - dscudiero - Remove the default answer for the last do you wish to copy questios
## 04-17-2019 @ 10:32:31 - 2.11.38 - dscudiero -  Switched to the new c++ argument parser Added code if altEnv is passed
## 04-19-2019 @ 10:57:24 - 2.11.52 - dscudiero -  Add process of fromDir and toDir allowing for adhoc source and target sites
## 05-01-2019 @ 16:31:03 - 2.11.53 - dscudiero - Add/Remove debug statements
