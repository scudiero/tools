#!/bin/bash
# DO NOT AUTOVERSION
#==================================================================================================
version=3.9.9 # -- dscudiero -- Wed 10/04/2017 @ 16:24:16.40
#==================================================================================================
TrapSigs 'on'
myIncludes='DbLog Prompt SelectFile VerifyContinue InitializeInterpreterRuntime GetExcel2 WriteChangelogEntry'
myIncludes="$myIncludes GetOutputFile BackupCourseleafFile ParseCourseleafFile GetCourseleafPgm RunCourseLeafCgi"
myIncludes="$myIncludes MkTmpFile ProtectedCall PrintBanner"
Import "$standardInteractiveIncludes $myIncludes"

originalArgStr="$*"
scriptDescription="Load Courseleaf Data"

#==================================================================================================
## Load courseleaf data from a spreadsheet (xlsx) file
#==================================================================================================
#==================================================================================================
## Copyright ©2014 David Scudiero -- all rights reserved.
## 06-17-15 -- 	dgs - Initial coding
#==================================================================================================
# Standard call back functions
#==================================================================================================
	#==============================================================================================
	# parse script specific arguments
	#==============================================================================================
	function loadCourseleafData-ParseArgsStd2  {
		#myArgs+=("shortToken|longToken|type|scriptVariableName|<command to run>|help group|help textHelp")
		myArgs+=("w|workbookfile|option|workbookFile||script|The fully qualified spreadsheet file name")
		myArgs+=("skipnulls|skipnulls|switch|skipNulls||script|If a data field is null then do not write out that data to the page")
		myArgs+=("ignore|ignoremissingPages|switch|ignoreMissingPages||script|Ignore missing catalog pages")
		myArgs+=("noignore|noignoremissingPages|switch||ignoreMissingPages=false|script|Do not ignore missing catalog pages")
		myArgs+=("uin|uinmap|switch|uinMap||script|Map role data UIDs to UINs even if the uses UIN flag is not set on the client record")
		myArgs+=("nouin|nouinmap|switch||uinMap=false|script|Do not map role data UIDs to UINs")
		myArgs+=("users|users|switch|processuserdata||script|Load user data")
		myArgs+=("role|role|switch|processroledata||script|Load role data")
		myArgs+=("page|page|switch|processpagedata||script|Load catalog page data")
		return 0
	}
	#==============================================================================================
	# Goodbye call back
	#==============================================================================================
	function loadCourseleafData-Goodbye  {
		local exitCode="$1"
		[[ $tmpWorkbookFile == true ]] && rm -f $workbookFile
		[[ -f $stepFile ]] && rm -f $stepFile
		[[ -f $backupStepFile ]] && mv -f $backupStepFile $stepFile
		[[ -f "$tmpDataFile" ]] && rm -f "$tmpDataFile"

		if [[ -f $logFile && $outFile != '' ]]; then
			cat $logFile | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g" > $outFile
			echo; Info "The output can be found in '$outFile'"
		fi
		return 0
	}

	#==========================================F====================================================
	# TestMode overrides
	#==============================================================================================
	function loadCourseleafData-testMode  {
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

	function loadCourseleafData-Help {
		helpSet='client,env'
		[[ $1 == 'setVarsOnly' ]] && return 0

		[[ -z $* ]] && return 0
		echo -e "This script can be used to load data into a CourseLeaf site.  The data that can be loaded includes the followng:"
		echo -e "\t- Catalog page owner and workflow data"
		echo -e "\t- Role data"
		echo -e "\t- User data"
		echo -e "You can find the loadCourseleafData template Excel Workbook at:"
		echo -e "\t$TOOLSPATH/workbooks/CourseleafData.xltm"
		echo -e "\nThe output log is written to the $HOME/clientData/<client> directory, if the directory does exist one will be created."
		echo -e "The output log file name is of the form '<clientCode>-<env>-$myName.log'"
		echo -e "\nThe actions performed are:"
		bullet=1; echo -e "\t$bullet) Read data from the supplied Microsoft Excel workbook"
		(( bullet++ )); echo -e "\t$bullet) Read the courseleaf data from the target environment from it's source object"
		(( bullet++ )); echo -e "\t$bullet) Compare the source data to the target data and merge/replace as requested"
		(( bullet++ )); echo -e "\t$bullet) If changes found, then ask user to verify change and if yes then write data back to the target environment source object"
		echo -e "\nTarget site data files potentially modified:"
		echo -e "\t.../web/courseleaf/roles.tcf"
		echo -e "\t.../db/clusers.sqlite"
		echo -e "\tAll client pages in source if request includes updating catalog data"

		return 0
	}

#==================================================================================================
# local functions
#==================================================================================================
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
	# Get the users data from the db, loads a hash table, key is the userid and the value is the remaining 
	# seperated with a '|' data if useUINs is set then it is assumed that the clusers table contains a 
	# uin field
	#==================================================================================================
	function GetUsersDataFromDB {
		local dbFile=$siteDir/db/clusers.sqlite
		[[ ! -r $dbFile ]] && Terminate "Could not read the clusers database file:\n\t$dbFile"
		Msg3 "Reading the user data from the clusers database ..."

		local sqlLiteFields="userid,lname,fname,email"
		SetFileExpansion 'off'
		local sqlStmt="select * from sqlite_master where type=\"table\" and name=\"users\""
		SetFileExpansion
		RunSql2 "$siteDir/db/clusers.sqlite" $sqlStmt
		[[ ${#resultSet[@]} -le 0 ]] && Terminate "Could not retrieve clusers.users table definition data from '$contactsSqliteFile'"
		local tData="${resultSet[0]#*(}"; tData="${tData%)*}"
		[[ $(Contains "${tData%)*}" 'uin') == true ]] && sqlLiteFields="$sqlLiteFields,uin"
		sqlStmt="select $sqlLiteFields FROM users"
		RunSql2 "$dbFile" "$sqlStmt"
		if [[ ${#resultSet[@]} -ne 0 ]]; then
			for resultRec in "${resultSet[@]}"; do
				key=${resultRec%%|*}; key=${key%%.*}
				[[ $key == '' ]] && continue
				local value=${resultRec#*|}; 
				usersFromDb["$key"]="$value"
				if [[ $useUINs == true ]] ; then
					[[ ! ${uidUinHash["$key"]+abc} ]] && uidUinHash["$key"]="${value##*|}"
				fi
			done
		fi
		numUsersfromDb=${#usersFromDb[@]}
		Msg3 "^Retrieved $numUsersfromDb records from the 'clusers' database"
		if [[ $verboseLevel -ge 1 ]]; then Msg3 "usersFromDb:"; for i in "${!usersFromDb[@]}"; do printf "\t\t[$i] = >${usersFromDb[$i]}<\n"; done; fi
		return 0
	} #GetUsersDataFromDB

	#==================================================================================================
	# Get the roles data from the file
	#==================================================================================================
	function GetRolesDataFromFile {
		[[ $useUINs == true && $processedUserData != true ]] && Terminate "$FUNCNAME: Requesting UIN mapping but no userid sheet was provided"
		Msg3 "Reading the roles.tcf file ..."
		## Get the roles data from the roles.tcf file
			local file=$rolesFile line
			[[ ! -r $file ]] && Terminate "Could not read the roles file: '$file'"
			while read line; do
				if [[ ${line:0:5} == 'role:' ]]; then
					local key=$(cut -d '|' -f 1 <<< "$line" | cut -d ':' -f 2)
					[[ $key == '' ]] && continue
					local data=$(Trim $(cut -d '|' -f 2- <<< "$line"))
					dump -3 -n line key data
			      	rolesFromFile+=([$key]="$data")
			      	rolesOut+=([$key]="$data")
		      	fi
			done < $file
			numRolesFromFile=${#rolesFromFile[@]}
			Msg3 "^Retrieved $numRolesFromFile records"
			if [[ $verboseLevel -ge 1 ]]; then Msg3 "\trolesFromFile:"; for i in "${!rolesFromFile[@]}"; do printf "\t\t[$i] = >${rolesFromFile[$i]}<\n"; done; fi
		return 0
	} #GetRolesDataFromFile

	#==================================================================================================
	# Get the workflows data from the workflow.tcf file
	#==================================================================================================
	function GetWorkflowDataFromFile {
		[[ $useUINs == true && $processedUserData != true ]] && Terminate "$FUNCNAME: Requesting UIN mapping but no userid sheet was provided"
		Msg3 "Reading the workflow.tcf file ..."
		## Get the roles data from the roles.tcf file
			local file="$siteDir/web/$courseleafProgDir/workflows.tcf" line
			[[ ! -r $file ]] && Terminate "Could not read the '$file' file"
			while read line; do
				if [[ ${line:0:9} == 'workflow:' ]]; then
					local key=$(cut -d ':' -f 2 <<< "$line" | cut -d '|' -f 1)
					[[ $key == '' ]] && continue
					workflowsFromFile[$key]=true
		      	fi
			done < $file
			numWorkflowsFromFile=${#workflowsFromFile[@]}
			Msg3 "^Retrieved $numWorkflowsFromFile records"
			if [[ $verboseLevel -ge 1 ]]; then Msg3 "\tworkflowsFromFile:"; for i in "${!workflowsFromFile[@]}"; do printf "\t\t[$i] = >${workflowsFromFile[$i]}<\n"; done; fi
			echo
		return 0
	} #GetWorkflowDataFromFile

	#==================================================================================================
	# Parse the worksheet header record, returning the column nubers for each column requrested
	#==================================================================================================
	function ParseWorksheetHeader {
		local sheetName="$1"; shift || true
		local requiredFields="$1"; shift || true
		local optionalFields="$1"; shift || true
		local headerIndicator=${headerRowIndicator:-***}
		dump 2 -t sheetName requiredFields optionalFields headerRowIndicator headerIndicator
		[[ ${#resultSet[@]} -le 0 ]] && Terminate "($FUNCNAME) No date in the workbook worksheet '$sheetName'"

		## Scan returned data looking for the 'headerRowIndicator'
			local result foundHeader=false i headerRow
			for ((i=0; i<${#resultSet[@]}; i++)); do
				result="${resultSet[$i]}"
				[[ ${result:0:${#headerIndicator}} == "$headerIndicator" ]] && { foundHeader=true; break; }
			done
			if [[ $foundHeader == true ]]; then
				(( i++ ))
				headerRow="${resultSet[$i]}"
				(( i++ ))
				resultSet=("${resultSet[@]:$i}")
			else
				Info 0 1 "Could not locate the header row indicator in the '$sheetName' worksheet, using the first row as the header data"
				headerRow="${resultSet[0]}"
				resultSet=("${resultSet[@]:1}")
			fi
			headerRow="$(Lower "$headerRow")"

		# Parse the header record, getting the column numbers of the fields
			IFS='|' read -r -a sheetCols <<< "$headerRow"
			local field colVar fieldCntr subField 
			for field in $requiredFields $optionalFields; do
				colVar="${field%%|*}Col"
				unset fieldCntr $colVar
				for sheetCol in "${sheetCols[@]}"; do
					(( fieldCntr += 1 ))
					for subField in $(tr '|' ' ' <<< $field); do
						if [[ $(Contains "$sheetCol" "$subField") == true ]]; then
							[[ -n ${!colVar} ]] && Terminate "Found duplicate '$field' fields in the worksheet header row:\n\t'$headerRow'"
							eval "$colVar=$fieldCntr"
						fi
					done
				done
				dump -2 -t field -t $colVar
			done

			## Make sure we found all the required fields
			for field in $requiredFields; do
				colVar="${field%%|*}Col"
				[[ -z ${!colVar} ]] && Terminate "Could not locate required column, '$colVar', in the '$sheetName' worksheet"
			done

		return 0
	} # ParseWorksheetHeader

	#==================================================================================================
	# Map UIDs to UINs in role members
	#==================================================================================================
	# function EditRoleMembers {
	# 	local memberData="$*"
	# 	[[ $useUINs != true ]] && echo "$memberData" && return

	# 	local memberDataNew member members
	# 	IFSsave=$IFS; IFS=',' read -a members <<< "$memberData"; IFS=$IFSsave
	# 	for member in "${members[@]}"; do
	# 		[[ ${usersFromDb["$member"]+abc} ]] && echo -e "\tusersFromDb" >> $stdout && memberDataNew="$memberDataNew,$member" && continue
	# 		[[ ${uidUinHash["$member"]+abc} ]] && echo -e "\tuidUinHash" >> $stdout && memberDataNew="$memberDataNew,${uidUinHash["$member"]}" && continue
	# 		# memberDataNew="$memberDataNew,$member"
	# 	done
	# 	echo "${memberDataNew:1}"
	# } #EditRoleMembers


	#==================================================================================================
	# Map UIDs to UINs in a comma seperated string
	#==================================================================================================
	function SubstituteUINs {
		local data="$*" editedString tmpStr tokens token
		[[ $useUINs != true ]] && echo "$data" && return

		unset tmpStr
		local IFSsave=$IFS; IFS=',' read -a tokens <<< "$data"; IFS=$IFSsave
		for token in "${tokens[@]}"; do
			[[ ${uidUinHash["$token"]+abc} ]] && tmpStr="$tmpStr,${uidUinHash["$token"]}" || tmpStr="$tmpStr,$token"
		done
		[[ ${tmpStr:0:1} == ',' ]] && echo "${tmpStr:1}" || echo "${tmpStr}"
		return 0
	} #SubstituteUINs

	#==================================================================================================
	# Process USER records
	#==================================================================================================
	function ProcessUserData {
		local workbookSheet="$1"
		local uin

		## See if this client has special case handling for usernames
			sqlStmt="select useridCase from $clientInfoTable where name=\"$client\""
			RunSql2 $sqlStmt
			local useridCase=$(Upper ${resultSet[0]:0:1}) || useridCase='M'

		Msg3 "Parsing the 'user' data from the '$workbookSheet' worksheet ..."
		## Get the user data from the spreadsheet
			GetExcel2 -wb "$workbookFile" -ws "$workbookSheet"
			## Read the header record, look for the specific columns to determine how to parse subsequent records
			ParseWorksheetHeader "$workbookSheet" 'userid first last email' 'uin'
			[[ $verboseLevel -ge 1 ]] && { for field in userid first last email uin; do dump ${field}Col; done; }
			[[ $useUINs == true && -z $uinCol ]] && Terminate "Use UINs was set and no 'UIN' column was found in the user data"

			## Parse the data rows into hash table
			for ((ii=0; ii<${#resultSet[@]}; ii++)); do
				local result="${resultSet[$ii]}"
				[[ -z ${result//|} ]] && continue
				local key=$(cut -d '|' -f $useridCol <<< "$result") ## userid
				[[ -z $key ]] && continue
				key="${key%%.*}"; key="${key// }"
				[[ $useridCase == 'U' ]] && key=${key^^[a-z]}
				[[ $useridCase == 'L' ]] && key=${key,,[a-z]}
				## Parse out the data
				local first="$(cut -d '|' -f $firstCol <<< "$result")"; first="${first/# }"; first="${first/% }"
				local last="$(cut -d '|' -f $lastCol <<< "$result")"; last="${last/# }"; last="${last/% }"
				local email="$(cut -d '|' -f $emailCol <<< "$result")"; email="${email/# }"; email="${email/% }"
				[[ -n $uinCol ]] && { uin="$(cut -d '|' -f $uinCol <<< "$result")"; uin="${uin%%.*}"; uin="${uin/# }"; uin="${uin/% }"; }

				value="$last|$first|$email"
				[[ -n $uinCol ]] && value="${value}|$uin"
				dump -2 -n result -t key value
				if [[ ${usersFromSpreadsheet["$key"]+abc} ]]; then
					if [[ -n $value && $value != '|' && ${usersFromSpreadsheet["$key"]} != $value ]]; then
						Terminate "The '$workbookSheet' sheet contains duplicate records for userid '$key'\
						\n^current value: '$value'\n^previous value: '${usersFromSpreadsheet["$key"]}'"
					fi
				else
					usersFromSpreadsheet["$key"]="$value"
				fi
			done
			numUsersfromSpreadsheet=${#usersFromSpreadsheet[@]}
			Msg3 "^Retrieved $numUsersfromSpreadsheet records from the '$workbookSheet' sheet"
			[[ $verboseLevel -ge 1 ]] && { Msg3 "^usersFromSpreadsheet:" ; for i in "${!usersFromSpreadsheet[@]}"; do Msg3 "^^[$i] = >${usersFromSpreadsheet[$i]}<"; done; }

		## Get the user data from the clusers database
			GetUsersDataFromDB

		## Merge the spreadsheet data and the file data
			numNewUsers=0
			numModifiedUsers=0
			[[ $informationOnlyMode != true ]] && verb='Merging' || verb='Checking'
			Msg3 "$verb User data..."

			local dbFile=$siteDir/db/clusers.sqlite
			BackupCourseleafFile $dbFile
			local procesingCntr=0
			local sTime=$(date "+%s")
			for key in "${!usersFromSpreadsheet[@]}"; do
				key="${key%%.*}"
				[[ $verboseLevel -ge 1 ]] && echo -e "\${usersFromSpreadsheet["$key"]} = '${usersFromSpreadsheet["$key"]}'"
				unset lname fname email
				local lname=$(Trim "$(cut -d '|' -f1 <<< ${usersFromSpreadsheet["$key"]})")
				local fname=$(Trim "$(cut -d '|' -f2 <<< ${usersFromSpreadsheet["$key"]})")
				local email=$(Trim "$(cut -d '|' -f3 <<< ${usersFromSpreadsheet["$key"]})")
				local uin=$(Trim "$(cut -d '|' -f4 <<< ${usersFromSpreadsheet["$key"]})")
				dump -1 -t2 lname fname email uin

				if [[ ${usersFromDb["$key"]+abc} ]]; then
					local oldData; unset oldData;
					oldData="${usersFromDb["$key"]}"
					[[ ${oldData:(-1)} == '|' ]] && oldData=${oldData:0:${#oldData}-1}
					local newData; unset newData;
					newData="${usersFromDb["$key"]}"
					[[ ${newData:(-1)} == '|' ]] && newData=${newData:0:${#newData}-1}
					if [[ $oldData != $newData ]]; then
						WarningMsg 0 1 "Found User '$key' in the clusers database file but data is different, using new data"
						Msg3 "^^New Data: $newData"
						Msg3 "^^Old Data: $oldData"
						sqlStmt="UPDATE users set lname=\"$lname\", fname=\"$fname\", email=\"$email\" where userid=\"$key\""
						[[ $informationOnlyMode == false ]] && $DOIT RunSql2 "$dbFile" "$sqlStmt"
						(( numModifiedUsers += 1 ))
					fi
				else
					Verbose 1 "Adding new user: $key"
					sqlStmt="INSERT into users values(NULL,\"$key\",\"$lname\",\"$fname\",\"$email\")"
					[[ $informationOnlyMode == false ]] && $DOIT RunSql2 "$dbFile" "$sqlStmt"
					usersFromDb["$key"]="${usersFromSpreadsheet["$key"]}"
					Verbose 1 2 "User added: $key"
					(( numNewUsers += 1 ))
				fi
				# If useUINs is active then build userid to uin map from the email information
				if [[ $useUINs == true && -n $uin ]]; then
					uid="${email%%@*}"
					uidUinHash["$uid"]="$uin"
				fi
				if [[ $procesingCntr -ne 0 && $(($procesingCntr % $notifyThreshold)) -eq 0 ]]; then
					local elapTime=$(( $(date "+%s") - $sTime )); [[ $elapTime -eq 0 ]] && elapTime=1
					sTime=$(date "+%s")
					Msg3 "^Processed $procesingCntr out of $numUsersfromSpreadsheet (${elapTime}s)..."
				fi
				let procesingCntr=$procesingCntr+1
			done
			if [[ $verboseLevel -ge 1 ]]; then 
				Msg3 "\tMerged User list (usersFromDb):"; for i in "${!usersFromDb[@]}"; do printf "\t\t[$i] = >${usersFromDb[$i]}<\n"; done; 
				Msg3 "\tUserid/UIN map (uidUinHash):"; for i in "${!uidUinHash[@]}"; do printf "\t\t[$i] = >${uidUinHash[$i]}<\n"; done; 
			fi

		## Rebuild the appache-group file
			[[ $informationOnlyMode == false ]] && RunCourseLeafCgi "$siteDir" "-r /apache-group.html"
			echo

		return 0
	} #ProcessUserData

	#==================================================================================================
	# Process ROLE records
	#==================================================================================================
	function ProcessRoleData {
		local workbookSheet="$1"
		Msg3 "Parsing the 'roles' data from the '$workbookSheet' worksheet ..."
		## Get the role data from the spreadsheet
			GetExcel2 -wb "$workbookFile" -ws "$workbookSheet"
			## Read the header record, look for the specific columns to determin how to parse subsequent records
			ParseWorksheetHeader "$workbookSheet" 'name members|userlist email'
			[[ $verboseLevel -ge 1 ]] && { for field in name members email; do dump ${field}Col; done; }
			## Read/Parse the data rows into hash table
			for ((ii=0; ii<${#resultSet[@]}; ii++)); do
				result="${resultSet[$ii]}"
				[[ -z $(tr -d '|' <<< "$result" ) ]] && continue
				key=$(cut -d '|' -f $nameCol <<< $result)
				[[ -z $key ]] && continue
				value=$(cut -d '|' -f $membersCol <<< "$result")'|'$(cut -d '|' -f $emailCol <<< "$result")
				value=$(tr -d ' ' <<< $value)
				dump -2 -n result -t key value
				[[ $(IsNumeric ${value:0:1}) == true ]] && value=$(cut -d'.' -f1 <<< $value)
				if [[ ${rolesFromSpreadsheet["$key"]+abc} ]]; then
					if [[ -n $value && $value != '|' && ${rolesFromSpreadsheet["$key"]} != $value ]]; then
						Terminate "The '$workbookSheet' sheet contains duplicate records for role '$key'\
						\n^current value: '$value'\n^previous value: '${rolesFromSpreadsheet["$key"]}'"
					fi
				else
					rolesFromSpreadsheet["$key"]="$value"
				fi
			done
			numRolesfromSpreadsheet=${#rolesFromSpreadsheet[@]}
			Msg3 "^Retrieved $numRolesfromSpreadsheet records from the '$workbookSheet' sheet"
			if [[ $verboseLevel -ge 1 ]]; then Msg3 "\trolesfromSpreadsheet:"; for i in "${!rolesFromSpreadsheet[@]}"; do printf "\t\t[$i] = >${rolesFromSpreadsheet[$i]}<\n"; done; fi

		## Merge the spreadsheet data and the file data
			GetRolesDataFromFile #Also sets rolesOut
			if [[ $verboseLevel -ge 1 ]]; then Msg3 "\trolesOut:"; for i in "${!rolesOut[@]}"; do printf "\t\t[$i] = >${rolesOut[$i]}<\n"; done; fi
			numNewRoles=0
			numModifiedRoles=0
			numRoleMembersMappedToUIN=0

			[[ $informationOnlyMode != true ]] && verb='Updating' || verb='Checking'
			Msg3 "$verb Role data..."
			local procesingCntr=0
			sTime=$(date "+%s")
			for key in "${!rolesFromSpreadsheet[@]}"; do
				## Edit role data if useUINs is on
				if [[ $useUINs == true ]]; then
					tmpStr="${rolesFromSpreadsheet["$key"]}"
					memberData=${tmpStr%%|*}; key=${key%%.*}; tmpStr=${tmpStr#*|};
					emailData=${tmpStr%%|*}; key=${key%%.*}; tmpStr=${tmpStr#*|};
					unset tmpStr
					tmpStr="$(SubstituteUINs $memberData)"
					if [[ $tmpStr != $memberData ]]; then
						rolesFromSpreadsheet["$key"]="$tmpStr|$emailData"
						#Note  "Role: '$key' -- UIDs mapped to UINs"
						(( numRoleMembersMappedToUIN +=1 ))
					fi
				fi

				## Check spreadsheet data vs file data
					if [[ ${rolesOut["$key"]+abc} ]]; then
						if [[ ${rolesFromSpreadsheet["$key"]} != ${rolesOut["$key"]} ]]; then
							if [[ $oldData != '' ]]; then
								WarningMsg 0 1 "Found Role '$key' in the roles file but data is different, using new data"
								Msg3 "^^New Data: ${rolesFromSpreadsheet["$key"]}"
								unset oldData;  oldData="${usersFromDb["$key"]}"
								[[ ${oldData:(-1)} == '|' ]] && oldData=${oldData:0:${#oldData}-1}
								Msg3 "^^Old Data: $oldData"
							fi
							Info 2 1 "Found Role '$key' in the roles file, old data is null, using new data"
							rolesOut["$key"]="${rolesFromSpreadsheet["$key"]}"
							(( numModifiedRoles += 1 ))
						fi
					else
						Verbose 2 2 "New role added: $key"
						rolesOut["$key"]="${rolesFromSpreadsheet["$key"]}"
						(( numNewRoles += 1 ))
					fi
				if [[ $procesingCntr -ne 0 && $(($procesingCntr % $notifyThreshold)) -eq 0 ]]; then
					elapTime=$(( $(date "+%s") - $sTime )); [[ $elapTime -eq 0 ]] && elapTime=1
					sTime=$(date "+%s")
					Msg3 "^Processed $procesingCntr out of $numRolesfromSpreadsheet (${elapTime}s)..."
				fi
				let procesingCntr=$procesingCntr+1
			done
			#for i in "${!rolesOut[@]}"; do echo -e "\tkey: '$i', value: '${rolesOut[$i]}'"; done;


##TODO: Replace writing of the roles data with a courseleaf step somehow
		## Write out the role data to the role file
			if [[ $informationOnlyMode == false ]]; then
				if [[ $numModifiedRoles -gt 0 || $numNewRoles -gt 0 ]]; then
					Msg3 "Writing out new roles.tcf file..."
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
					Msg3 "^$editFile written to disk"
				fi
			fi

		## Check the members against the user data
			if [[ $processUserData == true ]]; then
				numRoleMembersNotProvisoned=0
				Msg3 "Checking Role members..."
				for key in "${!rolesOut[@]}"; do
					members=$(cut -d '|' -f1 <<< "${rolesOut["$key"]}")
					for member in ${members//,/ }; do
						if [[ ! ${usersFromDb["$member"]+abc} ]]; then
							WarningMsg 0 1 "Role member '$member' use in role '$key' is not provisioned"
							(( numRoleMembersNotProvisoned += 1 ))
						fi
					done
					#IFS=$IFSsave
				done
			fi
			echo
		return 0
	} #ProcessRoleData

	#==================================================================================================
	# Process WORKFLOW records
	#==================================================================================================
	function ProcessCatalogPageData {
		local workbookSheet="$1"
		[[ $useUINs == true && $processedUserData != true ]] && Terminate "$FUNCNAME: Requesting UIN mapping but no userid sheet was provided"
		## Get the user data from the spreadsheet
			Msg3 "Parsing the 'catalog page' data from the '$workbookSheet' worksheet ..."
			GetExcel2 -wb "$workbookFile" -ws "$workbookSheet"
			## Read the header record, look for the specific columns to determin how to parse subsequent records
			ParseWorksheetHeader "$workbookSheet" 'path title owner workflow'
			[[ $verboseLevel -ge 1 ]] && { for field in path title owner workflow; do dump ${field}Col; done; }

			## Read/Parse the data rows into hash table
			numPagesNotFound=0
			for ((ii=0; ii<${#resultSet[@]}; ii++)); do
				result="${resultSet[$ii]}"
				key=$(cut -d '|' -f $pathCol <<< "$result")
				[[ ${key:0:1} != '/' ]] && Warning "Invalid page path data found in data row $ii ($key), skipping data" && continue
				[[ -z $key ]] && WarningMsg 0 1 "Work Sheet record:\n^^$result\n\tDoes not contain any path/url data, skipping" && continue
				if [[ $key != '/' && ! -d $(dirname $siteDir/web/$key) ]]; then
					[[ $ignoreMissingPages != true ]] && WarningMsg 0 1 "Page: '$key' Not found"
					((numPagesNotFound += 1))
					continue
				fi
				value=$(cut -d '|' -f $titleCol <<< "$result")'|'$(cut -d '|' -f $ownerCol <<< "$result")'|'$(cut -d '|' -f $workflowCol <<< "$result")
				if [[ ${workflowDataFromSpreadsheet["$key"]} != '' ]]; then
					if [[ -n $value && $value != '|' && ${workflowDataFromSpreadsheet["$key"]} != $value ]]; then
						Terminate "^The '$workbookSheet' sheet contains duplicate records with the same 'path' and differeing data\
						\n^^Path/url: $key\n^^Previous Data: ${workflowDataFromSpreadsheet["$key"]}\n^^Current Data: $value"
					fi
				else
					workflowDataFromSpreadsheet["$key"]="$value"
				fi
			done

			numWorkflowDataFromSpreadsheet=${#workflowDataFromSpreadsheet[@]}
			Msg3 "^Retrieved $numWorkflowDataFromSpreadsheet records from the '$workbookSheet' sheet"
			if [[ $verboseLevel -ge 1 ]]; then Msg3 "\tworkflowDataFromSpreadsheet:"; for i in "${!workflowDataFromSpreadsheet[@]}"; do printf "\t\t[$i] = >${workflowDataFromSpreadsheet[$i]}<\n"; done; fi

			## Get the courseleaf pgmname and dir
				cd $siteDir
				courseLeafPgm=$(GetCourseleafPgm | cut -d' ' -f1)
				courseLeafDir=$(GetCourseleafPgm | cut -d' ' -f2)
				if [[ $courseLeafPgm == '' || $courseLeafDir == '' ]]; then Terminate "^Could not find courseleaf executable"; fi
				dump -3 -q courseLeafPgm courseLeafDir
			## Install the stepfile to update the page data
				stepFile=$courseLeafDir/localsteps/$step.html
				BackupCourseleafFile $stepFile

			## Find the step file to run
				if [[ $informationOnlyMode != true ]]; then
					srcStepFile="$(FindExecutable -step "$step")"
					[[ -z $srcStepFile ]] && Terminate "Could find the step file ('$step')"
					Info 0 1 "Using step file: $srcStepFile"
					## Copy step file to localsteps
					cp -fP $srcStepFile $stepFile
					chmod ug+w $stepFile
				fi
			## Update the page data in courseleaf
			numPagesUpdated=0
			numMembersMappedToUIN=0
			[[ $informationOnlyMode != true ]] && verb='Updating' || verb='Checking'
			Msg3 "^$verb catalog page data (this takes a while)..."
			local procesingCntr=0
			local sTime=$(date "+%s")
			for key in "${!workflowDataFromSpreadsheet[@]}"; do
				tmpData="${workflowDataFromSpreadsheet[$key]}"
				pageTitle="$(cut -d'|' -f1 <<< "$tmpData")"
				pageOwner="$(CleanString "$(cut -d'|' -f2 <<< "$tmpData")")"
				pageWorkflow="$(cut -d'|' -f3 <<< "$tmpData")"

				## Check to see if the pageWorkflow data is a real defined workflow
					# foundNamedWorkflow=false
					# if [[ $pageWorkflow != '' && ${workflowsFromFile["$pageWorkflow"]} == true ]]; then
					# 	foundNamedWorkflow=true
					# else
					# 	pageWorkflow=$(CleanString $pageWorkflow)
					# fi

				## Edit role data if useUINs is on
					if [[ $useUINs == true ]]; then
						if [[ $foundNamedWorkflow != true ]]; then
						pageWorkflowNew="$(SubstituteUINs "$pageWorkflow")"
							if [[ $pageWorkflowNew != $pageWorkflow ]]; then
								pageWorkflow="$pageWorkflowNew"
								Note 1 1 "Page: '$key' -- Workflow UIDs mapped to UINs"
								((numMembersMappedToUIN +=1))
							fi
						fi
						pageOwnerNew="$(SubstituteUINs "$pageOwner")"
						if [[ $pageOwnerNew != $pageOwner ]]; then
							pageOwner="$pageOwnerNew"
							Note 1 1 "Page: '$key' -- Owner UIDs mapped to UINs"
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
						[[ $(Contains "$member" ' fyi') == true ]] && member="${member%% fyi*}"
						foundMember=false
						[[ ${usersFromDb["$member"]+abc} ]] && foundMember=true && continue
						[[ ${rolesOut["$member"]+abc} ]] && foundMember=true && continue
						[[ ${workflowsFromFile["$member"]+abc} ]] && foundMember=true && continue
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
							$DOIT ProtectedCall "RunCourseLeafCgi "$siteDir" "$step $key""
							((numPagesUpdated +=1))
						fi
					fi
					if [[ $procesingCntr -ne 0 && $(($procesingCntr % $notifyThreshold)) -eq 0 ]]; then
						elapTime=$(( $(date "+%s") - $sTime )); [[ $elapTime -eq 0 ]] && elapTime=1
						sTime=$(date "+%s")
						Msg3 "^Processed $procesingCntr out of $numWorkflowDataFromSpreadsheet (${elapTime}s)..."
					fi
					let procesingCntr=$procesingCntr+1
			done
			Msg3 "^$numWorkflowDataFromSpreadsheet out of $numWorkflowDataFromSpreadsheet processed"
	return 0
} #ProcessCatalogPageData

#==================================================================================================
# Declare local variables and constants
#==================================================================================================
step='setPageData'
falseVars='processUserData processRoleData processPageData processedUserData processedRoleData processedWorkflowData noUinMap uinMap useUINs informationOnlyMode'
for var in $falseVars; do eval $var=false; done
unset numUsersfromDb numUsersfromSpreadsheet numRolesFromFile numRolesfromSpreadsheet numWorkflowDataFromSpreadsheet numPagesUpdated
unset numRoleMembersNotProvisoned numRoleMembersMappedToUIN numModifiedRoles numNewRoles

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
tmpFile=$(MkTmpFile)

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
Hello
echo "Getting defaults..."
GetDefaultsData $myName
echo "Parsing arguments..."
ParseArgsStd2 $originalArgStr
[[ $allItems == true ]] && processUserData=true && processRoleData=true && processPageData=true
[[ $product != '' ]] && product=$(Lower $product)

[[ $hostName == 'build7' ]] && notifyThreshold=50 || notifyThreshold=100
displayGoodbyeSummaryMessages=true
echo "Calling Init"
Init 'getClient getEnv getDirs checkEnvs checkProdEnv addPvt'
dump -1 processUserData processRoleData processPageData informationOnlyMode ignoreMissingPages
echo "Back from Init"

## Find out if this client uses UINs
	if [[ $uinMap == true ]]; then
		useUINs=true
	else
		sqlStmt="select usesUINs from $clientInfoTable where name=\"$client\""
		RunSql2 $sqlStmt
		if [[ ${#resultSet[@]} -ne 0 ]]; then
			result="${resultSet[0]}"
			[[ $result == 'Y' ]] && useUINs=true && echo
		fi
	fi

## Get workflow file
	tmpWorkbookFile=false
	unset workbookFileIn workbookSearchDir
	if [[ $workbookFile == '' ]]; then
		[[ $verify != true ]] && Terminate "^No value specified for workbook file and verify is off"
		## Search for XLSx files in clientData and implimentation folders
		if [[ -d "$localClientWorkFolder/$client" ]]; then
			workbookSearchDir="$localClientWorkFolder/$client"
		else
			## Find out if user wants to load cat data or cim data
			Prompt product 'Are you loading CAT or CIM data' 'cat cim' 'cat';
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
	else
		[[ ${workbookFile:0:1} != '/' ]] && workbookFile=$localClientWorkFolder/$client/$workbookFile
		lenStr=${#workbookFile}
		[[ ${workbookFile:lenStr-5:4} != '.xls' ]] && workbookFile=$workbookFile.xlsx
	fi
	[[ -f "$tmpDataFile" ]] && rm -f "$tmpDataFile"

	[[ $workbookFile == "" ]] && echo
	Prompt workbookFile 'Please specify the full path to the workbook file' '*file*'

	## If the workbook file name contains blanks then copy to temp and use that one.
		tmpWorkbookFile=false
		if [[ $(Contains "$workbookFile" ' ') == true ]]; then
			cp -fp "$workbookFile" /tmp/$userName.$myName.workbookFile
			tmpWorkbookFile=true
			workbookFileIn="$workbookFile"
			workbookFile=/tmp/$userName.$myName.workbookFile
		fi
		[[ ! -r $workbookFile ]] && Terminate "Could not locate file: '$workbookFile'"

	echo

## Get the list of sheets in the workbook
	Msg3 "^Parsing workbook..."
	GetExcel2 -wb "$workbookFile" -ws 'GetSheets'
	IFS='|' read -ra sheets <<< "${resultSet[0]}"
	unset usersSheet rolesSheet pagesSheet
	for sheet in "${sheets[@]}"; do
		[[ $(Contains "$(Lower $sheet)" 'user') == true ]] && usersSheet="$sheet"
		[[ $(Contains "$(Lower $sheet)" 'role') == true ]] && rolesSheet="$sheet"
		[[ $(Contains "$(Lower $sheet)" 'workflow') == true ]] && pagesSheet="$sheet"
	done

[[ $processUserData == true || $processRoleData == true || $processPageData == true ]] && dataArgSpecified=true || dataArgSpecified=false
## What data should we load
	if [[ $verify == true && $processUserData != true && -n $usersSheet ]]; then
		unset ans; Prompt ans "Found a 'user' data worksheet ($usersSheet), do you wish to process that data" 'Yes No All'; ans=$(Lower ${ans:0:1})
		[[ $ans == 'y' ]] && processUserData=true
		[[ $ans == 'a' ]] && processUserData=true && processRoleData=true && processPageData=true
	else
		[[ $dataArgSpecified == false && -n $usersSheet ]] && processUserData=true
	fi

	if [[ $verify == true && $processRoleData != true && -n $rolesSheet ]]; then
		unset ans; Prompt ans "Found a 'roles' data worksheet ($rolesSheet), do you wish to process that data" 'Yes No All'; ans=$(Lower ${ans:0:1})
		[[ $ans == 'y' ]] && processRoleData=true
		[[ $ans == 'a' ]] && processUserData=true && processRoleData=true && processPageData=true
	else
		[[ $dataArgSpecified == false && -n $rolesSheet ]] && processRoleData=true
	fi

	if [[ $verify == true && $processPageData != true && -n $pagesSheet ]]; then
		unset ans; Prompt ans "Found a 'catalog page data' worksheet ($rolesSheet), do you wish to process that data" 'Yes No All'; ans=$(Lower ${ans:0:1})
		[[ $ans == 'y' ]] && processPageData=true
		[[ $ans == 'a' ]] && processUserData=true && processRoleData=true && processPageData=true
	else
		[[ $dataArgSpecified == false && -n $pagesSheet ]] && processPageData=true
	fi

	# ## If we are processing page data and role data see if the user page has uin mapping information
	# if [[ $verify == true && $processPageData == true ]] && [[ $processPageData == true || $processRoleData == true ]]; then
	# 	GetExcel2 -wb "$workbookFile" -ws 'GetSheets'
	# 	IFS='|' read -ra sheets <<< "${resultSet[0]}"
	# fi


## Do we have anything to do
	[[ $processUserData != true && $processRoleData != true && $processPageData != true ]] && Terminate "No load actions are avaiable given the data provided"

## Additional parms for page data
skipNulls=true
ignoreMissingPages=true

	if [[ $processPageData == true ]]; then
		if [[ $skipNulls == '' ]]; then
			if [[ $verify == true ]]; then
				unset ans; Prompt ans 'Do you wish to clear page values if the input cell data is empty' 'Yes No' 'Yes'; ans=$(Lower ${ans:0:1})
				[[ $ans == 'y' ]] && skipNulls=false || skipNulls=true
			fi
		fi
		if [[ $ignoreMissingPages == '' ]]; then
			if [[ $verify == true ]]; then
				unset ans; Prompt ans 'Do you wish to ignore nonexistent pages' 'No Yes' 'No'; ans=$(Lower ${ans:0:1})
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
	[[ $processUserData == false && $processRoleData == false && $processPageData == false ]] && echo && Terminate "No actions requested, please review help text"

## If this is next or curr then get a task number
	if [[ $env == 'next' || $env == 'curr' ]]; then
		Init 'getJalot'
	fi

	verifyArgs+=("Client:$client")
	verifyArgs+=("Env:$(TitleCase $env) ($siteDir)")
	[[ $tmpWorkbookFile == true ]] && verifyArgs+=("Input File:'$workbookFileIn' as '$workbookFile'") || verifyArgs+=("Input File:'$workbookFile'")
	#verifyArgs+=("Input workbook:'$workbookFileIn'")	
	[[ $processUserData == true ]] && verifyArgs+=("Process user sheet:$usersSheet")
	[[ $processRoleData == true ]] && verifyArgs+=("Process role sheet:$rolesSheet")
	[[ $processPageData == true ]] && verifyArgs+=("Process page sheet:$pagesSheet")
	verifyArgs+=("Skip null values:$skipNulls")
	verifyArgs+=("Ignore missing pages:$ignoreMissingPages")
	verifyArgs+=("Map UIDs to UINs:$useUINs")
	[[ -n $jalot ]] && verifyArgs+=("Jalot:$comment")

	VerifyContinue "You are asking to update CourseLeaf data"

	dump -1 client env siteDir processUserData processRoleData processPageData skipNulls useUINs
	myData="Client: '$client', Env: '$env', product: '$product', skipNulls: '$skipNulls', ignoreMissingPages: '$ignoreMissingPages', File: '$workbookFile' "
	[[ $logInDb != false && $myLogRecordIdx != "" ]] && dbLog 'data' $myLogRecordIdx "$myData"

#==================================================================================================
# Main
#==================================================================================================
## Process spreadsheet
	[[ $client == 'internal' ]] && courseleafProgDir='pagewiz' || courseleafProgDir='courseleaf'
	echo
	rolesFile=$siteDir/web/$courseleafProgDir/roles.tcf

	dump -1 processUserData processRoleData processedPageData sheets
	## Get process the sheets as directed
		if [[ $processUserData == true ]]; then
			[[ -z $usersSheet ]] && Terminate "Could not locate a 'Users' worksheet in the workbook."
			ProcessUserData "$usersSheet"
			processedUserData=true
		fi

		if [[ $processRoleData == true ]]; then
			[[ -z $rolesSheet ]] && Terminate "Could not locate a 'Roles' worksheet in the workbook."
			[[ $processUserData != true && -z numUsersfromDb ]] && GetUsersDataFromDB
			ProcessRoleData "$rolesSheet"
			processedRoleData=true
		fi

		if [[ $processPageData == true ]]; then
			[[ -z $pagesSheet ]] && Terminate "Could not locate a 'Page data' worksheet in the workbook."
			[[ $processUserData != true  && -z numUsersfromDb ]] && GetUsersDataFromDB
			[[ $processRoleData != true ]] && GetRolesDataFromFile && rolesOut=${rolesFromFile[@]}
			GetWorkflowDataFromFile
			ProcessCatalogPageData "$pagesSheet"
			processedPageData=true
		fi

## Processing summary
	unset changeLogLines
	echo
	PrintBanner "Processing Summary"
	[[ $informationOnlyMode == true ]] && echo "" && Msg3 ">>> The Information Only flag was set, no data has been updated <<<" && echo

	if [[ $processedUserData == true ]]; then
		Msg3 "User data:"
		Msg3 "^Retrieved $numUsersfromDb records from the clusers database"
		Msg3 "^Retrieved $numUsersfromSpreadsheet records from $workbookFileIn"
		string="Added $numNewUsers new users"
		[[ $informationOnlyMode == true ]] && string="$string $(ColorK "(Information Only flag was set)")"
		Msg3 "^$string"
		[[ $numNewUsers -gt 0 ]] && changeLogLines+=("$string")
		string="Modified $numModifiedUsers existing users"
		[[ $informationOnlyMode == true ]] && string="$string $(ColorK "(Information Only flag was set)")"
		Msg3 "^$string"
		[[ $numModifiedUsers -gt 0 ]] && changeLogLines+=("$string")
	fi

	[[ $processedUserData == true ]] && echo
	if [[ $processedRoleData == true ]]; then
		Msg3 "Role data:"
		Msg3 "^Retrieved $numRolesFromFile records from the roles.tcf file"
		Msg3 "^Retrieved $numRolesfromSpreadsheet records from $workbookFileIn"

		string="Added $numNewRoles new roles"
		[[ $informationOnlyMode != true ]] && string="Added $numNewRoles new roles" && string="Would add $numNewRoles new roles"
		Msg3 "^$string"
		[[ $numNewRoles -gt 0 ]] && changeLogLines+=("$string")

		[[ $informationOnlyMode != true ]] && string="Modified $numModifiedRoles existing roles" || string="Would modify $numModifiedRoles existing roles"
		Msg3 "^$string"
		[[ $numModifiedRoles -gt 0 ]] && changeLogLines+=("$string")

		string="Mapped $numRoleMembersMappedToUIN role members from UID to UIN"
		[[ $numRoleMembersMappedToUIN -gt 0 ]] && Msg3 "^$string" && changeLogLines+=("$string")

		string="Found $numRoleMembersNotProvisoned role members not in user provisioning"
		[[ $numRoleMembersNotProvisoned -gt 0 ]] && Msg3 "^$string" && changeLogLines+=("$string")
	fi

	[[ $processedUserData == true || $processedRoleData == true ]] && echo
	if [[ $processedPageData == true ]]; then
		Msg3 "Page data:"
		Msg3 "^Retrieved $numWorkflowDataFromSpreadsheet records from $workbookFileIn"

		[[ $informationOnlyMode != true ]] && string="Updated $numPagesUpdated pages" || string="Would update $numPagesUpdated pages"
		Msg3 "^$string"
		[[ $numPagesUpdated -gt 0 ]] && changeLogLines+=("$string")

		string="Mapped $numMembersMappedToUIN role members from UID to UIN"
		[[ $numMembersMappedToUIN -gt 0 ]] && Msg3 "^$string" && changeLogLines+=("$string")

		string="$numPagesNotFound pages not found"
		[[ $numPagesNotFound -gt 0 ]] && Msg3 "^$string" && changeLogLines+=("$string")

		string="Pages had errors in their owner/workflow data, see below for detailed information"
		[[ ${#membersErrors[@]} -gt 0 ]] && Msg3 "^$string" && changeLogLines+=("$string")

		## Member lookup errors

		if [[ ${#membersErrors[@]} -gt 0 ]]; then
			echo
			WarningMsg 0 1 "Found page owner or workflow data without a defined userid or role:"
			for key in "${!membersErrors[@]}"; do
				Msg3 "^$(ColorW "*Warning*") -- Workflow/Owner member: '$key' not defined and used on the following pages:"
				tmpStr="${membersErrors["$key"]}"
				IFSsave=$IFS; IFS='|' read -a pages <<< "${membersErrors["$key"]}"; IFS=$IFSsave
				for page in "${pages[@]}"; do
					Msg3 "^^'$page'"
				done
				echo
			done
		fi
	fi

	## Write out change log entries
	if [[ $informationOnlyMode != true ]]; then
		[[ $comment == true ]] && changeLogLines+=("$comment")
		changeLogLines=("Data updated from '$workbookFileIn':")
		[[ $processedUserData == true ]] && changeLogLines+=("User data")
		[[ $processedRoleData == true ]] && changeLogLines+=("Role data")
		[[ $processedPageData == true ]] && changeLogLines+=("Page data")
		WriteChangelogEntry 'changeLogLines' "$siteDir/changelog.txt"
	fi

#==================================================================================================
## Done
#==================================================================================================
## Exit nicely
	Goodbye 0 'alert' "$client/$env"

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
## Tue Jan  3 13:44:34 CST 2017 - dscudiero - sync
## Tue Jan  3 15:36:36 CST 2017 - dscudiero - misc cleanup
## Tue Jan 10 09:54:07 CST 2017 - dscudiero - Updated messaging to reflect if we are running with informationOnly set
## Tue Jan 10 15:24:53 CST 2017 - dscudiero - Tweek output messaging
## Wed Jan 18 14:22:27 CST 2017 - dscudiero - Do not copy step file if infomationonly flag is set
## Wed Jan 18 14:59:40 CST 2017 - dscudiero - Import WriteChangelogEntry
## Tue Jan 24 08:34:58 CST 2017 - dscudiero - Add 'information only' verbiage to messaging
## Tue Jan 24 12:48:26 CST 2017 - dscudiero - Tweak changelog text
## Mon Feb  6 08:17:01 CST 2017 - dscudiero - General syncing of dev to prod
## Mon Feb  6 09:41:54 CST 2017 - dscudiero - Set tmpFile
## Mon Feb  6 12:59:49 CST 2017 - dscudiero - remove the temporary workkbook file if one is used
## Mon Feb  6 13:04:58 CST 2017 - dscudiero - fix syntax error
## Mon Feb  6 13:44:35 CST 2017 - dscudiero - Add client and env to the goodbye / complete message
## Mon Feb  6 16:11:14 CST 2017 - dscudiero - tweak messageing written out to changelog
## Thu Feb  9 08:06:44 CST 2017 - dscudiero - make sure we are using our own tmpFile
## Thu Feb  9 11:49:37 CST 2017 - dscudiero - check if there is a uin column in the user sheet if the client has useUins set
## Thu Feb  9 11:57:48 CST 2017 - dscudiero - tweak messaging
## Wed Mar 22 15:30:31 CDT 2017 - dscudiero - Fix spelling error
## 04-06-2017 @ 10.10.20 - (3.8.86)    - dscudiero - renamed RunCourseLeafCgi, use new name
## 04-17-2017 @ 12.30.27 - (3.8.91)    - dscudiero - skip
## 05-15-2017 @ 14.27.49 - (3.8.94)    - dscudiero - Tweek changelog messages
## 07-17-2017 @ 13.48.41 - (3.8.95)    - dscudiero - Single quote strings to ParseWorksheetHeader function
## 09-29-2017 @ 10.15.03 - (3.8.119)   - dscudiero - Update FindExcecutable call for new syntax
## 10-09-2017 @ 16.54.07 - (3.9.9)     - dscudiero - Fixed problems with the conversion to getExecl2
## 11-02-2017 @ 12.47.27 - (3.9.9)     - dscudiero - Swtich to ParseArgsStd2
## 11-03-2017 @ 08.19.41 - (3.9.9)     - dscudiero - Check to make sure we have a valid 'path' when parsing the catalog workflow sheet
## 11-09-2017 @ 14.15.37 - (3.9.9)     - dscudiero - Added NotifyAllApprovers
## 11-10-2017 @ 12.37.41 - (3.9.9)     - dscudiero - Refactor the uid to uin mapping
## 12-20-2017 @ 09.29.24 - (3.9.9)     - dscudiero - Added gathering of a jalot task number for updates to next and curr
