#!/bin/bash
# XO NOT AUTOVERSION
#==================================================================================================
version=3.8.15 # -- dscudiero -- 12/21/2016 @ 16:18:54.08
#==================================================================================================
TrapSigs 'on'
imports='ParseArgs ParseArgsStd Hello Init Goodbye Prompt SelectFile InitializeInterpreterRuntime GetExcel'
imports="$imports GetOutputFile BackupCourseleafFile ParseCourseleafFile GetCourseleafPgm RunCoureleafCgi"
Import "$imports"
originalArgStr="$*"
scriptDescription="Load Courseleaf Data"

#==================================================================================================
## Load courseleaf data from a spreadsheet (xlsx) file
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
	function parseArgs-loadCourseleafData  {
		argList+=(-informationOnly,2,switch,informationOnlyMode,,script,'Only analyze data and print error messages, do not change any client data.')
		argList+=(-workbookFile,1,option,workbookFile,,script,'The fully qualified spreadsheet file name')
		argList+=(-skipNulls,2,switch,skipNulls,,script,'If a data field is null then do not write out that data to the page')
		argList+=(-noUinMap,3,switch,noUinMap,,script,'Do not map role data UIDs to UINs')
		argList+=(-users,1,switch,processUserData,,script,'Load user data')
		argList+=(-role,1,switch,processRoleData,,script,'Load role data')
		argList+=(-page,2,switch,processPageData,,script,'Load catalog page data')
		argList+=(-ignoreMissingPages,2,switch,ignoreMissingPages,,script,'Ignore missing catalog pages')
		argList+=(-noIgnoreMissingPages,3,switch,ignoreMissingPages,ignoreMissingPages=false,script,'Do not ignore missing catalog pages')
		argList+=(-product,2,option,product,,script,'Search the "CAT" or "CIM" Implementaton folders for spreadsheet files')
		return 0
	}
	#==============================================================================================
	# Goodbye call back
	#==============================================================================================
	function Goodbye-loadCourseleafData  {
		local exitCode="$1"
		[[ -f $tmpWorkbookFile ]] && rm $workbookFile
		[[ -f $stepFile ]] && rm -f $stepFile
		[[ -f $backupStepFile ]] && mv -f $backupStepFile $stepFile
		[[ -f "$tmpDataFile" ]] && rm -f "$tmpDataFile"

		if [[ -f $logFile && $outFile != '' ]]; then
			cat $logFile | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g" > $outFile
			Msg2; Msg2 $I "The output can be found in '$outFile'"
		fi
		return 0
	}

	#==========================================F====================================================
	# TestMode overrides
	#==============================================================================================
	function testMode-loadCourseleafData  {
		client='dscudiero-test'
		env='dev'
		workbookFile='dave-CIMWorkflowM1.xlsm'
		noCheck=true
		skipNulls=false
		useUINs=false
		verify=false
		informationOnlyMode=true
		return 0
	}

	#==================================================================================================
	# Cleanup funtion, strip leadning blanks, tabs and commas
	#==================================================================================================
	function CleanString {

		local string="$*"

		## blanks before commas
		string=$(echo "$string" | sed 's/ ,/,/g')

		## blanks  after commas
		string=$(echo "$string" | sed 's/, /,/g')

		## Strip leading blanks. tabs. commas
		string=$(echo "$string" | sed 's/^[ ,\t]*//g')

		## Strip trailing blanks. tabs. commas
		string=$(echo "$string" | sed 's/[ ,\t]*$//g')

		echo "$string"
	}

	#==================================================================================================
	# Get the users data from the db
	#==================================================================================================
	function GetUsersDataFromDB {
		dbFile=$srcDir/db/clusers.sqlite
		[[ ! -r $dbFile ]] && TerminateMsg "Could not read the clusers database file:\n\t$dbFile"
		Msg2 "Reading the user data from the clusers database ..."

		sqlLiteFields="userid,lname,fname,email"
		sqlStmt="select $sqlLiteFields FROM users"
		RunSql 'sqlite' "$dbFile" "$sqlStmt"
		if [[ ${#resultSet[@]} -ne 0 ]]; then
			for resultRec in "${resultSet[@]}"; do
				dump -2 resultRec
				key=$(echo $resultRec | cut -d '|' -f 1)
				key=$(cut -d'.' -f1 <<< $key)
				[[ $key == '' ]] && continue
				value=$(echo $resultRec | cut -d '|' -f 2)'|'$(echo $resultRec | cut -d '|' -f 3)'|'$(echo $resultRec | cut -d '|' -f 4)
				usersFromDb["$key"]="$value"
			done
		fi
		numUsersfromDb=${#usersFromDb[@]}
		Msg2 "^Retrieved $numUsersfromDb records from the 'clusers' database"
		if [[ $verboseLevel -ge 1 ]]; then Msg2 "usersFromDb:"; for i in "${!usersFromDb[@]}"; do printf "\t\t[$i] = >${usersFromDb[$i]}<\n"; done; fi
		return 0
	} #GetUsersDataFromDB

	#==================================================================================================
	# Get the roles data from the file
	#==================================================================================================
	function GetRolesDataFromFile {
		[[ $useUINs == true && $processedUserData != true ]] && TerminateMsg "$FUNCNAME: Requesting UIN mapping but no userid sheet was provided"
		Msg2 "Reading the roles.tcf file ..."
		## Get the roles data from the roles.tcf file
			file=$rolesFile
			[[ ! -r $file ]] && TerminateMsg "Could not read the roles file: '$file'"
			while read line; do
				if [[ ${line:0:5} == 'role:' ]]; then
					key=$(echo $line | cut -d '|' -f 1 | cut -d ':' -f 2)
					[[ $key == '' ]] && continue
					data=$(Trim $(echo $line | cut -d '|' -f 2-))
					dump -3 -n line key data
			      	rolesFromFile+=([$key]="$data")
			      	rolesOut+=([$key]="$data")
		      	fi
			done < $file
			numRolesFromFile=${#rolesFromFile[@]}
			Msg2 "^Retrieved $numRolesFromFile records"
			if [[ $verboseLevel -ge 1 ]]; then Msg2 "\trolesFromFile:"; for i in "${!rolesFromFile[@]}"; do printf "\t\t[$i] = >${rolesFromFile[$i]}<\n"; done; fi
		return 0
	} #GetRolesDataFromFile

	#==================================================================================================
	# Get the workflows data from the workflow.tcf file
	#==================================================================================================
	function GetWorkflowDataFromFile {
		[[ $useUINs == true && $processedUserData != true ]] && TerminateMsg "$FUNCNAME: Requesting UIN mapping but no userid sheet was provided"
		Msg2 "Reading the workflow.tcf file ..."
		## Get the roles data from the roles.tcf file
			file=$srcDir/web/$courseleafProgDir/workflows.tcf
			[[ ! -r $file ]] && TerminateMsg "Could not read the '$file' file"
			while read line; do
				if [[ ${line:0:9} == 'workflow:' ]]; then
					key=$(echo $line | cut -d ':' -f 2 | cut -d '|' -f 1)
					[[ $key == '' ]] && continue
					workflowsFromFile[$key]=true
		      	fi
			done < $file
			numWorkflowsFromFile=${#workflowsFromFile[@]}
			Msg2 "^Retrieved $numWorkflowsFromFile records"
			if [[ $verboseLevel -ge 1 ]]; then Msg2 "\tworkflowsFromFile:"; for i in "${!workflowsFromFile[@]}"; do printf "\t\t[$i] = >${workflowsFromFile[$i]}<\n"; done; fi
			Msg2
		return 0
	} #GetWorkflowDataFromFile

	#==================================================================================================
	# ParseWorksheetHeader "sheetName" "fields" "dataFileName"
	#
	# Parse the worksheet header record, scans file looking for the headerRowIndicator, if fouund
	# parsez record and sets variables of the form <fieldName>Col with the column number (starting at 1)
	# of the column in the spreadsheet data
	# Also sets 'startReadingAt' to be the record number of the first row of actual data
	#
	# e.g. ParseWorksheetHeader "$tmpFile" "$workbookSheet" "name members email"
	#
	#==================================================================================================
	function ParseWorksheetHeader {
		VerboseMsg 2 "<==== Starting: $FUNCNAME ====>"
		local dataFile="$1"
		local sheetName="$2"
		local requiredFields="$3"
		local optionalFields="$4"
		dump -2 -t sheetName requiredFields optionalFields dataFile
		[[ ! -r $dataFile ]] && TerminateMsg "($FUNCNAME) Could not read file: '$dataFile' "

		## Scan returned data looking for the 'headerRowIndicator'
			startReadingAt=0
			local headerRow
			while read line; do
				dump -2 -t -t line
				[[ ${line:0:${#headerRowIndicator}} == "$headerRowIndicator" ]] && read headerRow && break
				let startReadingAt=$startReadingAt+1
			done < $dataFile
			if [[ $headerRow == '' ]]; then
				InfoMsg 0 1 "Could not locate the header row indicator in the '$2' worksheet, using the first row as the header data"
				read headerRow < $dataFile
				startReadingAt=2
			else
				let startReadingAt=$startReadingAt+3
			fi
			dump -2 -t headerRow startReadingAt

		# Parse the header record, getting the column numbers of the fields
			IFSave=$IFS; IFS=\|; sheetCols=($headerRow); IFS=$IFSave;
			for field in $requiredFields $optionalFields; do
				unset fieldCntr $(cut -d'|' -f1 <<< $field)Col
				for sheetCol in "${sheetCols[@]}"; do
					(( fieldCntr += 1 ))
					for subField in $(tr '|' ' ' <<< $field); do
						if [[ $(Contains "$(Lower $sheetCol)" "$subField") == true ]]; then
							unset chkVal; eval chkVal=\$$(cut -d'|' -f1 <<< $field)Col
							[[ $chkVal != '' ]] && TerminateMsg "Found duplicate '$field' fields in the worksheet header:\n^$headerRow"
							eval "$(cut -d'|' -f1 <<< $field)Col=$fieldCntr"
						fi
					done
				done
				colVar="$(cut -d'|' -f1 <<< $field)Col"
				dump -2 -t -t colVar field
				if [[ ${!colVar} == '' && $(Contains "$requiredFields" "$(cut -d'|' -f1 <<< $field)") == true ]]; then
					TerminateMsg "^Could not locate required column, '$(cut -d'|' -f1 <<< $field)', in the '$sheetName' worksheet"
				fi
				dump -2 -t field -t $(cut -d'|' -f1 <<< $field)Col
			done

		VerboseMsg 2 "<==== Ending: $FUNCNAME ====>"
		return 0
	} # ParseWorksheetHeader


	#==================================================================================================
	# Map UIDs to UINs in role members
	#==================================================================================================
	function EditRoleMembers {
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
	} #EditRoleMembers

	#==================================================================================================
	# Process USER records
	#==================================================================================================
	function ProcessUserData {
		local workbookSheet="$1"
		Msg2 "Parsing the roles data from the '$workbookSheet' worksheet ..."

		## Get the user data from the spreadsheet
			GetExcel "$workbookFile" "$workbookSheet" > $tmpFile
			#echo; echo $tmpFile; cat $tmpFile; Pause

			## Read the header record, look for the specific columns to determin how to parse subsequent records
				ParseWorksheetHeader "$tmpFile" "$workbookSheet" "userid first last email" "uin"
				dump -1 startReadingAt
				for field in userid first last email uin ; do dump -1 field ${field}Col; done

			## See if this client has special case handeling for usernames
				sqlStmt="select useridCase from $clientInfoTable where name=\"$client\""
				RunSql 'mysql' "$sqlStmt"
				useridCase=$(Upper ${resultSet[0]:0:1}) || useridCase='M'

			## Read/Parse the data rows into hash table
			while read line; do
				[[ $line == '' ]] && continue
				key=$(echo $line | cut -d '|' -f $useridCol)
				[[ $useridCase == 'U' ]] && key=$(Upper $key)
				[[ $useridCase == 'L' ]] && key=$(Lower $key)
				[[ $uinCol == '' ]] && value=$(echo $line | cut -d '|' -f $lastCol)'|'$(echo $line | cut -d '|' -f $firstCol)'|'$(echo $line | cut -d '|' -f $emailCol) || \
							value=$(echo $line | cut -d '|' -f $lastCol)'|'$(echo $line | cut -d '|' -f $firstCol)'|'$(echo $line | cut -d '|' -f $emailCol)'|'$(echo $line | cut -d '|' -f $uinCol)
				dump -2 -n line -t key value
				[[ $key == '' ]] && continue
				key=$(cut -d'.' -f1 <<< $key)
				if [[ ${usersFromSpreadsheet["$key"]+abc} ]]; then
					if [[ ${usersFromSpreadsheet["$key"]} != $value ]]; then
						TerminateMsg "^The '$workbookSheet' tab in the workbook contains duplicate userid records \
						\n^^UserId: '$key' with value '$value' is duplicate\n^previous value = '${usersFromSpreadsheet["$key"]}'"
					fi
				else
					usersFromSpreadsheet["$key"]="$value"
				fi
			done < <(tail -n "+$startReadingAt" $tmpFile)

			numUsersfromSpreadsheet=${#usersFromSpreadsheet[@]}
			Msg2 "^Retrieved $numUsersfromSpreadsheet records from the '$workbookSheet' sheet"
			if [[ $verboseLevel -ge 1 ]]; then Msg2 "\tusersFromSpreadsheet:"; for i in "${!usersFromSpreadsheet[@]}"; do \
				printf "\t\t[$i] = >${usersFromSpreadsheet[$i]}<\n"; done; fi

		## Get the user data from the clusers database
			GetUsersDataFromDB

		## Merge the spreadsheet data and the file data
			numNewUsers=0
			numModifiedUsers=0
			Msg2 "Merging User data..."

			dbFile=$srcDir/db/clusers.sqlite
			BackupCourseleafFile $dbFile
			local procesingCntr=0
			for key in "${!usersFromSpreadsheet[@]}"; do
				#value="${rolesFromSpreadsheet["$key"]}"
				unset lname fname email
				lname=$(Trim "$(echo ${usersFromSpreadsheet["$key"]} | cut -d '|' -f 1)")
				fname=$(Trim "$(echo ${usersFromSpreadsheet["$key"]} | cut -d '|' -f 2)")
				email=$(Trim "$(echo ${usersFromSpreadsheet["$key"]} | cut -d '|' -f 3)")
				if [[ ${usersFromDb["$key"]+abc} ]]; then
					unset oldData;  oldData="${usersFromDb["$key"]}"
					[[ ${oldData:(-1)} == '|' ]] && oldData=${oldData:0:${#oldData}-1}
					unset newData;  newData="${usersFromDb["$key"]}"
					[[ ${newData:(-1)} == '|' ]] && newData=${newData:0:${#newData}-1}
					if [[ $oldData != $newData ]]; then
						WarningMsg 0 1 "Found User '$key' in the clusers database file but data is different, using new data"
						Msg2 "^^New Data: $newData"
						Msg2 "^^Old Data: $oldData"
						sqlStmt="UPDATE users set lname=\"$lname\", fname=\"$fname\", email=\"$email\" where userid=\"$key\" "
						[[ $informationOnlyMode == false ]] && $DOIT RunSql 'sqlite' "$dbFile" "$sqlStmt"
						(( numModifiedUsers += 1 ))
					fi
				else
					VerboseMsg 1 "Adding new user: $key"
					sqlStmt="INSERT into users values(NULL,\"$key\",\"$lname\",\"$fname\",\"$email\") "
					[[ $informationOnlyMode == false ]] && $DOIT RunSql 'sqlite' "$dbFile" "$sqlStmt"
					usersFromDb["$key"]="${usersFromSpreadsheet["$key"]}"
					VerboseMsg 1 2 "User added: $key"
					(( numNewUsers += 1 ))
				fi
				# If useUINs is active then build userid to uin map from the email information
				if [[ $useUINs == true ]]; then
					uid=$(echo ${usersFromDb["$key"]} | cut -d'|' -f 3 | cut -d'@' -f1)
					uidUinHash["$uid"]="$key"
				fi
				[[ $procesingCntr -ne 0 && $(($procesingCntr % 100)) -eq 0 ]] && Msg2 "^Processed $procesingCntr out of $numUsersfromSpreadsheet..."
				let procesingCntr=$procesingCntr+1
			done
			if [[ $verboseLevel -ge 1 ]]; then Msg2 "\tMerged User list:"; for i in "${!usersFromDb[@]}"; do printf "\t\t[$i] = >${usersFromDb[$i]}<\n"; done; fi

		## Rebuild the appache-group file
			if [[ $informationOnlyMode == false ]]; then
				RunCoureleafCgi "$srcDir" "-r /apache-group.html"
			fi
			Msg2
		return 0
	} #ProcessUserData

	#==================================================================================================
	# Process ROLE records
	#==================================================================================================
	function ProcessRoleData {
		local workbookSheet="$1"
		Msg2 "Parsing the roles data from the '$workbookSheet' worksheet ..."

		## Get the page data from the spreadsheet
			GetExcel "$workbookFile" "$workbookSheet" > $tmpFile
			#echo $tmpFile; cat $tmpFile; Pause

			## Read the header record, look for the specific columns to determin how to parse subsequent records
				ParseWorksheetHeader "$tmpFile" "$workbookSheet" "name members|userlist email"
				dump -1 startReadingAt
				for field in name members email; do dump -1 ${field}Col; done

			## Read/Parse the data rows into hash table
			while read line; do
				[[ $line == '' ]] && continue
				key=$(echo $line | cut -d '|' -f $nameCol)
				value=$(echo $line | cut -d '|' -f $membersCol)'|'$(echo $line | cut -d '|' -f $emailCol)
				value=$(echo $value | tr -d ' ')
				dump -2  -n line -t key value
				[[ $key == '' ]] && continue
				[[ $(IsNumeric ${value:0:1}) == true ]] && value=$(cut -d'.' -f1 <<< $value)
				if [[ ${rolesFromSpreadsheet["$key"]+abc} ]]; then
					if [[ ${rolesFromSpreadsheet["$key"]} != $value ]]; then
						TerminateMsg "^TThe '$workbookSheet' tab in the workbook contains duplicate role records \
						\n^^Role '$key' with value '$value' is duplicate\n^previous value = '${rolesFromSpreadsheet["$key"]}'"
					fi
				else
					rolesFromSpreadsheet["$key"]="$value"
				fi
			done < <(tail -n "+$startReadingAt" $tmpFile)
			numRolesfromSpreadsheet=${#rolesFromSpreadsheet[@]}
			Msg2 "^Retrieved $numRolesfromSpreadsheet records from the '$workbookSheet' sheet"
			if [[ $verboseLevel -ge 1 ]]; then Msg2 "\trolesfromSpreadsheet:"; for i in "${!rolesFromSpreadsheet[@]}"; do printf "\t\t[$i] = >${rolesFromSpreadsheet[$i]}<\n"; done; fi

		## Merge the spreadsheet data and the file data
			GetRolesDataFromFile #Also sets rolesOut

			if [[ $verboseLevel -ge 1 ]]; then Msg2 "\trolesOut:"; for i in "${!rolesOut[@]}"; do printf "\t\t[$i] = >${rolesOut[$i]}<\n"; done; fi
			numNewRoles=0
			numModifiedRoles=0
			numRoleMembersMappedToUIN=0

			Msg2 "Merging Role data..."
			local procesingCntr=0
			for key in "${!rolesFromSpreadsheet[@]}"; do
				## Edit role data if useUINs is on
					memberData="$(echo "${rolesFromSpreadsheet["$key"]}" | cut -d'|' -f 1)"
					emailData="$(echo "${rolesFromSpreadsheet["$key"]}" | cut -d'|' -f 2)"
					newMemberData="$(EditRoleMembers "$memberData")"
					if [[ $memberData != $newMemberData ]]; then
						rolesFromSpreadsheet["$key"]="$newMemberData|$emailData"
						Msg2 $NT1 "Role: '$key' -- UIDs mapped to UINs"
						(( numRoleMembersMappedToUIN +=1 ))
					fi

				## Check spreadsheet data vs file data
					if [[ ${rolesOut["$key"]+abc} ]]; then
						if [[ ${rolesFromSpreadsheet["$key"]} != ${rolesOut["$key"]} ]]; then
							if [[ $oldData != '' ]]; then
								WarningMsg 0 1 "Found Role '$key' in the roles file but data is different, using new data"
								Msg2 "^^New Data: ${rolesFromSpreadsheet["$key"]}"
								unset oldData;  oldData="${usersFromDb["$key"]}"
								[[ ${oldData:(-1)} == '|' ]] && oldData=${oldData:0:${#oldData}-1}
								Msg2 "^^Old Data: $oldData"
							fi
							Msg2 $IT1 "Found Role '$key' in the roles file, old data is null, using new data"
							rolesOut["$key"]="${rolesFromSpreadsheet["$key"]}"
							(( numModifiedRoles += 1 ))
						fi
					else
						VerboseMsg 1 2 "New role added: $key"
						rolesOut["$key"]="${rolesFromSpreadsheet["$key"]}"
						(( numNewRoles += 1 ))
					fi
				[[ $procesingCntr -ne 0 && $(($procesingCntr % 100)) -eq 0 ]] && Msg2 "^Processed $procesingCntr out of $numRolesfromSpreadsheet..."
				let procesingCntr=$procesingCntr+1
			done

##TODO: Replace writing of the roles data with a courseleaf step somehow
		## Write out the role data to the role file
			if [[ $informationOnlyMode == false ]]; then
				if [[ $numModifiedRoles -gt 0 || $numNewRoles -gt 0 ]]; then
					Msg2 "Writing out new roles.tcf file..."
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
						echo "role:${key}|${rolesOut["$key"]}" >> $editFile.new
					done
					echo >> $editFile.new
					[[ -f $bottomPart ]] && $DOIT cat $bottomPart >> $editFile.new
					## Swap the files
					mv $editFile.new $editFile
					[[ -f $topPart ]] && rm -f $topPart; [[ -f $bottomPart ]] && rm -f $bottomPart
					Msg2 "^$editFile written to disk"
				fi
			fi

		## Check the members against the user data
			if [[ $processUserData == true ]]; then
				numRoleMembersNotProvisoned=0
				Msg2 "Checking Role members..."
				for key in "${!rolesOut[@]}"; do
					members=$(echo ${rolesOut["$key"]} | cut -d '|' -f 1)
					#IFSsave=$IFS; IFS=','
					for member in $(tr ',' ' ' <<< $members); do
						if [[ ! ${usersFromDb["$member"]+abc} ]]; then
							WarningMsg 0 1 "Role member '$member' use in role '$key' is not provisioned"
							(( numRoleMembersNotProvisoned += 1 ))
						fi
					done
					#IFS=$IFSsave
				done
			fi
			Msg2
		return 0
	} #ProcessRoleData

	#==================================================================================================
	# Process WORKFLOW records
	#==================================================================================================
	function ProcessCatalogPageData {
		[[ $useUINs == true && $processedUserData != true ]] && TerminateMsg "$FUNCNAME: Requesting UIN mapping but no userid sheet was provided"
		## Get the user data from the spreadsheet
			unset workbookSheet
			[[ $(Contains "$(Lower $sheets)" 'page') == true ]] && workbookSheet='page'
			[[ $(Contains "$(Lower $sheets)" 'workflow') == true ]] && workbookSheet='workflow'
			Msg2 "Parsing the catalog page data from the '$workbookSheet' worksheet ..."
			GetExcel "$workbookFile" "$workbookSheet" > $tmpFile
			#echo $tmpFile; cat $tmpFile; Pause

		## Read the header record, look for the specific columns to determin how to parse subsequent records
			ParseWorksheetHeader "$tmpFile" "$workbookSheet" "path title owner workflow"
			dump -1 startReadingAt
			for field in path title owner workflow; do dump -1 ${field}Col; done

			## Read/Parse the data rows into hash table
			numPagesNotFound=0
			while read line; do
				[[ $line == '' ]] && continue
				key=$(echo $line | cut -d '|' -f $pathCol)
				dump -1 line -t key
				[[ $key == '' ]] && WarningMsg 0 1 "Work Sheet record:\n^^$line\n\tDoes not contain any path/url data, skipping" && continue
				if [[ $key != '/' && ! -d $(dirname $srcDir/web/$key) ]]; then
					[[ $ignoreMissingPages != true ]] && WarningMsg 0 1 "Page: '$key' Not found"
					((numPagesNotFound += 1))
					continue
				fi
				value=$(echo $line | cut -d '|' -f $titleCol)'|'$(echo $line | cut -d '|' -f $ownerCol)'|'$(echo $line | cut -d '|' -f $workflowCol)
				dump -2 -n line -t key value
				if [[ ${workflowDataFromSpreadsheet["$key"]} != '' ]]; then
					if [[ ${workflowDataFromSpreadsheet["$key"]} != $value ]]; then
						TerminateMsg "^The '$workbookSheet' sheet in the workbook contains duplicate records with the same 'path' and differeing data\
						\n^^Path/url: $key\n^^Previous Data: ${workflowDataFromSpreadsheet["$key"]}\n^^Current Data: $value"
					fi
				else
					workflowDataFromSpreadsheet["$key"]="$value"
				fi
			done < <(tail -n "+$startReadingAt" $tmpFile)

			numWorkflowDataFromSpreadsheet=${#workflowDataFromSpreadsheet[@]}
			Msg2 "^Retrieved $numWorkflowDataFromSpreadsheet records from the '$workbookSheet' sheet"
			if [[ $verboseLevel -ge 1 ]]; then Msg2 "\tworkflowDataFromSpreadsheet:"; for i in "${!workflowDataFromSpreadsheet[@]}"; do printf "\t\t[$i] = >${workflowDataFromSpreadsheet[$i]}<\n"; done; fi

			## Get the courseleaf pgmname and dir
				cd $srcDir
				courseLeafPgm=$(GetCourseleafPgm | cut -d' ' -f1)
				courseLeafDir=$(GetCourseleafPgm | cut -d' ' -f2)
				if [[ $courseLeafPgm == '' || $courseLeafDir == '' ]]; then TerminateMsg "^Could not find courseleaf executable"; fi
				dump -3 -q courseLeafPgm courseLeafDir
			## Install the stepfile to update the page data
				stepFile=$courseLeafDir/localsteps/$step.html
				BackupCourseleafFile $stepFile

			## Find the step file to run
				FindExecutable "$step" 'step:html'
				srcStepFile="$executeFile"
				InfoMsg 0 1 "Using step file: $srcStepFile"

			## Copy step file to localsteps
				cp -fP $srcStepFile $stepFile
				chmod ug+w $stepFile

			## Update the page data in courseleaf
			numPagesUpdated=0
			numMembersMappedToUIN=0
			Msg2 "^Updating catalog page data (this takes a while)..."
			local procesingCntr=0
			for key in "${!workflowDataFromSpreadsheet[@]}"; do
				pageTitle="$(echo ${workflowDataFromSpreadsheet[$key]} | cut -d'|' -f1)"
				pageOwner="$(CleanString $(echo ${workflowDataFromSpreadsheet[$key]} | cut -d'|' -f2))"
				pageWorkflow="$(echo ${workflowDataFromSpreadsheet[$key]} | cut -d'|' -f3)"

				## Check to see if the pageWorkflow data is a real defined workflow
					foundNamedWorkflow=false
					if [[ $pageWorkflow != '' && ${workflowsFromFile["$pageWorkflow"]} == true ]]; then
						foundNamedWorkflow=true
					else
						pageWorkflow=$(CleanString $pageWorkflow)
					fi

				## Edit role data if useUINs is on
					if [[ $useUINs == true ]]; then
						if [[ $foundNamedWorkflow != true ]]; then
						pageWorkflowNew="$(EditRoleMembers "$pageWorkflow")"
							if [[ $pageWorkflowNew != $pageWorkflow ]]; then
								pageWorkflow="$pageWorkflowNew"
								Msg2 $NT1 "Page: '$key' -- Workflow UIDs mapped to UINs"
								((numMembersMappedToUIN +=1))
							fi
						fi
						pageOwnerNew="$(EditRoleMembers "$pageOwner")"
						if [[ $pageOwnerNew != $pageOwner ]]; then
							pageOwner="$pageOwnerNew"
							Msg2 $NT1 "Page: '$key' -- Owner UIDs mapped to UINs"
							((numMembersMappedToUIN +=1))
						fi
					fi
					dump -2 -t key pageTitle pageOwner pageWorkflow

				## Check the owners and role members to make sure they exist
					errorInMemberLookup=false
					[[ $foundNamedWorkflow == true ]] && checkMembers="$pageOwner" || checkMembers="$pageOwner,$pageWorkflow"
					IFSsave=$IFS; IFS=',' read -a members <<< "$checkMembers"; IFS=$IFSsave
					for member in "${members[@]}"; do
						[[ $member == '' ]] && continue
						foundMember=false
						[[ ${usersFromDb["$member"]+abc} ]] && foundMember=true && continue
						[[ ${rolesOut["$member"]+abc} ]] && foundMember=true && continue
						if [[ $foundMember == false ]]; then
							errorInMemberLookup=true
							if [[ ${membersErrors["$member"]+abc} ]]; then
								membersErrors["$member"]="${membersErrors["$member"]}|$key"
							else
								membersErrors["$member"]="$key"
							fi
						fi
					done

				## export the data to make it available to the step, then run step to update page data
					if [[ $informationOnlyMode == false ]]; then
						if [[ $pageOwner != '' || $pageWorkflow != '' || $skipNulls == false ]]; then
							export QUERY_STRING="owner=$pageOwner|workflow=$pageWorkflow|skipNulls=$skipNulls"
							$DOIT ProtectedCall "RunCoureleafCgi "$srcDir" "$step $key""
							((numPagesUpdated +=1))
						fi
					fi
					[[ $procesingCntr -ne 0 && $(($procesingCntr % 100)) -eq 0 ]] && Msg2 "^Processed $procesingCntr out of $numWorkflowDataFromSpreadsheet..."
					let procesingCntr=$procesingCntr+1
			done
			Msg2 "^$numWorkflowDataFromSpreadsheet out of $numWorkflowDataFromSpreadsheet processed"
	return 0
} #ProcessCatalogPageData

#==================================================================================================
# Declare local variables and constants
#==================================================================================================
step='setPageData'
falseVars='processUserData processRoleData processPageData processedUserData processedRoleData processedWorkflowData noUinMap useUINs informationOnlyMode'
for var in $falseVars; do eval $var=false; done

declare -A usersFromSpreadsheet
declare -A usersFromDb
declare -A rolesFromFile
declare -A rolesOut
declare -A rolesFromSpreadsheet
declare -A workflowDataFromSpreadsheet
declare -A workflowsFromFile
declare -A uidUinHash
declare -A membersErrors
#headerRowIndicator='*** Please do NOT change column headings, please do NOT add any columns, both will prevent the data from being loaded ***'
headerRowIndicator='***'

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
helpSet='script,client,env'
helpNotes+=("The output is written to the $HOME/clientData/<client> directory,\n\t   if the directory does exist one will be created.")
GetDefaultsData $myName
ParseArgsStd
[[ $allItems == true ]] && processUserData=true && processRoleData=true && processPageData=true
[[ $product != '' ]] && product=$(Lower $product)

Hello
displayGoodbyeSummaryMessages=true
Init 'getClient getEnv getDirs checkEnvs checkProdEnv'
dump -1 processUserData processRoleData processPageData informationOnlyMode ignoreMissingPages

## Information only mode
 	[[ $informationOnlyMode == true ]] && WarningMsg "'informationOnlyMode' flag is set, no data will be modified."

## Find out if this client uses UINs
	if [[ $noUinMap == false ]]; then
		sqlStmt="select usesUINs from $clientInfoTable where name=\"$client\""
			RunSql 'mysql' $sqlStmt
			if [[ ${#resultSet[@]} -ne 0 ]]; then
				result="${resultSet[0]}"
				[[ $result == 'Y' ]] && useUINs=true && Msg2
			fi
	fi

## Get workflow file
	tmpWorkbookFile=false
	unset workbookFileIn workflowSearchDir
	if [[ $workbookFile == '' ]]; then
		[[ $verify != true ]] && TerminateMsg "^No value specified for workbook file and verify is off"
		## Search for XLSx files in clientData and implimentation folders
		if [[ -d "$localClientWorkFolder/$client" ]]; then
			workflowSearchDir="$localClientWorkFolder/$client"
		else
			## Find out if user wants to load cat data or cim data
			Prompt product 'Are you loading CAT or CIM data' 'cat cim' 'cat';
			product=$(Upper $product)
			implimentationRoot="/steamboat/leepfrog/docs/Clients/$client/Implementation"
			if   [[ -d "$implimentationRoot/Attachments/$product/Workflow" ]]; then workflowSearchDir="$implimentationRoot/Attachments/$product/Workflow"
			elif [[ -d "$implimentationRoot/Attachments/$product" ]]; then workflowSearchDir="$implimentationRoot/Attachments/$product"
			elif [[ -d "$implimentationRoot/$product/Workflow" ]]; then workflowSearchDir="$implimentationRoot/$product/Workflow"
			elif [[ -d "$implimentationRoot/$product" ]]; then workflowSearchDir="$implimentationRoot/$product"
			fi
		fi
		if [[ $workflowSearchDir != '' ]]; then
			SelectFile $workflowSearchDir 'workbookFile' '*.xls*' "\nPlease specify the $(ColorK '(ordinal)') number of the Excel workbook you wish to load data from:\
				\n(*/.xls* files found in '$(ColorK $workflowSearchDir)')\n(sorted ordered newest to oldest)\n\n"
			workbookFile="$workflowSearchDir/$workbookFile"
		fi
	else
		[[ ${workbookFile:0:1} != '/' ]] && workbookFile=$localClientWorkFolder/$client/$workbookFile
		lenStr=${#workbookFile}
		[[ ${workbookFile:lenStr-5:4} != '.xls' ]] && workbookFile=$workbookFile.xlsx
	fi
	[[ -f "$tmpDataFile" ]] && rm -f "$tmpDataFile"

	[[ $workbookFile == "" ]] && Msg2
	Prompt workbookFile 'Please specify the full path to the workbook file' '*file*'

	## If the workbook file name contains blanks then copy to temp and use that one.
		tmpWorkbookFile=false
		if [[ $(Contains "$workbookFile" ' ') == true ]]; then
			cp -fp "$workbookFile" /tmp/$userName.$myName.workbookFile
			tmpWorkbookFile=true
			workbookFileIn="$workbookFile"
			workbookFile=/tmp/$userName.$myName.workbookFile
		fi
		[[ ! -r $workbookFile ]] && TerminateMsg "Could not locate file: '$workbookFile'"

	Msg2

## Get the list of sheets in the workbook
	GetExcel "$workbookFile" 'GetSheets' > $tmpFile
	sheets=$(tail -n 1 $tmpFile | tr '|' ',')
	dump -1 sheets

## What data should we load
	if [[ $verify == true && $processUserData != true && $(Contains "$(Lower $sheets)" 'user') == true ]]; then
		unset ans; Prompt ans 'Found a user data spreadsheet, do you wish to process user data' 'Yes No All'; ans=$(Lower ${ans:0:1})
		[[ $ans == 'y' ]] && processUserData=true
		[[ $ans == 'a' ]] && processUserData=true && processRoleData=true && processPageData=true
	else
		[[ $(Contains "$(Lower $sheets)" 'user') == true ]] && processUserData=true
	fi

	if [[ $verify == true && $processRoleData != true && $(Contains "$(Lower $sheets)" 'role') == true ]]; then
		unset ans; Prompt ans 'Found a roles data spreadsheet, do you wish to process role data' 'Yes No'; ans=$(Lower ${ans:0:1})
		[[ $ans == 'y' ]] && processRoleData=true
		[[ $ans == 'a' ]] && processUserData=true && processRoleData=true && processPageData=true
	else
		[[ $(Contains "$(Lower $sheets)" 'role') == true ]] && processRoleData=true
	fi

	if [[ $verify == true && $processPageData != true ]]; then
		if [[ $(Contains "$(Lower $sheets)" 'workflow') == true || $(Contains "$(Lower $sheets)" 'page') == true ]]; then
			unset ans; Prompt ans 'Found a catalog page data spreadsheet, do you wish to process page data' 'Yes No'; ans=$(Lower ${ans:0:1})
			[[ $ans == 'y' ]] && processPageData=true
			[[ $ans == 'a' ]] && processUserData=true && processRoleData=true && processPageData=true
		fi
	else
		[[ $(Contains "$(Lower $sheets)" 'workflow') == true || $(Contains "$(Lower $sheets)" 'page') == true ]] && processPageData=true
	fi

## Do we have anything to do
	[[ $processUserData != true && $processRoleData != true && $processPageData != true ]] && TerminateMsg "No load actions are avaiable given the data provided"

## Additional parms for page data
	if [[ $processPageData == true ]]; then
		if [[ $skipNulls == '' ]]; then
			if [[ $verify == true ]]; then
				unset ans; Prompt ans 'Do you wish to clear page values if the input cell data is empty' 'Yes No' 'Yes'; ans=$(Lower ${ans:0:1})
				[[ $ans == 'y' ]] && skipNulls=false || skipNulls=true
			fi
		fi
		if [[ $ignoreMissingPages == '' ]]; then
			if [[ $verify == true ]]; then
				unset ans; Prompt ans 'Do you wish to ignore nonexiting pages' 'No Yes' 'No'; ans=$(Lower ${ans:0:1})
				[[ $ans == 'y' ]] && ignoreMissingPages=true || ignoreMissingPages=false
			fi
		fi
	fi

## set default values
	[[ $ignoreMissingPages == '' ]] && ignoreMissingPages=false
	[[ $skipNulls == '' ]] && skipNulls=false

## Set output file
	outFile="$(GetOutputFile "$client" "$env" "$product")"

## Verify processing
	[[ $processUserData == false && $processRoleData == false && $processPageData == false ]] && Msg2 && TerminateMsg "No actions requested, please review help text"

	verifyArgs+=("Client:$client")
	verifyArgs+=("Env:$(TitleCase $env) ($srcDir)")
	[[ $tmpWorkbookFile == true ]] && verifyArgs+=("Input File:'$workbookFileIn' as '$workbookFile'") || verifyArgs+=("Input File:'$workbookFile'")
	#verifyArgs+=("Input workbook:'$workbookFileIn'")
	verifyArgs+=("Process user data:$processUserData")
	verifyArgs+=("Process role data:$processRoleData")
	verifyArgs+=("Process page data:$processPageData")
	verifyArgs+=("Skip null values:$skipNulls")
	verifyArgs+=("Ignore missing pages:$ignoreMissingPages")
	verifyArgs+=("Map UIDs to UINs:$useUINs")
	VerifyContinue "You are asking to update CourseLeaf data"

	dump -1 client env srcDir processUserData processRoleData processPageData skipNulls useUINs
	myData="Client: '$client', Env: '$env', product: '$product', skipNulls: '$skipNulls', ignoreMissingPages: '$ignoreMissingPages', File: '$workbookFile' "
	[[ $logInDb != false && $myLogRecordIdx != "" ]] && dbLog 'data' $myLogRecordIdx "$myData"

#==================================================================================================
# Main
#==================================================================================================
## Process spreadsheet
	[[ $client == 'internal' ]] && courseleafProgDir='pagewiz' || courseleafProgDir='courseleaf'
	Msg2
	rolesFile=$srcDir/web/$courseleafProgDir/roles.tcf

	## Get process the sheets as directed
		if [[ $processUserData == true ]]; then
			if [[ $(Contains "$(Lower $sheets)" 'user') == true ]]; then
				## find the 'users' sheet
				unset usersSheet
				for sheet in $(tr ',' ' ' <<< $sheets); do
					[[ $(Contains "$(Lower "$sheet")" 'user') == true ]] && usersSheet="$sheet" && break
				done
				[[ $usersSheet == '' ]] && TerminateMsg "Could not locate a 'Users' worksheet in the workbook."
				ProcessUserData "$usersSheet"
				processedUserData=true
			else
				WarningMsg 0 1 "No user data sheet found in workbook, sheets found: '$sheets', Skipping user data"
			fi
		fi

		if [[ $processRoleData == true ]]; then
			if [[ $(Contains "$(Lower $sheets)" 'role') == true ]]; then
				[[ $processUserData != true ]] && GetUsersDataFromDB
				## find the 'roles' sheet
				unset rolesSheet
				for sheet in $(tr ',' ' ' <<< $sheets); do
					[[ $(Contains "$(Lower "$sheet")" 'role') == true ]] && rolesSheet="$sheet" && break
				done
				[[ $rolesSheet == '' ]] && TerminateMsg "Could not locate a 'Roles' worksheet in the workbook."
				ProcessRoleData "$rolesSheet"
				processedRoleData=true
			else
				WarningMsg 0 1 "No role data sheet found in workbook, sheets found: '$sheets', skipping role data"
			fi
		fi

		if [[ $processPageData == true ]]; then
			if [[ $(Contains "$(Lower $sheets)" 'workflow') == true || $(Contains "$(Lower $sheets)" 'page') == true ]]; then
				[[ $processUserData != true ]] && GetUsersDataFromDB
				[[ $processRoleData != true ]] && GetRolesDataFromFile && rolesOut=${rolesFromFile[@]}
				GetWorkflowDataFromFile
				ProcessCatalogPageData
				processedPageData=true
			else
				WarningMsg 0 1 "No page data sheet found in workbook, sheets found: '$sheets', skipping user data"
			fi
		fi

## Write out change log entries
	$DOIT Msg2 "\n$userName\t$(date)" >> $srcDir/changelog.txt
	$DOIT Msg2 "^$myName updated from $workbookFile" >> $srcDir/changelog.txt

## Processing summary
	Msg2
	PrintBanner "Processing Summary"
	[[ $informationOnlyMode == true ]] && Msg2 "" && Msg2 ">>> The Information Only flag was set, no data has been updated <<<" && Msg2

	if [[ $processedUserData == true ]]; then
		Msg2 "User data:"
		Msg2 "^Retrieved $numUsersfromDb records from the clusers database"
		Msg2 "^Retrieved $numUsersfromSpreadsheet records from $workbookFile"
		Msg2 "^Added $numNewUsers new users" | tee -a $srcDir/changelog.txt
		Msg2 "^Modified $numModifiedUsers existing users" | tee -a $srcDir/changelog.txt
	fi

	[[ $processedUserData == true ]] && Msg2
	if [[ $processedRoleData == true ]]; then
		Msg2 "Role data:"
		Msg2 "^Retrieved $numRolesFromFile records from the roles.tcf file"
		Msg2 "^Retrieved $numRolesfromSpreadsheet records from $workbookFile"
		Msg2 "^Added $numNewRoles new roles" | tee -a $srcDir/changelog.txt
		Msg2 "^Modified $numModifiedRoles existing roles" | tee -a $srcDir/changelog.txt
		[[ $numRoleMembersMappedToUIN -gt 0 ]] && Msg2 "^Mapped $numRoleMembersMappedToUIN role members from UID to UIN" | tee -a $srcDir/changelog.txt
		[[ $numRoleMembersNotProvisoned -gt 0 ]] && Msg2 "^Found $numRoleMembersNotProvisoned role members not in user provisoning" | tee -a $srcDir/changelog.txt
	fi

	[[ $processedUserData == true || $processedRoleData == true ]] && Msg2
	if [[ $processedPageData == true ]]; then
		Msg2 "Page data:"
		Msg2 "^Retrieved $numWorkflowDataFromSpreadsheet records from $workbookFile"
		Msg2 "^Updated $numPagesUpdated pages" | tee -a $srcDir/changelog.txt
		[[ $numMembersMappedToUIN -gt 0 ]] && Msg2 "^Mapped $numMembersMappedToUIN role members from UID to UIN" | tee -a $srcDir/changelog.txt
		[[ $numPagesNotFound -gt 0 ]] && Msg2 "^$numPagesNotFound pages not found" | tee -a $srcDir/changelog.txt
		[[ ${#membersErrors[@]} -gt 0 ]] && Msg2 "^${#membersErrors[@]} pages had errors in their owner/workflow data, see below for detailed information" | tee -a $srcDir/changelog.txt
		## Member lookup errors

		if [[ ${#membersErrors[@]} -gt 0 ]]; then
			Msg2
			WarningMsg 0 1 "Found page owner or role data without a defined user or role, please see above"
			for key in "${!membersErrors[@]}"; do
				Msg2 "^$(ColorW "*Warning*") -- Workflow/Owner member: '$key' not defined and used on the following pages:"
				IFSsave=$IFS; IFS='|' read -a pages <<< "${membersErrors["$key"]}"; IFS=$IFSsave
				for page in "${pages[@]}"; do
					Msg2 "^^'$page'"
				done
				Msg2
			done
		fi
	fi

#==================================================================================================
## Done
#==================================================================================================
## Exit nicely
	Goodbye 0 #'alert'

#==================================================================================================
## Check-in log
#==================================================================================================
# 08-07-2015 -- dscudiero -- Complete rewrite in bash shell (2.1)
# 08-26-2015 -- dscudiero -- Updated to 1) Map UIDs to UINs if necesary. 2) Check owner and workflow members against user and role data (2.2)
# 10-16-2015 -- dscudiero -- Update for framework 6 (2.6)
# 10-22-2015 -- dscudiero -- Updated for errexit (2.7)
# 11-10-2015 -- dscudiero -- fixed problem checking role members (3.1)
# 11-23-2015 -- dscudiero -- refactored rolemanagement (3.2)
# 12-03-2015 -- dscudiero -- Updated to also check workflows against the clients named workflows (3.3)
# 12-08-2015 -- dscudiero -- Fix problem where roleFile variable was not set before use (3.4)
# 12-18-2015 -- dscudiero -- Fix problem writing role data (3.5.0)
# 12-30-2015 -- dscudiero -- refactored workflow file discovery (3.6.15)
## Thu Mar 17 13:30:39 EDT 2016 - dscudiero - If we cannot find the header line then default to the first line
## Tue Mar 22 15:09:02 CDT 2016 - dscudiero - Fix problem if using the first line as the default header
## Mon Mar 28 12:49:21 CDT 2016 - dscudiero - Fix some messaging
## Tue Mar 29 10:38:04 CDT 2016 - dscudiero - Minor cleanup
## Tue Mar 29 10:49:53 CDT 2016 - dscudiero - Update message when we find duplicate path records
## Tue Mar 29 11:48:23 CDT 2016 - dscudiero - Remove the early quit if verboseLevel is on
## Fri Apr  1 13:30:34 CDT 2016 - dscudiero - Swithch --useLocal to $useLocal
## Wed Apr  6 16:09:26 CDT 2016 - dscudiero - switch for
## Wed Apr 13 07:21:00 CDT 2016 - dscudiero - Fix spelling
## Wed Apr 27 16:04:50 CDT 2016 - dscudiero - Switch to use RunSql
## Wed Apr 27 16:32:57 CDT 2016 - dscudiero - Switch to use RunSql
## Mon Jun  6 12:44:11 CDT 2016 - dscudiero - Fix messaging if using the real workbook name
## Wed Jun  8 09:54:21 CDT 2016 - dscudiero - Add support for alternate column names in the spreadsheets
## Wed Jun 22 10:28:49 CDT 2016 - dscudiero - Added a check for duplicate field tokens in the worksheet header
## Wed Jul  6 09:30:48 CDT 2016 - dscudiero - Fix problem with worksheet column parsing
## Thu Jul 14 07:15:01 CDT 2016 - dscudiero - Fix problem when parsing a blank line
## Mon Jul 25 14:40:09 CDT 2016 - dscudiero - Tweaks for internal site
## Thu Aug  4 11:01:51 CDT 2016 - dscudiero - Added displayGoodbyeSummaryMessages=true
## Mon Aug 15 12:39:35 CDT 2016 - dscudiero - Adjust warning messages
## Thu Aug 18 08:07:11 CDT 2016 - dscudiero - Refactored the code that compares old user data with new user data
## Thu Aug 18 11:58:00 CDT 2016 - dscudiero - Only display role data different messages when the old data is not null
## Wed Sep 21 08:53:36 CDT 2016 - dscudiero - Switch Msg calls to Msg2
## Wed Sep 28 16:03:09 CDT 2016 - dscudiero - Added status messages to the processing loops
## Tue Oct 11 07:28:26 CDT 2016 - dscudiero - Fix message
## Tue Oct 11 07:56:05 CDT 2016 - dscudiero - Regress last change
## Mon Oct 17 16:17:26 CDT 2016 - dscudiero - Move the skipnull code into the script from the step
