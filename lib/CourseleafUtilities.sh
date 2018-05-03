## XO NOT AUTOVERSION
#===================================================================================================
# version="1.0.35" # -- dscudiero -- Thu 05/03/2018 @ 14:27:37.46
#===================================================================================================
# Various data manipulation functions for courseleaf things
#===================================================================================================
# Copyright 2018 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

#===================================================================================================
# Return the product version string
# Usage: GetProductVersion <product> <siteDir>
# Returns: (stdout) productVersion, null string if no version data found
#===================================================================================================
	function GetProductVersion {
		local product=$1
		local siteDir=$2
		local verFile prodVer

		case "$product" in
			cat|courseleaf)
				verFile="$siteDir/web/courseleaf/clver.txt"						## A normal siteDir
				[[ ! -r $verFile ]] && verFile="$siteDir/courseleaf/clver.txt"	## a git repo shadow
				if [[ -r $verFile ]]; then
					prodVer=$(cut -d":" -f2 <<< $(cat $verFile))
				else
					verFile=$siteDir/web/courseleaf/default.tcf 				## look in the /courseleaf/default.tcf file
					if [[ -r $verFile ]]; then
						prodVer=$(ProtectedCall "grep '^clver:' $verFile");
						prodVer=$(cut -d":" -f2 <<< $prodVer);
					fi
				fi
				;;
			cim)
				verFile="$siteDir/web/courseleaf/cim/clver.txt"				## A normal siteDir
				[[ ! -r $verFile ]] && verFile="$siteDir/cim/clver.txt" 	## a git repo shadow
				[[ -r $verFile ]] && prodVer=$(cut -d":" -f2 <<< $(cat $verFile))
				;;
		esac
		prodVer=${prodVer%% *} ; prodVer=${prodVer%%rc*}

		echo "$prodVer"
		return 0
	} #GetProductVersion
export -f GetProductVersion

#===================================================================================================
# Parse a courseleaf client file 
# Usage: ParseCourseleafFile <fileName>
# 	clientRoot is everything up to the 'web' directory.  e.g. '/mnt/rainier/uww/next' or
# 	'/mnt/dev6/web/uww-dscudiero'
# Returns: (stdout) clientName clientEnv clientRoot fileEnd
#===================================================================================================
function ParseCourseleafFile {
	local file="$1"
	[[ $file == '' ]] && file="$(pwd)"
	file=${file:1}
	local tokens=($(tr '/' ' ' <<< $file))
	local clientRoot fileEnd clientName env pcfCntr len str
	local parseStart=4

	clientRoot="/${tokens[0]}/${tokens[1]}/${tokens[2]}/${tokens[3]}"
	if [[ ${tokens[1]:0:3} == 'dev' ]]; then
		clientName="$(cut -d'.' -f1 <<< ${tokens[3]})"
		env='dev'
		str="-$userName"; len=${#str}
		[[ ${clientName:(-$len)} == "-$userName" ]] && env='pvt'
	else
		clientName="${tokens[2]}"
		env="${tokens[3]}"
	fi

	for ((pcfCntr = $parseStart ; pcfCntr < ${#tokens[@]} ; pcfCntr++)); do
	  	token="${tokens[$pcfCntr]}"
		fileEnd="${fileEnd}/${token}"
	done

	echo "$clientName" "$env" "$clientRoot" "$fileEnd"

	return 0
} #ParseCourseleafFile
export -f ParseCourseleafFile

#===================================================================================================
# find out what the courseleaf pgm is and its location
# Usage: GetCourseleafPgm
# 	Expects to be run from a client root directory (i.e. in .../$client)
# Returns: (stdout) courseleafPgmName courselafePgmDir
#===================================================================================================
function GetCourseleafPgm {
	local checkDir=${1:-$(pwd)}
	local cwd=$(pwd)

	cd $checkDir
	for token in 'courseleaf' 'pagewiz'; do
		if [[ -x ./$token.cgi ]]; then
			echo "$token" "$checkDir"
			cd $cwd
			return 0
		elif [[ -x $checkDir/$token/$token.cgi ]]; then
			echo "$token" "$checkDir/$token"
			cd $cwd
			return 0
		elif [[ -x $checkDir/web/$token/$token.cgi ]]; then
			echo "$token" "$checkDir/web/$token"
			cd $cwd
			return 0
		fi
	done
	cd $cwd
	return 0
} #GetCourseleafPgm
export -f GetCourseleafPgm

#===================================================================================================
# Backup a courseleaf file, copy to the 'attic' creating directories as necessary
# Usage: BackupCourseleafFile <fileName> [<backupDirectory>]
#	Expects the variable 'client' to be set
#	Parses the courseleaf site data from the passed in file name using ParseCourseleafFile
#	If no backup directory is specified then a default of 
#		'${clientRoot}/attic/$myName/$userName.$backupSuffix' 
#	will be used
# Returns: none
#===================================================================================================
function BackupCourseleafFile {
	[[ $informationOnlyMode == true ]] && return 0
	local file=$1; shift || true
	[[ ! -r $file ]] && return 0
	local backupDir=$1; shift || true

	## Parse the file name
	local data="$(ParseCourseleafFile "$file")"
	local client="${data%% *}"; data="${data#* }"
	local env="${data%% *}"; data="${data#* }"
	local clientRoot="${data%% *}"; data="${data#* }"
	local fileEnd="${data%% *}"; data="${data#* }"
	#dump file client env clientRoot fileEnd

	## Set backup location
	[[ -z $backupDir ]] && backupDir="${clientRoot}/attic/$myName/$userName.$backupSuffix"	
	[[ ! -d $backupDir ]] && $DOIT mkdir -p $backupDir
	local bakFile="${backupDir}${fileEnd}"

	if [[ -f $file ]]; then
		[[ ! -d $(dirname $bakFile) ]] && $DOIT mkdir -p $(dirname $bakFile)
		$DOIT cp -fp $file $bakFile
	elif [[ -d $file ]]; then
		[[ ! -d $bakFile ]] && $DOIT mkdir -p $bakFile
		$DOIT cp -rfp $file $bakFile
	fi

	return 0
} #BackupCourseleafFile

#===================================================================================================
# Run a courseleaf.cgi command, check output for atj errors
# Usage: RunCourseLeafCgi <siteDir> <commandString> 
# Returns: none 
# Calls 'Terminate' if the we cannot fine the cgi or the command issues an 'ATJ error'
#===================================================================================================
function RunCourseLeafCgi {
	myIncludes="GetCourseleafPgm ProtectedCall PushPop"
	Import "$standardIncludes $myIncludes"

	local siteDir="$1"; shift
	local cgiCmd="$*"
	local cgiOut="$(MkTmpFile "${FUNCNAME}.${BASHPID}")"

	pushd "$siteDir" > /dev/null
	courseLeafPgm=$(GetCourseleafPgm | cut -d' ' -f1).cgi
	courseLeafDir=$(GetCourseleafPgm | cut -d' ' -f2)
	if [[ $courseLeafPgm == '.cgi' || $courseLeafDir == '' ]]; then Terminate "$FUNCNAME: Could not find courseleaf executable"; fi
	dump -3  siteDir courseLeafPgm courseLeafDir cgiCmd
	[[ ! -x $courseLeafDir/$courseLeafPgm ]] && Terminate "$FUNCNAME: Could not find $courseLeafPgm in '$courseLeafDir' trying:\n^'$cgiCmd'\n^($calledLineNo)"

	## Run command
	cd $courseLeafDir
	{ ( ./$courseLeafPgm $cgiCmd ); } &> $cgiOut
	grepStr="$(ProtectedCall "grep -m 1 'ATJ error:' $cgiOut")"
	[[ $grepStr != '' ]] && Terminate "$FUNCNAME: ATJ errors were reported by the step.\n^^cgi cmd: '$cgiCmd'\n^^$grepStr"
	rm -f "$cgiOut"
	popd > /dev/null
	return 0
} #RunCourseLeafCgi
export -f RunCourseLeafCgi

#===================================================================================================
# Write a 'standard' format courseleaf changelog.txt
# Usage: <logFileName> <${lineArray[@]}>
#	A standard header is automatically generated and should not be included in lineArray
#	LineArray is an array containing the lines of text to write to the log
#	If user has a local 'logit' script ($HOME/bin/logit), it will also be called as follows:
#		$HOME/bin/logit -cl "${client:--}" -e "${env:--}" "$logText"
# Returns: none
#===================================================================================================
function WriteCourseleafChangelogEntry {
	Import "ParseCourseleafFile"
	local ref=$1[@]
	[[ -z $ref || -n $DOIT || $listOnly == true || $informationOnlyMode == true ]] && return 0
	local logFile="$2"
	local logger=${3-$myName}
	[[ ! -f "$logFile" ]] && touch "$logFile"

	local clientDataLogFile clientSummaryLogFile usersClientLogFile="/dev/null" usersActivityLog="/dev/null"

	## Parse the file name
	local data=$(ParseCourseleafFile "$logFile")
	local client="${data%% *}"; data="${data#* }"
	local env="${data%% *}"; data="${data#* }"
	local clientRoot="${data%% *}"; data="${data#* }"
	local fileEnd="${data%% *}"; data="${data#* }"

	[[ $env == 'pvt' || $env == 'dev' ]] && return 0
	[[ $env == 'test' ]] && client=${client%-*}

	## If there is a clientData folder then write out to there also
		if [[ -n $localClientWorkFolder && -d $localClientWorkFolder ]]; then
			[[ -n $client && ! -d "$localClientWorkFolder/$client" ]] && mkdir -p $localClientWorkFolder/$client
			usersClientLogFile="$localClientWorkFolder/$client/changelog.txt"
			usersActivityLog="$localClientWorkFolder/activityLog.txt"
		fi

	## Write out records
		echo -e "\n$userName\t$(date) via '$logger' version: $version" | tee -a "$logFile" | tee -a "$usersActivityLog" >> "$usersClientLogFile"
		echo -e "\tClient: $client, Environment: $env" | tee -a "$usersActivityLog" >> "$usersClientLogFile"
		printf '\t%s\n' "${!ref}" | tee -a "$logFile" | tee -a "$usersActivityLog" >> "$usersClientLogFile"

	## Check if the user has a local logit script in $HOME/bin, if found the call it.
		if [[ -x $HOME/bin/logit ]]; then
			logText=$(sed "s_'_\\\'_"g <<< "$logger: ${!ref[0]}")
			logText=$(sed 's_\"_\\\"_'g <<< "$logText")
			$HOME/bin/logit -cl "${client:--}" -e "${env:--}" "$logText"
		fi

	return 0
} #WriteCourseleafChangelogEntry
export -f WriteCourseleafChangelogEntry

#===================================================================================================
# Edit a tcf value
# Usage: EditTcfValue <varName> <varValue> <editFile>
# 	1) If already there, return true
# 	2) If found commented out, uncomment & return
# 	3) If found varible but value is different, edit & return
# 	4) If not found in target
#		2) If found in skeleton then insert target line after the line found in the skeleton
#		1) Scan file in skeleton to find the line immediaterly above the target line in the skel file
#		3) If not found in the skeleton of the 'afterline' returned in 1) above is not found, insert at top
# Returns: 'true' for success, anything else is an error message
#===================================================================================================
function EditTcfValue {
	[[ $DOIT != '' ]] && echo true && return 0
	local varName=$1
	local varVal=$2
	local editFile=$3
	local skelDir=$skeletonRoot/release
	local findStr grepStr fromStr

	[[ $var == '' ]] && echo "($FUNCNAME) Required argument 'var' not passed to function" && return 0
	[[ $varVal == '' ]] && echo "($FUNCNAME) Required argument 'var' not passed to function" && return 0
	[[ $editFile == '' || ! -w $editFile ]] && echo "($FUNCNAME) Could not read/write editFile: '$editFile'" && return 0
	local toStr="${varName}:${varVal}"
	dump -3 -r
	dump -3 -l varName varVal editFile toStr

	## Check to see if string is already there
		findStr="${varName}"':'"${varVal}"
		dump -3 -l -t findStr
		grepStr="$(ProtectedCall "grep \"^$findStr\" $editFile")"
		[[ $grepStr != '' ]] && echo true && return 0

	BackupCourseleafFile $editFile
	## Look for a commented variable, if found uncomment and edit
		findStr="//$varName:"
		dump -3 -l -t findStr
		grepStr="$(ProtectedCall "grep \"^$findStr\" $editFile")"
		if [[ $grepStr != '' ]]; then
			fromStr="$grepStr"
			sed -i s"#^${fromStr}#${toStr}#" $editFile
			echo true
			return 0
		fi

	## Look for a existing variable, if found edit
		findStr="$varName:"
		dump -3 -l -t findStr
		grepStr="$(ProtectedCall "grep \"^$findStr\" $editFile")"
		if [[ $grepStr != '' ]]; then
			fromStr="$grepStr"
			sed -i s"#^${fromStr}#${toStr}#" $editFile
			echo true
			return 0
		fi

	## OK, variable is not found in target file, find location in skeleton and add,
	## if not found in skeleton then add to top of file
		local siteDir=$(ParseCourseleafFile $editFile | cut -d' ' -f2)
		local fileEnd=$(ParseCourseleafFile $editFile | cut -d' ' -f4)
		dump -3 -l -t siteDir fileEnd
		## Scan skeleton looking for line:
			unset foundLine afterLine insertMsg;
			while read -r line; do
				[[ "${line:0:${#varName}+1}" == "$varName:" || "${line:0:${#varName}+3}" == "//$varName:" ]] && foundLine=true && break
				afterLine="$line"
			done < "${skelDir}${fileEnd}"
			dump -3 -l -t foundLine afterLine
		## If we found the line then insert the new line after the line previous line in the skeleton file
			if [[ $foundLine == true ]]; then
				local verboseLevelSave=$verboseLevel
				verboseLevel=0; insertMsg=$(InsertLineInFile "$toStr" "$editFile" "$afterLine"); verboseLevel=$verboseLevelSave
				dump -3 -l -t insertMsg
				if [[ $insertMsg != true ]]; then
					## If insert could not find the insert after line then add to the top of the target file
					[[ $(Contains "$insertMsg" 'Could not locate target string/line' ) == true ]] && insertMsg=$(sed -i "1i$toStr" $editFile)
				fi
			else
				## If we did not fine the line in the skeletion then just insert at the top of the target file
				insertMsg=$(sed -i "1i$toStr" $editFile)
			fi
		## Error?
			[[ $insertMsg != '' && $insertMsg != true ]] && echo $insertMsg || echo true

	return 0
} #EditTcfValue
export -f  EditTcfValue

#===================================================================================================
# Insert a new line into the courseleaf console file
# Usage: EditCourseleafConsole <action> <targetFile> <string>
# 	<action> in {'insert','delete'}
# 	<string> is a full navlinks record or is the name of the console action, i.e. navlinks:...|<name>|...
#	
# 	if action == 'delete' then the line will be commented out
# Returns 'true' for success, anything else is an error message
#===================================================================================================
function EditCourseleafConsole {
	local action="$1"
	local tgtFile="$2"
	local string="$3"

	Import 'BackupCourseleafFile InsertLineInFile CopyFileWithCheck StringFunctions'

	[[ $action == '' ]] && echo "($FUNCNAME) Required argument 'action' not passed to function" && return 0
	[[ $tgtFile == '' || ! -w $tgtFile ]] && echo "($FUNCNAME) Could not read/write tgtFile: '$tgtFile'" && return 0
	[[ $string == '' ]] && echo "($FUNCNAME) Required argument 'string' not passed to function" && return 0
	local skelFile=$skeletonRoot/release/web/courseleaf/index.tcf
	local grepStr insertRec name navlinkName

	if [[ $(Contains "$string" 'navlinks:') == true ]]; then
		insertRec="$(Trim "$string")"
		name=$(echo $string | cut -d'|' -f2)
	else
		name="$string"
		grepStr="$(ProtectedCall "grep \"|$name|\" $skelFile")"
		if [[ $grepStr != '' ]]; then
			insertRec="$(Trim "$grepStr")"
			[[ ${insertRec:0:2} == '//' ]] && insertRec=${insertRec:2}
		else
			echo "($FUNCNAME) Could not locate a navlinks record with 'name' of '|$name|' in the skeleton"
			return 0
		fi
	fi
	dump -3 -l name insertRec
	BackupCourseleafFile $editFile

	## See if line is there already, if found & insert then quit, if found & delete then comment out
		grepStr="$(ProtectedCall "grep \"^$insertRec\" $editFile")"
		if [[ $grepStr != '' ]]; then
			[[ $(Lower ${action:0:1}) == 'd' ]] && sed -i s"#^$insertRec#//$insertRec#"g $editFile
			echo true
			return 0
		fi
		[[ $(Lower ${action:0:1}) == 'd' ]] && echo true && return 0

	## See if line is there but commented out
		grepStr="$(ProtectedCall "grep \"^//$insertRec\" $editFile")"
		if [[ $grepStr != '' ]]; then
			sed -i s"#^//$insertRec#$insertRec#"g $editFile
			Msg "^Uncommented line: $toStr..."
			changesMade=true
			echo true
			return 0
		fi

	## Scan skeleton looking for line:
		unset foundLine afterLine insertMsg
		while read -r line; do
			line=$(Trim "$line")
			[[ "$line" == "$insertRec" || "$line" == "//$insertRec" ]] && foundLine=true && break
			afterLine="$line"
		done < "$skelFile"
		dump -3 -l -t foundLine afterLine

	## Insert the line
		editFile="$tgtFile"
		if [[ $foundLine == true ]]; then
			local verboseLevelSave=$verboseLevel
			verboseLevel=0; insertMsg="$(InsertLineInFile "$insertRec" "$editFile" "$afterLine")"; verboseLevel=$verboseLevelSave
			dump -3 -l -t insertMsg
			[[ $insertMsg == true ]] && echo true || echo "$insertMsg"
			return 0
		fi
		## OK, we need to insert the line but cannot find the after record, so just add to the end of the group
			navlinkName=$(echo $insertRec | cut -d'|' -f1)
			afterLine="$(ProtectedCall "grep \"^$navlinkName\" $editFile | tail -1")"
			if [[ -z $afterLine ]]; then
				insertMsg="($FUNCNAME) Could not insert line:\n\t$insertRec\nCould not locate suitable insert location"
			else
				verboseLevel=0; insertMsg=$(InsertLineInFile "$insertRec" "$editFile" "$afterLine"); verboseLevel=$verboseLevelSave
				#[[ $insertMsg != true ]] && echo "($FUNCNAME) Could not insert line:\n\t$insertRec\nMessages are:\n\t$insertMsg" || echo true
			fi
			echo $insertMsg

	return 0
} #EditCourseleafConsole
export -f EditCourseleafConsole

#===================================================================================================
# Find the administration navlink in /courseleaf/index.tcf
# Usage: FindCourseleafNavlinkName <siteDir>
# Returns: navlinkName or null string
#===================================================================================================
function FindCourseleafNavlinkName {
	local dir=$1
	local editFile="$dir/web/courseleaf/index.tcf"
	local navlink grepStr
	[[ ! -f $editFile ]] && return 0
	for navlinkName in CourseLeaf Courseleaf Administration; do
		grepStr="$(ProtectedCall "grep \"^navlinks:$navlinkName\" $editFile | tail -1")"
		[[ $grepStr != '' ]] && echo "$navlinkName" && break
	done
	return 0
} #FindCourseleafNavlinkName
export -f FindCourseleafNavlinkName

#===================================================================================================
# Resolve a clients siteDir without using the database
# Usage GetSiteDirNoCheck <clientCode>
# Sets global variable: siteDir
#===================================================================================================
function GetSiteDirNoCheck {
	Import 'SelectMenuNew ProtectedCall'
	local client="$1"; shift || true
	[[ -z $client ]] && return 0
	local promptStr=${1:-"Do you wish to work with a 'development' or 'production' environment"}
	local checkDir envType server ans dirs dir line
	unset siteDir
	cwd=$(pwd)

	unset envType
	if [[ -z $env ]]; then
		echo
		Prompt envType "$promptStr" 'production development' 'development'; envType=$(Lower ${envType:0:1})
		[[ $envType == 'd' ]] && validEnvs="$(tr ',' ' ' <<< $courseleafDevEnvs)" || validEnvs="$(echo "$courseleafProdEnvs" | sed s/,preview,public,prior// | tr ',' ' ')"
	fi

	## Get the server and site names
		local tmpFile=$(MkTmpFile $FUNCNAME)
		[[ -f $tmpFile ]] && rm "$tmpFile"
		if [[ $envType == 'd' ]]; then
			unset dirs
			for server in $(tr ',' ' ' <<< $devServers); do
				if [[ -d /mnt/$server/web ]]; then
					cd /mnt/$server/web
					find -mindepth 1 -maxdepth 1 -type d -name $client\* -printf "$server %f\n" >> $tmpFile
				fi
			done
		else
			for server in $(tr ',' ' ' <<< $prodServers); do
				if [[ -d /mnt/$server/$client ]]; then
					cd /mnt/$server/$client
					find -mindepth 1 -maxdepth 1 -type d -printf "$server %f\n" | grep 'next\|curr\|prior' >> $tmpFile
				fi
				[[ -d "/mnt/$server/$client-test" ]] && echo "$server test" >> $tmpFile
			done
		fi
	## Build the menu and ask the user to select the site
		local numLines=$(echo $(ProtectedCall "wc -l "$tmpFile" 2>/dev/null") | cut -d' ' -f1)
		if [[ $numLines -gt 0 ]]; then
			menuItems+=("|server/share|Site Type")
			while read -r line; do menuItems+=("|$(tr ' ' '|' <<< $line)"); done < $tmpFile;
			SelectMenuNew 'menuItems' 'menuItem' "\nEnter the $(ColorK '(ordinal)') number of the site you wish to act on (or 'x' to quit) > "
			[[ $menuItem == '' ]] && Goodbye 0
			server="$(cut -d' ' -f1 <<< $menuItem)"
			if [[ ${envType:0:1} == 'd' ]]; then
				client="$(cut -d' ' -f2 <<< $menuItem)"
				[[ $(Contains "$client" "-$userName") == true ]] && env='pvt' || env='dev'
 				siteDir="/mnt/$server/web/$client"
			else
				env="$(cut -d' ' -f2 <<< $menuItem)"
				[[ $env == 'test' ]] && client="$client-test"
				siteDir="/mnt/$server/$client/$env"
			fi
		fi

	## Done
		cd "$cwd"
		if [[ ! -d $siteDir ]]; then
			unset siteDir
			if [[ $testMode == true && -n $env ]]; then
				[[ -d  $HOME/testData/$env ]] && siteDir="$HOME/testData/$env" || unset siteDir
			else
				Error "Could not resolve the site directory with the information provided"
				Prompt siteDir "Please enter the full path to the site you wish to patch" '*dir*'
			fi
		fi
		[[ ! -d $siteDir ]] && unset siteDir
		[[ -f "$tmpFile" ]] && rm "$tmpFile"
		return 0
}
export -f GetSiteDirNoCheck

#===================================================================================================
# Get CIMs
# Usage: [options] <siteDir> 
# Options:
#	-all / --getAllCims
#	-multi / --multipleCims
#	-o / --onlyWithTestFile
#	-v / --verb
#	-p / --prefix
# Returns: 	cims (Array of the found cims)
#			cimStr (string of cims found formatted for display -- comma separated with blanks)
#===================================================================================================
function GetCims {
	myIncludes="ProtectedCall PushPop"
	Import "$standardInteractiveIncludes $myIncludes"

	local siteDir jj verb prefix multiCims onlyWithTestFile getAllCims
	[[ -n $allowMultiCims ]] && multiCims=$allowMultiCims
	[[ -n $onlyCimsWithTestFile ]] && onlyWithTestFile=$onlyCimsWithTestFile
	[[ -n $allCims ]] && getAllCims=$allCims

	## Parse defaults
		while [[ $# -gt 0 ]]; do
		    [[ $1 =~ ^-all|--getAllCims$ ]] && { getAllCims=true; shift 1; continue; }
		    [[ $1 =~ ^-multi|--multipleCims$ ]] && { multiCims=true; shift 1; continue; }
		    [[ $1 =~ ^-o|--onlyWithTestFile$ ]] && { onlyWithTestFile=true; shift 1; continue; }
		    [[ $1 =~ ^-v|--verb$ ]] && { verb="$2"; shift 2; continue; }
		    [[ $1 =~ ^-p|--prefix$ ]] && { prefix="$2"; shift 2; continue; }
		    [[ -z $siteDir ]] && siteDir=$1
		    shift 1 || true
		done

	[[ ${#*} -eq 2 ]] && verb="$2" && prefix="$1"
	[[ ${#*} -eq 1 ]] && verb="use" && prefix="$1"

	local ans suffix validVals
	if [[ $allowMultiCims == true ]]; then
		suffix=', a for all cims'
		validVals='Yes No Other All'
	else
		unset suffix
		validVals='Yes No Other'
	fi
	dump -3 -t siteDir allowMultiCims suffix validVals

	[[ ! -d $siteDir/web ]] && { unset cims cimStr; return 0; }
	Pushd "$siteDir/web"
	cimDirsStr=$(ProtectedCall "find -mindepth 2 -maxdepth 2 -type f -name cimconfig.cfg -printf '%h\n' | sort")
	unset cimDirs
	[[ $cimDirsStr != '' ]] && readarray -t cimDirs <<< "${cimDirsStr}"
	#echo;echo "Array '$cimDirs':"; for ((jj=0; jj<${#cimDirs[@]}; jj++)); do echo -e "\t cimDirs[$jj] = >${cimDirs[$jj]}<"; done
	[[ -f ./cim/cimconfig.cfg ]] && cimDirs+=('./cim')
	Popd

	for ((jj=0; jj<${#cimDirs[@]}; jj++)); do
		dir="${cimDirs[$jj]}"; dir=${dir:2}
		[[ $(Contains "$dir" ".old") == true || $(Contains "$dir" ".bak") == true || $(Contains "$dir" " - Copy") == true  || $(Contains "$dir" "_") == true ]] && continue
		[[ $onlyWithTestFile == true && ! -f $siteDir/web/$dir/wfTest.xml ]] && continue
		if [[ $verify == true && $getAllCims != true ]]; then
			unset ans
			Prompt ans "${prefix}Found CIM Instance '$(ColorK $dir)' in source instance,\n${prefix}\tdo you wish to $verb it? (y to use$suffix)? >"\
		 			"$validVals"; ans=${ans,,[a-z]} ans=${ans:0:1};
			[[ $ans == 'a' ]] && { cims=(${cimDirs[@]}); break; }
			if [[ $ans == 'y' ]]; then
				cims+=($dir);
				[[ $multiCims != true ]] && break
			elif [[ $ans == 'o' ]]; then
				local dir
				while [[ -z $dir ]]; do
					Prompt dir "${prefix}Please specifiy the CIM instance directory (relative to '$siteDir/web')? >" '*dir'
					[[ $dir == 'x' || $dir == 'X' ]] && GoodBye 'x'
					[[ ! -f "$siteDir/web/$dir/cimconfig.cfg" ]] && { Error "Specified directory '$dir' is not a CIM instance (no cimconfig.cfg), "; unset dir; } || \
					{ unset cims; cimStr="$dir"; return 0; } 
				done
			fi
		else
			cims+=($dir)
		fi
	done
	if [[ -z $cimStr ]]; then
		cimStr=$(printf -- "%s, " "${cims[@]}")
		cimStr="${cimStr//.\//}"
		cimStr=${cimStr:0:${#cimStr}-2}
	fi
	#[[ $products == '' ]] && products='cim' || products="$products,cim"
	[[ $verbose == true && $verboseLevel -ge 2 ]] && dump cimStr
	return 0
} #GetCims
export -f GetCims




#===================================================================================================
# Check-in Log
#===================================================================================================
## 05-02-2018 @ 16:45:23 - 1.0.32 - dscudiero - Re-factor BackupCourseleafFile, allow passing in of the backup directory name
## 05-03-2018 @ 08:26:09 - 1.0.34 - dscudiero - Change how we parse off the client and env data
## 05-03-2018 @ 14:27:56 - 1.0.35 - dscudiero - Allow 'courseleaf' as a product
