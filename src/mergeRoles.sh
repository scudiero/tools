#!/bin/bash
#==================================================================================================
version=2.2.22 # -- dscudiero -- Tue 06/06/2017 @ 13:54:05.34
#==================================================================================================
TrapSigs 'on'
imports='GetDefaultsData ParseArgs ParseArgsStd Hello Init Goodbye'
imports="$imports GetOutputFile BackupCourseleafFile"
Import "$imports"
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
	function parseArgs-mergeRoles  {
		trap 'SignalHandler ERR ${LINENO} $? ${BASH_SOURCE[0]}' ERR
		argList+=(-informationOnly,2,switch,informationOnlyMode,,script,'Only analyze data and print error messages, do not change any client data.')
		argList+=(-workbookFile,1,option,workbookFile,,script,'The fully qualified spreadsheet file name')
		argList+=(-merge,1,switch,merge,,script,'Merge role data when duplicate role names are found')
		argList+=(-overlay,1,switch,overlay,,script,'Overlay role data when duplicate role names are found')
		return 0
	}
	#==============================================================================================
	# Goodbye call back
	#==============================================================================================
	function Goodbye-mergeRoles  {
		trap 'SignalHandler ERR ${LINENO} $? ${BASH_SOURCE[0]}' ERR
		local exitCode="$1"
		[[ -f $tmpWorkbookFile ]] && rm $tmpWorkbookFile
		[[ -f $stepFile ]] && rm -f $stepFile
		[[ -f $backupStepFile ]] && mv -f $backupStepFile $stepFile
		[[ -f "$tmpDataFile" ]] && rm -f "$tmpDataFile"
		[[ -f $logFile && $outFile != '' ]] && cp -fp "$logFile" "$outFile"
		return 0
	}

	#==============================================================================================
	# TestMode overrides
	#==============================================================================================
	function testMode-mergeRoles  {
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
		string=$(echo "$string" | sed 's/ ,/,/g')

		## blanks after commas
		string=$(echo "$string" | sed 's/, /,/g')

		## Strip leading blanks. tabs. commas
		string=$(echo "$string" | sed 's/^[ ,\t]*//g')

		## Strip trailing blanks. tabs. commas
		string=$(echo "$string" | sed 's/[ ,\t]*$//g')

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
		[[ $useUINs == true && $processedUserData != true ]] && Msg2 $T "$FUNCNAME: Requesting UIN mapping but no userid sheet was provided"
		Msg2 "\nParsing the roles.tcf file ($rolesFile) ..."
		## Get the roles data from the roles.tcf file
			[[ ! -r $rolesFile ]] && Msg2 $T "Could not read the .../courseleaf/roles.tcf file"
			while read line; do
				if [[ ${line:0:5} == 'role:' ]]; then
					key=$(echo $line | cut -d '|' -f 1 | cut -d ':' -f 2)
					data=$(Trim $(echo $line | cut -d '|' -f 2-))
					dump -2 -n line key data
						rolesFromFile["$key"]="$data"
		      	fi
			done < $rolesFile

			Msg2 "^Retrieved ${#rolesFromFile[@]} records"
			if [[ $verboseLevel -ge 1 ]]; then Msg2 "\n^rolesFromFile: $roleFile"; for i in "${!rolesFromFile[@]}"; do printf "\t\t[$i] = >${rolesFromFile[$i]}<\n"; done; fi
		return 0
	} #GetRolesDataFromFile

	#==================================================================================================
	# Read / Parse roles data from spreadsheet
	#==================================================================================================
	function GetRolesDataFromSpreadsheet {
		trap 'SignalHandler ERR ${LINENO} $? ${BASH_SOURCE[0]}' ERR
		Msg2 "\nParsing the roles data from the workbook file ($workbookFile)..."
		## Parse the role data from the spreadsheet
			workbookSheet='roles'
			getXlsx $USELOCAL --noLog --noLogInDb $workbookFile $workbookSheet \| > $tmpFile
			grepStr=$(ProtectedCall "grep '*Fatal Error*' $tmpFile")
			if [[ $grepStr != '' ]]; then
				Msg2 $E "Could not retrieve data from workbook, please see below"
				tail -n 6 $tmpFile 2>&1 | xargs -I{} printf "\\t%s\\n" "{}"
				Msg2
				Goodbye -1
			fi

		## Read the getXlsx output file
			#unset rolesFromSpreadsheet
			foundHeader=false; foundData=false
			while read line; do
				dump -2 line
				[[ $line == '' ]] && continue
				if [[ $(Lower ${line:0:7}) == '*start*' && $foundHeader == false ]]; then
					read line
					Msg2 $V1 'Parsing header record'
					IFSave=$IFS; IFS=\|; sheetCols=($line); IFS=$IFSave;
					findFields="role members email"
					for field in $findFields; do
						dump -2 -n field
						unset fieldCntr
						for sheetCol in "${sheetCols[@]}"; do
							(( fieldCntr += 1 ))
							dump -2 -t sheetCol fieldCntr
							[[ $(Contains "$(Lower $sheetCol)" "$field") == true ]] && eval "${field}Col=$fieldCntr" && break
						done
					done
					dump -2 roleCol membersCol emailCol
					membersCol=$membersCol$userCol
					[[ $roleCol == '' ]] && Msg2 $T "Could not find a 'RoleName' column in the 'RolesData' sheet"
					[[ $membersCol == '' ]] && Msg2 $T "Could not find a 'MemberList or UserList' column in the 'RolesData' sheet"
					[[ $emailCol == '' ]] && Msg2 $T "Could not find a 'Email or UserList' column in the 'RolesData' sheet"
					foundHeader=true
				elif [[ $foundHeader == true ]]; then
					Msg2 $V1 'Parsing data record'
					key=$(echo $line | cut -d '|' -f $roleCol)
					[[ $key == '' ]] && continue
					value=$(echo $line | cut -d '|' -f $membersCol)'|'$(echo $line | cut -d '|' -f $emailCol)
					dump -2 -n line -t key value
					if [[ ${rolesFromSpreadsheet["$key"]+abc} ]]; then
						if [[ ${rolesFromSpreadsheet["$key"]} != $value ]]; then
							Msg2 $T "The '$workbookSheet' tab in the workbook contains duplicate role records \
							\n\tRole '$key' with value '$value' is duplicate\n\tprevious value = '${rolesFromSpreadsheet["$key"]}'"
						fi
					else
						rolesFromSpreadsheet["$key"]="$value"
					fi
				fi
		done < $tmpFile

		[[ ${#rolesFromSpreadsheet[@]} -eq 0 ]] && Msg2 $T "Did not retrieve any records from the spreadsheet, \
													\n^most likely it is missing the '*start*' directive in \
													\n^column 'A' just above the header record."
		Msg2 "^Retrieved ${#rolesFromSpreadsheet[@]} records"
		if [[ $verboseLevel -ge 1 ]]; then Msg2 "\n^rolesFromSpreadsheet: $roleFile"; for i in "${!rolesFromSpreadsheet[@]}"; do printf "\t\t[$i] = >${rolesFromSpreadsheet[$i]}<\n"; done; fi

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
GetDefaultsData $myName
ParseArgsStd
displayGoodbyeSummaryMessages=true
Hello
Init 'getClient getSrcEnv getTgtEnv getDirs checkEnvs'
srcEnv="$(TitleCase "$srcEnv")"
tgtEnv="$(TitleCase "$tgtEnv")"

## Information only mode
 	[[ $informationOnlyMode == true ]] && Msg2 $W "'informationOnlyMode' flag is set, no data will be modified."

## Set output file
	outFile="$(GetOutputFile "$client" "$env" "$product")"

## Findout if we should merge or overlay role data
	unset mergeMode
	[[ $overlay == true ]] && mergeMode='overlay'
	[[ $merge == true ]] && mergeMode='merge'
	if [[ $mergeMode == '' ]]; then
		unset ans
		Msg2 "\n Do you wish to merge data when roles are found in both source and target, or do you want to overlay the target data from the source"
		Prompt ans "'Yes' = 'merge', 'No' = 'overlay'" 'Yes No' 'Yes'; ans=$(Lower ${ans:0:1})
		[[ $ans == 'y' ]] && mergeMode='merge' || mergeMode='overlay'
	else
		Msg2 $N "Using specified value of '$mergeMode' for 'mergeMode'"
	fi

## Find out if this client uses UINs
	if [[ $noUinMap == false ]]; then
		sqlStmt="select usesUINs from $clientInfoTable where name=\"$client\""
			RunSql2 $sqlStmt
			if [[ ${#resultSet[@]} -ne 0 ]]; then
				result="${resultSet[0]}"
				[[ $result == 'Y' ]] && useUINs=true && Msg2
			fi
	fi

## Get workbook file
	unset workflowSearchDir
	if [[ $workbookFile == '' && $verify != false ]]; then
		if [[ $verify != false ]]; then
			unset ans
			Msg2
			Prompt ans "Do you wish to merge in spreadsheet data" 'Yes No' 'No'; ans=$(Lower ${ans:0:1})
			if [[ $ans == 'y' ]]; then
				## Search for XLSx files in clientData and implimentation folders
				if [[ -d "$localClientWorkFolder/$client" ]]; then
					workflowSearchDir="$localClientWorkFolder/$client"
				else
					## Find out if user wants to load cat data or cim data
					Prompt product 'Are you merging CAT or CIM data' 'cat cim' 'cat';
					product=$(Upper $product)
					implimentationRoot="/steamboat/leepfrog/docs/Clients/$client/Implementation"
					if   [[ -d "$implimentationRoot/Attachments/$product/Workflow" ]]; then workflowSearchDir="$implimentationRoot/Attachments/$product/Workflow"
					elif [[ -d "$implimentationRoot/Attachments/$product" ]]; then workflowSearchDir="$implimentationRoot/Attachments/$product"
					elif [[ -d "$implimentationRoot/$product/Workflow" ]]; then workflowSearchDir="$implimentationRoot/$product/Workflow"
					elif [[ -d "$implimentationRoot/$product" ]]; then workflowSearchDir="$implimentationRoot/$product"
					fi
				fi
				if [[ $workflowSearchDir != '' ]]; then
					PushSettings; set +f
					tmpDataFile="/tmp/$userName.$myName.$$.data"
					cd "$workflowSearchDir"
					ProtectedCall "ls -t *.xlsx 2> /dev/null | grep -v '~' > "$tmpDataFile""
					PopSettings
					numLines=$(ProtectedCall "wc -l "$tmpDataFile"")
					numLines=$(echo $(ProtectedCall "wc -l "$tmpDataFile"") | cut -d' ' -f1)
					if [[ $numLines -gt 0 ]]; then
						while IFS=$'\n' read -r line; do menuList+=("$line"); done < "$tmpDataFile"; rm -f "$tmpDataFile";
						printf "\nPlease specify the $(ColorK '(ordinal)') number of the file you wish to load data from:\n(Data/.xlsx files found in '$(ColorK $workflowSearchDir)')\n\n"
						SelectMenu 'menuList' 'selectResp' "\nFile name $(ColorK '(ordinal)') number (or 'x' to quit) > "
						[[ $selectResp == '' ]] && Goodbye 0
						workbookFile="$(pwd)/$selectResp"
					else
						Msg2 $I "No .xlsx files found"
					fi
				[[ $workbookFile == "" ]] && Msg2
				Prompt workbookFile 'Please specify the full path to the workbook file' '*file*'
				fi
			fi
		fi
	fi
	[[ $workbookFile != '' && ! -f $workbookFile ]] && Msg2 $T "Could not locate the workbookFile:\n\t$workbookFile"

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
			[[ ! -r $workbookFile ]] && Msg2 $T "Could not locate file: '$workbookFile'"
	fi

## set default values
	[[ $useUINs == '' ]] && useUINs='N/A'

## Verify processing
	verifyArgs+=("Client:$client")
	verifyArgs+=("Source Env:$(TitleCase $srcEnv) ($srcDir)")
	verifyArgs+=("Target Env:$(TitleCase $tgtEnv) ($tgtDir)")
	[[ $workbookFile != '' ]] && verifyArgs+=("Input file:$workbookFileStr")
	verifyArgs+=("Map UIDs to UINs:$useUINs")
	verifyArgs+=("Role combination rule:$mergeMode")
	verifyArgs+=("Output File:$outFile")
	VerifyContinue "You are asking to update CourseLeaf data"

	dump -1 client srcEnv srcDir tgtEnv tgtDir useUINs
	myData="Client: '$client', SrcEnv: '$srcEnv', TgtEnv: '$tgtEnv', File: '$workbookFile' "
	[[ $logInDb != false && $myLogRecordIdx != "" ]] && dbLog 'data' $myLogRecordIdx "$myData"


#==================================================================================================
# Main
#==================================================================================================

## Process spreadsheet
	if [[ $workbookFile != '' ]]; then
		## Get the list of sheets in the workbook
			getXlsx $USELOCAL --noLog --noLogInDb "$workbookFile" 'GetSheets' \| -v > $tmpFile
			grepStr=$(ProtectedCall "grep '*Fatal Error*' $tmpFile")
			if [[ $grepStr != '' ]]; then
				Msg2 $E "Could not retrieve data from workbook, please see below"
				tail -n 6 $tmpFile 2>&1 | xargs -I{} printf "\\t%s\\n" "{}"
				Msg2
				Goodbye -1
			fi
			sheets=$(tail -n 1 $tmpFile)
			dump -1 sheets
		## Make sure we have a 'role' sheet
			[[ $(Contains "$(Lower $sheets)" 'role') != true ]] && Msg2 $T "Could not locate a sheet with 'role' in its name in workbook:\n^$workbookFile"
			GetRolesDataFromSpreadsheet
			if [[ $verboseLevel -ge 1 ]]; then Msg2 "\n^rolesfromSpreadsheet:"; for i in "${!rolesFromSpreadsheet[@]}"; do printf "\t\t[$i] = >${rolesFromSpreadsheet[$i]}<\n"; done; fi
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
	Msg2 "\nMerging the '$srcEnv' roles into the '$tgtEnv' roles ..."
	unset numDifferentFromSrc addedFromSrc
	## Prime roles out array with the tgt file data.
	for key in "${!rolesFromTgtFile[@]}"; do rolesOut["$key"]="${rolesFromTgtFile["$key"]}"; done
	for key in "${!rolesFromSrcFile[@]}"; do
		if [[ ${rolesOut["$key"]+abc} ]]; then
			if [[ ${rolesFromSrcFile["$key"]} != ${rolesOut["$key"]} ]]; then
				Msg2 $WT1 "Role '$key' data in '$srcEnv' differs from '$tgtEnv'"
				Msg2 "^^$srcEnv data: ${rolesFromSrcFile["$key"]}"
				Msg2 "^^$tgtEnv data: ${rolesOut["$key"]}"
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
						Msg2 "^^Email data on the roles do not match, using: '$mergedEmail' from '$fromEnv'"
						#warningMsgs+=("\tEmail data on the roles do not match, using: '$mergedEmail' from '$fromEnv'")
					else
						mergedEmail="$email2"
					fi
					dump -1 -t -t members1 members2 mergedMembers email1 email2 mergedEmail
					rolesOut["$key"]="$mergedMembers|$mergedEmail"
					Msg2 "^^New $tgtEnv (merged) data: ${rolesOut["$key"]}"
					#warningMsgs+=("\tNew $tgtEnv (merged) data: ${rolesOut["$key"]}")
				else
					rolesOut["//$key"]="${rolesFromSrcFile["$key"]}   <-- Pre-merge $srcEnv value"
					Msg2 "^^Keeping existing ($tgtEnv) data."
				fi
				(( numDifferentFromSrc += 1 ))
			fi
		else
			Msg2 $V1  "^Role added from src: $key"
			rolesOut["$key"]="${rolesFromSrcFile["$key"]}"
			(( addedFromSrc += 1 ))
		fi
	done;

	numRolesOut=${#rolesOut[@]}
	Msg2 "^Merged roles out record count: ${numRolesOut}"
	[[ $addedFromSrc -gt 0 ]] && Msg2 "^$addedFromSrc records added from '$srcEnv'"
	[[ $numDifferentFromSrc -gt 0 ]] && Msg2 "^$numDifferentFromSrc records differed between '$srcEnv' and '$tgtEnv'"

	if [[ $verboseLevel -ge 1 ]]; then Msg2 "\n^rolesOut: "; for i in "${!rolesOut[@]}"; do printf "\t\t[$i] = >${rolesOut[$i]}<\n"; done; fi

## Merge role spreadsheet data
	if [[ $workbookFile != '' ]]; then
		unset numDifferentFromSpreadsheet addedFromSpreadsheet
		Msg2 "\nMerging the spreadsheet role data into the '$tgtEnv' roles ..."
		for key in "${!rolesFromSpreadsheet[@]}"; do
			if [[ ${rolesOut["$key"]+abc} ]]; then
				if [[ ${rolesFromSpreadsheet["$key"]} != ${rolesOut["$key"]} ]]; then
					Msg2 $WT1 "Role '$key' data in spreadsheet differs from '$tgtEnv'"
					Msg2 "^^Spreadsheet data: ${rolesFromSpreadsheet["$key"]}"
					Msg2 "^^$tgtEnv data: ${rolesOut["$key"]}"
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
						Msg2 "^^Email data on the roles do not match, using: '$mergedEmail' from '$fromEnv'"
						#warningMsgs+=("\tEmail data on the roles do not match, using: '$mergedEmail' from '$fromEnv'")
						else
							mergedEmail="$email2"
						fi
						dump -1 -t -t members1 members2 mergedMembers email1 email2 mergedEmail
						rolesOut["$key"]="$mergedMembers|$mergedEmail"
						Msg2 "^^New $tgtEnv (merged) data: ${rolesOut["$key"]}"
						#warningMsgs+=("^New $tgtEnv (merged) data: ${rolesOut["$key"]}")
					else
						rolesOut["//$key"]="${rolesFromSpreadsheet["$key"]}   <-- Pre-merge spreadsheet value"
						Msg2 "^^Keeping existing ($tgtEnv) data."
					fi
					(( numDifferentFromSrc += 1 ))
				fi
			else
				Msg2 $V1 "^Role added from src: $key"
				rolesOut["$key"]="${rolesFromSpreadsheet["$key"]}"
				(( addedFromSrc += 1 ))
			fi
		done

		Msg2 "^Merged roles out record count: ${#rolesOut[@]}"
		[[ $addedFromSpreadsheet -gt 0 ]] && Msg2 "^$addedFromSpreadsheet records added from the Spreadsheet"
		[[ $numDifferentFromSpreadsheet -gt 0 ]] && Msg2 "^$numDifferentFromSpreadsheet records differed between Spreadsheet and '$tgtEnv'"
	fi

## Write out file
##TODO: Replace writing of the roles data with a courseleaf step somehow
	if [[ $informationOnlyMode != true ]]; then
		writeFile=true
		if [[ ${#warningMsgs[@]} -gt 0 ]]; then
			Msg2; unset ans
			Prompt ans "Warning messages were issued, do you wish to write the role data out to '$tgtEnv'" "Yes No"; ans=$(Lower ${ans:0:1})
			[[ $ans != 'y' ]] && writeFile=false
		fi
		if [[ $writeFile == true ]]; then
			rolesFile=$tgtDir/web/courseleaf/roles.tcf
			Msg2 "\nWriting out new roles.tcf file to '$tgtEnv' ($rolesFile)..."
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
			Msg2 "^$editFile written to disk"
			summaryMsgs+=("$editFile written to disk")
			## Write out change log entries
				$DOIT Msg2 "\n$userName\t$(date) via '$myName' version: $version" >> $tgtDir/changelog.txt
				$DOIT Msg2 "^Merged data from '$srcEnv'" >> $tgtDir/changelog.txt
				[[ $workbookFile != '' ]] && $DOIT Msg2 "^Merged data from $realWorkbookFile" >> $tgtDir/changelog.txt
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
	#[[ $informationOnlyMode == false ]] && summaryMsgs+=("$tgtEnv roles.tcf file written ($tgtDir/web/courseleaf/roles.tcf)") || \

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
