#!/bin/bash
#==================================================================================================
version=2.3.0 # -- dscudiero -- Tue 05/22/2018 @ 14:06:07.01
#==================================================================================================
TrapSigs 'on'
myIncludes="GetOutputFile BackupCourseleafFile ProtectedCall GetExcel SetFileExpansion"
Import "$standardInteractiveIncludes $myIncludes"

originalArgStr="$*"
scriptDescription="Merge role data"

#==================================================================================================
# Merge role data
#==================================================================================================
#==================================================================================================
## Copyright ©2014 David Scudiero -- all rights reserved.
## 06-17-15 -- 	dgs - Initial coding

#==================================================================================================

#==================================================================================================
# local functions
#==================================================================================================
	#==============================================================================================
	# parse script specific arguments
	#==============================================================================================
	function mergeRoles-ParseArgsStd {
		myArgs+=("w|workbookFile|option|workbookFile||script|The fully qualified workbook file name")
		myArgs+=("m|merge|switch|merge||script|Merge role data when duplicate role names are found")
		myArgs+=("o|overlay|switch|overlay||script|Overlay role data when duplicate role names are found")
		return 0
	}
	#==============================================================================================
	# Goodbye call back
	#==============================================================================================
	function mergeRoles-Goodbye {
		trap 'SignalHandler ERR ${LINENO} $? ${BASH_SOURCE[0]}' ERR
		local exitCode="$1"
		[[ -f $tmpWorkbookFile ]] && rm $tmpWorkbookFile
		[[ -f $stepFile ]] && rm -f $stepFile
		[[ -f $backupStepFile ]] && mv -f $backupStepFile $stepFile
		[[ -f "$tmpDataFile" ]] && rm -f "$tmpDataFile"
		return 0
	}

	#==============================================================================================
	# TestMode overrides
	#==============================================================================================
	function mergeRoles-testMode {
		trap 'SignalHandler ERR ${LINENO} $? ${BASH_SOURCE[0]}' ERR
		srcEnv='dev'
		srcDir=~/testData/dev
		tgtEnv='test'
		tgtDir=~/testData/next
		return 0
	}

	#==================================================================================================
	# Cleanup funtion, strip leadning blanks, tabs and commas
	#==================================================================================================
	function CleanMembers {
		trap 'SignalHandler ERR ${LINENO} $? ${BASH_SOURCE[0]}' ERR
		local string="$1"

		## blanks before commas
		string=$(sed 's/ ,/,/g' <<< "$string" )

		## blanks after commas
		string=$(sed 's/, /,/g' <<< "$string" )

		## Strip leading blanks. tabs. commas
		string=$(sed 's/^[ ,\t]*//g' <<< "$string" )

		## Strip trailing blanks. tabs. commas
		string=$(sed 's/[ ,\t]*$//g' <<< "$string" )

		echo "$string"
		return 0
	}

	#==================================================================================================
	# Merge two comma delimited strings, sort and remove duplicates
	#==================================================================================================
	function MergeRoleData {
		trap 'SignalHandler ERR ${LINENO} $? ${BASH_SOURCE[0]}' ERR
		local srcData="$1"
		local tgtData="$2"
		local mergeArray=($(echo $srcData,$tgtData | tr ',' '\n' | sort -u | tr '\n' ' '))
		echo $(echo ${mergeArray[@]} | tr ' ' ',')
		return 0
	}

	#==================================================================================================
	# Get the roles data from the file
	#==================================================================================================
	function GetRolesDataFromFile {
		trap 'SignalHandler ERR ${LINENO} $? ${BASH_SOURCE[0]}' ERR
		local rolesFile="$1"
		#PushSettings; set +e; shift; PopSettings
		[[ $useUINs == true && $processedUserData != true ]] && Msg $T "$FUNCNAME: Requesting UIN mapping but no userid sheet was provided"
		Msg "\nParsing the roles.tcf file ($rolesFile) ..."
		## Get the roles data from the roles.tcf file
			[[ ! -r $rolesFile ]] && Terminate "Could not read the .../courseleaf/roles.tcf file"
			while read line; do
				if [[ ${line:0:5} == 'role:' ]]; then
					key=$(echo $line | cut -d '|' -f 1 | cut -d ':' -f 2)
					data=$(Trim $(echo $line | cut -d '|' -f 2-))
					dump 2 -n line key data
						rolesFromFile["$key"]="$data"
		      	fi
			done < $rolesFile

			Msg "^Retrieved ${#rolesFromFile[@]} records"
			if [[ $verboseLevel -ge 1 ]]; then Msg "\n^rolesFromFile: $roleFile"; for i in "${!rolesFromFile[@]}"; do printf "\t\t[$i] = >${rolesFromFile[$i]}<\n"; done; fi
		return 0
	} #GetRolesDataFromFile

	#==================================================================================================
	# Read / Parse roles data from spreadsheet
	#==================================================================================================
	function GetRolesDataFromSpreadsheet {
		trap 'SignalHandler ERR ${LINENO} $? ${BASH_SOURCE[0]}' ERR
		Msg "\nParsing the roles data from the workbook file ($workbookFile)..."
		## Parse the role data from the spreadsheet
			workbookSheet='roles'
			GetExcel -wb "$workbookFile" -ws "$workbookSheet"
		## Parse the output array
			foundHeader=false; foundData=false
			for ((ii=0; ii<${#resultSet[@]}; ii++)); do
				result="${resultSet[$ii]}"
				dump 2 -n result
				[[ $result == '' || $result = '|||' ]] && continue
				SetFileExpansion 'off'
				if [[ $(Lower ${result:0:7}) == '*start*' || $(Lower ${result:0:3}) == '***' ]] && [[ $foundHeader == false ]]; then
					(( ii++ ))
					result="${resultSet[$ii]}"
					SetFileExpansion
					Msg $V1 'Parsing header record'
					IFSave=$IFS; IFS=\|; sheetCols=($result); IFS=$IFSave;
					findFields="role members email"
					for field in $findFields; do
						dump 2 -n field
						unset fieldCntr
						for sheetCol in "${sheetCols[@]}"; do
							(( fieldCntr += 1 ))
							dump 2 -t sheetCol fieldCntr
							[[ $(Contains "$(Lower $sheetCol)" "$field") == true ]] && eval "${field}Col=$fieldCntr" && break
						done
					done
					dump 2 roleCol membersCol emailCol
					membersCol=$membersCol$userCol
					[[ $roleCol == '' ]] && Terminate "Could not find a 'RoleName' column in the 'RolesData' sheet"
					[[ $membersCol == '' ]] && Terminate "Could not find a 'MemberList or UserList' column in the 'RolesData' sheet"
					[[ $emailCol == '' ]] && Terminate "Could not find a 'Email or UserList' column in the 'RolesData' sheet"
					foundHeader=true
				elif [[ $foundHeader == true ]]; then
					key=$(echo $result | cut -d '|' -f $roleCol)
					[[ $key == '' ]] && continue
					value=$(echo $result | cut -d '|' -f $membersCol)'|'$(echo $result | cut -d '|' -f $emailCol)
					dump 2 -n result -t key value
					if [[ ${rolesFromSpreadsheet["$key"]+abc} ]]; then
						if [[ ${rolesFromSpreadsheet["$key"]} != $value ]]; then
							Terminate "The '$workbookSheet' tab in the workbook contains duplicate role records \
							\n\tRole '$key' with value '$value' is duplicate\n\tprevious value = '${rolesFromSpreadsheet["$key"]}'"
						fi
					else
						rolesFromSpreadsheet["$key"]="$value"
					fi
				fi
			done

		[[ ${#rolesFromSpreadsheet[@]} -eq 0 ]] && Terminate "Did not retrieve any records from the spreadsheet, \
					\n^most likely it is missing the 'start' directive ('*start*' or '***') in column 'A' just above the header record."
		Msg "^Retrieved ${#rolesFromSpreadsheet[@]} records"
		if [[ $verboseLevel -ge 1 ]]; then Msg "\n^rolesFromSpreadsheet: $roleFile"; for i in "${!rolesFromSpreadsheet[@]}"; do printf "\t\t[$i] = >${rolesFromSpreadsheet[$i]}<\n"; done; fi

		return 0

	} #GetRolesDataFromSpreadsheet

	#==================================================================================================
	# Map UIDs to UINs in role members
	#==================================================================================================
	function EditRoleMembers {
		trap 'SignalHandler ERR ${LINENO} $? ${BASH_SOURCE[0]}' ERR
		local memberData="$*"
		[[ $useUINs != true ]] && echo "$memberData" && return

		local memberDataNew
		local member
		local members

		IFSsave=$IFS; IFS=',' read -a members <<< "$memberData"; IFS=$IFSsave
		for member in "${members[@]}"; do
			[[ ${usersFromDb["$member"]+abc} ]] && memberDataNew="$memberDataNew,$member" && continue
			[[ ${uidUinHash["$member"]+abc} ]] && memberDataNew="$memberDataNew,${uidUinHash["$member"]}" && continue
			memberDataNew="$memberDataNew,$member"
		done
		echo "${memberDataNew:1}"
		return 0
	} #EditRoleMembers

#==================================================================================================
# Declare local variables and constants
#==================================================================================================
falseVars='noUinMap useUINs'
for var in $falseVars; do eval $var=false; done
unset workbookFile

declare -A rolesFromSrcFile
declare -A rolesFromTgtFile
declare -A rolesOut
declare -A rolesFromSpreadsheet
declare -A uidUinHash
declare -A membersErrors

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
helpSet='script,client,env'
helpNotes+=("The output is written to the $HOME/clientData/<client> directory,\n\t   if the directory does exist one will be created.")
Hello
GetDefaultsData -f $myName
ParseArgsStd $originalArgStr
dump -1 client env envs srcEnv tgtEnv -q

displayGoodbyeSummaryMessages=true
Init 'getClient getSrcEnv getTgtEnv getDirs checkEnvs addPvt'
srcEnv="$(TitleCase "$srcEnv")"
tgtEnv="$(TitleCase "$tgtEnv")"

## Findout if we should merge or overlay role data
	unset mergeMode
	[[ $overlay == true ]] && mergeMode='overlay'
	[[ $merge == true ]] && mergeMode='merge'
	if [[ $mergeMode == '' && $informationOnlyMode != true ]]; then
		unset ans
		Msg "\n Do you wish to merge data when roles are found in both source and target, or do you want to overlay the target data from the source"
		Prompt ans "'Yes' = 'merge', 'No' = 'overlay'" 'Yes No' 'Yes'; ans=$(Lower ${ans:0:1})
		[[ $ans == 'y' ]] && mergeMode='merge' || mergeMode='overlay'
	else
		[[ -n $mergeMode ]] && Note "Using specified value of '$mergeMode' for 'mergeMode'"
	fi

## Find out if this client uses UINs
	if [[ $noUinMap == false ]]; then
		sqlStmt="select usesUINs from $clientInfoTable where name=\"$client\""
			RunSql $sqlStmt
			if [[ ${#resultSet[@]} -ne 0 ]]; then
				result="${resultSet[0]}"
				[[ $result == 'Y' ]] && useUINs=true && Msg
			fi
	fi

## Get workbook file
	unset workflowSearchDir
	if [[ $workbookFile == '' && $verify != false ]]; then
		if [[ $verify != false ]]; then
			unset ans
			Msg
			Prompt ans "Do you wish to merge in spreadsheet data" 'Yes No' 'No'; ans=$(Lower ${ans:0:1})
			if [[ $ans == 'y' ]]; then
				## Search for XLSx files in clientData and implimentation folders
				if [[ -d "$localClientWorkFolder/$client" ]]; then
					workbookSearchDir="$localClientWorkFolder/$client"
				else
					## Find out if user wants to load cat data or cim data
					Prompt product 'Are you merging CAT or CIM data' 'cat cim' 'cat';
					product=$(Upper $product)
					implimentationRoot="/steamboat/leepfrog/docs/Clients/$client/Implementation"
					if   [[ -d "$implimentationRoot/Attachments/$product/Workflow" ]]; then workbookSearchDir="$implimentationRoot/Attachments/$product/Workflow"
					elif [[ -d "$implimentationRoot/Attachments/$product" ]]; then workbookSearchDir="$implimentationRoot/Attachments/$product"
					elif [[ -d "$implimentationRoot/$product/Workflow" ]]; then workbookSearchDir="$implimentationRoot/$product/Workflow"
					elif [[ -d "$implimentationRoot/$product" ]]; then workbookSearchDir="$implimentationRoot/$product"
					fi
				fi			
				if [[ $workbookSearchDir != '' ]]; then
					SelectFile $workbookSearchDir 'workbookFile' '*.xls*' "\nPlease specify the $(ColorK '(ordinal)') number of the Excel workbook you wish to load data from:\
						\n(*/.xls* files found in '$(ColorK $workbookSearchDir)')\n(sorted ordered newest to oldest)\n\n"
					workbookFile="$workbookSearchDir/$workbookFile"
				fi	
			fi
		fi
	fi
	[[ $workbookFile != '' && ! -f $workbookFile ]] && Terminate "Could not locate the workbookFile:\n\t$workbookFile"

	workbookFileStr='N/A'
	if [[ $workbookFile != '' ]]; then
		## If the workbook file name contains blanks then copy to temp and use that one.
			realWorkbookFile="$workbookFile"
			unset tmpWorkbookFile
			if [[ $(Contains "$workbookFile" ' ') == true ]]; then
				cp -fp "$workbookFile" /tmp/$userName.$myName.workbookFile
				tmpWorkbookFile="/tmp/$userName.$myName.workbookFile"
				workbookFileStr="$workbookFile as $tmpWorkbookFile"
				workbookFile="$tmpWorkbookFile"
			else
				workbookFileStr="$workbookFile"
			fi
			[[ ! -r $workbookFile ]] && Terminate "Could not locate file: '$workbookFile'"
	fi

## set default values
	[[ $useUINs == '' ]] && useUINs='N/A'

## output file
	unset outFile
	## Set outfile -- look for std locations
	outFile="/home/$userName/$client-$srcEnv-$tgtEnv-CIM_Roles.txt"
	if [[ -d $localClientWorkFolder ]]; then
		if [[ ! -d $localClientWorkFolder/$client ]]; then mkdir -p "$localClientWorkFolder/$client"; fi
		outFile="$localClientWorkFolder/$client/$client-$srcEnv-$tgtEnv-CIM_Roles.txt"
	fi
	echo -e "Role name\t'$srcEnv' site member list\t'$srcEnv' site email\t'$tgtEnv' site member list\t'$tgtEnv' site email" > "$outFile"

## Verify processing
	verifyArgs+=("Client:$client")
	verifyArgs+=("Source Env:$(TitleCase $srcEnv) ($srcDir)")
	verifyArgs+=("Target Env:$(TitleCase $tgtEnv) ($tgtDir)")
	[[ $workbookFile != '' ]] && verifyArgs+=("Input file:$workbookFileStr")
	verifyArgs+=("Map UIDs to UINs:$useUINs")
	verifyArgs+=("Role combination rule:$mergeMode")
	[[ -n $outFile ]] && verifyArgs+=("Output File:$outFile")
	VerifyContinue "You are asking to update CourseLeaf data"

	dump -1 client srcEnv srcDir tgtEnv tgtDir useUINs outFile
	myData="Client: '$client', SrcEnv: '$srcEnv', TgtEnv: '$tgtEnv', File: '$workbookFile' "
	[[ $logInDb != false && $myLogRecordIdx != "" ]] && dbLog 'data' $myLogRecordIdx "$myData"

#==================================================================================================
# Main
#==================================================================================================
## Process spreadsheet
	if [[ $workbookFile != '' ]]; then
		## Get the list of sheets in the workbook
			GetExcel -wb "$workbookFile" -ws 'GetSheets'
			sheets="${resultSet[0]}"
			dump -1 sheets
		## Make sure we have a 'role' sheet
			[[ $(Contains "$(Lower $sheets)" 'role') != true ]] && Terminate"Could not locate a sheet with 'role' in its name in workbook:\n^$workbookFile"
			GetRolesDataFromSpreadsheet
			if [[ $verboseLevel -ge 1 ]]; then Msg "\n^rolesfromSpreadsheet:"; for i in "${!rolesFromSpreadsheet[@]}"; do printf "\t\t[$i] = >${rolesFromSpreadsheet[$i]}<\n"; done; fi
	fi

## Process role.tcf files
	declare -A rolesFromFile
	rolesFile=$srcDir/web/courseleaf/roles.tcf
	GetRolesDataFromFile $rolesFile
	for key in "${!rolesFromFile[@]}"; do rolesFromSrcFile["$key"]="${rolesFromFile["$key"]}"; done
	unset rolesFromFile

	declare -A rolesFromFile
	rolesFile=$tgtDir/web/courseleaf/roles.tcf
	GetRolesDataFromFile $rolesFile
	for key in "${!rolesFromFile[@]}"; do rolesFromTgtFile["$key"]="${rolesFromFile["$key"]}"; done
	unset rolesFromFile

## Merge role file data
	Msg "\nMerging the '$srcEnv' roles into the '$tgtEnv' roles ..."
	unset numDifferentFromSrc addedFromSrc
	## Prime roles out hash with the tgt file data.
	for key in "${!rolesFromTgtFile[@]}"; do rolesOut["$key"]="${rolesFromTgtFile["$key"]}"; done
	## Loop through target hash and report on any roles not found in the source
	for key in "${!rolesFromTgtFile[@]}"; do
		if [[ !${rolesFromSrcFile["$key"]+abc} ]]; then
			Info 0 1 "Role '$key' found in $tgtEnv but not in $srcEnv"
			echo -e "${key}\t\t\t$(echo ${rolesFromTgtFile["$key"]} | cut -d'|' -f1)\t$(echo ${rolesFromTgtFile["$key"]} | cut -d'|' -f2)" >> "$outFile"
		fi
	done

	## Loop through source hash and see if it is in the target hash, if yes then compare
	for key in "${!rolesFromSrcFile[@]}"; do
		if [[ ${rolesOut["$key"]+abc} ]]; then
			if [[ ${rolesFromSrcFile["$key"]} != ${rolesOut["$key"]} ]]; then
				Warning  0 1 "Role '$key' data in '$srcEnv' differs from '$tgtEnv'"
				Msg "^^$srcEnv data: ${rolesFromSrcFile["$key"]}"
				Msg "^^$tgtEnv data: ${rolesOut["$key"]}"
				if [[ $mergeMode == 'merge' ]]; then
					unset members1 members2 email1 email2 mergedMembers mergedEmail fromEnv
					rolesOut["//$key"]="${rolesFromSrcFile["$key"]}   <-- Pre-merge $srcEnv value"
					rolesOut["//$key"]="${rolesOut["$key"]}   <-- Pre-merge $tgtEnv value"
					members1=$(echo ${rolesFromSrcFile["$key"]} | cut -d'|' -f1)
					email1=$(echo ${rolesFromSrcFile["$key"]} | cut -d'|' -f2)
					members2=$(echo ${rolesOut["$key"]} | cut -d'|' -f1)
					email2=$(echo ${rolesOut["$key"]} | cut -s -d'|' -f2)
					mergedMembers=$(MergeRoleData "$members1" "$members2")
					if [[ $email1 != $email2 ]]; then
						[[ $email1 != '' ]] && mergedEmail="$email1" && fromEnv="$srcEnv"
						[[ $email2 != '' ]] && mergedEmail="$email2" && fromEnv="$tgtEnv"
						Msg "^^Email data on the roles do not match, using: '$mergedEmail' from '$fromEnv'"
						#warningMsgs+=("\tEmail data on the roles do not match, using: '$mergedEmail' from '$fromEnv'")
					else
						mergedEmail="$email2"
					fi
					dump -1 -t -t members1 members2 mergedMembers email1 email2 mergedEmail
					rolesOut["$key"]="$mergedMembers|$mergedEmail"
					Msg "^^New $tgtEnv (merged) data: ${rolesOut["$key"]}"
					#warningMsgs+=("\tNew $tgtEnv (merged) data: ${rolesOut["$key"]}")
				else
					rolesOut["//$key"]="${rolesFromSrcFile["$key"]}   <-- Pre-merge $srcEnv value"
					Msg "^^Keeping existing ($tgtEnv) data."
				fi
				echo -e "${key}\t$(echo ${rolesFromSrcFile["$key"]} | cut -d'|' -f1)\t$(echo ${rolesFromSrcFile["$key"]} | cut -d'|' -f2)$(echo ${rolesFromTgtFile["$key"]} | cut -d'|' -f1)\t$(echo ${rolesFromTgtFile["$key"]} | cut -d'|' -f2)" >> "$outFile"
				(( numDifferentFromSrc += 1 ))					
			fi
		else
			Note 0 1 "Role '$key' found in $srcEnv but not in $tgtEnv, adding to $tgtEnv"
			rolesOut["$key"]="${rolesFromSrcFile["$key"]}"
			echo -e "${key}\t$(echo ${rolesFromSrcFile["$key"]} | cut -d'|' -f1)\t$(echo ${rolesFromSrcFile["$key"]} | cut -d'|' -f2)\t\t" >> "$outFile"
			(( addedFromSrc += 1 ))
		fi
	done;

	numRolesOut=${#rolesOut[@]}
	Msg "^Merged roles out record count: ${numRolesOut}"
	[[ $addedFromSrc -gt 0 ]] && Msg "^$addedFromSrc records added from '$srcEnv'"
	[[ $numDifferentFromSrc -gt 0 ]] && Msg "^$numDifferentFromSrc records differed between '$srcEnv' and '$tgtEnv'"

	if [[ $verboseLevel -ge 1 ]]; then Msg "\n^rolesOut: "; for i in "${!rolesOut[@]}"; do printf "\t\t[$i] = >${rolesOut[$i]}<\n"; done; fi

## Merge role spreadsheet data
	if [[ $workbookFile != '' ]]; then
		unset numDifferentFromSpreadsheet addedFromSpreadsheet
		Msg "\nMerging the spreadsheet role data into the '$tgtEnv' roles ..."
		for key in "${!rolesFromSpreadsheet[@]}"; do
			if [[ ${rolesOut["$key"]+abc} ]]; then
				if [[ ${rolesFromSpreadsheet["$key"]} != ${rolesOut["$key"]} ]]; then
					Warning 0 1 "Role '$key' data in spreadsheet differs from '$tgtEnv'"
					Msg "^^Spreadsheet data: ${rolesFromSpreadsheet["$key"]}"
					Msg "^^$tgtEnv data: ${rolesOut["$key"]}"
					if [[ $mergeMode == 'merge' ]]; then
						unset members1 members2 email1 email2 mergedMembers mergedEmail
						rolesOut["//$key"]="${rolesFromSpreadsheet["$key"]}   <-- Pre-merge spreadsheet value"
						rolesOut["//$key"]="${rolesOut["$key"]}   <-- Pre-merge $tgtEnv value"
						members1=$(echo ${rolesFromSpreadsheet["$key"]} | cut -d'|' -f1)
						email1=$(echo ${rolesFromSpreadsheet["$key"]} | cut -d'|' -f2)
						members2=$(echo ${rolesOut["$key"]} | cut -d'|' -f1)
						email2=$(echo ${rolesOut["$key"]} | cut -s -d'|' -f2)
						mergedMembers=$(MergeRoleData "$members1" "$members2")
						if [[ $email1 != $email2 ]]; then
						[[ $email2 != '' ]] && mergedEmail="$email2" && fromEnv="$tgtEnv"
						[[ $email1 != '' ]] && mergedEmail="$email1" && fromEnv="spreadsheet"
						Msg "^^Email data on the roles do not match, using: '$mergedEmail' from '$fromEnv'"
						#warningMsgs+=("\tEmail data on the roles do not match, using: '$mergedEmail' from '$fromEnv'")
						else
							mergedEmail="$email2"
						fi
						dump -1 -t -t members1 members2 mergedMembers email1 email2 mergedEmail
						rolesOut["$key"]="$mergedMembers|$mergedEmail"
						Msg "^^New $tgtEnv (merged) data: ${rolesOut["$key"]}"
						#warningMsgs+=("^New $tgtEnv (merged) data: ${rolesOut["$key"]}")
					else
						rolesOut["//$key"]="${rolesFromSpreadsheet["$key"]}   <-- Pre-merge spreadsheet value"
						Msg "^^Keeping existing ($tgtEnv) data."
					fi
					(( numDifferentFromSrc += 1 ))
				fi
			else
				rolesOut["$key"]="${rolesFromSpreadsheet["$key"]}"
				(( addedFromSrc += 1 ))
			fi
		done

		Msg "^Merged roles out record count: ${#rolesOut[@]}"
		[[ $addedFromSpreadsheet -gt 0 ]] && Msg "^$addedFromSpreadsheet records added from the Spreadsheet"
		[[ $numDifferentFromSpreadsheet -gt 0 ]] && Msg "^$numDifferentFromSpreadsheet records differed between Spreadsheet and '$tgtEnv'"
	fi

## Write out file
##TODO: Replace writing of the roles data with a courseleaf step somehow
	if [[ $informationOnlyMode != true ]]; then
		writeFile=true
		if [[ ${#warningMsgs[@]} -gt 0 ]]; then
			Msg; unset ans
			Prompt ans "Warning messages were issued, do you wish to write the role data out to '$tgtEnv'" "Yes No"; ans=$(Lower ${ans:0:1})
			[[ $ans != 'y' ]] && writeFile=false
		fi
		if [[ $writeFile == true ]]; then
			rolesFile=$tgtDir/web/courseleaf/roles.tcf
			Msg "\nWriting out new roles.tcf file to '$tgtEnv' ($rolesFile)..."
			editFile=$rolesFile
			BackupCourseleafFile $editFile
			# Parse the target file to put source data in the correct location in target file.
			topPart=/tmp/$userName.$myName.topPart; [[ -f $topPart ]] && rm -f $topPart
			bottomPart=/tmp/$userName.$myName.bottomPart; [[ -f $bottomPart ]] && rm -f $bottomPart
			found=false
			while read -r line; do
				#echo "line='${line}'" >> $stdout
				[[ ${line:0:5} == 'role:' ]] && found=true
				[[ ${line:0:5} != 'role:' ]] && [[ $found == false ]] && echo "${line}" >> $topPart
				[[ ${line:0:5} != 'role:' ]] && [[ $found == true ]] && echo "${line}" >> $bottomPart
			done < $editFile
			## Paste the target file together
				[[ -f $topPart ]] && $DOIT cp -f $topPart $editFile.new
				echo >> $editFile.new
				for key in "${!rolesOut[@]}"; do
					[[ ${key:0:2} == '//' ]] && echo "//role:${key:2}|${rolesOut["$key"]}" >> $editFile.new || echo "role:${key}|${rolesOut["$key"]}" >> $editFile.new
				done
				echo >> $editFile.new
				[[ -f $bottomPart ]] && $DOIT cat $bottomPart >> $editFile.new
			## Swap the files
				mv $editFile.new $editFile
				[[ -f $topPart ]] && rm -f $topPart; [[ -f $bottomPart ]] && rm -f $bottomPart
			Msg "^$editFile written to disk"
			summaryMsgs+=("$editFile written to disk")
			## Write out change log entries
				$DOIT Msg "\n$userName\t$(date) via '$myName' version: $version" >> $tgtDir/changelog.txt
				$DOIT Msg "^Merged data from '$srcEnv'" >> $tgtDir/changelog.txt
				[[ $workbookFile != '' ]] && $DOIT Msg "^Merged data from $realWorkbookFile" >> $tgtDir/changelog.txt
		fi # writeFile
	fi #not informationOnlyMode

## Processing summary
	summaryMsgs+=("Retrieved ${#rolesFromSrcFile[@]} records from the '$srcEnv' roles.tcf file")
	summaryMsgs+=("Retrieved ${#rolesFromTgtFile[@]} records from the '$tgtEnv' roles.tcf file")
	[[ $addedFromSrc -gt 0 ]] && summaryMsgs+=("\t$addedFromSrc records added from '$srcEnv'")
	[[ $numDifferentFromSrc -gt 0 ]] && summaryMsgs+=("\t$numDifferentFromSrc records differed between '$srcEnv' and '$tgtEnv'")
	if [[ $workbookFile != '' ]]; then
		summaryMsgs+=("Retrieved ${#rolesFromSpreadsheet[@]} records from '$workbookFile'")
		[[ $addedFromSpreadsheet -gt 0 ]] && summaryMsgs+=("\t$addedFromSpreadsheet records added from Spreadsheet")
		[[ $numDifferentFromSpreadsheet -gt 0 ]] && summaryMsgs+=("\t$numDifferentFromSpreadsheet records differed between Spreadsheet and '$tgtEnv'")
	fi
	summaryMsgs+=("")
	summaryMsgs+=("${#rolesOut[@]} Merged Records")

	summaryMsgs+=("")
	summaryMsgs+=("Data comparison workbook file: $outFile")
	[[ $informationOnlyMode == false ]] && { summaryMsgs+=(""); summaryMsgs+=("$tgtEnv roles.tcf file written ($tgtDir/web/courseleaf/roles.tcf)"); }

#==================================================================================================
## Done
#==================================================================================================
## Exit nicely
	Goodbye 0 #'alert'

#==================================================================================================
## Check-in log
#==================================================================================================

# 11-24-2015 -- dscudiero -- Merge CourseLeaf roles (1.1)
# 12-30-2015 -- dscudiero -- refactor workbook file selection (2.2.1)
## Fri Apr  1 13:30:46 CDT 2016 - dscudiero - Swithch --useLocal to $useLocal
## Wed Apr  6 16:09:35 CDT 2016 - dscudiero - switch for
## Wed Apr 27 16:05:00 CDT 2016 - dscudiero - Switch to use RunSql
## Thu Aug  4 11:02:15 CDT 2016 - dscudiero - Added displayGoodbyeSummaryMessages=true
## Tue Sep 20 12:34:42 CDT 2016 - dscudiero - Switched to use Msg2
## 05-26-2017 @ 12.49.39 - (2.2.21)    - dscudiero - Found an instance of Msg vs Msg2
## 06-07-2017 @ 07.44.14 - (2.2.22)    - dscudiero - Added BackupCourseleafFIle to the import list
## 09-25-2017 @ 12.26.53 - (2.2.24)    - dscudiero - Switch to use Msg
## 10-16-2017 @ 09.06.27 - (2.2.45)    - dscudiero - Updated to use GetExcel
## 11-02-2017 @ 06.58.56 - (2.2.47)    - dscudiero - Switch to ParseArgsStd
## 11-02-2017 @ 11.02.12 - (2.2.48)    - dscudiero - Add addPvt to the init call
## 03-22-2018 @ 14:06:58 - 2.2.49 - dscudiero - Updated for Msg3/Msg, RunSql2/RunSql, ParseArgStd/ParseArgStd2
## 03-23-2018 @ 11:56:24 - 2.2.50 - dscudiero - Updated for GetExcel2/GetExcel
## 03-23-2018 @ 15:35:13 - 2.2.51 - dscudiero - D
## 03-23-2018 @ 16:52:33 - 2.2.52 - dscudiero - Msg3 -> Msg
## 04-11-2018 @ 14:57:01 - 2.2.53 - dscudiero - Added wfHello, tweaked wfDebug & wfDump
## 05-22-2018 @ 14:08:14 - 2.3.0 - dscudiero - Create a comparison file as outout
