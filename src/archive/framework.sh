
frameworkVersion=6.8.100 # -- dscudiero -- 10/19/2016 @ 14:21:39.81

#===================================================================================================
# Common Subs
# CopyrighFt David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
#===================================================================================================
# Declare variables and constants *** SEE END OF FILE ***
#===================================================================================================
[[ $TOOLSPATH == '' ]] && \
	printf "\n\e[0;31m*Error* -- Sorry cannot execute this script, variable TOOLSPATH does not have a value\e[m\a\n\n" && exit -1
[[ ! -d $TOOLSPATH ]] && \
	printf "\n\e[0;31m*Error* -- Sorry cannot execute this script, variable TOOLSPATH ($TOOLSPATH) is not a directory\e[m\a\n\n" && exit -1

function GetFrameworkVersion { echo "$frameworkVersion" ; }

#===================================================================================================
# Execute statement if userid is me
#===================================================================================================
IfMeFirstCall=true
function IfMe {
	[[ $TOOLSDEBUG != true && $MYDEBUG != true ]] && return 0
	[[ $userName != $ME ]] && return 0

	[[ $stdout == '' ]] && stdout=/dev/tty
	[[ $IfMeFirstCall == true ]] && SetFileExpansion 'off' && echo "***  Deep debug active, more info in '$stdout' ***" && SetFileExpansion \
								 && IfMeFirstCall=false && echo -e "\n$myName: $(date)\n" >> $stdout
	[[ $* == '' ]] && echo > $stdout && return 0
	$* >> $stdout
	return 0
}
function ifme { IfMe $* ; }
function IsMe { IfMe $* ; }
function isme { IfMe $* ; }

#===================================================================================================
# Get a temp file name
#===================================================================================================
function mkTmpFile {
	local functionName=${1:-$FUNCNAME}
	[[ ! -d $tmpRoot ]] && mkdir -p $tmpRoot
	local tmpFile="$(mktemp $tmpRoot/$myName.$functionName.XXXXXXXXXX)"
	echo "$tmpFile"
	return 0
}

#===================================================================================================
# Get default variable values from the defaults database
#===================================================================================================
function GetDefaultsData {
	Msg2 $V3 "*** Starting $FUNCNAME ***"
	#echo > $stdout
	local scriptName=${1:-$myName}
	dump -3 -t scriptName
	local tempVarVal

	## Set myPath based on if the current file has been sourced
		[[ -d $(dirname ${BASH_SOURCE[0]}) ]] && myPath=$(dirname ${BASH_SOURCE[0]})

	## Get common config data
		if [[ $scriptName == $myName ]]; then
			Msg2 $V3 "$FUNCNAME: Loading common values..."
			dbFields="name,value"
			whereClause="(os=\"$osName\" or os is null) and (host=\"$hostName\" or host is null)"
			sqlStmt="select $dbFields from defaults where $whereClause order by name,host"
			RunSql 'mysql' $sqlStmt
			if [[ ${#resultSet[@]} -eq 0 ]]; then
				Msg2 $T "Could not retrieve common defaults data from the $mySqlDb.defaults table."
			else
				recCntr=0
				while [[ $recCntr -lt ${#resultSet[@]} ]]; do
					varName=$(cut -d'|' -f1 <<< ${resultSet[$recCntr]})
					dump -3 -t -t varName
					## See if the variable already has a value, if yes then skip
						unset tempVarVal; eval tempVarVal=\"${!varName}\"
						dump -3 -t -t tempVarVal
 						[[ $tempVarVal != '' ]] && (( recCntr += 1 )) && continue
 					## Set the variable value
						varValue=$(cut -d '|' -f 2-  <<< ${resultSet[$recCntr]})
						dump -3 -t -t varValue
						eval unset $varName
						eval $varName=\"$varValue\"
					(( recCntr += 1 ))
				done
			fi

			sqlStmt="select edate from $newsInfoTable where userName=\"$userName\" and object=\"tools\" "
			RunSql 'mysql' $sqlStmt
			[[ ${#resultSet[@]} -gt 0 ]] && lastViewedToolsNewsEdate=$(cut -d '|' -f2 <<< ${resultSet[0]})
		fi

	## Get script specific data from the script record in the scripts database
		Msg2 $V3 "$FUNCNAME: Loading $scriptName..."
		## Get all the fields in the database table
			unset scriptDbFields
			sqlStmt="select column_name from information_schema.columns where table_schema=\"$warehouseDb\" and table_name=\"$scriptsTable\""
			RunSql 'mysql' $sqlStmt
			for result in "${resultSet[@]}"; do
				field=$(cut -d'|' -f1 <<< $result)
				scriptDbFields="$scriptDbFields,$field"
			done
			scriptDbFields=${scriptDbFields:1}
		## Set field variables
		for field in $(tr ',' ' ' <<< $scriptDbFields) ; do unset $field; done
		sqlStmt="select $scriptDbFields from $mySqlDb.$scriptsTable where name=\"$scriptName\""
		RunSql 'mysql' $sqlStmt
		if [[ ${#resultSet[@]} -ne 0 ]]; then
			fieldCntr=1
			for field in $(tr ',' ' ' <<< $scriptDbFields); do

				eval $field=\"$(cut -d '|' -f $fieldCntr <<< "${resultSet[0]}")\"
				if [[ $(eval echo "\$$field") == 'NULL' ]]; then eval $field=''; fi
				(( fieldCntr += 1 ))
			done
		fi

	## Get last viewed news eDate
		sqlStmt="select edate from $newsInfoTable where userName=\"$userName\" and object=\"$scriptName\" "
		RunSql 'mysql' $sqlStmt
		[[ ${#resultSet[@]} -gt 0 ]] && lastViewedScriptNewsEdate=$(cut -d '|' -f2 <<< ${resultSet[0]})

		Msg2 $V3 "*** Ending $FUNCNAME ***"
	return 0
} #GetDefaultsData

#===================================================================================================
# Parse an argumenst string driven by an control array that is passed in
# argList+=(argFlag,minLen,type,scriptVariable,extraToken/exCmd,helpSet,helpText)  #type in {switch,switch#,option,help}
# extraToken/exCmd = a command to execute for switch & option
# 					 a variable to set the value of # for switch#
# e.g.+
# 	argList+=(-verbose,switch,verbose)
# 	argList+=(-cat,switch,cat)
# 	argList+=(-debug,switch#,debug,"env="dev";dev=true")
# 	argList+=(-file,option,file,'env="dev"')
# ParseArgsStd "${argList[@]}"
#
#===================================================================================================
function ParseArgs {
	#verboseLevel=3
	Msg2 $V3 "*** $FUNCNAME -- Starting ***"
	local argToken foundArg parseStr argName minLen argType scriptVar exCmd argGroup helpText scriptVarVal badArgList
	[[ "$*" == '' ]] && return 0
	local tmpStr

	Msg2 $V3 "\tInitial ArgStr = >$*<"
	## Loop through all of the tokens on the passed in argument list
	until [[ "$*" == '' ]]; do
		origArgToken="$1"; shift || true
		## If the token does not start with a '-' then set client variable if not already set
		if [[ ${origArgToken:0:1} != '-' && $client == '' ]]; then
			Client=$origArgToken; client=$(Lower $origArgToken)
			Msg2 $V3 "\t\t*** found client value = '$client'"
			continue
		fi
		Msg2 $V3 "\n\tProcessing input token: '$origArgToken'..."
		## Loop through all defined arguments (argList)
		foundArg=false
		for argDef in "${argList[@]}"; do
			origArgName=$(echo $argDef | cut  -d ',' -f 1)
			## Check to see if this argument is defined in the users .tools file


			minLen=$(echo $argDef | cut  -d ',' -f 2)
			## Does the argument match the argument def
			if [[ $(Lower "${origArgToken:0:$minLen+1}") == $(Lower ${origArgName:0:$minLen+1}) ]]; then
				argType=$(Lower $(echo $argDef | cut  -d ',' -f 3))
				scriptVar=$(echo $argDef | cut  -d ',' -f 4)
				exCmd=$(echo $argDef | cut  -d ',' -f 5)
				argGroup=$(Lower $(echo $argDef | cut  -d ',' -f 6))
				helpText=$(echo $argDef | cut  -d ',' -f 7-)
				foundArg=true
				## Parse data based on argument type
				if [[ $argType == 'switch' ]]; then
					[[ $scriptVar != '' ]] && eval $scriptVar=true
					if [[ $exCmd != '' ]]; then eval $exCmd; fi
					break
				elif [[ $argType == 'switch#' ]]; then
					re='^[0-9]+$'
					if   [[ ${origArgToken:2} =~ $re ]]; then
						eval $exCmd=${origArgToken:2}
					fi
					if [[ $scriptVar != '' ]]; then eval $scriptVar=true; fi
					break
				elif [[ $argType == 'option' ]]; then
					[[ ${1:0:1} == '-' ]] && Msg2 $W "Option flag '$origArgToken' secified with no value" && continue
					## Check for a quotes string, if found then pull whole string
					if [[ ${1:0:1} == "'" || ${1:0:1} == '"' ]]; then
						## Pull off the string to the trailing quote
						quoteChar=${1:0:1}
						unset tmpStr
						until [[ ${1:${#1}-1:1} == $quoteChar || ${#*} -eq 0 ]]; do
							tmpStr="$tmpStr $1"
							shift || true
						done
						tmpStr="$tmpStr $1"
						scriptVarVal=${tmpStr:2:${#tmpStr}-3} ## Need to start at 2 since there is a leading blank char
						[[ $scriptVar != '' ]] && eval $scriptVar=\""$scriptVarVal"\"
						shift || true
					## Not a quotes string
					else
						scriptVarVal="$1"
						[[ $scriptVar != '' ]] && eval $scriptVar=\""$scriptVarVal"\"
						shift || true
						break
					fi
				elif [[ $argType == 'help' ]]; then
					Help "${argList[@]}"
					Msg2 $V3 "*** $FUNCNAME -- Completed ***"
					Goodbye 0
				fi
			fi ## token matched arg  def
		done ## arg definition array

		if [[ $foundArg == true ]]; then
			Msg2 $V3 "^^*** found match for $argType: '$origArgName' specified as '$origArgToken', scriptVarName = $scriptVar, value = >${!scriptVar}<"
			[[ $argType == 'option' ]] && tmpStr=${!scriptVar} && myArgStr="${myArgStr:${#tmpStr}+1}" ## Remove argument value
		else
			[[ $parseQuiet != true ]] && Msg2 $W "Argument token '$origArgToken' is not defined, it will be ignored"
			badArgList="$badArgList, $origArgToken"
			myArgStr="${myArgStr:${#origArgToken}+1}" ## Remove argument token
		fi
		Msg2 $V3 "\t\tAfter parse \$* = >$*<"
	done ## tokens in the input string

	Msg2 $V3 "\tSurviving Arguments = >$*<"
	if [[ $badArgList != '' ]]; then
		badArgList="${badArgList:1}"
	fi
	parsedArgStr="$badArgList"

	## Special processing for specific args
	if [[ $verbose == true && $verboseLevel -eq 0 ]]; then verboseLevel=1; fi
	if [[ ${#cims[@]} -gt 0 && $cimStr == '' ]]; then
		cimStr=$(printf '%s, ' "${cims[@]}")
		cimStr=${cimStr:0:${#cimStr}-2}
	fi

	#===================================================================================================
	## If testMode then run local customizations
		[[ $testMode == true && $(Contains "$administrators" "$userName") != true ]] && Msg2 $T "You do not have sufficient permissions to run this script in 'testMode'"
		[[ $testMode == true && -n "$(type -t testMode-$myName)"  && "$(type -t testMode-$myName)" = function ]] && testMode-$myName
		[[ $testMode == true && -n "$(type -t testMode-local)"  && "$(type -t testMode-local)" = function ]] && testMode-local

	[[ $verboseLevel -ge 3 ]] && Pause
	Msg2 $V3 "*** $FUNCNAME -- Completed ***"
	return 0
} #ParseArg

#===================================================================================================
## Standard argument parsing
#===================================================================================================
function ParseArgsStd {
	Msg2 $V3 "*** $FUNCNAME -- Starting ***"
	local myOpts="$*"
	[[ $myOpts == '' ]] && myOpts="$originalArgStr"
	## If there is a local function defined to parse script specific arguments then call it
	unset argList
	[[ -n "$(type -t parseArgs-$myName)"  && "$(type -t parseArgs-$myName)" = function ]] && parseArgs-$myName
	[[ -n "$(type -t parseArgs-local)"  && "$(type -t parseArgs-local)" = function ]] && parseArgs-local

	#for arg in "${argList[@]}"; do dump -l arg; done
	#trueVars="verify"
	#local var; for var in $trueVars; do eval $var=true; done
	#falseVars="testMode noEmails noHeaders noCheck traceLog verbose quiet"
	#local var; for var in $falseVars; do eval $var=false; done
	#argList+=(argFlag,minLen,type,scriptVariable,extraToken/exCmd,helpSet,helpText)
	argList+=(-batchMode,9,switch,batchMode,,script2,"Run in batch mode")
	argList+=(-noClear,4,switch,noClear,,script2,"Do not clear the screen on script start")
	argList+=(-noEmails,3,switch,noEmails,,script2,"Turn off emails")
	argList+=(-noHeaders,3,switch,noHeaders,,script2,"Turn off Hello and Goodbye messaging")
	argList+=(-noLog,3,switch,traceLog,,script2,"Turn off logging")
	argList+=(-noNews,3,switch,noNews,,script2,"Do not display the news")
	argList+=(-quiet,1,switch,quiet,,script2,"Turn off all status messages")
 	argList+=(-secondaryMessagesOnly,3,switch,secondaryMessagesOnly,,script2,'Only display secondary messages from child scripts.')
	argList+=(-testMode,5,switch,testMode,,script2,"Test mode, use test data")
	argList+=(-x,1,switch,DOIT,DOIT='echo',script2,"eXperimental mode - no data will be change/committed")
	argList+=(-autoRemote,4,switch,autoRemote,,script2,"Automatically launch remote ssh session if the client is not hosted on the current host")

	argList+=(-allItems,3,switch,allItems,,script,"Perform action on all items in the context of the script, e.g all envs")
	argList+=(-asUser,2,switch,asUser,,script,"Perform action on behalf of another user")
	argList+=(-force,5,switch,force,,script,"Perform action even if it has already been done on the site")
	argList+=(-fork,4,switch,fork,,script,"Fork off sub-process if supported by script")
	#[[ $(Contains ",$administrators," ",$userName,") == true ]] && argList+=(-forUser,4,option,forUser,,script,'Run on behalf of another user (admins only)')
	argList+=(-forUser,4,option,forUser,,script,'Run on behalf of another user (admins only)')
 	argList+=(-ignoreList,7,option,ignoreList,,script,'Comma seperated list if items to ignore, items are based on the script')
 	argList+=(-informationOnly,4,switch,informationOnlyMode,,script,'Only analyze data and print error messages, do not change any data')
	argList+=(-noPrompt,3,switch,verify,"verify=false",script,"Turn off prompt mode, all data needs to be specified on command string")
	argList+=(-noCheck,4,switch,noCheck,,script,"Do not validate the client data in the $warehouseDb.$clientInfoTable table")
	argList+=(-envs,4,option,envs,,envs,"Environment or Environments (e.g. {$courseleafDevEnvs,$courseleafProdEnvs} or comma separated multiples 'test,next'")
	argList+=(-products,4,option,products,,prod,"Product or products (e.g. 'cat' or 'cim' or 'clss' or 'cat,cim')")
	argList+=(-srcEnv,3,option,srcEnv,,src,"Source Environment (e.g. $courseleafDevEnvs,$courseleafProdEnvs)")
	argList+=(-tgtEnv,3,option,tgtEnv,,tgt,"Target Environment (e.g. $courseleafDevEnvs,$courseleafProdEnvs)")
	argList+=(-verbose,1,switch#,verbose,verboseLevel,script,"Additional messaging, -V# sets verbosity level to #")

	cimc=false; cimp=false; cimm=false; cims=false; allCims=false; unset cims; unset cimStr
	argList+=(-cimc,4,switch,cimc,"cims+=('courseadmin')",cim,"CIM Courses")
	argList+=(-cimp,4,switch,cimp,"cims+=('programadmin')",cim,"CIM Programs")
	argList+=(-cimm,4,switch,cimm,"cims+=('miscadmin')",cim,"CIM Miscellanious")
	argList+=(-cims,4,switch,cims,"cims+=('syllubusadmin')",cim,"CIM Syllabi")
	argList+=(-cima,4,switch,allCims,,cim,"Use all CIMs found")

	argList+=(-cat,3,switch,cat,,cat,"Product is CAT")
	argList+=(-cim,3,switch,cim,,cim,"Product is CIM")
	argList+=(-clss,4,switch,clss,,clss,"Product is CLSS/WEN")

	## Setup ENV arguments
	local singleCharArgs="pvt dev test next curr"
	local doubleCharArgs="preview public qa"
	local envStr
	for envStr in $singleCharArgs $doubleCharArgs; do
		[[ $(Contains "$doubleCharArgs" "$envStr") == true ]] && minLen=2 || minLen=1;
		if [[ $myName != 'bashShell' ]]; then unset $envStr; fi
		oldIFS=$IFS; IFS=''
		tempStr="-$envStr,$minLen,switch,env,env='$envStr';$envStr=true,env,Use $(Upper $envStr) as source or target environment"
		argList+=($tempStr)
		IFS=$oldIFS
	done

	help=false;
	argList+=(-help,1,help,,,,"Display help text")

	## Call arg parser
	ParseArgs $myOpts

	if [[ $verboseLevel -ge 3 ]]; then
		local prevScriptVar
		for argDef in "${argList[@]}"; do
			scriptVar=$(echo $argDef | cut  -d ',' -f 4)
			[[ $scriptVar != $prevScriptVar ]] && dump -t $scriptVar && prevScriptVar=$scriptVar
		done
	fi

	[[ $fork == true ]] && forkStr='&' || unset forkStr

	if [[ $forUser != '' ]]; then
		[[ -d /home/$forUser ]] && userName=$forUser || Msg2 $E "Userid specified as -forUser ($forUser) is not valid, ignoring directive"
	fi

	Msg2 $V3 "*** $FUNCNAME -- Completed ***"
	return 0
} #ParseArgsStd

#===================================================================================================
# Display script help -- passed an array of argument definitinons, see ParseArg function
#===================================================================================================
function Help {
	Msg2 $V3 "*** $FUNCNAME -- Starting ***"
	local parseDefs=("$@")
	local helpSet=$(echo $helpSet,script | tr ' ' ',')
	local tempStr="$(ColorK "Usage:") $myName"
	[[ $(Contains ",$helpSet," ",client,") == true ]] && hasClient=true && tempStr="$tempStr [client]"
	tempStr="$tempStr [OPTIONS]"

	[[ $batchMode != true && $noClear != true && $TERM != 'dumb' ]] && clear
	Msg2; Msg2 "$tempStr"; Msg2
	## Print out header info
		[[ $shortDescription != '' ]] && Msg2 "$(ColorK "$shortDescription.")"
		[[ $longDescription != '' ]] && Msg2 && Msg2 "$longDescription" && Msg2
		[[ $scriptHelpDesc != '' ]] && Msg2 && Msg2 "$scriptHelpDesc" && Msg2
		[[ $author != '' ]] && Msg2 "$(ColorK "Author:") $author"
		[[ $supported != '' ]] && Msg2 "$(ColorK "Supported:") $supported"

	## Loop through them and find the max widths for the name and min name
		local maxWidthMin=0
		local maxWidthName=0
		for parseStr in "${argList[@]}"; do
			local argName=$(Lower $(echo $parseStr | cut  -d ',' -f 1))
			[[ ${#argName} -gt $maxWidthName ]] && maxWidthName=${#argName}
			local minLen=$(echo $parseStr | cut  -d ',' -f 2)
			[[ $minLen -gt $maxWidthMin ]] && maxWidthMin=$minLen
		done
		(( maxWidthMin += 1 ))

	Msg2
	Msg2 "$(ColorK "[client]:")"
	Msg2 "^This is the client code (abbreviation) for the client that you wish to work with."


	## print them out
		#dump helpSet validArgs
		local optionsArray switchesArray argGroup argName minLen argType tempStr1 tempStr2 helpText msgString
		unset optionsArray switchesArray argGroup argName minLen argType tempStr1 tempStr2 helpText msgString
		## seperate out options from flags
		for parseStr in "${argList[@]}"; do
			argGroup=$(Lower $(echo $parseStr | cut  -d ',' -f 6))
			#dump parseStr -t argGroup
			[[ $argGroup != '' && $(Contains ",$helpSet," ",$argGroup,") == false ]] && continue
			argName=$(echo $parseStr | cut  -d ',' -f 1)
			#dump -t argName
			if [[ $validArgs != '' ]]; then
				[[ $(Contains ",$(Lower "$validArgs")," ",$(Lower "$argName"),") != true ]] && continue
			fi
			minLen=$(echo $parseStr | cut  -d ',' -f 2)
			argType=$(Lower $(echo $parseStr | cut  -d ',' -f 3))
			helpText=$(echo $parseStr | cut  -d ',' -f 7-)
			tempStr1=$(ColorK ${argName:0:$minLen+1})
			junk=$(( padLen = $maxWidthName - ${#argName} ))
			tempStr2="${argName:$minLen+1}$(PadChar ' ' $padLen)"
			argName="${tempStr1}${tempStr2}"
			msgString="^^$argName - $helpText"
			[[ ${argType:0:6} == 'option' ]] && optionsArray+=("$msgString") || switchesArray+=("$msgString")
		done

	Msg2
	Msg2 "$(ColorK "[OPTIONS]:")"
	## Options
		if [[ ${#optionsArray[@]} -gt 0 ]]; then
			Msg2 "^$(ColorK "Arguments with values (i.e. a flag with value e.g. -flag value):")"
			for msgString in "${optionsArray[@]}"; do
				Msg2 "$msgString"
			done
		fi
	## Switches
		if [[ ${#switchesArray[@]} -gt 0 ]]; then
			Msg2
			Msg2 "^$(ColorK "Arguments without values (i.e. a flag e.g. -flag):")"
			for msgString in "${switchesArray[@]}"; do
				Msg2 "$msgString"
			done
		fi

	## print out script specific help notes
		if [[ ${#helpNotes[@]} -gt 0 ]]; then
			Msg2
			Msg2 "$(ColorK "Script specific notes:")"
			for ((cntr = 0 ; cntr < ${#helpNotes[@]} ; cntr++)); do
				let idx=$cntr+1
		 		Msg2 "^$idx) ${helpNotes[$cntr]}"
			done
		fi

	## General help notes for all scripts
		Msg2
		Msg2 "$(ColorK "General Notes:")"
		local notesClient notesAlways notes
		notesClient+=("The minimum abbreviations for argument flags are indicated in the $(ColorK highlight) color above.")
		notesClient+=("A value of '.' may be specified for client to parse the client value from the current working directory.")
		notesClient+=("A value of '?' may be specified for client to display a selection list of all clients.")

		notesAlways+=("All flags must be delimited from other flags by at lease one blank character.")
		notesAlways+=("While all flags may be specified, not all of them may active.")
		notesAlways+=("If a argument is an option with a value, and the value contains blanks/spaces, the argument value needs to be enclosed in single quotes which need to be escaped on the command line, e.g. -wo \'This is a File Name\'")

		notes=("${notesAlways[@]}")
		[[ $hasClient == true ]] && notes=("${notesClient[@]}" "${notes[@]}")

		idx=1
		for line in "${notes[@]}"; do
			Msg2 ",,+1,,true" "$idx) $line"
			((idx+=1))
		done
		Msg2

		Msg2 $V3 "*** $FUNCNAME -- Completed ***"
		return 0
} # Help

#===================================================================================================
## Make sure the user really wants to do this
## If the first argument is 'loop' then loop back to self if user responds with 'n'
#===================================================================================================
function VerifyContinue {
	[[ $secondaryMessagesOnly == true ]] && return 0
	local mode="$1"
	local verifyPrompt="$2"
	if [[ $verifyPrompt == '' ]]; then verifyPrompt="$mode"; mode='loop'; fi
	local arg tempStr

	Msg2; Msg2 "$verifyPrompt"
	if [[ ${#verifyArgs[@]} -gt 0 ]]; then
		[[ $allItems == true ]] && verifyArgs+=("Auto process all items:$allItems")
		[[ $force == true ]] && verifyArgs+=("Force execution:$force")

		local maxArgWidth
		for arg in "${verifyArgs[@]}"; do tempStr=$(echo $arg | cut -d':' -f1); [[ ${#tempStr} -gt $maxArgWidth ]] && maxArgWidth=${#tempStr}; done
		dots=$(PadChar '.' $maxArgWidth)
		for arg in "${verifyArgs[@]}"; do
			tempStr="$(echo $arg | cut -d':' -f1)"
			tempStr="${tempStr}${dots}"
			tempStr=${tempStr:0:$maxArgWidth+3}
			Msg2 '-,-,+1' "$(ColorK ${tempStr})$(echo $arg | cut -d':' -f2-)"
		done
		[[ $testMode == true ]] && Msg2 '-,-,1' "$(ColorE "*** Running in Test Mode ***")"
		[[ $informationOnlyMode == true ]] && Msg2 '-,-,1' "$(ColorE "*** Information only mode ***")"
	fi

	if [[ $verify == true && $quiet != true ]]; then
		unset ans
		Prompt ans "\n'Yes' to continue, 'No' to exit" 'Yes No'; ans=$(Lower ${ans:0:1})
		if [[ $ans != "y" ]]; then
			[[ $logInDb != false && $myLogRecordIdx != "" ]] && dbLog 'remove' $myLogRecordIdx
			Quit
		fi
	else
		Msg2 "^$(ColorI "Info -- ")'NoPrompt' flag was set, continuing..."
	fi
	Msg
	return 0
} #VerifyContinue

#===================================================================================================
# Standard initializations for Courseleaf Scripts
# Parms:
# 	'courseleaf' - get all items, client, env, site dirs, cims
# 	'getClient' -  get client name
# 	'getEnv' - get environments
# 	'getDirs' - get site dirs
# 	'checkEnvs' - check to make sure env dirs exist
# 	'getCims' - get cims
#===================================================================================================
function Init {
	PushSettings "$FUNCNAME"
	SetFileExpansion 'off'
	Msg2 $V3 "*** Starting: $FUNCNAME ***"

	local trueVars='noPreview noPublic'
	local falseVars='getClient anyClient getProducts getCims getEnv getSrcEnv getTgtEnv getDirs checkEnvs'
	falseVars="$falseVars allowMulti allowMultiProds allowMultiEnvs allowMultiCims"
	for var in $trueVars; do eval $var=true; done
	for var in $falseVars; do eval $var=false; done

	local token
	#printf "%s\n" "$@"
	for token in $@; do
		token=$(Lower $token)
		dump -3 -t token
		if [[ $token == 'courseleaf' || $token == 'all' ]]; then getClient=true; getEnv=true; getDirs=true; checkEnvs=true; fi
		if [[ $token == 'getclient' || $token == 'getclients' ]]; then getClient=true; fi
		if [[ $token == 'anyclient' || $token == 'anyclients' ]]; then anyClient=true; fi
		if [[ $token == 'getproduct' ]]; then getProducts=true; fi
		if [[ $token == 'getproducts' ]]; then getProducts=true; allowMultiProds=true; fi
		if [[ $token == 'getcim' ]]; then getCims=true; fi
		if [[ $token == 'getcims' ]]; then getCims=true; allowMultiCims=true; fi
		if [[ $token == 'nocim' || $token == 'nocims' ]]; then getCims=false; fi
		if [[ $token == 'allcim' || $token == 'allcims' ]]; then allCims=true; fi
		if [[ $token == 'getenv' ]]; then getEnv=true; fi
		if [[ $token == 'getenvs' ]]; then getEnv=true; allowMultiEnvs=true; fi
		if [[ $token == 'getsrcenv' ]]; then getSrcEnv=true; getEnv=false; fi
		if [[ $token == 'gettgtenv' ]]; then getTgtEnv=true; getEnv=false; fi
		if [[ $token == 'getdirs' ]]; then getDirs=true; fi
		if [[ $token == 'checkenv'  || $token == 'checkenvs' || $token == 'checkdir' || $token == 'checkdirs' ]]; then checkEnvs=true; fi
		if [[ $token == 'nopreview' ]]; then noPreview=true; fi
		if [[ $token == 'nopublic' ]]; then noPublic=true; fi
	done
	dump -3 -t -t parseStr getClient getEnv getDirs checkEnvs getProducts getCims allCims noPreview noPublic

	#===================================================================================================
	## Get data from user if necessary
	if [[ $getClient == true ]]; then
		local checkClient; unset checkClient
		if [[ $noCheck == true ]]; then
			Msg2 $W "Requiring a client value and 'noCheck' flag was set"
			checkClient='noCheck';
		fi
		Prompt client 'What client do you wish to work with?' "$checkClient";
		Client="$client"; client=$(Lower $client)
		if [[ $client == '.' ]]; then
			client=$(basename $(pwd))
			if [[ $client == 'qa' || $client == 'test' || $client == 'next' || $client == 'curr'  || $client == 'preview'  || $client == 'public' ]]; then
				pushd $(pwd)
				cd ..
				Client=$(basename $(pwd)); client=$(Lower $client)
				popd
			fi
			getEnv=false; getSrcEnv=false; getTgtEnv=false; getDirs=false; checkEnvs=false
			srcDir="$(pwd)/web"
		fi
		#[[ $client == '*' || $client == 'all' || $client == '.' ]] && PopSettings "$FUNCNAME" && return 0
	fi

	## Special processing for the 'internal' site
	if [[ $getEnv == true && $client == 'internal' ]]; then
		srcDir=/mnt/internal/site/stage
		[[ ! -d "$srcDir" ]] && Msg2 $T "Client = 'internal' but could not locate source directory:\n\t$srcDir"
		nextDir="/mnt/internal/site/stage"
		pvtDir=/mnt/dev11/web/internal-$userName
		[[ $env == '' ]] && env='next'
		eval "srcDir="\$${env}Dir""
		PopSettings "$FUNCNAME"
		siteDir="$srcDir"
		tgtDir="$pvtDir"
		return 0
	fi

	## Process env and envs
	if [[ $getEnv == true || $getSrcEnv == true || $getTgtEnv == true ]]; then
		unset clientEnvs
		if [[ $noCheck == true ]]; then
			Msg2 $W "Requiring a environment value and 'noCheck' flag was set"
			clientEnvs='noCheck'
		else
			if [[ $client == '*' || $client == 'all' || $client == '.' ]]; then
				clientEnvs="$courseleafDevEnvs,$courseleafProdEnvs"
			else
				unset notIn
				if [[ $noPreview == true || $noPublic == true ]]; then notIn='and env not in('; fi
				if [[ $noPreview == true ]]; then notIn="$notIn'preview'"; fi
				if [[ $noPublic == true ]]; then if [[ $noPreview == true ]]; then notIn="$notIn,'public'"; else notIn="$notIn'public'"; fi; fi
				if [[ $noPreview == true || $noPublic == true ]]; then notIn="$notIn)"; fi
				sqlStmt="select distinct env from $siteInfoTable where (name=\"$client\" or name=\"$client-test\") $notIn order by env"
				RunSql 'mysql' $sqlStmt
				if [[ ${#resultSet[@]} -eq 0 ]]; then
					for checkEnv in pvt dev test next curr; do
						[[ $(SetSiteDirs 'check' $checkEnv) == true ]] && clientEnvs="$clientEnvs $checkEnv"
					done
				else
					for result in "${resultSet[@]}"; do
						clientEnvs="$clientEnvs $result"
					done
					[[ $(SetSiteDirs 'check' 'pvt') == true ]] && clientEnvs=" pvt$clientEnvs"
				fi
				clientEnvs=${clientEnvs:1}
			fi
		fi

		if [[ $getEnv == true ]]; then
			unset promptModifer varSuffix
			if [[ $allowMultiEnvs == true ]]; then
				[[ $env != '' && $envs == '' ]] && envs="$env" && unset env
				varSuffix='s'
				promptModifer=" (comma separated)"
				clientEnvs="all $clientEnvs"
			fi
			Prompt "env$varSuffix" "What environment$varSuffix/site$varSuffix do you wish to use$promptModifer?" "$clientEnvs"; env=$(Lower $env)
		fi
		if [[ $getSrcEnv == true ]]; then
			clientEnvsSave="$clientEnvs"
			clientEnvs="$clientEnvs skel"
			Prompt srcEnv "What $(ColorK source) environment/site do you wish to use?" "$clientEnvs"; env=$(Lower $env)
			clientEnvs="$clientEnvsSave"
		fi
		if [[ $getTgtEnv == true ]]; then
			if [[ $srcEnv != '' ]]; then clientEnvs=$(echo $clientEnvs | sed s"/$srcEnv//"g); fi
			unset defaultEnv
			[[ $addPvt == true && $(Contains "$clientEnvs" 'pvt') == false ]] && clientEnvs="pvt,$clientEnvs"
			[[ $(Contains "$clientEnvs" 'pvt') == true ]] && defaultEnv='pvt'
			Prompt tgtEnv "What $(ColorK target) environment/site do you wish to use?" "$clientEnvs" "$defaultEnv"; env=$(Lower $env)
		fi

		if [[ $envs != '' ]]; then
			if [[ $envs = 'all' ]]; then
				envs="$clientEnvs"
				envs=$(sed s'/all//' <<< $envs)
			else
				local i j tmpEnvs
				tmpEnvs="$envs"
				unset envs
				for i in $(echo $tmpEnvs | tr ',' ' '); do
					for j in $(echo $clientEnvs | tr ',' ' '); do
						[[ $i == ${j:0:${#i}} ]] && envs="$envs,$j" && break;
					done
				done
				envs="${envs:1}"
			fi
		fi
		if [[ $srcEnv != '' ]]; then
			for j in $(echo $clientEnvs skel | tr ',' ' '); do
				[[ $srcEnv == ${j:0:${#srcEnv}} ]] && srcEnv="$j" && break;
			done
		fi
		if [[ $tgtEnv != '' ]]; then
			for j in $(echo $clientEnvs | tr ',' ' '); do
				[[ $tgtEnv == ${j:0:${#tgtEnv}} ]] && tgtEnv="$j" && break;
			done
		fi
	fi
	dump -3 clientEnvs env envs srcEnv tgtEnv -n

	#===================================================================================================
	## get products
	if [[ $getProducts == true && $client != '' ]]; then
		if [[ $client == '*' || $client == 'all' || $client == '.' ]]; then
			validProducts="$(tr ',' ' ' <<< $(Upper "$courseleafProducts"))"
		else
			unset validProducts
			## Get the products for this client
			sqlStmt="select products from $clientInfoTable where (name=\"$client\")"
			RunSql 'mysql' $sqlStmt
			if [[ ${#resultSet[@]} -gt 0 ]]; then
				## Remove the extra vanity products from the validProducts list
				for prod in $(tr ',' ' ' <<< ${resultSet[0]}); do
					[[ $(Contains ",$skipProducts," ",$prod,") == true ]] && continue
					validProducts="$validProducts,$prod"
				done
				[[ ${validProducts:0:1} == ',' ]] && validProducts=${validProducts:1}
				validProducts="$(tr ',' ' ' <<< $validProducts)"
			fi
		fi
		unset promptModifer
		[[ $allowMultiProds == true ]] && prodVar='products' && promptModifer=" (comma separated)" || prodVar='product'
		## If there is only one product for this client then us it, otherwise prompt user
		prodCnt=$(grep -o ' ' <<< "$validProducts" | wc -l)
		if [[ $prodCnt -gt 0 ]]; then
			Prompt $prodVar "What $prodVar do you wish to work with$promptModifer?" "$validProducts"
			eval $prodVar=$(Lower \$$prodVar)
		else
			Msg2 $NT1 "Only one value valid for '$prodVar', using '$validProducts'"
			eval $prodVar=$(Lower $validProducts)
		fi
	fi

	## If all clients then split
	[[ $client == '*' || $client == 'all' || $client == '.' ]] && PopSettings "$FUNCNAME" && return 0

	#===================================================================================================
	## Set Directories based on the current host name and client name
	# Set src and tgt directories based on client and env
	[[ $getDirs == true ]] && SetSiteDirs 'setDefault'
	dump -3 pvtDir devDir testDir nextDir currDir previewDir publicDir skelDir checkEnvs

	#===================================================================================================
	## Check to see if the srcDir exists
	#if [[ $checkEnvs == true && $anyClient != true && $srcDir == '' && $allowMultiEnvs != true ]] && [[ $getDirs == true || $getEnv == true || $getSrcEnv == true ]]; then
	if [[ $srcDir == '' && $allowMultiEnvs != true ]] && [[ $getDirs == true || $getEnv == true || $getSrcEnv == true ]]; then
		[[ $srcEnv == '' && $env != '' ]] && srcEnv=$env
		dump -3 srcEnv
		local i
		for i in $(echo "$courseleafDevEnvs $courseleafProdEnvs" | tr ',' ' ') skel; do
			if [[ $srcEnv == $i ]]; then
				chkDirName="${i}Dir"; chkDir="${!chkDirName}"
				[[ ! -d $chkDir && $checkEnvs == true && $noCheck != true ]] && Msg2 $T "Env is '$(TitleCase $i)' and directory '$chkDir' not found\nProcess stopping."
				srcDir=$chkDir
				break
			fi
		done
		dump -3 srcDir
	fi

	#===================================================================================================
	## Check to see if the tgtDir exists
	if [[ $getTgtEnv == true && $getDirs == true && $tgtDir == '' && $allowMultiEnvs != true ]]; then
		[[ $tgtEnv == '' && $env != '' ]] && tgtEnv=$env
		dump -3 tgtEnv
		local i
		for i in $(echo "$courseleafDevEnvs $courseleafProdEnvs" | tr ',' ' '); do
			if [[ $tgtEnv == $i ]]; then
				chkDirName="${i}Dir"; chkDir="${!chkDirName}"
				[[ ! -d $chkDir && $checkEnvs == true && $noCheck != true ]] && Msg2 $T "Env is '$(TitleCase $i)' and directory '$chkDir' not found\nProcess stopping."
				tgtDir=$chkDir
				break
			fi
		done
		dump -3 tgtDir
	fi

	#===================================================================================================
	## find CIMs
	if [[ $getCims == true || $allCims == true ]] && [[ $getDirs == true ]] && [[ $cimStr == '' ]]; then
		[[ ${#cims} -eq 0 ]] && GetCims $srcDir
		[[ $cimStr == '' ]] && cimStr=$(printf -- "%s, " "${cims[@]}") && cimStr=${cimStr:0:${#cimStr}-2}
	fi

	#===================================================================================================
	## If testMode then run local customizations
		[[ $testMode == true && $(type -t testmode-$myName) == 'function' ]] && testMode-$myName
		[[ $testMode == true && $(type -t testmode-local) == 'function' ]] && testMode-local

	PopSettings "$FUNCNAME"
	Msg2 $V3 "*** Ending: $FUNCNAME ***"

	siteDir="$srcDir"
	return 0
} #Init

#===================================================================================================
## Get CIMs
#===================================================================================================
function GetCims {
	Msg2 $V3 "*** $FUNCNAME -- Starting ***"
	local siteDir=$1 ans suffix validVals
	if [[ $allowMultiCims == true ]]; then
		suffix=', a for all cims'
		validVals='Yes No All'
	else
		unset suffix
		validVals='Yes No'
	fi
	dump -3 -t siteDir allowMultiCims suffix validVals

	cd $siteDir/web
	adminDirs=($(ProtectedCall "find -maxdepth 1 -type d -name '[a-z]*admin' -printf '%f\n' | sort"))

	[[ -d $siteDir/web/cim ]] && adminDirs+=('cim')
	for dir in ${adminDirs[@]}; do
		dump -3 -t -t dir
		[[ $(Contains "$dir" ".old") == true || $(Contains "$dir" ".bak") == true ]] && continue
		if [[ -f $siteDir/web/$dir/cimconfig.cfg ]]; then
			[[ $onlyCimsWithTestFile == true && ! -f $siteDir/web/$dir/wfTest.xml ]] && continue
			if [[ $verify == true && $allCims != true ]]; then
				unset ans
				Prompt ans "\tFound CIM Instance '$(ColorK $dir)' in source instance,\n\t\tdo you wish to use it? (y to use$suffix)? >"\
			 			"$validVals"; ans=$(Lower ${ans:0:1});
				[[ $ans == 'a' ]] && cims=(${adminDirs[@]}) && break
				if [[ $ans == 'y' ]]; then
					cims+=($dir);
					[[ $allowMultiCims != true ]] && break
				fi
			else
				cims+=($dir)
			fi
		fi
	done
	if [[ $cimStr == '' ]]; then
		cimStr=$(printf -- "%s, " "${cims[@]}")
		cimStr=${cimStr:0:${#cimStr}-2}
	fi
	#[[ $products == '' ]] && products='cim' || products="$products,cim"
	[[ $verbose == true && $verboseLevel -ge 2 ]] && DumpArray 'cims' ${cims[@]} && dump cimStr

	Msg2 $V3 "*** $FUNCNAME -- Completed ***"
	return 0
} #GetCims

#===================================================================================================
# Pause execution
#===================================================================================================
function Pause {
	local ans
	if [[ "$*" != '' ]]; then
		printf "${colorGreen}$*\n${colorDefault}"
	else printf "${colorGreen}*** Script ($myName) execution paused, please press enter to continue (x to quit, d for debug) ***${colorDefault}\n";
	fi

	ans='junk'
	while [[ $ans != '' ]]; do
		unset ans; read ans; ans=$(Lower ${ans:0:1});
		[[ "$ans" == 'x' ]] && Goodbye 'quickquit'
		[[ "$ans" == '?' ]] && echo -e "Stack trace:" && printf '\t%s\n' "${FUNCNAME[@]}"
		[[ "$ans" == 'v' ]] && set -xv
	done

	return 0
} #Pause


#===================================================================================================
# Display a message with optional logging,
#	if global variable $quiet is 1 or true then do not display or log message
#	if global variable $logit is 1 or true then write message out to the global variable $logfile
#	First Char of token1 processing
#		'v' - only if verbose == true
#		'w' - warning message
#		'e' - error message
#		't' - termination message, processing will be stopped
#	Last Char of token1 processing
#		If the last char of token1 of the message is numeric, then it is assumed to be a message
#		level and is compared against the current debug level (debugLevel) and the message isS
#		only displayde if $msgLevel >= $debugLevel
#
# Msg stringToPrint
#
#===================================================================================================
function Msg {
	set +xv # Turn off trace
	SetFileExpansion 'off'
	local string="$*"
	[[ $string == '' ]] && echo && SetFileExpansion && return 0
	local numTabs=0
	local alertStr msgLevel
	local fold=true
	local sttySize
	local screenWidth=80
	[[ $TERM == 'xterm' ]] && sttySize=$(stty size </dev/tty) || fold=false
	[[ $sttySize != '' ]] && screenWidth=$(stty size </dev/tty | cut -d' ' -f2)
	[[ $allowAlerts != true ]] && alertStr='' || alertStr="\a"

	local firstChar="$(Upper "${string:0:1}")"
	local secondChar="$(Upper "${string:1:1}")"
	local thirdChar="$(Upper "${string:2:1}")"
	local fourthChar="$(Upper "${string:3:1}")"
	#dump firstChar secondChar thirdChar fourthChar

	## If the first chare is '-' then turn off folding
		if [[ $firstChar == '-' ]]; then
			string=${string:1}
			firstChar="$(Upper "${string:0:1}")"
			secondChar="$(Upper "${string:1:1}")"
			thirdChar="$(Upper "${string:2:1}")"
			fourthChar="$(Upper "${string:3:1}")"
			fold=false
		elif [[ $firstChar == 'L' && $secondChar == ' ' ]]; then
			string=${string:2}
			firstChar="$(Upper "${string:0:1}")"
			secondChar="$(Upper "${string:1:1}")"
			thirdChar="$(Upper "${string:2:1}")"
			fourthChar="$(Upper "${string:3:1}")"
		fi

	## Parse message prefix
		local msgType='normal'
		if [[ $firstChar == '\' ]]; then
			unset secondChar
			msgText="$string"
		elif [[ $firstChar == 'V' ]] && [[ $secondChar == '' || $secondChar == ' ' || $secondChar == 'T' || $(IsNumeric $secondChar) == true ]]; then
			msgType='verbose'
			[[ $(IsNumeric $secondChar) == true ]] && msgLevel=$secondChar
			[[ $msgLevel == '' && $verbose == false ]] && SetFileExpansion && return 0
			[[ $msgLevel -gt $verboseLevel ]] && SetFileExpansion && return 0
			[[ $thirdChar == 'T' || $(IsNumeric $fourthChar) == true ]] && numTabs=$fourthChar
		elif [[ $firstChar == 'T' || $firstChar == 'E' ]] && [[ $secondChar == '' || $secondChar == 'T' ]]; then
			[[ $firstChar == 'T' ]] && msgType='terminate' || msgType='error'
		elif [[ $firstChar == 'W' ]] && [[ $secondChar == '' || $secondChar == 'T' ]]; then
			msgType='warning'
		elif [[ $firstChar == 'I' ]] && [[ $secondChar == '' || $secondChar == 'T' ]]; then
			msgType='info'
		elif [[ $firstChar == 'N' ]] && [[ $secondChar == '' || $secondChar == 'T' ]]; then
			msgType='note'
		else
			msgType='normal'
			msgText="$string"
		fi

	## Process message type, add prefix if needed
		local unset msgPrefix
		[[ $msgType != 'normal' ]] && msgText="$(echo $string | cut -d' ' -f2-)"
		[[ $msgType != 'normal' && $msgType != 'verbose' ]] && msgPrefix="$(Color$firstChar "*$(TitleCase $msgType)*") -- "

	## Add alert
		[[ $msgType == 'terminate' || $msgType == 'error' ]] && msgText="${msgText}${alertStr}"

	## Add Tabs
		if [[ $firstChar == 'T' && $(IsNumeric $secondChar) == true ]]; then
			msgText="$(echo $string | cut -d' ' -f2-)"
			numTabs=$secondChar
		else
			[[ $(IsNumeric $thirdChar) == true ]] && numTabs=$thirdChar
		fi

		if [[ $numTabs -gt 0 ]]; then
			local i
			for ((i = 0 ; i < $numTabs; i++)); do msgPrefix="     $msgPrefix"; done
		fi

		local var msgPrefixLen=${#msgPrefix}
		local msgPadLen=0

		[[ $msgType != 'normal' ]] && let msgPadLen=${#msgType}+6+$numTabs*5 || msgPadLen=$msgPrefixLen

	#dump msgType msgPadLen msgPrefixLen msgPrefix
	## Print message, folding text as necessary
		[[ $msgType != 'T' && $quiet == true ]] && SetFileExpansion && return 0
		msgText=${msgPrefix}${msgText}
		[[ $secondaryMessagesOnly == true && msgText != '' ]] && msgText="     $msgText" && let msgPadLen=$msgPadLen+5

		# dump msgText msgType screenWidth fold msgPadLen; echo '${#msgText} = >'${#msgText}'<'
		if [[ ${#msgText} -le $screenWidth || $fold != true ]]; then
			[[ ${myRhel:0:1} -gt 5 ]] && stdbuf -oL echo -en "$msgText\n" || echo -en "$msgText\n"
		else
			## Break line into segiments based on screen width
			let breakLineAt=$screenWidth-$msgPadLen
			while [[ true ]]; do
				## Find the space char nearest to the screen width
				while [[ ${msgText:$breakLineAt:1} != ' ' ]]; do
					let breakLineAt=$breakLineAt-1
				done
				#dump breakLineAt

				tmpStr=${msgText:0:$breakLineAt}
				msgText=$(PadChar ' ' $msgPadLen)${msgText:$breakLineAt+1}
				[[ ${myRhel:0:1} -gt 5 ]] && stdbuf -oL echo -en "$tmpStr\n" || echo -en "$tmpStr\n"
				breakLineAt=$screenWidth
				if [[ ${#msgText} -lt $screenWidth ]]; then
					[[ ${myRhel:0:1} -gt 5 ]] && stdbuf -oL echo -en "$msgText\n" || echo -en "$msgText\n"
					break
				fi
			done
		fi

	## Termiate script if necessary
		if [[ $msgType == 'terminate' ]]; then
			[[ $calledViaScripts == true ]] && \
				Pause "\n$(ColorE "*** Script execution terminated, please review messages***\n*** Press 'enter' to return to the shell ***")"
			PopSettings "$FUNCNAME"
			Goodbye -1
		fi
	SetFileExpansion

	return 0
} #Msg

#===================================================================================================
# Set global indention level
#===================================================================================================
function SetIndent {
	local indent=$1
	[[ $indentLevel == '' ]] && indentLevel=0
	if [[ ${indent:0:1} == '+' || ${indent:0:1} == '-' ]]; then
		let indentLevel=${indentLevel}${indent:0:1}${indent:1}
	else
		indentLevel=$indent
	fi
	return 0
}

#===================================================================================================
# Display a message with optional logging,
#	if global variable $quiet is true then do not display message
#	if global variable $logit is true then write message out to the global variable $logfile
#
#	'<msgType>,<msgLevel>,<msgTabs>,<msgMode>,<msgFold>'
#	<msgType> in {'-','Note','Info','Warning','Error','Terminate','Verbose'}, default is '-'
#	<msgLevel> in {'-','#number'} where #number is a integer, defaout is '0'
#	<msgTabs> in {'-','#number'} where #number is a integer which can be prefixed with a '+' or '-',
#				default is '+0'
#	<msgMode> in {'-','Screen','Log','Both'}; default is 'Screen'
#	<msgFold> in {'-','true','false'}; default is 'true'
#
# e.g.
# SetIndent 0 ## Set indent level at zero
# Msg2 "1This is a normal message without any controls 2This is a normal message without any controls"
# Msg2 $NT "This is a normal message indented once"
# SetIndent 1 ## Set indent level at one
# Msg2 $IT2 "This is an^info message indented twice beyond indent level"
# SetIndent '-1' ## Set indent level in one
# Msg2 $NT1 "This is an note message indented once"
# Msg2 $E$MsgNoFold "This is an error, do not fold the message This is an error, do not fold the message"
# Msg2 $T "This is a terminating message"
#
#===================================================================================================
## Msg2 Shortcuts for typical msg control codes,e.g. $N or $NT2
MsgNoFold=',false'
MsgFold=',true'
for msgType in 'N' 'I' 'W' 'E' 'T' 'V'; do
	eval ${msgType}=\'${msgType},-,-,S\'
	eval ${msgType}1=\'${msgType},1,-,S\'
	eval ${msgType}2=\'${msgType},2,-,S\'
	eval ${msgType}3=\'${msgType},3,-,S\'
	eval ${msgType}4=\'${msgType},4,-,S\'
	eval ${msgType}T=\'${msgType},-,+1,S\'
	eval ${msgType}T1=\'${msgType},-,+1,S\'
	eval ${msgType}T2=\'${msgType},-,+2,S\'
	eval ${msgType}T3=\'${msgType},-,+3,S\'
done

function Msg2 {
	PushSettings "$FUNCNAME"
	set +xv # Turn off trace
	SetFileExpansion 'off'

	## Sub function to to the actual outout
	function Msg2WriteIt {
		[[ $msgMode == 'S' || $msgMode = 'B' ]] && [[ $quiet != true ]] && echo -e "$*"
		[[ $msgMode == 'L' || $msgMode = 'B' || $logit == true ]] && echo -e "$*" >> $logFile
		return 0
	}

	local msgCtrl
	[[ ${#*} -gt 1 ]] && msgCtrl="$1" && shift
	local msgText="$*"
	[[ $msgCtrl == '' ]] && msgCtrl='normal,0,+0,S,true'
	local terminateProcessing=false
	[[ $indentLevel == '' ]] && indentLevel=0
	[[ $tabStr = '' ]] && tabStr="$(PadChar ' ' 5)"
	local msgType msgLevel msgTabs msgMode msgFold
	unset msgType msgLevel msgTabs msgMode msgFold
	dump -4 -n msgText -t msgCtrl

	## Parse control string
	local numTokens=1; for (( tCntr=0; tCntr<=${#msgCtrl}; tCntr++ )); do [[ ${msgCtrl:$tCntr:1} == ',' ]] && let numTokens=numTokens+1; done
	msgType=$(cut -d',' -f1 <<< $msgCtrl)
	[[ $numTokens -gt 1 ]] && msgLevel=$(cut -d',' -f2 <<< $msgCtrl)
	[[ $numTokens -gt 2 ]] && msgTabs=$(cut -d',' -f3 <<< $msgCtrl)
	[[ $numTokens -gt 3 ]] && msgMode=$(cut -d',' -f4 <<< $msgCtrl)
	[[ $numTokens -gt 4 ]] && msgFold=$(cut -d',' -f5 <<< $msgCtrl)
	#[[ $verboseLevel -ge 4 ]] && echo -e '\tmsgLevel = >'$msgLevel'<'
	#dump -4 -t msgType msgTabs msgMode msgFold msgText

	[[ $msgType == '.' || $msgType  == '-' || $msgType  == '' ]] && msgType='normal'
	[[ $msgType != 'normal' ]] && msgType=$(Upper ${msgType:0:1})
	[[ $msgLevel == '-' || $msgLevel == '.' || $msgLevel == '' ]] && msgLevel=0
	[[ $msgTabs  == '-' || $msgTabs  == '.' || $msgTabs  == '' ]] && msgTabs='+0'
	[[ $msgMode  == '-' || $msgMode  == '.' || $msgMode  == '' ]] && msgMode='S' || msgMode=$(Upper ${msgMode:0:1})
	[[ $msgFold  == '-' || $msgFold  == '.' || $msgFold  == '' ]] && msgFold=true

	[[ $verboseLevel -ge 4 ]] && echo -e '\tmsgLevel = >'$msgLevel'<'
	dump -4 -t msgType msgTabs msgMode msgFold msgText

	## Check to see if we should just quit
	if [[ $msgLevel != '' && $msgLevel -gt $verboseLevel ]] || [[ $quiet == true && $msgMode != 'L' && $msgMode != 'B' ]]; then
		SetFileExpansion
		PopSettings "$FUNCNAME"
		return 0
	fi

	## Set prefix
	local msgPrefix=''
	local msgSuffix=''
	local subtractFactor=0
	local tempStr=$(ColorI)
	local subtractor1=${#tempStr}
	local tempStr=$(ColorT)
	local subtractor2=${#tempStr}

	[[ $msgType == 'N' ]] && msgPrefix="$(ColorI "*Note*") -- " && subtractFactor=$subtractor1
	[[ $msgType == 'I' ]] && msgPrefix="$(ColorI "*Info*") -- " && subtractFactor=$subtractor1
	[[ $msgType == 'W' ]] && msgPrefix="$(ColorW "*Warning*") -- " && subtractFactor=$subtractor1 && msgSuffix="\a"
	[[ $msgType == 'E' ]] && msgPrefix="$(ColorE "*Error*") -- " && subtractFactor=$subtractor1 && msgSuffix="\a"
	[[ $msgType == 'T' ]] && msgPrefix="\n$(ColorT "*Fatal Error*") -- " && subtractFactor=$subtractor2 && terminateProcessing=true && msgSuffix="\a"
	[[ $msgType == 'V' ]] && msgText="$(ColorV "$msgText")" && subtractFactor=$subtractor1

	[[ $allowAlerts != true || $batchMode != true ]] && unset msgSuffix

	## If warning or error add to message accumulators
	[[ $msgType == 'W' ]] && warningMsgsIssued=true && warningMsgs+=("$(sed s"/\^//g" <<< "${msgPrefix}${msgText}")")
	[[ $msgType == 'E' || $msgType == 'T' ]] && errorMsgsIssued=true && errorMsgs+=("$(sed s"/\^//g" <<< "${msgPrefix}${msgText}")")

	## Add tabs based on global indentLevel value plus message tabs value
	let msgTabs=${indentLevel}${msgTabs:0:1}${msgTabs:1}
	local tabCntr; for ((tabCntr = 0 ; tabCntr < $msgTabs; tabCntr++)); do msgPrefix="${tabStr}${msgPrefix}"; done

	## Construct message
	msgText="${msgPrefix}${msgText}${msgSuffix}"

	## Convert '^' chars to tabStr
	msgText="$(sed s"/\^/$tabStr/g" <<< "$msgText")"

	## Set screenwidth
	local screenWidth=80
	[[ $TERM == 'xterm' ]] && screenWidth=$(stty size </dev/tty | cut -d' ' -f2) || msgFold=false
	dump -4 -t screenWidth msgFold #;echo -e '\t${#msgText} = >'${#msgText}'<'

	## Display / log message
	if [[ $msgFold == false || ${#msgText} -le $screenWidth ]]; then
		Msg2WriteIt "$msgText"
	else
		## Find breakpoint for the first line and print
		local cutAt
		let cutAt=$screenWidth+$subtractFactor-2
		local nextChar=${msgText:$cutAt:1}
		if [[ $nextChar != '' ]]; then
			for ((cutAt = $cutAt ; cutAt > 0 ; cutAt--)); do
			  [[ ${msgText:$cutAt:1} == ' ' ]] && break
			done
		fi
		[[ $cutAt -le 0 ]] && cutAt=$screenWidth
		Msg2WriteIt "${msgText:0:$cutAt+1}"
		msgText=${msgText:$cutAt+1}

		## process the remaining text using the fold command
		tmpFile=$(mkTmpFile "$FUNCNAME")
		let foldCols=$screenWidth-${#msgPrefix}
		let padLen=${#msgPrefix}-$subtractFactor
		padStr=$(PadChar ' ' $padLen)
		fold -sw $foldCols <<< $(echo "$msgText") > $tmpFile
		while read -r line; do
			Msg2WriteIt "${padStr}${line}"
		done < $tmpFile
		rm -f $tmpFile
	fi

	SetFileExpansion
	PopSettings "$FUNCNAME"
	## Quit if terminating message
	[[ $terminateProcessing == true ]] && Msg2 && Goodbye -1

	return 0
} # Msg2

#===================================================================================================
# Set the standard output file name
# args <client> <env> <product>
#===================================================================================================
function GetOutputFile {
	local client="$1"
	local env="$2"
	local product="$3"
	local outDir outFile outFileName
	outFileName=$myName.out
	[[ $client == 'all' || $client == '*' ]] && client='allClients'
	[[ $env == 'all' || $env == '*' ]] && env='allClients'
	[[ $product == 'all' || $product == '*' ]] && product='allClients'

	## Set directory
		if [[ -d $localClientWorkFolder ]]; then
			outDir="$localClientWorkFolder"
			[[ $client != '' ]] && outDir="$outDir/$client"
		elif [[ $client != '' && -d "$clientDocs/$client" ]]; then
			outDir="$clientDocs/$client"
			[[ -d $outDir/Implementation ]] && outDir="$outDir/Implementation"
			[[ -d $outDir/Attachments ]] && outDir="$outDir/Attachments"
			[[ $product != '' && -d $outDir/$(Upper $product) ]] && outDir="$outDir/$(Upper $product)"
		else
			outDir=$HOME/$myName
		fi
		[[ ! -d $outDir ]] && $DOIT mkdir -p $outDir

	# Set file name
		[[ $env != '' ]] && outFileName=$env-$outFileName
		[[ $client != '' ]] && outFileName=$client-$outFileName
		outFile=$outDir/$outFileName
		[[ -f $outFile ]] && mv -f $outFile $outFile.old

	echo "$outFile"
	return 0
} #GetOutputFile

#===================================================================================================
# Find a executable file using the same logic as callPgm
# <pgmName>
#===================================================================================================
function GetPgmFile {
	local exName="$1"

	## Get a list of file extensions to search fo
		unset searchForFileExtensions
		sqlStmt="select scriptData1 from $scriptsTable where name =\"callPgm\" "
		RunSql 'mysql' $sqlStmt
		[[ ${#resultSet[0]} -ne 0 ]] && searchForFileExtensions="$(echo ${resultSet[0]} | tr ',' ' ')"
		IfMe dump searchForFileExtensions
		[[ $searchForFileExtensions == '' ]] && Msg2 $T "$FUNCNAME: Could not lookup the 'searchForFileExtensions'"

	## Look for the file
		unset executeFile foundFile
		scriptDirs=($(find $TOOLSPATH/src -maxdepth 1 -type d \( ! -iname '.*' \) -printf "%f " ))
		for dir in ${pathDirs[@]}; do
			[[ ${dir:0:4} == '/usr' || $dir == '/bin' || $dir == '/sbin' ]] && continue
			#dump -4 -n -t dir
			for fileExt in $searchForFileExtensions; do
				fileExt=".$fileExt"
				IfMe echo -e "\t\t$dir/$exName$fileExt"
				[[ -r $dir/$exName$fileExt ]] && executeFile=$dir/$exName$fileExt && foundFile=true && break
				for scriptDir in "${scriptDirs[@]}"; do
					#echo -e "\t\t$(pwd)/$scriptDir/$exName$fileExt"
					[[ -r $dir/$scriptDir/$exName$fileExt ]] && executeFile=$dir/$scriptDir/$exName$fileExt && foundFile=true && break
				done
				[[ $foundFile == true ]] && break
			done
			[[ $foundFile == true ]] && break
		done

	[[ $foundFile != true ]] && Msg2 $T "$FUNCNAME: Execute file for '$exName' not found." || echo $executeFile

	return 0
}

#===================================================================================================
# Write a 'standard' format courseleaf changelog.txt
# args: "logFileName" ${lineArray[@]}
#===================================================================================================
function WriteChangelogEntry {
	[[ $DOIT != '' || $listOnly == true || $informationOnlyMode == true ]] && return 0
	local ref=$1[@]
	local logFile="$2"
	[[ ! -f "$logFile" ]] && touch $logFile

	## Write out records
	[[ $(tail -n 1 $logFile) != '' ]] && echo >> $logFile && echo >> $logFile
	printf "$userName\t$(date) via '$myName' version: $version\n" >> $logFile
	[[ $ref != '' ]] && printf '\t%s\n' "${!ref}" >> $logFile

	return 0
}

#===================================================================================================
# Write log messages to the end of a file
# args: "logFileName" <prefix> <logline>
# If logline is not passed then a preformatted string will be written out:
# 	$beginCommentChar $(date) by $userName, client: '$client', Env: '$env'$endCommentChar
#===================================================================================================
function LogInFile {
	[[ $DOIT != '' || $listOnly == true || $informationOnlyMode == true ]] && return 0
	local file=$1; shift
	local beginCommentChar='##'
	[[ $1 != '' ]] && local beginCommentChar="$1" && shift
	[[ $* != '' ]] && logString="$*" || unset logString
	local endCommentChar
	[[ $beginCommentChar == '/*' ]] && endCommentChar=' */' || unset endCommentChar
	#echo '$file = >'$file'<'; echo '$beginCommentChar == >'$beginCommentChar'<'; echo '$logString == >'$logString'<'

	## Do we already have a comment block at end if file, if not add
		unset grepStr
		grepStr=$(ProtectedCall "grep \"$beginCommentChar Change/Commit/Patch History\" $file")
		if [[ $grepStr == '' ]]; then
			echo >> $file
			echo "${beginCommentChar}$(head -c 100 < /dev/zero | tr '\0' "=")${endCommentChar}" >> $file
			echo "${beginCommentChar} Change/Commit/Patch History$endCommentChar" >> $file
			echo "${beginCommentChar}$(head -c 100 < /dev/zero | tr '\0' "=")${endCommentChar}" >> $file
		fi
	## Add log record or passed string
		if [[ $logString == '' ]]; then
			echo "${beginCommentChar} $(date) updated by $userName via ${myName}${endCommentChar}" >> $file
		else
			echo -e "${beginCommentChar}\t\t$logString" >> $file
		fi

	return 0
}

#===================================================================================================
# Prompt user for a value
# Usage: varName promptText [validationList] [defaultValue] [autoTimeoutTimer]
# varName in the caller will be set to the response
#===================================================================================================
function Prompt {
	declare promptVar=$1
	declare promptText=$2
	declare validateList=$3
	declare defaultVal=$4
	declare timeOut=${5:-0}
	declare validateListString="$(echo $validateList | tr " " ",")"
	if [[ $defaultVal != '' ]]; then
		validateListString=",$validateListString,"
		validateListString=$(sed "s/,${defaultVal},/,\\${colorDefaultVal}${defaultVal}\\${colorDefault},/" <<< "$validateListString")
		validateListString="${validateListString:1:${#validateListString}-2}"
	fi
	if [[ "$promptText" != "" && "$validateList" != "" ]]; then
		[[ "$validateList" != '*optional*' && "$validateList" != '*any*'  ]] && promptText="$promptText ($validateListString, or 'X' to quit)";
	fi
	local respFirstChar rc readTimeOutOpt
	local numTabs=0
	IFS=' ' read -ra validValues <<< $(echo $validateList | tr "," " ")
	[[ $timeOut -ne 0 && $timeOut != '' ]] && readTimeOutOpt="-t $timeOut" || unset readTimeOutOpt

	#===================================================================================================
	## Main
	## Retrieve value for the variable from the callers address space, verify if not null and verify is on
	response=\$$promptVar
	response=$(eval echo $response)

	#printf "%s = >%s<\n" promptVar "$promptVar" response "$response" validateList "$validateList" >> ~/stdout.txt
	local loop=true
	local hadValue=true

	dump -2 -r
	dump -2 -l promptVar response validateList defaultVal validateListString promptText

	local verifyMsg
	until [[ $loop != true ]]; do
		while [[ $response == '' ]]; do
			hadValue=false
			[[ $promptText == '' ]] && promptText="Please specify a value for '$promptVar' ($validateListString, or 'X' to quit) > "
			let numTabs=$(grep -o "^" <<< "$promptText" | wc -l)
			promptText="$(sed "s/\^/$tabStr/g" <<< $promptText)"
			echo -n -e "$promptText > "
			ProtectedCall "read $readTimeOutOpt response";
			[[ $rc -ne 0 ]] && echo
			[[ $(Lower ${response}) == 'x' ]] && Goodbye 'x'
			if [[ $response == '' && $defaultVal != '' ]]; then
				eval $promptVar=\"$defaultVal\"
				[[ $defaultValueUseNotes == true ]] && Msg2 $NT1 "Using default value of '$defaultVal' for '$promptVar'"
				return 0
			fi
			[[ $response != '' && $validateList == '*any*' ]] && eval $promptVar=\"$response\" && return 0
			[[ $validateList == '*optional*' ]] && eval $promptVar=\"$response\" && return 0
			[[ $response == '' && $validateList == '*optional*' ]] && eval unset $promptVar && return 0
		done
		dump -2 -l response

		if [[  "$promptVar" == 'client' && $response == '?' ]]; then
			Msg2 "IT Gathering data..."
			SelectClient 'response'
			[[ $secondaryMessagesOnly != true && $defaultValueUseNotes == true ]] && Msg2 && Msg2 $NT1 "Using selected value of '$selectResp' for 'client'"
			eval $promptVar=\"$response\"
			loop=false

		elif [[  "$promptVar" == 'client' && $response == 'internal' ]]; then
			eval $promptVar=\"$response\"
			loop=false

		elif [[ "$validateList" == '' && "$promptVar" != 'client' && "${promptVar:0:7}" != 'product' ]]; then
			eval $promptVar=\"$response\"
			loop=false
		else
			unset verifyMsg
			VerifyPromptVal
			if [[ $verifyMsg != '' && $verifyMsg != true ]]; then
				[[ $hadValue == true ]] && echo "Specified value for '$promptVar' is '$response'"
				if [[ $numTabs -gt 0 ]]; then
					local cntr
					for ((cntr=1; cntr<$numTabs; cntr++)); do
						verifyMsg="${tabStr}${verifyMsg}"
					done
				fi
				echo "$verifyMsg"
				unset response
			else
				## Map abbreviated response to full response token from the validataion list
				if [[ "$promptVar" != 'client' ]]; then
					local answer=$(Lower $response)
					local length=${#answer}
					for i in "${validValues[@]}"; do
						local checkStr=$(Lower ${i:0:$length})
						[[ $answer == "$checkStr" ]] && response=$i && break
					done
				fi
				eval $promptVar=\"$response\"
				[[ $hadValue == true && $secondaryMessagesOnly != true && $defaultValueUseNotes == true ]] && Msg2 $NT1 "Using specified value of '$response' for '$promptVar'"
				loop=false
			fi
		fi
	done
	[[ $hadValue != true && $logFile != '' ]] && Msg2 "\n^$FUNCNAME: Useing specified value of '$response' for '$promptVar'" >> $logFile

	return 0
} #Prompt

#===================================================================================================
# Verify result value
#===================================================================================================
#===================================================================================================
# Verify result value
#===================================================================================================
function VerifyPromptVal {
	local i
	PushSettings "$FUNCNAME"
	SetFileExpansion 'off'
	local allowMultiple=false
	local processedRequest=false
	[[ ${promptVar:(-1)} == 's' ]] && allowMultiple=true
	dump -2 -l -t allowMultiple promptVar response validateList
	unset verifyMsg

	if [[ $(Contains "$validateListString" 'noCheck') == true ]]; then
		verifyMsg=true
		SetFileExpansion
		PopSettings "$FUNCNAME"
		return 0
	fi

	## Client
	if [[ $promptVar == 'client' && $verifyMsg == '' ]]; then
		#if [[ $response == '*' || $response == 'all' || $response == '.' ]]; then
		if [[ ${response:0:1} == '?' ]]; then
			SelectClient 'response'
		elif [[ ${response:0:1} == '<' ]]; then
			response=${response:1}
			lenResponse=${#response}
			response=${response:0:$lenResponse-1}
			checkClient=false
		else
			## Look for client in the clients table
			local sqlStmt="select idx from $clientInfoTable where name=\"$response\" "
			RunSql 'mysql' $sqlStmt
			if [[ ${#resultSet[@]} -eq 0 ]]; then
				verifyMsg="$(Msg2 $E "Client value of '$response' not found in $warehouseDb.$clientInfoTable")"
			fi
			## OK found client, now make sure it is valid for the current host
			if [[ $verifyMsg == "" ]]; then
				if [[ $anyClient != 'true' ]]; then
					sqlStmt="select host from $siteInfoTable where name=\"$response\""
					RunSql 'mysql' $sqlStmt
					[[ ${#resultSet[0]} -eq 0 ]] && verifyMsg="$(Msg2 $E "Could not retrieve any records for '$response' in the $warehouseDb.$siteInfoTable")"
					if [[ $verifyMsg == "" ]]; then
						hostedOn="${resultSet[0]}"
						if [[ $hostedOn != $hostName ]]; then
							if [[ $verify == true ]]; then
								if [[ $autoRemote == false ]]; then
									responseSave="$response"
									unset ans; Prompt ans "Client '$response' is hosted on '$hostedOn', Do you wish to start a session on that host" 'Yes No' 'Yes'; ans=$(Lower ${ans:0:1})
									response="$responseSave"
								else
									ans='y'
								fi
								if [[ $ans == 'y' ]]; then
									Msg2; Msg2 $I "Starting ssh session to host '$hostedOn', enter credentials and then 'exit' to return to '$hostName'...";
									[[ $(Contains "$originalArgStr" "$response") == false ]] && commandStr="$response $originalArgStr" || commandStr="$originalArgStr"
									StartRemoteSession "${userName}@${hostedOn}" $myName $commandStr
									Msg2; Msg2 $I "Back from remote ssh session"; Msg2
									Goodbye 0
								fi ## [[ $ans == 'y' ]]
							else
								ans='n'
							fi
							[[ $ans == 'n' ]] && verifyMsg="$(Msg2 $E "Client value of '$response' is not valid on this host ('$hostName') it is hosted on '$hostedOn' ")"
						fi ## [[ $hostedOn != $hostName ]]
					fi ## [[ $verifyMsg == "" ]]
				fi ## [[ $anyClient != 'true' ]]
			fi ## [[ $verifyMsg == "" ]]
		fi ## [[ ${response:0:1} == '?' ]];
	fi ## Client

	## Envs(s)
	if [[ $${promptVar:0:3} == 'env' && $verifyMsg == '' ]]; then
		local answer=$(Lower $response)
		if [[ $allowMultiple != true && $(Contains "$answer" ",") == true ]]; then
			verifyMsg=$(Msg2 $E "$promptVar' does not allow for multiple values, valid values is one in {$validateList}")
		else
			local i j found foundAll=true badList
			for i in $(tr ',' ' ' <<< $answer); do
				found=false
				for j in $(tr ',' ' ' <<< $validateList); do
					[[ $i == ${j:0:${#i}} ]] && found=true && break;
				done
				if [[ $found == false ]]; then
					badList="$badList,$i"
					foundAll=false
				fi
			done
			if [[ $foundAll == false ]]; then
				[[ $badList != '' ]] && badList=${badList:1}
				verifyMsg=$(Msg2 $E "Value of '$(ColorE "$badList")' not valid for '$promptVar', valid values in $(ColorK "{$validateList}")")
			fi
		fi
	fi ## Envs(s)

	## Product(s)
	if [[ ${promptVar:0:7} == 'product' && $verifyMsg == '' ]]; then

		validProducts='cat,cim,clss'
		if [[ $client != '' ]]; then
			local sqlStmt="select products from $clientInfoTable where name='$client'"
			RunSql 'mysql' "$sqlStmt"
			[[ ${#resultSet[@]} -gt 0 ]] && validProducts="${resultSet[0]}"
		fi

		local ans=$(Lower $response)
		if [[ $allowMultiple != true && $(Contains "$ans" ",") == true ]]; then
			verifyMsg=$(Msg2 $E "$promptVar' does not allow for multiple values, valid values is one in {$validProducts}")
		else
			local i j found foundAll=false
			for i in $(tr ',' ' ' <<< $ans); do
				found=false
				for j in $(tr ',' ' ' <<< $validProducts); do
					[[ $i == $j ]] && found=true && break;
				done
				[[ $found == false ]] && foundAll=false || foundAll=true
			done
			if [[ $foundAll == false ]]; then
				if [[ $allowExtraProducts == true ]]; then
					unset ans
					echo -n -e "\tYou have specified a product not on this clients product list, please confirm this is correct (Yes, No)>"
					read ans
					[[ $(Lower ${ans}) == 'x' ]] && Goodbye 'x'
					[[ $ans == 'y' ]] && foundAll=true
				fi
			fi
			[[ $foundAll == false ]] && verifyMsg=$(Msg2 $E "Value of '$response' not valid for '$promptVar', valid values in {$validProducts}")
		fi

	fi ## Product(s)

	## File
	if [[ $(Contains "$validateListString" '*file*') == true && $verifyMsg == '' ]]; then
		[[ ! -d $response ]] && verifyMsg=$(Msg2 $E "File '$response' does not exist") || unset validateListString
	fi ## File

	## Dir
	if [[ $(Contains "$validateListString" '*dir*') == true && $verifyMsg == '' ]]; then
		[[ ! -d $response ]] && verifyMsg=$(Msg2 $E "Directory '$response' does not exist") || unset validateListString
	fi ## Dir

	## Everything else
	if [[ $verifyMsg == '' ]]; then
		if [[ $validateListString == '' ]]; then
			eval $promptVar=$response
		else
			local answer=$(Lower $response)
			local length=${#answer}
			for i in "${validValues[@]}"; do
				[[ $i == '*any*' ]] && PopSettings && verifyMsg=true && SetFileExpansion && return 0
				local checkStr=$(Lower ${i:0:$length})
				dump -2 -l -t -t answer length i checkStr
				[[ $answer == $checkStr ]] && PopSettings && verifyMsg=true && SetFileExpansion && return 0
			done
			verifyMsg=$(Msg2 $E "Value of '$response' not valid for '$promptVar', valid values in {$validateListString}")
		fi
		processedRequest=true
	fi ## Everything else

	[[ $verifyMsg == '' ]] && verifyMsg=true
	SetFileExpansion
	PopSettings "$FUNCNAME"
	return 0

} #VerifyPromptVal

#===================================================================================================
# Display a selection list of clients, returns data in the client global variable
#===================================================================================================
function SelectClient {
	local returnVarName=$1
	local resultRec
	local selectRespt
	local menuList=()

	## Get the max width of client abbreviations
	local sqlStmt="select max(length(name)) from $clientInfoTable"
	RunSql 'mysql' $sqlStmt
	maxNameWidth=${resultSet[0]}

	## Get the clients data
	local sqlStmt="select distinct clients.name,clients.longName from $clientInfoTable,$siteInfoTable \
	where clients.idx=sites.clientId and sites.host = \"$hostName\" order by clients.name"
	RunSql 'mysql' $sqlStmt
	for resultRec in "${resultSet[@]}"; do
		resultRec=$(tr "\t" "|" <<< "$resultRec" )

		local clientCode=$(printf "%-${maxNameWidth}s" "$(cut -d"|" -f1 <<< "$resultRec")")
		local clientName=$(cut -d"|" -f2 <<< "$resultRec")
		menuList+=("$clientCode $clientName ")
	done

	[[ $batchMode != true && $noClear != true && $TERM != 'dumb' ]] && clear
	printf "\nPlease specify the number of the client you wish to use:\n\n"
	SelectMenu 'menuList' 'selectResp' '\nClient number (or 'X' to quit) > '
	[[ $selectResp == '' ]] && Goodbye 0
	selectResp="$(cut -d ' ' -f1 <<< "$selectResp")"
	eval $returnVarName=\"$selectResp\"

	return 0
} #SelectClient

#===================================================================================================
# verify that client / host / env combo valid
#===================================================================================================
function ValidateClientHostEnv {
	client=$1
	env=$2
	sqlStmt="select idx from $clientInfoTable where name=\"$client\" "
	RunSql 'mysql' $sqlStmt
	clientId=${resultSet[0]}

	if [[ "$clientId" = "" ]]; then
		printf "Client value of '$client' not found in leepfrog.$clientInfoTable"
		return 0
	fi
	sqlStmt="select siteId from $siteInfoTable where clientId=\"$clientId\" and host=\"$hostName\" "
	RunSql 'mysql' $sqlStmt
	siteId=${resultSet[0]}
	if [[ "$siteId" = "" ]]; then
		printf "Client value of '$client' not valid on host '$hostName'"
		return 0
	fi
	if [[ "$env" != "" ]]; then
		sqlStmt="select siteId from $siteInfoTable where clientId=\"$clientId\" and env=\"$env\" "
		RunSql 'mysql' $sqlStmt
		siteId=${resultSet[0]}
		if [[ "$siteId" = "" ]]; then
			printf "Environment value of '$env' not valid for client '$client'"
			return 0
		fi
	fi

	return 0
} #ValidateClientHostEnv

#===================================================================================================
# Parse a courseleaf client file returns <clientName> <clientEnv> <clientRoot> <fileEnd>
# clientRoot is everything up to the 'web' directory.  e.g. '/mnt/rainier/uww/next' or
# '/mnt/dev6/web/uww-dscudiero'
#===================================================================================================
function ParseCourseleafFile {
	local file="$1"
	[[ $file == '' ]] && file="$(pwd)"
	file=${file:1}
	local tokens=($(tr '/' ' ' <<< $file))

	local clientRoot fileEnd clientName env pcfCntr len
	local parseStart=4

	clientRoot="/${tokens[0]}/${tokens[1]}/${tokens[2]}/${tokens[3]}"
	if [[ ${tokens[1]:0:3} == 'dev' ]]; then
		clientName="${tokens[3]}"
		env='dev'
		len="-$userName"; len=${#len}
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

#===================================================================================================
# Edit a tcf value
# EditTcfValue <varName> <varValue> <editFile>
# 1) If already there, return true
# 2) If found commented out, uncomment & return
# 3) If found varible but value is different, edit & return
# 4) If not found in target
#	1) Scan file in skeleton to find the line immediaterly above the target line in the skel file
#	2) If found in skeleton then insert target line after the line found in the skeleton
#	3) If not found in the skeleton of the 'afterline' returned in 1) above is not found, insert at top
#
# returns 'true' for success, anything else is an error message
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
			if [[ $foundLine == true ]]; then
				local verboseLevelSave=$verboseLevel
				verboseLevel=0; insertMsg=$(InsertLineInFile "$toStr" "$editFile" "$afterLine"); verboseLevel=$verboseLevelSave
				dump -3 -l -t insertMsg
				[[ $insertMsg != true && $(Contains "$insertMsg" 'Could not locate target string/line' ) != true ]] && insertMsg=$(sed -i "1i$toStr" $editFile)
			else
				insertMsg=$(sed -i "1i$toStr" $editFile)
			fi
			[[ $insertMsg != '' && $insertMsg != true ]] && echo $insertMsg || echo true

	return 0
} #EditTcfValue

#===================================================================================================
# Insert a new line into the courseleaf console file
# EditCourseleafConsole <action> <targetFile> <string>
# <action> in {'insert','delete'}
# <string> is a full navlinks record or is the name of the console action, i.e. navlinks:...|<name>|...
#
# if action == 'delete' then the line will be commented out
# returns 'true' for success, anything else is an error message
#===================================================================================================
function EditCourseleafConsole {
	local action="$1"
	local tgtFile="$2"
	local string="$3"

	[[ $action == '' ]] && echo "($FUNCNAME) Required argument 'action' not passed to function" && return 0
	[[ $tgtFile == '' || ! -w $tgtFile ]] && echo "($FUNCNAME) Could not read/write tgtFile: '$tgtFile'" && return 0
	[[ $string == '' ]] && echo "($FUNCNAME) Required argument 'string' not passed to function" && return 0
	local skelFile=$skeletonRoot/release/web/courseleaf/index.tcf
	local grepStr insertRec name navlinkName

	if [[ $(Contains "$string" 'navlinks:') == true ]]; then
		insertRec="$string"
		name=$(echo $string | cut -d'|' -f2)
	else
		name="$string"
		grepStr="$(ProtectedCall "grep \"|$name|\" $skelFile")"
		if [[ $grepStr != '' ]]; then
			insertRec="$grepStr"
		else
			echo "($FUNCNAME) Could not locate navlinks record with 'name' of '|$name|'"
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
			Msg2 "^Uncommented line: $toStr..."
			changesMade=true
			echo true
			return 0
		fi

	## Scan skeleton looking for line:
		unset foundLine afterLine insertMsg;
		while read -r line; do
			[[ "$line" == "$insertRec" ]] && foundLine=true && break
			afterLine="$line"
		done < "$skelFile"
		dump -3 -l -t foundLine afterLine

	## Insert the line
		editFile="$tgtFile"
		if [[ $foundLine == true ]]; then
			local verboseLevelSave=$verboseLevel
			verboseLevel=0; insertMsg="$(InsertLineInFile "$insertRec" "$editFile" "$afterLine")"; verboseLevel=$verboseLevelSave
			dump -3 -l -t insertMsg
			[[ $foundLine == true && $insertMsg != '' ]] && [[ $(Contains "$insertMsg" 'Could not locate target string/line' ) != true ]] && echo "$insertMsg" return 0
			[[ $insertMsg == true ]] && echo true && return 0
		fi

		## OK, we need to insert the line but cannot find the after record, so just add to the end of the group
			navlinkName=$(echo $insertRec | cut -d'|' -f1)
			afterLine="$(ProtectedCall "grep \"^$navlinkName\" $editFile | tail -1")"
			verboseLevel=0; insertMsg=$(InsertLineInFile "$insertRec" "$editFile" "$afterLine"); verboseLevel=$verboseLevelSave
			[[ $insertMsg != true ]] && echo "$FUNCNAME) Could not insert line:\n\t$insertRec\nMessages are:\n\t$insertMsg"

		echo true
	return 0
}

#===================================================================================================
# find out what the courseleaf pgm is and its location
# Expects to be run from a client root directory (i.e. in .../$client)
#===================================================================================================
# Returns via echo 'courseleafPgmName' 'courselafePgmDir'
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
		elif [[ -x $(pwd)/web/$token/$token.cgi ]]; then
			echo "$token" "$checkDir/web/$token"
			cd $cwd
			return 0
		fi
	done
	cd $cwd
	return 0
} #GetCourseleafPgm

#===================================================================================================
#Retrieve credentials from the .pw2 file
#===================================================================================================
function GetPW {
	searchStr=$(Trim "$*")
	pwFile=$HOME/.pw2
	unset pwRec pw
	[[ -r $pwFile ]] && pwRec=$(ProtectedCall "grep "^$searchStr" $pwFile")
	[[ $pwRec != '' ]] && echo $pwRec | cut -d' ' -f  3 || echo  ''

	return 0
} #GetPW

#===================================================================================================
## Check to see if the current excution environment supports script execution
## Returns 1 in $? if user is authorized, otherwise it returns 0
## Always returns 1 if the script is not registerd in the scripts database
#===================================================================================================
function CheckRun {
	local script=${1:-$myName}
	local tempStr grepOut os host sqlStmt resultString
	IfMe echo "Starting: $FUNCNAME"

	## Check to see if the user is in the leepfrog group
		grepOut=$(cat /etc/group | grep leepfrog: | grep $userName)
		[[ grepOut == '' ]] && echo "Your userid ($userName) is not in the 'leepfrog' linux group.\nPlease contact the System Admin team and ask them to add you to the group." return 0

	## check to see if script is in the scripts table
		sqlStmt="select count(*) from $scriptsTable where name=\"$script\""
		RunSql 'mysql' $sqlStmt
		[[ ${resultSet[0]} -eq 0 ]] && echo true && return 0

	IfMe echo -e "\tChecking offline/inactive"
	## Check to see if the script is offline
		local offlineFileFound=false
		local scriptActive=true
		## Check to see if active flag is off
		IfMe echo -e "\t\tChecking active flag"
		sqlStmt="select active from $scriptsTable where name=\"$script\" and (host=\"$hostName\" or host is null) and (os=\"$osName\" or os is null)"
		RunSql 'mysql' $sqlStmt
		if [[ ${#resultSet[@]} -gt 0 ]]; then
			[[ ${resultSet[0]} != 'Yes' && ${resultSet[0]} != 'N/A' ]] && scriptActive=false
			IfMe echo -e "\t\t\t\${resultSet[0]} = >${resultSet[0]}<"
		fi
		[[ $scriptActive == false ]] && echo "Script '$script' is currently offline/inactive, please try again later." && return 0

		## Look for offline file
		IfMe echo -e "\t\tChecking for offline file"
		[[ ${script:${#script}-3:3} != '.sh' ]] && tempStr="${script}.sh" || tempStr=$script
		[[ -f $TOOLSPATH/${tempStr}-offline ]] && offlineFileFound=true
		IfMe echo -e "\t\t\tofflineFileFound = >$offlineFileFound<"
		[[ $offlineFileFound == true ]] && echo "Script '$script' is currently offline for maintenance, please try again later." && return 0


	IfMe echo -e "\t Checking env"
	## check host and os information
		sqlStmt="select os,host from $scriptsTable where name=\"$script\" and (host=\"$hostName\" or host is null) and (os=\"$osName\" or os is null)"
		RunSql 'mysql' $sqlStmt
		[[ ${#resultSet[@]} -ne 0 ]] && echo true && return 0

	## return message
		echo "Script is not supported in the current environment."
		sqlStmt="select os,host from $scriptsTable where name=\"$script\""
		RunSql 'mysql' $sqlStmt
		resultString=${resultSet[0]}
		resultString=$(echo "$resultString" | tr "\t" "|" )
		os=$(echo $resultString | cut -d '|' -f 1)
		host=$(echo $resultString | cut -d '|' -f 2)
		echo -e "\tScript execution is restricted to:"
		[[ $os != NULL ]] && echo -e "\t\tos = '$os'"
		[[ $host != NULL ]] && echo -e "\t\thost = '$host'"

	return 0
} #CheckRun


#===================================================================================================
## Check to see if the logged user can run this script
## Returns true if user is authorized, otherwise it returns a message
## Always returns true if the script is not registerd in the scripts database
#===================================================================================================
# 03/22/16 - dgs - Tweaked logic to clean it up a bit
#===================================================================================================
function CheckAuth {
	local sqlStmt

	## check to see if script is in the scripts table
		local sqlStmt="select count(*) from $scriptsTable where name=\"$myName\""
		RunSql 'mysql' $sqlStmt
		[[ ${resultSet[0]} -eq 0 ]] && echo true && return 0

	## check user to see if they are the author
		sqlStmt="select author from $scriptsTable where name=\"$myName\""
		RunSql 'mysql' $sqlStmt
		if [[ ${#resultSet[@]} -ne 0 ]]; then
			local author="${resultSet[0]}"
			[[ $author == $userName ]] && echo true && return 0
		fi

	## check user restrict informaton for this script
		local haveRestrictToUsers=false
		sqlStmt="select restrictToUsers from $scriptsTable where name=\"$myName\""
		RunSql 'mysql' $sqlStmt
		if [[ ${#resultSet[@]} -ne 0 ]]; then
			local scriptUsers="$(echo ${resultSet[0]} | tr ' ' ',')"
			if [[ $scriptUsers != 'NULL' && $scriptUsers != '' ]]; then
				haveRestrictToUsers=true
				[[ $(Contains ",$scriptUsers," ",$userName,") == true ]] && echo true && return 0
			fi
		fi

	## check group restrict informaton for this script
		local haveRestrictToGroups=false
		sqlStmt="select restrictToGroups from $scriptsTable where name=\"$myName\""
		RunSql 'mysql' $sqlStmt
		if [[ ${#resultSet[@]} -ne 0 ]]; then
			local scriptGroups="\"$(echo ${resultSet[0]} | sed 's/,/","/g')\""
			if [[ $scriptGroups != \"NULL\" && $scriptGroups != '' ]]; then
				haveRestrictToGroups=true
				sqlStmt="select code from $authGroupsTable where members like \"%,$userName,%\" and code in ($scriptGroups)"
				RunSql 'mysql' $sqlStmt
				[[ ${#resultSet[@]} -ne 0 ]] && echo true && return 0
			fi
		fi
		[[ $haveRestrictToUsers == false && $haveRestrictToGroups == false ]] && echo true && return 0

	## User does not have access
	Msg2 "Current user ($userName) does not have permissions to run this script."
	if [[ $restrictToGroupsIsNull == false || $restrictToUsersIsNull == false ]]; then
		Msg2 "^Script $myName is restricted to:"
		[[ $haveRestrictToUsers == true ]] && Msg2 "^Users in {$scriptUsers}"
		[[ $haveRestrictToGroups == true ]] && Msg2 "^Users in auth group(s) {$scriptGroups}"
	fi
	return 0

} #CheckAuth

#===================================================================================================
# Parse ini file
#ParsIniFile iniFileName sectionName
# Sets variables & values with names based on the ini file section def.
#===================================================================================================
# function ParseIniFile {
# 	iniSection="$1"
# 	iniFile="$2"
# 	#dump -n iniSection iniFile
#
# 	function readIniFile {
# 		local section=$1
# 		local file=$2
# 		local tempIniFile=/tmp/$myName.$LOGNAME.$BASHPID
# 		## Remove comment lines
# 		if [[ -f $tempIniFile ]]; then rm $tempIniFile > /dev/null 2>&1; fi
# 		grep -v '^#' $file > $tempIniFile
# 		#cat $tempIniFile >> $HOME/stdout.txt
# 		## assignments
# 		#eval `sed -e 's/[[:space:]]*\=[[:space:]]*/=/g' -e 's/;.*$//' -e 's/[[:space:]]*$//' -e 's/^[[:space:]]*//' -e "s/^\(.*\)=\([^\"']*\)$/\1=\"\2\"/" < $tempIniFile \
# 		#   | sed -n -e "/^\[$section\]/,/^\s*\[/{/^[^;].*\=.*/p;}"`
#
# 		eval `sed -e 's/[[:space:]]*\=[[:space:]]*/=/g' \
# 		 	-e 's/;.*$//' \
# 			-e 's/[[:space:]]*$//' \
# 			-e 's/^[[:space:]]*//' \
# 			-e "s/^\(.*\)=\([^\"']*\)$/\1=\"\2\"/" \
# 			< $tempIniFile \
# 		    | sed -n -e "/^\[$section\]/,/^\s*\[/{/^[^;].*\=.*/p;}"`
#
# 		if [[ -f $tempIniFile ]]; then rm $tempIniFile > /dev/null 2>&1; fi
# 	} #readIniFile
#
# 	## MAIN ===================================================================================
# 	#dump -n iniSection iniFile
# 	if [[ $iniFile == '' ]]; then
# 		if [[ -f $linuxIniFile ]]; then readIniFile $iniSection $linuxIniFile; fi
# 		if [[ -f $defaultIniFile ]]; then readIniFile $iniSection $defaultIniFile; fi
# 		if [[ -f $myIniFile ]]; then readIniFile $iniSection $myIniFile; fi
# 	else
# 		readIniFile $iniSection $iniFile
# 	fi
#
# 	return 0
# } #ParseIniFile

#===================================================================================================
# Calculate Elapsed time
# CalcElapsedTime startTime endTime
# Sets variable elapsedTime
#===================================================================================================
function CalcElapsed {
	startTime="$1"
	endTime="$2"
	if [[ "$endTime" = "" ]]; then
		date=$(date)
		endTime=$(date +%s)
	fi

	elapTime=''
	elapSeconds=$(( endTime - startTime ))
	eHr=$(( elapSeconds / 3600 ))
	elapSeconds=$(( elapSeconds - eHr * 3600 ))
	eMin=$(( elapSeconds / 60 ))
	elapSeconds=$(( elapSeconds - eMin * 60 ))
	elapTime=$(printf "%02dh %02dm %02ds" $eHr $eMin $elapSeconds)

	return 0
} #CalcElapsed

#===================================================================================================
# find out if a string contains another substring
#===================================================================================================
# contains(string, substring)
# Returns false if the specified string does not contain the specified substring,
# otherwise returns true.
function Contains {
	local string="$1"
	local substring="$2"
	local testStr=${string#*$substring}

	[[ "$testStr" != "$string" ]] && echo true || echo false
	return 0
} #Contains

#===================================================================================================
# Find the adminstration navlink in /courseleaf/index.tcf
# FindCourseleafNavlinkName <siteDir>
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

#===================================================================================================
# Run a courseleaf.cgi command, check outpout
# Courseleaf.cgi $LINENO <siteDir> <command string>
#===================================================================================================
function Courseleaf.cgi { shift; RunCoureleafCgi $*; return 0; }
function RunCoureleafCgi {
	local siteDir="$1"; shift
	local cgiCmd="$*"

	cwd=$(pwd)
	cd $siteDir
	courseLeafPgm=$(GetCourseleafPgm | cut -d' ' -f1).cgi
	courseLeafDir=$(GetCourseleafPgm | cut -d' ' -f2)
	if [[ $courseLeafPgm == '.cgi' || $courseLeafDir == '' ]]; then Msg2 $T "Could not find courseleaf executable"; fi
	dump -3  siteDir courseLeafPgm courseLeafDir cgiCmd
	[[ ! -x $courseLeafDir/$courseLeafPgm ]] && Msg2 $TT1 "Could not find $courseLeafPgm in '$courseLeafDir' trying:\n^'$cgiCmd'\n^($calledLineNo)"

	## Run command
	cd $courseLeafDir
	local cgiOut=/tmp/$userName.$myName.$BASHPID.cgiOut
	$DOIT ./$courseLeafPgm $cgiCmd 2>&1 > $cgiOut; rc=$?
	grepStr="$(ProtectedCall "grep 'ATJ error:' $cgiOut")"
	[[ $grepStr != '' ]] && Msg2 $TT1 "ATJ errors were reported by the step.\n^Cgi cmd: '$cgiCmd'\n^Please see below:\n^$grepStr\n\tAdditional information may be found in:\n^$cgiOut"
	rm -f $cgiOut
	cd $cwd
	return 0
} #RunCoureleafCgi

#===================================================================================================
# Copy files protected, copy the file to a different name, check if it made it, then swap names
#===================================================================================================
function CpSwapFiles {
	local callerLineNo=$1; shift || true
	local file="$1"; shift || true
	local fromDir="$1"; shift || true
	local fromFile="$fromDir/$file"
	local toDir="$1"; shift || true
	local toFile="$toDir/$file"
	local backupDir="$1"
	local foundToFile=false
	local srcMd5 tgtMd5

	dump -3 -n callerLineNo file fromDir fromFile toDir toFile backupDir
	[[ ! -r $fromFile ]] && Msg2 $TT1 "Could not find file '$fromFile'\n^^($callerLineNo)"
	srcMd5=$(md5sum $fromFile | cut -f1 -d" ")
	[[ -w $toFile ]] && foundToFile=true && tgtMd5=$(md5sum $toFile | cut -f1 -d" ")
	dump -3 foundToFile

	if [[ $foundToFile == true ]]; then
		## If files are the same just return 0
		[[ $srcMd5 == $tgtMd5 ]] && return 0
		if [[ $backupDir != '' ]]; then
			[[ ! -d $backupDir ]] && mkdir -p $backupDir
			cp -f $toFile $backupDir/$(basename $toFile)
		fi
		local tmpOrigFileName="$toFile $toFile.orig.$BASHPID"
		$DOIT mv $toFile $tmpOrigFileName
	else
		[[ ! -d $toDir ]] && mkdir -p $toDir
	fi

	local tmpNewFileName="$toFile.new.$BASHPID"
	$DOIT cp $fromFile $tmpNewFileName
	if [[ ! -f $tmpNewFileName ]]; then
		$DOIT mv $tmpOrigFileName $toFile
		Msg2 $TT1 "Could not copy file:\n^^From file:'$fromFile'\n^^To file: $toFile to find file\n^^($callerLineNo)"
	fi
	$DOIT mv $tmpNewFileName $toFile
	[[ $foundToFile == true ]] && $DOIT rm -f $tmpOrigFileName

	return 0
} #CpSwapFiles

#===================================================================================================
# Get connection information from the users .pw2 file
#===================================================================================================
function GetConnectInfo {
	local key="$1"
	local alternateFile="$2"

	local pwFile=$HOME/.pw2
	local pwRec
	[[ -r $pwFile ]] && pwRec=$(ProtectedCall "grep -m 1 "^$key" $pwFile")
	[[ $pwRec == '' &&  -r $alternateFile ]] && pwRec=$(ProtectedCall "grep -m 1 "^$key" $alternateFile")
	echo "$(echo $pwRec | tr -d '\011\012\015')"
	return 0
} #GetConnectInfo

#===================================================================================================
# Run a statement
# <sqlType> <sqlFile> <sql>
# Where:
# 	<sqlType> 	in {'mysql','sqlite'}
# 	<sqlFile> 	is valid only for sqlite
# 	<sql> 		The sql statement to run
# returns data in an array called 'resultSet'
#===================================================================================================
function RunSql {
	SetFileExpansion 'off'
	local type=$(Lower "$1")
	[[ $type != 'mysql' && $type != 'sqlite' ]] && type='mysql' || shift
	[[ $type == 'sqlite' ]] && local dbFile="$1" && shift
	local sql="$*"
	[[ ${sql:${#sql}:1} != ';' ]] && sql="$sql;"
	#dump -r -l type sql

	local validSqlTypes='select insert delete update pragma'
	local adminOnlySqlTypes='truncate'
	local readOnlySqlTypes='select'
	local sqlCmdString mySqlConnectStringSave dbAcc
	local stmtType=$(Lower $(echo $sql | cut -d' ' -f1))


	if [[ $type == 'mysql' ]]; then
		[[ $mySqlConnectString == '' ]] && Msg2 $T "Could not resolve mysql connection information to '$warehouseDb'\n^^$sqlStmt"
		validSqlTypes="$validSqlTypes show"
		[[ $(Contains ",${administrators}," ",${LOGNAME},") == true ]] && validSqlTypes="$validSqlTypes truncate"
		[[ $(Contains "$validSqlTypes" "$stmtType") != true ]] &&  Msg2 $T "$FUNCNAME: Unknown SQL statement type '$stmtType'\n\tSql: $sql"
		[[ $DOIT != '' && $(Contains "$readOnlySqlTypes" "$stmtType") != true ]] && echo "sqlStmt = >$sqlStmt<" && return 0
		## Override access level
		if [[ $(Contains "$readOnlySqlTypes" "$stmtType") != true ]]; then
			mySqlConnectStringSave="$mySqlConnectString";
			[[ $(Contains "$adminOnlySqlTypes" "$stmtType") == true ]] && dbAcc="Admin" || dbAcc='Update'
			mySqlConnectString=$(sed "s/Read/$dbAcc/" <<< $mySqlConnectString)
		fi
		sqlCmdString="mysql --skip-column-names --batch $mySqlConnectString -e "
	else
		sqlCmdString="sqlite3 $dbFile"
		validSqlTypes="$validSqlTypes .dump"
	fi

	## Run the query
	unset resultStr resultSet
	resultStr=$($sqlCmdString "$sql" 2>&1 | tr "\t" '|')

	local tmpStr="$(echo $resultStr | cut -d' ' -f1)"
	if [[ $(Upper "${tmpStr:0:5}") == 'ERROR' ]]; then
		[[ $type == 'mysql' ]] && Msg2 $T$MsgNoFold "$(ColorK "$myName").$FUNCNAME: Error returned from $type:\n\tDatabase: $mySqlDb\n\tSql: $sql\n\t$resultStr"
		[[ $type == 'sqlite' ]] && Msg2 $T$MsgNoFold "$(ColorK "$myName").$FUNCNAME: Error returned from sqlite3:\n\tFile: $dbFile\n\tSql: $sql\n\t$resultStr"
	fi

	[[ $resultStr != '' ]] && IFS=$'\n' read -rd '' -a resultSet <<<"$resultStr"

	[[ $mySqlConnectStringSave != '' ]] && mySqlConnectString="$mySqlConnectStringSave"
	SetFileExpansion
	return 0
} ##RunSql

#===================================================================================================
# Set Directories based on the current hostName name and school name
# Sets globals: devDir, nextDir, previewDir, publicDir, upgradeDir
#===================================================================================================
function SetSiteDirs {
	local mode=$1
	if [[ $mode == 'check' ]]; then local checkEnv=$2; fi

	if [[ "$client" = "" ]]; then client=$school; fi
	if [[ "$client" = '' ]]; then printf "SetSiteDirs: No value for client/school.  Stopping\n\a"; Goodbye 1; fi

	dir=""
	## Find dev directories
	for server in $(echo $devServers | tr ',' ' '); do
		foundClient=false
		for chkenv in $(echo $courseleafDevEnvs | tr ',' ' '); do
			unset ${chkenv}Dir
			[[ $chkenv == pvt && -d /mnt/$server/web/$client-$userName ]] && eval ${chkenv}Dir=/mnt/$server/web/$client-$userName && foundClient=true && continue
			[[ $chkenv == dev && -d /mnt/$server/web/$client ]] && eval ${chkenv}Dir=/mnt/$server/web/$client && foundClient=true && continue
		done
		[[ -d "/mnt/$server/web/$client-cim" ]] && testDir="cimDevDir=/mnt/$server/web/$client-cim"
		[[ $foundClient == true ]] && break
	done

	## Find production directories
	skelDir=$skeletonRoot/release
	for server in $(echo $prodServers | tr ',' ' '); do
		foundClient=false
		for chkenv in $(echo $courseleafProdEnvs | tr ',' ' '); do
			unset ${chkenv}Dir
			[[ -d /mnt/$server/$client/$chkenv ]] && eval ${chkenv}Dir=/mnt/$server/$client/$chkenv && foundClient=true
		done
		[[ -d "/mnt/$server/$client-test/test" ]] && testDir="/mnt/$server/$client-test/test"
		[[ $foundClient == true ]] && break
	done

	if [[ $mode = 'setDefault' ]]; then
		if [[ $nextDir == '' ]]; then
			if [[ $noCheck != true ]]; then
				## Get the share and
				sqlStmt="select share from $siteInfoTable where name=\"$client\" and env=\"next\""
				RunSql 'mysql' $sqlStmt
				if [[ ${#resultSet[@]} -gt 0 ]]; then
					nextDir="/mnt/${resultSet[0]}/$client/next"
				else
					Msg2 $T "SetSiteDirs: Mode is $mode and could not resolve the NEXT site directory"
				fi
			else
				nextDir="/mnt/$server/$client/next/"
			fi
		fi
		[[ $testDir == '' ]] && testDir=$(sed "s!/next!-test/test!" <<< $nextDir)
		[[ $currDir == '' ]] && currDir=$(sed "s/next/curr/" <<< $nextDir)
		[[ $previewDir == '' ]] && previewDir=$(sed "s/next/preview/" <<< $nextDir)
		[[ $priorDir == '' ]] && priorDir=$(sed "s/next/prior/" <<< $nextDir)
		[[ $publicDir == '' ]] &&  publicDir=$(sed "s/next/public/" <<< $nextDir)
		[[ $devDir == '' ]] && devDir="/mnt/$defaultDevServer/web/$client"
		[[ $pvtDir == '' ]] && pvtDir=$(sed "s!$client!$client-$userName!" <<< $devDir)
		devSiteDir=$devDir
		prodSiteDir=$(dirname $nextDir)
	fi

	if [[ $mode == 'check' ]]; then
		local checkDir='Dir'
		eval checkDir=\$$checkEnv$checkDir
		[[ -d $checkDir ]] && echo true || echo false
	fi

	return 0
} #SetSiteDirs

#===================================================================================================
## Write out a start record into the process log database
#===================================================================================================
function dbLog {
	[[ $logInDb == false ]] && return 0

	local mode=$(Lower ${1:0:1}); shift || true
	[[ $mode == 'd' && $testmode == true ]] && mode='r' && unset myLogRecordIdx
	local idx argString sqlStmt myName epochEtime endTime elapSeconds eMin eSec

	if [[ $mode == 's' ]]; then # START
		myName=$1; shift || true
		argString="$*"
		[[ $informationOnlyMode == true ]] && argString="${argString}, informationOnlyMode"
		[[ $allItems != '' && $(Contains "$argString" 'allItems') != true ]] && argString="${argString}, AllItems"
		sqlStmt="insert into $processLogTable (idx,name,hostName,userName,viaScripts,startTime,argString) \
				values(NULL,\"$myName\",\"$hostName\",\"$userName\",\"$calledViaScripts\",\"$startTime\",\"$argString\")"
		RunSql 'mysql' $sqlStmt
		sqlStmt="select max(idx) from $processLogTable"
		RunSql 'mysql' $sqlStmt
		echo ${resultSet[0]}
	elif [[ $mode == 'd' ]]; then # UPDATE DATA
		idx=$1; shift || true
		argString="$*"
		[[ $informationOnlyMode == true ]] && argString="${argString}, informationOnlyMode"
		[[ $allItems != '' && $(Contains "$argString" 'allItems') != true ]] && argString="${argString}, AllItems"
		sqlStmt="update $processLogTable set data=\"$argString\" where idx=$idx"
		RunSql 'mysql' $sqlStmt
	elif [[ $mode == 'x' ]]; then # UPDATE EXITCODE
		idx=$1; shift || true
		argString="$*"
		sqlStmt="update $processLogTable set exitCode=\"$argString\" where idx=$idx"
		RunSql 'mysql' $sqlStmt
	elif [[ $mode == 'e' ]]; then # END
		idx=$1
		epochEtime=$(date +%s)
		endTime=$(date '+%Y-%m-%d %H:%M:%S')
		elapSeconds=$(( epochEtime - epochStime ))
		eHr=$(( elapSeconds / 3600 ))
		elapSeconds=$(( elapSeconds - eHr * 3600 ))
		eMin=$(( elapSeconds / 60 ))
		elapSeconds=$(( elapSeconds - eMin * 60 ))
		eSec=$elapSeconds
		elapTime=$(printf "%02dh %02dm %02ds" $eHr $eMin $eSec)
		sqlStmt="update $processLogTable set endTime=\"$startTime\",elapsedTime=\"$elapTime\" where idx=$idx"
		RunSql 'mysql' $sqlStmt
	elif [[ $mode == 'r' ]]; then # REMOVE
		idx=$1; shift || true
		sqlStmt="delete from $processLogTable where idx=$idx"
		[[ $idx != '' ]] && RunSql 'mysql' $sqlStmt
	fi

	return 0
} #dbLog

#===================================================================================================
# Insert a line onto a file, inserts BELOW the serachLine
# InsertLineInFile lineToInsert fileName searchLine
#===================================================================================================
# 07/22/16 - dgs - Refactored, use copyfilewithcheck and backup
#===================================================================================================
function InsertLineInFile {
	[[ $DOIT != '' || $listOnly == true || $informationOnlyMode == true ]] && echo true && return 0
	local insertLine=$1; shift || true
	local editFile=$1; shift || true
	local searchLine=$1
	local lengthOfSearchLine=${#searchLine}
	#Here I1 > $stdout; echo 'insertLine  =>'$insertLine'<' >> $stdout; echo 'searchLine  =>'$searchLine'<' >> $stdout; echo >> $stdout
	dump -3 -l -t insertLine editFile searchLine lengthOfSearchLine

	# Read in file, scan for searchLine, once we find the searchLine in the file then we insert
	# the insertLine the below the search line
	local tmpFile=$(mkTmpFile $FUNCNAME)
	local line found=false
	while read -r line; do
		if [[ $found != true ]]; then
			if [[ ${line:0:$lengthOfSearchLine} == $searchLine ]]; then
				echo "${line}" >> $tmpFile
				echo "${insertLine}" >> $tmpFile
				found=true
				continue
			fi
		fi
		echo "${line}" >> $tmpFile
	done < "$editFile"

	if [[ $found == true ]]; then
		result=$(CopyFileWithCheck "$tmpFile" "$editFile" 'courseleaf')
		[[ $result == true || $result == 'same' ]] && echo true  || Msg2 "($FUNCNAME) $result"
	else
		Msg2 "($FUNCNAME) Could not locate target string/line '$searchLine'"
		#echo '*** NOT FOUND ***' >> $stdout
	fi

	return 0
} #InsertLineInFile

#===================================================================================================
# Copy a file only if files are diffeent
# copyIfDifferent <srcFile> <tgtFile> <backup {true:false}>
# If backup != false then callBackpCourseleafFile
#===================================================================================================
function CopyFileWithCheck {
	[[ $DOIT != '' || $listOnly == true || $informationOnlyMode == true ]] && echo true && return 0
	local srcFile=$1
	local tgtFile=$2
	local backup=${3:false}
	local srcMd5 tgtMd5

	srcMd5=$(md5sum $srcFile | cut -f1 -d" ")
	[[ -f $tgtFile ]] && tgtMd5=$(md5sum $tgtFile | cut -f1 -d" ") || unset tgtMd5
	[[ $srcMd5 == $tgtMd5 ]] && echo 'same' && return 0

	[[ $backup != false && -f $tgtFile ]] && BackupCourseleafFile $tgtFile
	cp -fp $srcFile $tgtFile.new &> $tmpFile.$myName.$FUNCNAME.$$
	[[ -f $tgtFile.new ]] && tgtMd5=$(md5sum $tgtFile.new | cut -f1 -d" ") || unset tgtMd5
	[[ $srcMd5 != $tgtMd5 ]] && echo $(cat $tmpFile.$myName.$FUNCNAME.$$) && rm -rf $tmpFile.$myName.$FUNCNAME.$$ && return 0
	[[ -f $tgtFile ]] && rm $tgtFile
	mv -f $tgtFile.new $tgtFile
	echo true
	rm -rf $tmpFile.$myName.$FUNCNAME.$$
	return 0
} #CopyFileWithCheck

#===================================================================================================
# Backup a courseleaf file, copy to the attic createing directories as necessary
# Expects the variable 'client' to be set
#===================================================================================================
function BackupCourseleafFile {
	[[ $DOIT != '' || $listOnly == true || $informationOnlyMode == true ]] && return 0
	local file=$1; shift || true
	[[ ! -r $file ]] && return 0

	local client=$(ParseCourseleafFile "$file" | cut -d ' ' -f1)
	local clientRoot=$(ParseCourseleafFile "$file" | cut -d ' ' -f3)
	local fileEnd=$(ParseCourseleafFile "$file" | cut -d ' ' -f4)
	local backupRoot="${clientRoot}/attic/$myName.$userName.$(date +"%H-%M-%S")"
	[[ ! -d $backupRoot ]] && mkdir -p $backupRoot
	local bakFile="${backupRoot}${fileEnd}"

	if [[ -f $file ]]; then
		[[ ! -d $(dirname $bakFile) ]] && mkdir -p $(dirname $bakFile)
		$DOIT cp -fp $file $bakFile
	elif [[ -d $file ]]; then
		[[ ! -d $bakFile ]] && $DOIT mkdir -p $bakFile
		$DOIT cp -rfp $file $bakFile
	fi

	return 0
} #BackupCourseleafFile

#===================================================================================================
# Display News
#===================================================================================================
function DisplayNews {
	local lastViewedDate lastViewedEdate displayedHeader itemNum msgText
	newsDisplayed=false
	[[ $noNews == true ]] && return 0

	## Loop through news types
		for newsType in tools $(tr -d '-' <<< $myName); do
			unset lastViewedDate; lastViewedEdate=0; displayedHeader=false; itemNum=0
			eval "unset ${newsType}LastRunDate"
			eval "${newsType}LastRunEDate=0"
			## Get users last accessed time date
				sqlStmt="select date,edate from $newsInfoTable where userName=\"$userName\" and object=\"$newsType\""
				RunSql 'mysql' "$sqlStmt"
				#[[ ${#resultSet[@]} -gt 0 ]] && lastViewedDate=$(echo "${resultSet[0]}" | cut -d'|' -f1) && lastViewedEDate=$(echo "${resultSet[0]}" | cut -d'|' -f2)
				if [[ ${#resultSet[@]} -gt 0 ]]; then
					lastViewedDate=$(cut -d'|' -f1 <<< "${resultSet[0]}")
					lastViewedEdate=$(cut -d'|' -f2 <<< "${resultSet[0]}")
					eval ${newsType}LastRunDate=\"$lastViewedDate\"
					eval ${newsType}LastRunEdate=$lastViewedEdate
				fi
				#dump ${newsType}LastRunDate ${newsType}LastRunEDate

			## Read news items from the database
				#dump newsType lastViewedEdate

				sqlStmt="select item,date from $newsTable where edate >= \"$lastViewedEdate\" and object=\"$newsType\""
				RunSql 'mysql' "$sqlStmt"
				for result in "${resultSet[@]}"; do
					if [[ $displayedHeader == false ]]; then
						msgText="\n$(ColorK "'$newsType'") news items"
						[[ $lastViewedDate != '' ]] && msgText="$msgText since the last time you ran this script/report ($(cut -d ' ' -f1 <<< $lastViewedDate))"
						Msg2 $I "$msgText:\a"
						displayedHeader=true
					fi
					item=$(cut -d'|' -f1 <<< $result)
					date=$(cut -d'|' -f2 <<< $result)
					ProtectedCall "((itemNum++))"
					Msg2 "\t   $itemNum) $item"
					newsDisplayed=true
				done
			## Set the last read date on the database
				if [[ $lastViewedDate == '' ]]; then
					sqlStmt="insert into $newsInfoTable values(NULL,\"$newsType\",\"$userName\",NOW(),\"$(date +%s)\")"
				else
					sqlStmt="update $newsInfoTable set date=NOW(),edate=\"$(date +%s)\" where userName=\"$userName\" and object=\"$newsType\""
				fi
				RunSql 'mysql' "$sqlStmt"
		done
			[[ $newsDisplayed == true ]] && Msg2
	return 0
} #DisplayNews

#===================================================================================================
# Common script start
#===================================================================================================
function Hello {
	[[ $quiet == true || $noHeaders == true || $secondaryMessagesOnly == true ]] && return 0
	[[ $batchMode != true && $noClear != true && $TERM != 'dumb' ]] && clear
	Msg2
	[[ $TERM == 'dumb' ]] && echo
	Msg2 "$(PadChar)"
	date=$(date)

	[[ "$version" = "" ]] && version=1.0.0
	[[ $myTitle != '' ]] && title=" - $myTitle" || title=''
	Msg2 "${myName} (Script version: $version, Framework version: $frameworkVersion)$title"

	[[ "$myDescription" != "" ]] && Msg2 && Msg2 "$myDescription"
	Msg2 "User: $userName, Host: $hostName, Date: $date PID: $$"
	[[ "$originalArgStr" != '' ]] && Msg2 "Arg String:($originalArgStr)"

	[[ ${myPath:0:6} == '/home/' ]] && 	Msg2 "$(ColorW "*** Running from '$myPath'")"
	[[ $testMode == true ]] && Msg2 "$(ColorW "*** Running in Testmode")"
	[[ "$DOIT" != ''  ]] && Msg2 "$(ColorW "*** The 'Doit' flag is turned off, changes not committed")"
	[[ "$informationOnlyMode" == true  ]] && Msg2 "$(ColorW "*** The 'informationOnly' flag is set, changes not committed")"
	[[ $userName != $LOGNAME ]] && Msg2 "$(ColorK "*** Running as user $userName")"

	Msg2

	## Display script and tools news
		DisplayNews

	return 0
} #Hello

################################################################################
# Common script exit
# args:
# 	exitCode, if exitCode = 'X' the quit without messages
# 	additionalText, if first token of additional text is 'alert' then call Alert
################################################################################
function Goodbye {

	set +xveE
	SetFileExpansion 'off'
	Msg2 $V3 "*** Starting: $FUNCNAME ***"

	local exitCode=$1; shift
	local additionalText=$*
	dump -3 exitCode additionalText

	local tokens
	local alert=false
	local token=$(Lower $(echo $additionalText | cut -d' ' -f1))
	[[ $token == 'alert' ]] && alert=true && shift && additionalText=$*
	[[ "$exitCode" = "" ]] && exitCode=0

	## Call script specific goodbye script if defined
		[[ $(type -t $FUNCNAME-$myName ) == 'function' ]] && $FUNCNAME-$myName "$exitCode"
		[[ $(type -t $FUNCNAME-local ) == 'function' ]] && $FUNCNAME-local "$exitCode"

	## Cleanup temp files
		rm -rf $tmpRoot > /dev/null 2>&1

	## Exit Process
	case "$(Lower "$exitCode")" in
		quiet)
			dbLog 'remove' $myLogRecordIdx
			exitCode=0
			;;
		quickquit)
			dbLog 'remove' $myLogRecordIdx
			Msg2 "\n*** Stopping at user's request (quickQuit) ***"
			exitCode=0
			;;
		x)
			dbLog 'remove' $myLogRecordIdx
			Msg2 "\n*** Stopping at user's request (x) ***"
			exitCode=0
			;;
		*)
			## Write end record to db log
				[[ $logInDb != false && $myLogRecordIdx != "" ]] && dbLog 'xitCode' $myLogRecordIdx "$exitCode"

			## If there are any forked process, then wait on them
				if [[ ${#forkedProcesses[@]} -gt 0  && $waitOnForkedProcess == true ]]; then
					Msg2; Msg2 "*** Waiting for ${#forkedProcesses[@]} forked processes to complete ***"
					for pid in ${forkedProcesses[@]}; do
						wait $pid;
					done;
					Msg2 '*** All forked process have completed ***'
				fi

			## calculate epapsed time
				if [[ epochStime != "" ]]; then
					epochEtime=$(date +%s)
					endTime=$(date '+%Y-%m-%d %H:%M:%S')
					elapSeconds=$(( epochEtime - epochStime ))
					eHr=$(( elapSeconds / 3600 ))
					elapSeconds=$(( elapSeconds - eHr * 3600 ))
					eMin=$(( elapSeconds / 60 ))
					elapSeconds=$(( elapSeconds - eMin * 60 ))
					eSec=$elapSeconds
					elapTime=$(printf "%02dh %02dm %02ds" $eHr $eMin $eSec)
				fi

			## print goodbye message
				date=$(date)
				if [[ $quiet != true && $noHeaders != true && $secondaryMessagesOnly != true ]]; then
					## Standard messages
						local numMsgs=0
						Alert 'off'
						if [[ ${#summaryMsgs[@]} -gt 0 && $displayGoodbyeSummaryMessages == true ]]; then
							Msg2
							PrintBanner "Processing Summary"
							Msg2
							for msg in "${summaryMsgs[@]}"; do Msg2 "^$msg"; done
							let numMsgs=$numMsgs+${#summaryMsgs[@]}
						fi
						if [[ ${#warningMsgs[@]} -gt 0 && $displayGoodbyeSummaryMessages == true ]]; then
							Msg2
							PrintBanner "${#warningMsgs[@]} warning message(s) were issued during processing"
							Msg2
							for msg in "${warningMsgs[@]}"; do Msg2 "^$msg"; done
							let numMsgs=$numMsgs+${#warningMsgs[@]}
						fi
						if [[ ${#errorMsgs[@]} -gt 0 && $displayGoodbyeSummaryMessages == true ]]; then
							Msg
							PrintBanner "${#errorMsgs[@]} error message(s) were issued during processing"
							Msg
							for msg in "${errorMsgs[@]}"; do Msg2 "^$msg"; done
							let numMsgs=$numMsgs+${#errorMsgs[@]}
						fi
						[[ $numMsgs -gt 0 ]] && printf "\n$(PadChar)\n"
						Alert 'on'

					Msg2
					if [[ $(Lower $exitCode) == 'x' ]]; then
						Msg2 "*** Stopping at user's request ***"
					elif [[ $exitCode -eq 0 ]]; then
						[[ $DOIT != '' ]] && Msg2 "$(ColorE "*** The 'DOIT' flag is turned off, changes not committed ***")"
						[[ $informationOnlyMode == true ]] && Msg2 "$(ColorE "*** Information only mode, no data updated ***")"
						Msg2 "$(ColorK "${myName}") $(ColorI " -- $additionalText completed successfully.")"
						[[ $logFile != '/dev/null' ]] && Msg2 "Additional details may be found in '$logFile'"
						Msg2 "$date (Elapsed time: $elapTime)"
						[[ $TERM == 'dumb' ]] && echo
						Msg2 "$(PadChar)"
					else
						[[ $DOIT != '' ]] && Msg2 "$(ColorE "*** The 'DOIT' flag is turned off, changes not committed ***")"
						[[ $informationOnlyMode == true ]] && Msg2 "$(ColorE "*** Information only mode, no data updated ***")"
						Msg2 "-$(ColorK "${myName}") $(ColorE " -- $additionalText completed with errors, exit code = $exitCode")\a"
						[[ $logFile != '/dev/null' ]] && Msg2 "Additional details may be found in '$logFile'"
						Msg2 "$date (Elapsed time: $elapTime)"
						[[ $TERM == 'dumb' ]] && echo
						Msg2 "$(PadChar)"
					fi
					Msg2
				fi #not quiet noHeaders secondaryMessagesOnly
			[[ $alert == true ]] && Alert
	esac
	#[[ $calledViaScripts != true ]] && exit $exitCode || return 0
	exit $exitCode
} #Goodbye

#===================================================================================================
# Process semaphores
# Semaphore <mode> <key/name> <sleeptime>
#	mode = 	set <name>					-- Sets a semaphore for 'name' on the current host
#			check <name>				-- Checks to see if semaphore with 'name' is set in the current host
#			clear <keyid>				-- Clears semaphore with key = '$keyid'
#			waiton <name> <sleeptime>	-- waits on any semaphore set for 'name' on any host
#										   if name is 'self', then will wait on name '$myName'
#===================================================================================================
# 03-22-16 -- dgs - added documentation, tweaked waiton to support 'self'
#===================================================================================================
function Semaphore {
	local mode=$1
	mode=$(Lower $mode)
	local keyId=$2
	[[ $keyId == 'self' ]] && keyId="$myName"
	local checkAllHosts=${3:-false}
	local sleepTime=5
	local sqlStmt result printMsg andClause

	[[ $checkAllHosts != false ]] && unset andClause || andClause="and hostName=\"$hostName\""
	dump -3 mode keyId checkAllHosts sleeptime andClause

	if [[ $mode = 'set' ]]; then
		sqlStmt="insert into $semaphoreInfoTable (keyId,processName,hostName,createdBy,createdOn) \
						 values(NULL,\"$myName\",\"$hostName\",\"$userName\",\"$startTime\")";
		RunSql 'mysql' $sqlStmt
		sqlStmt="select max(keyId) from $semaphoreInfoTable"
		RunSql 'mysql' $sqlStmt
		echo ${resultSet[0]}

	elif [[ $mode = 'check' ]]; then
		sqlStmt="select count(*) from $semaphoreInfoTable where processName=\"$keyId\" $andClause";
		RunSql 'mysql' $sqlStmt
 		[[ ${resultSet[0]} -ne 0 ]] && echo false || echo true

	elif [[ $mode = 'clear' ]]; then
		sqlStmt="delete from $semaphoreInfoTable where keyId=\"$keyId\"";
		RunSql 'mysql' $sqlStmt

	elif [[ $mode = 'waiton' ]]; then
		count=1
		#echo 'Starting wait on' >> ~/stdout.txt
		while [[ $count -gt 0 ]]; do
			sqlStmt="select count(*) from $semaphoreInfoTable where processName=\"$keyId\"";
			RunSql 'mysql' $sqlStmt
 			[[ ${#resultSet[@]} -ne 0 ]] && count=${resultSet[0]} || count=0
 			[[ $count -gt 0 ]] && dump -3 -l -t count && sleep $sleepTime
		done
	fi

	return 0
} #Semaphore

#===================================================================================================
# Display a selection menue
# SelectMenu <MenueItemsArrayName> <returnVariableName> <Prompt text>
#===================================================================================================
function SelectMenu {

	local menuListArrayName=$1[@]
	local menuListArray=("${!menuListArrayName}")
	PushSettings "$FUNCNAME"
	shift
	local returnVarName=$1
	shift
	PopSettings
	local menuPrompt=$*
	[[ $menuPrompt == '' ]] && menuPrompt="\nPlease enter the (ordinal) number for an item above (or 'X' to quit) > "

	## Write out screen
		numMenuItems=${#menuListArray[@]}
		maxIdxWidth=${#numMenuItems}
		local i
		for (( i=0; i<=$(( $numMenuItems-1 )); i++ )); do
			printi=$(printf "%$maxIdxWidth"s "$i")
			printf "\t($printi) ${menuListArray[i]}\n"
		done

		printf "$menuPrompt"
		unset ans
		while [[ $ans == '' ]]; do
			read ans; ans=$(Lower $ans)
			#dump ans
			#echo '${#menuListArray[@]} = >'${#menuListArray[@]}'<'
			[[ ${ans:0:1} == 'x' || ${ans:0:1} == 'q' ]] && eval $returnVarName='' && return 0
			#echo '${#menuListArray[@]} = >'${#menuListArray[@]}'<'
			#echo '$(IsNumeric $ans)  = >'$(IsNumeric $ans)'<'
			if [[ $ans != '' && $ans -ge 0 && $ans -lt ${#menuListArray[@]} && $(IsNumeric $ans) == true ]]; then
				#eval $returnVarName=$(echo "${menuListArray[$ans]}" | cut -d" " -f1)
				#dump returnVarName
				#echo '${menuListArray[$ans]} = >'${menuListArray[$ans]}'<'
				[[ ${returnVarName:(-2)} == 'Id' ]] && eval $returnVarName=\"$ans\"|| eval $returnVarName=\"${menuListArray[$ans]}\"
				#eval $returnVarName=\"${menuListArray[$ans]}\"
				return 0
			else
				printf "*Error* -- Invalid selection ('$ans'), please try again > "
				unset ans
			fi
		done
		[[ $logFile != '' ]] && Msg2 "\n^$FUNCNAME: User selected '$ans', ${menuListArray[i]} " >> $logFile

	return 0
} #SelectMenu

#===================================================================================================
# Display a selection menue
# SelectMenuNew <MenueItemsArrayName> <returnVariableName> <Prompt text>
# First line of the array is the header, first char of the header is the data delimiter
#
# If lst 2 chars of the returnVariableName is 'ID' then will return the ordinal number of the
# response, otherwise the input line responding to the ordinal selected will be returned
#===================================================================================================
# 03-8-16 - dgs - initial
#===================================================================================================
function SelectMenuNew {
	local menuListArrayName=$1[@]
	local menuListArray=("${!menuListArrayName}"); shift
	local returnVarName=$1; shift
	local menuPrompt=$*
	[[ $menuPrompt == '' ]] && menuPrompt="\n${tabStr}Please enter the ordinal number $(ColorM "(ord)") for an item above (or 'X' to quit) > "
	local screenWidth=80
	[[ $TERM != '' && $TERM != 'dumb' ]] && screenWidth=$(stty size </dev/tty | cut -d' ' -f2)
	#let screenWidth=$screenWidth+12
	local printStr

	## Parse header
		local numCols=0
		local char1
		header="${menuListArray[0]}"
		delim=${header:0:1}
		for (( i=0; i<=${#header}; i++ )); do
			[[ ${header:$i:1} == $delim ]] && let numCols=numCols+1;
		done
		dump -3 header delim numCols

	## Loop through data and get the max widths of each column
		maxWidths=()
		for record in "${menuListArray[@]}"; do
			record="${record:1}"
			for (( i=1; i<=$numCols; i++ )); do
				local tmpStr="$(echo "$record" | cut -d$delim -f$i)"
				maxWidth=${maxWidths[$i]}
				[[ ${#tmpStr} -gt $maxWidth ]] && maxWidths[$i]=${#tmpStr}
			done
		done
		if [[ $verboseLevel -ge 3 ]]; then for (( i=1; i<= $numCols; i++ )); do echo '${maxWidths[$i]} = >'${maxWidths[$i]}'<'; done fi

	## Loop through data and build menu lines
		menuItems=()
		for record in "${menuListArray[@]}"; do
			record="${record:1}"
			unset menuItem
			for (( i=1; i<=$numCols; i++ )); do
				local tmpStr="$(echo "$record" | cut -d$delim -f$i)"$(PadChar ' ' 200)
				maxWidth=${maxWidths[$i]}
				menuItem=$menuItem${tmpStr:0:$maxWidth+3}
			done
			dump -3 menuItem
			menuItems+=("$menuItem")
		done

	## Display menue
		numMenuItems=${#menuItems[@]}
		maxIdxWidth=${#numMenuItems}

		## Print header
			ord="ord$(PadChar ' ' 10)"
			ord=${ord:0:$maxIdxWidth+2}
			printStr="${tabStr}${ord} ${menuItems[0]}"
			printStr="${printStr:0:$screenWidth}"
			echo -e "$(ColorM "$printStr")"
		## Print 'data' rows
			for (( i=1; i<=$(( $numMenuItems-1 )); i++ )); do
				printi=$(printf "%$maxIdxWidth"s "$i")
				#printStr="    $(ColorM "($printi)") ${menuItems[i]}"
				printStr="${tabStr}$(ColorM "($printi)") ${menuItems[i]}"
				printStr="${printStr:0:$screenWidth}"
				echo -e "$printStr"
			done
		## Print prompt
		echo -ne "$menuPrompt"
		((i--))
		#let i=$i-1
		validVals="{1-$i}"

	## Loop on response
		unset ans
		while [[ $ans == '' ]]; do
			read ans; ans=$(Lower $ans)
			[[ ${ans:0:1} == 'x' || ${ans:0:1} == 'q' ]] && eval $returnVarName='' && return 0
			[[ ${ans:0:1} == 'r' ]] && eval $returnVarName='REFRESHLIST' && return 0
			if [[ $ans != '' && $ans -ge 0 && $ans -lt ${#menuItems[@]} && $(IsNumeric $ans) == true ]]; then
				eval $returnVarName=$(echo "${menuItems[$ans]}" | cut -d" " -f1)

				if [[ $(Lower ${returnVarName:(-2)}) == 'id' ]]; then
					eval $returnVarName=\"$ans\"
				else
					#echo '${menuListArray[$ans]} = >'${menuListArray[$ans]}'<'
					local tempStr=$(echo ${menuListArray[$ans]} | cut -d"$delim" -f2-)
					eval $returnVarName=\"$tempStr\"
				fi

				[[ $logFile != '' ]] && Msg2 "\n^$FUNCNAME: User selected '$ans', '${menuListArray[$ans]}'" >> $logFile
				return 0
			else
				printf "${tabStr}$(ColorE *Error*) -- Invalid selection, '$ans', valid value in $validVals, please try again > "
				unset ans
			fi
		done
} #SelectMenuNew

#===================================================================================================
# Display a selection menue of files in a directory that match a filter
# SelectFile <dir> <returnVariableName> <filter> <Prompt text>
# Files are displayed newest to oldest
# Sets the value of <returnVariableName> to the file selected
#===================================================================================================
# 03-8-16 - dgs - initial
#===================================================================================================
function SelectFile {
	local dir=$1; shift
	local returnVarName=$1; shift
	local fileFilter="$1"; shift
	local menuPrompt="$*"
	[[ $menuPrompt == '' ]] && menuPrompt="\nPlease enter the (ordinal) number for an item above (or 'X' to quit) > "
	[[ ! -d $dir ]] && eval $returnVarName='' && return 0

	## Get a list of files, if none found return
		SetFileExpansion 'on'
		tmpDataFile="/tmp/$userName.$myName.$BASHPID.data"
		cd "$dir"
		ProtectedCall "ls -t $fileFilter 2> /dev/null | grep -v '~' > "$tmpDataFile""
		numLines=$(ProtectedCall "wc -l "$tmpDataFile"")
		numLines=$(echo $(ProtectedCall "wc -l "$tmpDataFile"") | cut -d' ' -f1)
	## If only one file found then just return it
		[[ $numLines -eq 0 ]] && rm -f "$tmpDataFile" && eval $returnVarName='' && SetFileExpansion && return 0
		if [[ $numLines -eq 1 ]]; then
			read -r selectResp < "$tmpDataFile"
			rm -f "$tmpDataFile"
			eval "$returnVarName=\"$selectResp\""
			SetFileExpansion
			return 0
		fi
	##Build menuList
		local menuList
		menuList+=("|File Name|File last mod date")
		while IFS=$'\n' read -r line; do
			file=$line
			#cdate=$(stat -c %y "$file" | cut -d'.' -f1 | awk 'BEGIN {FS=" "}{printf "%s at %s", $1,$2}')
			menuList+=("|$file|$(stat -c %y "$file" | cut -d'.' -f1 | awk 'BEGIN {FS=" "}{printf "%s at %s", $1,$2}')")
		done < "$tmpDataFile"
		[[ -f "$tmpDataFile" ]] && rm -f "$tmpDataFile"

	##Display menu
		local selectResp
		printf "$menuPrompt"
		SelectMenuNew 'menuList' 'selectResp' "\nEnter the $(ColorK '(ordinal)') number of the file you wish to use (or 'X' to quit) > "
		[[ $selectResp == '' ]] && SetFileExpansion && Goodbye 0 || selectResp=$(cut -d'|' -f1 <<< $selectResp)
		eval $returnVarName=\"$(echo "$selectResp" | cut -d"|" -f2)\"

	SetFileExpansion
	return 0
} # SelectFile

#===================================================================================================
# Get a sting of a char repeated n times
# PadChar <char> <count>
#===================================================================================================
function PadChar {

	local char="$1"; shift
	local len=$1
	local re='^[0-9]+$'
	#[[ $len -eq 0 ]] && echo '' && return 0

	[[ ${char:1} =~ $re ]] && len=$char && unset char
	[[ $char == '' ]] && char='='

	if [[ $len == '' ]]; then
		[[ $TERM == 'xterm' ]] && len=$(stty size </dev/tty | cut -d' ' -f2) || len=80
	fi

	echo "$(head -c $len < /dev/zero | tr '\0' "$char")"
	return 0
} #PadChar

#===================================================================================================
# Print a banner
#===================================================================================================
function PrintBanner {
	local centerText=$*
	local centerPad printStr len
	local horizontalLine="$(PadChar)"
	echo "$horizontalLine"
	[[ $TERM == 'xterm' ]] && len=$(stty size </dev/tty | cut -d' ' -f2) || len=80
	if [[ ${#centerText} -ge $len ]]; then
		printStr="$centerText"
	else
		let centerPad=$len-2-${#centerText}; let centerPad=$centerPad/2
		printStr="=$(PadChar ' ' ${centerPad})${centerText}$(PadChar ' ' ${centerPad})     "
		printStr=${printStr:0:$len-1}
	fi
	echo -e "${printStr}="
	echo "$horizontalLine"

	return 0
} #PrintBanner

#===================================================================================================
# Turn signal process off
#===================================================================================================
function TrapSigs {
	local mode=${1: -on}

	if [[ $mode == 'on' ]]; then
		trap 'SigHandeler ERR ${LINENO} ${?}' ERR
		trap 'SigHandeler SIGINT ${LINENO} ${?}' SIGINT
		trap 'SigHandeler SIGTERM ${LINENO} ${?}' SIGTERM
		trap 'SigHandeler SIGQUIT ${LINENO} ${?}' SIGQUIT
		trap 'SigHandeler SIGHUP ${LINENO} ${?}' SIGHUP
		trap 'SigHandeler SIGABRT ${LINENO} ${?}' SIGABRT
	else
		trap - ERR SIGINT SIGTERM SIGQUIT SIGHUP SIGABRT
	fi
	return 0
}

#===================================================================================================
# Process interrupts
#===================================================================================================
function SigHandeler {
	local sig="$(Upper $1)"
    local errorLineNo="$2"
    local errorCode="$3"
    parentModule="$(echo $(caller) | cut -d' ' -f2)"
    local errorLine="$(Trim "$(sed "$errorLineNo!d" "$parentModule")")"
	#dump -p sig errorLineNo errorCode parentModule errorLine
    local message

	echo -e "\n$(PadChar)"
    if [[ $sig == 'ERR' ]]; then
    	message="$FUNCNAME: Unknow error condition ($errorCode) raised in module\n^$parentModule, $(ColorE "line($errorLineNo)"):\n^$(ColorK "$errorLine")"
    	Msg2 $E "$message";
    	Msg2 $E "Call Stack: $(GetCallStack)"
    	Goodbye -1
    #elif [[ $sig == 'EXIT' ]]; then
    #	message="$FUNCNAME: Trapped signal: '$sig' in module\n\t'$parentModule', please replace with 'Goodbye' or 'Quit'"
    #	Msg "W $message\t";
    #	Goodbye -1
    elif [[ $sig == 'SIGINT' || $sig == 'SIGQUIT' ]]; then
    	message="$FUNCNAME: Trapped signal: '$sig', script '$myName' is terminating at user's request"
    	Msg2 $W "$message";
    	Goodbye -1
    elif [[ $sig == 'SIGHUP' ]]; then
    	Goodbye -1
    else
    	message="$FUNCNAME: Trapped signal: '$sig' in module\n^'$parentModule'"
    	Msg2 $E "$message";
    	Msg2 "^Call Stack: $(GetCallStack)"
    	Goodbye -1
    fi
	return 0
} #Signal_handler

#===================================================================================================
# Run a command and ignore non zero exit code trapping
#===================================================================================================
function ProtectedCall {
	IfMe echo "In $FUNCNAME \$\* = >"$*'<'
	previousTrapERR=$(trap -p ERR | cut -d ' ' -f3-)
	trap - ERR
	[[ $verbose == true && $verboseLevel -gt 1 ]] && printf "\n$FUNCNAME - $(date)\n" >> $stdout && printf "\tcwd: $(pwd)\n" >> $stdout && printf "\t$*\n\n" >> $stdout
	SetFileExpansion 'on'
	rc=0
	eval "$*"
	rc=$?
	SetFileExpansion
	[[ $previousTrapERR != '' ]] && eval "trap $previousTrapERR"
	return 0
}

#===================================================================================================
# Start a remote session via ssh
# StartRemoteSession userid@domain [command]
#===================================================================================================
function StartRemoteSession {
	local remoteUserAtHost=$1; shift
	local remoteCommand="$*"

	local commmandPrefix pwRec lookupKey tokens remoteHost remoteUser remotePw remoteDomain
	unset pwRec

	remoteUser=$(cut -d '@' -f1 <<< $remoteUserAtHost)
	remoteDomain=$(cut -d '@' -f2 <<< $remoteUserAtHost)
	remoteHost=$(cut -d '.' -f1 <<< $remoteDomain)
	lookupKey=$remoteHost

	#E Does the user have sshpass and a .pw2 file in their home directory
	local pwFile=$HOME/.pw2
	whichOut=$(ProtectedCall "which sshpass 2> /dev/null")
	if [[ $whichOut != '' && -r $pwFile && $lookupKey != '' ]]; then
		pwRec=$(grep "^$lookupKey" $pwFile)
		if [[ $pwRec != '' ]]; then ## [0]=key, [1]=userid, [2]=password, [3]=remoteHost
			read -ra tokens <<< "$pwRec"
			[[ ${tokens[3]} != '' ]] && remoteUserAtHost="${tokens[1]}@${tokens[3]}" || remoteUserAtHost="${tokens[1]}@${remoteDomain}"
			commmandPrefix="sshpass -p ${tokens[2]}"
		fi
	fi

	[[ $(Contains "$remoteUserAtHost" '.') == false ]] && remoteUserAtHost="${remoteUserAtHost}.leepfrog.com"
	[[ $(Contains ",$slowHosts," ",$remoteHost,") == true ]] && Msg2 $N "Target host has been found to be a bit slow, please be patient" && Msg2
	$commmandPrefix ssh $remoteUserAtHost $remoteCommand
	return 0
} ## StartRemoteSession

#=========================================================================================================================================================================
# Setup the execution environment for a secondary interpreter
# SetupInterpreterExecutionEnv [interpreter|python] [interpreterVer]
# Interpreters supported are {'python','go'}
# if interpreterVer is not specified then it will look for a env variable called 'Use<Interpreter>Ver' to use, if that is not found it defaults to 'current'
# Sets the interpreter gloal variales, dowes not effect the PATH
#=========================================================================================================================================================================
function SetupInterpreterExecutionEnv {
	local interpreter=${1:-python}; shift
	local interpreterVer=$1
	local interpreterVar
	if [[ $interpreterVer == '' ]]; then
		interpreterVar="Use$(TitleCase "$interpreter")Ver"
		interpreterVer=${!interpreterVar}
	fi
	[[ $interpreterVer == '' ]] && interpreterVer='current'

	local interpreterRoot interpreterBinDir
	cwd=$(pwd)
	dump -3 -t interpreter interpreterVer osName osVer

	## Find the interpreter root, check for local directory, then TOOLSPROD
		local interpreterRoot; unset interpreterRoot
		[[ -d $HOME/$interpreter ]] && interpreterRoot="$HOME/$interpreter"
		[[ $interpreterRoot == '' && -d $HOME/$(TitleCase "$interpreter") ]] && interpreterRoot="$HOME/$(TitleCase $interpreter)"
		[[ $interpreterRoot == '' && -d $TOOLSPATH/$interpreter ]] && interpreterRoot="$TOOLSPATH/$interpreter"
		[[ $interpreterRoot == '' && -d $TOOLSPATH/$(TitleCase $interpreter) ]] && interpreterRoot="$TOOLSPATH/$(TitleCase $interpreter)"

		[[ -d $interpreterRoot/$osName ]] && interpreterRoot="$interpreterRoot/$osName"
		[[ -d $interpreterRoot/$osVer ]] && interpreterRoot="$interpreterRoot/$osVer"
		dump -3 -t interpreterRoot

	## Find the interpreter root directory
		cd "$interpreterRoot"
		[[ ! -d $interpreterRoot/$interpreterVer ]] && interpreterVer="$(find -maxdepth 1 -mindepth 1 -type d -name "$interpreterVer*" -printf '%f\n' | sort -n -r -t / | cut -d$'\n' -f1)"
		interpreterBinDir="$interpreterRoot/$interpreterVer/bin"
		dump -3 -t interpreterVer interpreterBinDir

	## Interpreter specific stuff
		interpreter="$(Lower "$interpreter")"
		if [[ $interpreter == 'python' ]]; then
			PYDIR="$(dirname $interpreterBinDir)"
			cd "$interpreterBinDir"
			local pip="$(find -maxdepth 1 -mindepth 1 -type f -name "pip*" -printf '%f\n' | sort -n -r -t / | cut -d$'\n' -f1)"
			alias pip="$interpreterBinDir/$pip"
			local pypm="$(find -maxdepth 1 -mindepth 1 -type f -name "pypm*" -printf '%f\n' | sort -n -r -t / | cut -d$'\n' -f1)"
			alias pypm="$interpreterBinDir/$pypm"
			cd "$(dirname $interpreterBinDir)/lib/"
			local lib="$(find -maxdepth 1 -mindepth 1 -type d -name "python*" -printf '%f\n' | sort -n -r -t / | cut -d$'\n' -f1)"
			export "PYTHONPATH=$(pwd)/$lib/site-packages"
		elif [[ $interpreter == 'go' ]]; then
			export GOROOT=$interpreterBinDir
			GOPATH="$TOOLSPATH/src/go"
			[[ -d $HOME/tools/go ]] && GOPATH="$HOME/tools/go:$GOPATH"
			#[[ -d $HOME/work ]] && GOPATH="$HOME/work:$GOPATH"
		fi

	cd "$cwd"
	return 0
} #SetupInterpreterExecutionEnv

#===================================================================================================
# Quick quit
#===================================================================================================
function Quit {
	exitCode=$1
	Goodbye 'quickQuit'
} #Quit
function quit { Quit $* ; }
function q { Quit $* ; }

function QUIT { trap - ERR EXIT; set +xveE; rm -rf $tmpRoot > /dev/null 2>&1; exit; }
function QQ { QUIT ; }

#===================================================================================================
# Save or restore shell settings
#===================================================================================================
function PushSettings {
	local tempArray=($(set -o | tr "\t" ' ' | tr -s ' '))
	local vSetting=$(set -o | grep verbose | tr "\t" ' ' | tr -s ' ' | cut -d' ' -f2)
	local xSetting=$(set -o | grep xtrace | tr "\t" ' ' | tr -s ' ' | cut -d' ' -f2)
	set +vx

	local idx=${1:-N/A}
	local i settingsString attr attrVal

	for ((i = 0 ; i < ${#tempArray[@]} ; i++)); do
	 	attr=${tempArray[$i]}
	 	attrVal=${tempArray[$i+1]}
	 	#echo -e 'attr = >'$attr'<, attrVal = >'$attrVal'<'
	 	settingsString="${settingsString}|${attr} ${attrVal}"
	 	#echo -e 'settingsString = >'$settingsString'<'
	 	i=$((i + 1))
	done
	savedSettings+=("${idx} ${settingsString:1}")
	[[ $vSetting == 'on' ]] && set -o verbose || set +o verbose
	[[ $xSetting == 'on' ]] && set -o xtrace || set +o xtrace
	return 0
} #PushSettings

function PopSettings {
	vSetting=$(set -o | grep verbose | tr "\t" ' ' | tr -s ' ' | cut -d' ' -f2)
	xSetting=$(set -o | grep xtrace | tr "\t" ' ' | tr -s ' ' | cut -d' ' -f2)
	set +vx

	local idx=${1:-N/A}
	local i setting settingsString attr attrVal tempArray
	[[ ${#savedSettings[@]} -eq 0 ]] && return 0

	for ((i = ${#savedSettings[@]}-1 ; i >= 0 ; i--)); do
		#echo; echo $i ${savedSettings[$i]}
		savedIdx=$(echo ${savedSettings[$i]} | cut -d' ' -f 1)
		[[ $savedIdx == $idx || $savedIdx == 'N/A' ]] && break
	done
	if [[ $i -ge 0 ]]; then
		settingsString=$(echo ${savedSettings[$i]} | cut -d' ' -f 2-)
		#dump settingsString
		IFSave="$IFS"; IFS=$'|'
		read -r -a tempArray <<< "${settingsString}"
		IFS="$IFSave"
		for setting in "${tempArray[@]}"; do
			attr=$(echo $setting | cut -d' ' -f 1)
			attrVal=$(echo $setting | cut -d' ' -f 2)
			#dump -n setting -t attr attrVal
			[[ $attrVal == 'on' ]] && set -o ${attr} || set +o ${attr}
		done
		unset savedSettings[$i]
	fi
	[[ $vSetting == 'on' ]] && set -o verbose || set +o verbose
	[[ $xSetting == 'on' ]] && set -o xtrace || set +o xtrace
	return 0
} #PopSettings

#===================================================================================================
# Recursively modify attrributes for each directory in a path
#===================================================================================================
function CmdAlongPath {
	declare cmd="$1"
	declare root="$2"
	declare dir="$3"
	if [[ ${dir:0:1} != '/' ]]; then dir=/$dir; fi
	IFS='/' read -ra dirs <<< "$dir"
	path=$root
	for dir in "${dirs[@]:1}"; do
		path=$path'/'$dir
 		$cmd $path > /dev/null 2>&1
	done

	return 0
} #CmdAlongPath

#===================================================================================================
# Ring the bell
# Alert <#ofAlerts> <sleepTime>
# Defaults: 5 1
#===================================================================================================
function Alert {
	[[ $batchMode == true || $quiet == true ]] && return 0
	local numAlerts=$1; shift || true
	if [[ $numAlerts != '' && $(IsNumeric $numAlerts) == false ]]; then
	 [[ $numAlerts == 'on' ]] && allowAlerts=true || allowAlerts=false
	 return 0
	fi

	if [[ $numAlerts = '' ]]; then numAlerts=4; fi
	local sleepTime=$1
	if [[ $sleepTime = '' ]]; then sleepTime=1; fi
   local cntr=1
	until [  $cntr -gt $numAlerts ]; do
		printf "\a";
		sleep $sleepTime;
		let cntr=cntr+1
	done

	return 0
} #Alert

#===================================================================================================
# Check to see if the url is valid using ping
#===================================================================================================
function IsValidURL {
	local url=$1
	local tmpFile=$(mkTmpFile $FUNCNAME)

	ProtectedCall "ping -c 1 $url > $tmpFile 2>&1"
	grepStr=$(ProtectedCall "grep 'ping: unknown host' $tmpFile")
	[[ $grepStr == '' ]] && echo true || echo false
	rm $tmpFile
	return 0
} #IsValidURL

#===================================================================================================
# Set the noglob value
#===================================================================================================
function SetFileExpansion {
	local mode=$1
	local prev

	if [[ $mode == '' ]]; then
		if [[ ${#previousFileExpansionSettings[@]} -eq 0 ]]; then
			previousFileExpansionSettings+=($(set -o | grep noglob | tr "\t" ' ' | tr -s ' ' | cut -d' ' -f2))
			return 0
		fi

		## Toggle value
		prev=${previousFileExpansionSettings[${#previousFileExpansionSettings[@]}-1]}
		unset previousFileExpansionSettings[${#previousFileExpansionSettings[@]}-1]
		[[ $prev == 'on' ]] && set -f || set +f
		return 0
	fi

	previousFileExpansionSettings+=($(set -o | grep noglob | tr "\t" ' ' | tr -s ' ' | cut -d' ' -f2))
	[[ $(Lower $mode) == 'on' ]] && set +f || set -f

	return 0
}

#===================================================================================================
# Check to see if passed string consists of only mumerics
#===================================================================================================
function IsNumeric {
	local reNum='^[0-9]+$'
	[[ $1 =~ $reNum ]] && echo true || echo false
	return 0
} #IsNumeric

#===================================================================================================
# Upper case a string
#===================================================================================================
function Upper {
	## Need to use printf, echo absorbs '-n'
	printf "%s" $(printf "%s" "$*" | tr '[:lower:]' '[:upper:]')
	return 0
} #Upper

#===================================================================================================
# Title case a string
#===================================================================================================
function Lower {
	## Need to use printf, echo absorbs '-n'
	printf "%s" $(printf "%s" "$*" | tr '[:upper:]' '[:lower:]')
	return 0
} #Lower

#===================================================================================================
# Title case a string
#===================================================================================================

function TitleCase {
	local string="$*"
	echo "$(Upper "${string:0:1}")${string:1}"
	return 0
} #TitleCase

#===================================================================================================
# Rtrip all non printable chars from a variable
#===================================================================================================
function Trim {
 	echo "$(echo $* | sed 's/^[ \t]*//;s/[ \t]*$//')"
 	return 0
} #Trim

#===================================================================================================
# Remove special chars from a string
#===================================================================================================
function CleanString {
	local inStr="$*"
	local editOut1='\000\001\002\003\004\005\006\007\008\009\010\011\012\013\014\015\016\017\018\019'
	local editOut2='\020\021\022\023\024\025\026\027\028\029\030\031\032\033\034\035\036\037\038\039'
	inStr=$(tr -d $editOut1 <<< "$inStr")
	inStr=$(tr -d $editOut2 <<< "$inStr")
 	echo "$inStr"
 	return 0
} #CleanString

#=================================================================================================
## Dump an array, pass in the name of the array as follows
# DumpArray <msgLevel> keysArray[@]
# e.g. DumpArray keysArray[@]
# e.g. DumpArray 1 keysArray[@]
#===================================================================================================
function DumpArray {

	## If we have 2 parms passed the parse off the msgLevel
		if [[ ${#*} -eq 2 ]]; then
			local dumpLevel=$1; shift
			[[ $dumpLevel -gt $verboseLevel ]] && return 0
		fi

	declare -a argArray=("${!1}")
	echo "Array: $1"
	local total=${#argArray[*]}
	local i
	for (( i=1; i<=$(( $total -1 )); i++ )); do
		echo -e "\t[$i] = >${argArray[$i]}<"
	done
	return 0
} # DumpArray

#==================================================================================================
# Dump an hash table
# DumpMap <msgLevel> HashArrayDef
# e.g. DumpMap "$(declare -p variableMap)"
# e.g. DumpMap 1 "$(declare -p variableMap)"
#==================================================================================================
function DumpMap {
	local dumpMapCtr dumpMapKeyStr dumpMapMaxKeyWidth

	## If we have 2 parms passed the parse off the msgLevel
		if [[ ${#*} -eq 2 ]]; then
			local dumpLevel=$1; shift
			[[ $dumpLevel -gt $verboseLevel ]] && return 0
		fi

	## Get the name of the map we are printing, make a copy of the array
		local dumpMapName=$(cut -d'=' -f1 <<< $*);
		dumpMapName=$(cut -d' ' -f3 <<< $dumpMapName)
		eval "declare -A dumpMap="${1#*=}

	## Get the max width of the keys
		for dumpMapCtr in "${!dumpMap[@]}"; do [[ ${#dumpMapCtr} -gt $dumpMapMaxKeyWidth ]] && dumpMapMaxKeyWidth=${#dumpMapCtr}; done;

	## Print the map
		echo; echo "Map '$dumpMapName':"
		for dumpMapCtr in "${!dumpMap[@]}"; do
			dumpMapKeyStr="${dumpMapCtr}$(PadChar ' ')";
			echo -e "\tkey: ${dumpMapKeyStr:0:$dumpMapMaxKeyWidth}  value: '${dumpMap[$dumpMapCtr]}'";
		done;
		echo

	return 0
}

#===================================================================================================
# Quick dump a list of variables
#===================================================================================================
dumpFirstWrite=true
function Dump {
	declare lowervName
	local singleLine=false
	local quit=false
	local pause=false
	local logit=false
	local tabs=''
	local dumpLogFile=$HOME/stdout.txt
	local vName vVal prefix

	writeIt() {
		local writeItVar="$1"
		local writeItVal="$2"
		local writeItOutStr
		local sep='\n'
		[[ $singleLine -eq 1 ]] && sep=', '
		local prefix=''
		[[ $caller != 'source' ]] && prefix="$(ColorV "$myName.$caller")."
		local varStr="$(ColorN "$writeItVar")"

		if [[ $logit == false ]]; then
			[[ $writeItVar != '' ]] && writeItOutStr="${prefix}${varStr} = >${writeItVal}<${sep}" || writeItOutStr="$sep"
			echo -en "${tabs}${writeItOutStr}";
		elif [[ -w $dumpLogFile ]]; then
			[[ $dumpFirstWrite == true ]] && echo $(date) >> $dumpLogFile
			dumpFirstWrite=dumpLogFile
			[[ $writeItVar != '' ]] && writeItOutStr="${prefix}${writeItVar} = >${writeItVal}<${sep}" || writeItOutStr="$sep"
			echo -en "$tabs$writeItOutStr" >> $dumpLogFile
		fi
		return 0
	} #writeIt

	## Loop through arguments
		local debugVarArray=($*)
		for debugVar in ${debugVarArray[@]};do
			vName=$debugVar; lowervName=$(Lower $vName)
			if [[ ${vName:0:1} == '-' ]]; then
				if [[ $lowervName == '-r' ]]; then
					echo > $dumpLogFile
				elif [[ $lowervName == '-s' ]]; then
					singleLine=true
				elif [[ $lowervName == '-l' ]]; then
					logit=true
				elif [[ $lowervName == '-t' ]]; then
					tabs="\t"$tabs
				elif [[ $lowervName == '-q' ]]; then
					quit=true
				elif [[ $lowervName == '-p' ]]; then
					pause=true
				elif [[ $lowervName == '-n' ]]; then
					writeIt;
				elif [[ $lowervName == '-m' ]]; then
					writeIt 'msg'
				else
					local re='^[0-9]+$'
					if [[ ${vName:1} =~ $re ]]; then
						local msgLevel=${vName:1}
						[[ $msgLevel -gt $verboseLevel ]] && return 0
					fi
				fi
			else
				vVal=${!vName}
				caller=${FUNCNAME[1]}
				[[ $(Lower $caller) == 'dump' ]] && caller=${FUNCNAME[2]}
				writeIt $vName "$vVal"
			fi
		done

	## Write it out and or quit
		if [[ $singleLine == true ]]; then vName=''; writeIt; fi
		[[ $quit == true ]] && Quit
		[[ $pause == true ]] && Msg2 && Pause '*** Dump paused script execution, press enter to continue ***'

		return 0
} #Dump
function dump { Dump $* ; }
function d { Dump $* ; }
function D { Dump $* ; }

#===================================================================================================
# Got HERE
#===================================================================================================
function Here {
	if [[ $1 == '-l' ]]; then
		shift || true
		echo HERE $* >> $HOME/stdout.txt
	else
		echo HERE $*
	fi

	return 0
} #Here
function here { Here $* ; }
function h { Here $* ; }
function H { Here $* ; }

#===================================================================================================
# Returns (echo) a formatted string of the call stack to the currently executing module
#===================================================================================================
function GetCallStack { local callStack callStackLenmodCntr;
	local moduleName

	for ((modCntr=0; modCntr<${#FUNCNAME[@]}; modCntr++)); do
		moduleName="${FUNCNAME[$modCntr]}"
		#echo "module($modCntr) =  $moduleName"
		if [[ $moduleName == 'source' ]]; then
			break
		elif [[ $moduleName == 'main' ]]; then
			callStack="$moduleName($myName), $callStack"
		else
			callStack="$moduleName(${BASH_LINENO[$modCntr]}), $callStack"
		fi
	done
	callStackLen=${#callStack};
	callStack="callPgm(${BASH_LINENO[$modCntr]}): ${callStack:0:$callStackLen-2}"
	echo "$callStack"
	return 0
}

#===================================================================================================
#===================================================================================================
# MAIN -- Code runs on load
#===================================================================================================
#===================================================================================================
#dump /n > ~/stdout.txt
#printf "\n\n *** Loading subs *** \n\n" > ~/stdout.txt

IfMe echo '>>>> Framework -- Starting <<<<'

[[ $TERM == '' ]] && export TERM=xterm
shopt -s checkwinsize
set +e

unset helpSet helpNotes warningMsgs errorMsgs summaryMsgs myRealPath myRealName changeLogRecs parsedArgStr
unset USELOCAL USEDEVDB

## Who we are, where we are
userName=$(whoami)
[[ $(whoami) == 'dscudiero' ]] && userName=$LOGNAME

if [[ $userName == 'dscudiero' ]]; then
	USELOCAL='--useLocal'
	[[ $useDevDB == true ]] && USEDEVDB='--useDevDB'
fi
tmpRoot=/tmp/$userName/$$

#echo "In framework. indentLevel = >$indentLevel<"
[[ $indentLevel == '' ]] && indentLevel=0 && export indentLevel=$indentLevel
[[ $verboseLevel == '' ]] && verboseLevel=0 && export verboseLevel=$verboseLevel

epochStime=$(date +%s)
hostName=$(hostname)
hostName="$(echo $hostName | cut -d"." -f1)"
osType="$(echo `uname -m`)" # x86_64 or i686
osName='linux'
osVer=$(uname -m)
if [[ ${osVer:0:1} = 'x' ]]; then osVer=64; else osVer=32; fi
myRhel=$(cat /etc/redhat-release | cut -d" " -f3)
[[ $(IsNumeric ${myRhel:0:1}) != true ]] && myRhel=$(cat /etc/redhat-release | cut -d" " -f4)

[[ $_ != $0 ]] && sourcePath=$(dirname ${BASH_SOURCE[0]}) || unset sourcePath

tabStr="$(PadChar ' ' 5)"

## set default values
	if [[ $myName != 'bashShell' ]]; then
		trueVars="verify traceLog trapExceptions logInDb allowAlerts waitOnForkedProcess defaultValueUseNotes"
		for var in $trueVars; do [[ $(eval echo \$$var) == '' ]] && eval "$var=true"; done

		falseVars="testMode noEmails noHeaders noCheck noLog verbose quiet warningMsgsIssued errorMsgsIssued noClear"
		falseVars="$falseVars force newsDisplayed noNews informationOnlyMode secondaryMessagesOnly changesMade fork"
		falseVars="$falseVars onlyCimsWithTestFile displayGoodbyeSummaryMessages autoRemote"
		for var in $falseVars; do [[ $(eval echo \$$var) == '' ]] && eval "$var=false"; done
	fi

# Default Colors and Emphasis
	if [[ $TERM != 'dumb' ]]; then
		colorWhite='\e[97m'
		colorBlack='\e[30m'
		colorRed='\e[31m'
		colorBlue='\e[34m'
		colorGreen='\e[32m'
		colorCyan='\e[36m'
		colorMagenta='\e[35m'
		colorPurple="$colorMagenta"
		colorOrange='\e[33m'
		colorGrey='\e[90m'
		colorDefault='\e[m'
		#colorDefaultVal='\e[0;4;90m' #0=normal, 4=bold,90=foreground
		colorDefaultVal=$colorMagenta #0=normal, 4=bold,90=foreground
		colorTerminate='\e[1;97;101m' #1=bold, 97=foreground, 41=background
		colorFatalError="$colorTerminate"
		#colorTerminate='\e[1;31m'

		#backGroundColorRed='\e[41m'
		#colorTerminate=${backGroundColorRed}${colorWhite}
		colorError=$colorRed
		colorWarn=$colorMagenta
		colorKey=$colorGreen
		#colorKey=$colorMagenta
		colorWarning=$colorWarn
		colorInfo=$colorGreen
		colorNote=$colorGreen
		colorVerbose=$colorGrey
		colorMenu=$colorGreen
	else
		unset colorRed colorBlue colorGreen colorCyan colorMagenta colorOrange colorGrey colorDefault
		unset colorTerminate colorError colorWarn colorWarning
		noNews=true
	fi
	function ColorT { local string="$*"; echo "${colorTerminate}${string}${colorDefault}"; }
	function ColorE { local string="$*"; echo "${colorError}${string}${colorDefault}"; }
	function ColorW { local string="$*"; echo "${colorWarn}${string}${colorDefault}"; }
	function ColorI { local string="$*"; echo "${colorInfo}${string}${colorDefault}"; }
	function ColorN { local string="$*"; echo "${colorNote}${string}${colorDefault}"; }
	function ColorV { local string="$*"; echo "${colorVerbose}${string}${colorDefault}"; }

## Trap interrupts
	TrapSigs 'on'

## Load defaults value
	GetDefaultsData
	SetFileExpansion

## If the user has a .tools file then read the values into a hash table
	#echo "allowedUserVars = >$allowedUserVars<"
	if [[ -r "$HOME/tools.cfg" && ${myRhel:0:1} -gt 5 ]]; then
		ifs="$IFS"; IFS=$'\n'; while read -r line; do
			line=$(tr -d '\011\012\015' <<< "$line")
			[[ $line == '' || ${line:0:1} == '#' ]] && continue
			vName=$(cut -d'=' -f1 <<< "$line"); [[ $vName == '' ]] && $(cut -d':' -f1 <<< "$line")
			[[ $(Contains ",${allowedUserVars}," ",${vName},") == false ]] && Msg2 $E "Variable '$vName' not allowed in tools.cfg file, setting will be ignored" && continue
			vValue=$(cut -d'=' -f2 <<< "$line"); [[ $vName == '' ]] && $(cut -d':' -f2 <<< "$line")
			eval $vName=\"$vValue\"
		done < "$HOME/tools.cfg"
		IFS="$ifs"
	fi

# Define Color functions (set after we have read user config file)
	function ColorD { local string="$*"; echo "${colorDefaultVal}${string}${colorDefault}"; }
	function ColorK { local string="$*"; echo "${colorKey}${string}${colorDefault}"; }
	function ColorI { local string="$*"; echo "${colorInfo}${string}${colorDefault}"; }
	function ColorN { local string="$*"; echo "${colorNote}${string}${colorDefault}"; }
	function ColorW { local string="$*"; echo "${colorWarn}${string}${colorDefault}"; }
	function ColorE { local string="$*"; echo "${colorError}${string}${colorDefault}"; }
	function ColorT { local string="$*"; echo "${colorTerminate}${string}${colorDefault}"; }
	function ColorV { local string="$*"; echo "${colorVerbose}${string}${colorDefault}"; }
	function ColorM { local string="$*"; echo "${colorMenu}${string}${colorDefault}"; }

	# Msg " Default Color $(ColorK "This is ColorK") Default Color"
	# Msg " Default Color $(ColorI "This is ColorI") Default Color"
	# Msg " Default Color $(ColorN "This is ColorN") Default Color"
	# Msg " Default Color $(ColorW "This is ColorW") Default Color"
	# Msg " Default Color $(ColorE "This is ColorE") Default Color"
	# Msg " Default Color $(ColorT "This is ColorT") Default Color"
	# Msg " Default Color $(ColorV "This is ColorV") Default Color"

## Set forking limit
	maxForkedProcesses=$maxForkedProcessesPrime
	[[ $scriptData3 != '' ]] && maxForkedProcesses=$scriptData3
	hour=$(date +%H)
	hour=${hour#0}
	[[ $hour -ge 20 && $maxForkedProcessesAfterHours -gt $maxForkedProcesses ]] && maxForkedProcesses=$maxForkedProcessesAfterHours
	[[ $maxForkedProcesses == '' ]] && maxForkedProcesses=2

## set framework loaded variables
	frameWorkLoaded=$frameworkVersion
	export frameWorkLoaded=$frameWorkLoaded

IfMe echo '>>>> Framework -- Ending <<<<'

#===================================================================================================
## Check-in log
#===================================================================================================
# 08-26-2015 -- dscudiero -- tweak init
# 10-16-2015 -- dscudiero -- Update for framework 6
# 11-04-2015 -- dscudiero -- Added news processing
# 11-30-2015 -- dscudiero -- refactor displaynews to use the database news entries
# 12-01-2015 -- dscudiero -- Many updated
# 12-03-2015 -- dscudiero -- Fix problem with alerts not fireing
# 12-18-2015 -- dscudiero -- add GetFrameworkVersion function.
# 12-30-2015 -- dscudiero -- tweaked help text display
# 01-07-2016 -- dscudiero -- sync
# 01-14-2016 -- dscudiero -- refactored ParseArgs
# 01-19-2016 -- dscudiero -- sync
## Fri Mar 11 16:22:45 CST 2016 - dscudiero - Added FindCourseleafNavlinkName
## Tue Mar 15 15:51:54 CDT 2016 - dscudiero - Added EditTcfValue
## Wed Mar 16 16:33:10 CDT 2016 - dscudiero - General syncing of dev to prod
## Wed Mar 16 16:46:31 CDT 2016 - dscudiero - Tweak Goodbye messages
## Wed Mar 16 16:51:39 CDT 2016 - dscudiero - General syncing of dev to prod
## Tue Mar 22 09:37:06 CDT 2016 - dscudiero - Add BackupToGoogleDrive function
## Tue Mar 22 15:09:35 CDT 2016 - dscudiero - General syncing of dev to prod
## Wed Mar 23 07:39:09 CDT 2016 - dscudiero - General syncing of dev to prod
## Wed Mar 23 11:15:15 CDT 2016 - dscudiero - General syncing of dev to prod
## Thu Mar 24 10:31:47 CDT 2016 - dscudiero - General syncing of dev to prod
## Fri Mar 25 13:22:33 CDT 2016 - dscudiero - Allow exit signals in Goodbye so exit is processed by callPgm
## Fri Mar 25 16:19:41 CDT 2016 - dscudiero - Fix column logic in SelectMenuNew
## Mon Mar 28 10:04:28 CDT 2016 - dscudiero - Return zero from TrapSigs
## Mon Mar 28 12:48:10 CDT 2016 - dscudiero - Fix but in calculating terminal window width
## Mon Mar 28 16:54:39 CDT 2016 - dscudiero - Fix bug in PadChars
## Tue Mar 29 09:32:32 CDT 2016 - dscudiero - many fixes
## Tue Mar 29 10:37:29 CDT 2016 - dscudiero - General syncing of dev to prod
## Tue Mar 29 11:23:13 CDT 2016 - dscudiero - General syncing of dev to prod
## Tue Mar 29 12:22:53 CDT 2016 - dscudiero - Misc updates
## Tue Mar 29 12:31:21 CDT 2016 - dscudiero - Fix problem parsing script options in ParseArgs
## Tue Mar 29 13:10:13 CDT 2016 - dscudiero - sync
## Tue Mar 29 13:20:16 CDT 2016 - dscudiero - Do not run logging functions if infoOnlyMode
## Tue Mar 29 14:12:44 CDT 2016 - dscudiero - Modified LogInFile proc to change default messaging
## Wed Mar 30 13:36:43 CDT 2016 - dscudiero - fix SelectMenuNew to truncate items to fit screenwidth
## Wed Mar 30 16:21:51 CDT 2016 - dscudiero - Changed color of the information only message to red
## Thu Mar 31 09:28:28 CDT 2016 - dscudiero - Fix RunCourseleafCgi to use cgi name based on pageleaf or courseleaf depending on which is found
## Thu Mar 31 09:54:43 CDT 2016 - dscudiero - force a blank line in goodbye if term=dumb
## Thu Mar 31 10:19:15 CDT 2016 - dscudiero - Added shopt -s checkwinsize
## Thu Mar 31 16:42:15 CDT 2016 - dscudiero - Do not run Alert if in batchMode
## Fri Apr  1 07:34:16 CDT 2016 - dscudiero - Force fold to false if term!= xterm in Msg
## Fri Apr  1 08:30:07 CDT 2016 - dscudiero - Add tarfileName to BackupToGoogle
## Fri Apr  1 08:44:25 CDT 2016 - dscudiero - Fix BackupToGoogleDrive
## Fri Apr  1 08:48:16 CDT 2016 - dscudiero - Fix BackupToGoogleDrive
## Fri Apr  1 11:52:44 CDT 2016 - dscudiero - Update Arg parsing to set parsedArgStr with data left over after parsing
## Fri Apr  1 12:08:45 CDT 2016 - dscudiero - added -fork option to the base
## Fri Apr  1 12:49:01 CDT 2016 - dscudiero - If fork is on set forkStr = &
## Fri Apr  1 13:24:49 CDT 2016 - dscudiero - Add setting of the useLocal variable if me
## Fri Apr  1 13:43:06 CDT 2016 - dscudiero - Updated Greedy parsing in ParseArgs to also remove client
## Mon Apr  4 10:10:18 CDT 2016 - dscudiero - Fixed ParseCourseleafFile function
## Mon Apr  4 12:39:37 CDT 2016 - dscudiero - Update IsValidUrl
## Tue Apr  5 10:53:50 CDT 2016 - dscudiero - General syncing of dev to prod
## Tue Apr  5 13:49:06 CDT 2016 - dscudiero - Many changes
## Wed Apr  6 11:16:08 CDT 2016 - dscudiero - Fix CheckRun and CheckAuth
## Wed Apr  6 11:52:28 CDT 2016 - dscudiero - removed setting of sqldb attrs from runMySql
## Wed Apr  6 12:08:34 CDT 2016 - dscudiero - removed setting of sqldb attrs from runMySql
## Wed Apr  6 12:08:48 CDT 2016 - dscudiero - removed setting of sqldb attrs from runMySql
## Wed Apr  6 12:11:07 CDT 2016 - dscudiero - Fixed a problem with GetCims
## Wed Apr  6 16:10:39 CDT 2016 - dscudiero - Added logic for database selection to support dev database
## Thu Apr  7 07:22:51 CDT 2016 - dscudiero - Set maxForkedProcesses variable
## Thu Apr  7 08:17:15 CDT 2016 - dscudiero - Strip leading zeros from hour before checking vale
## Thu Apr  7 16:29:30 CDT 2016 - dscudiero - Updated colors and Prompt text editing
## Thu Apr  7 16:42:40 CDT 2016 - dscudiero - Update SelectMenuNew to set screenWidth
## Thu Apr  7 16:44:35 CDT 2016 - dscudiero - Update colors used in Hello
## Thu Apr  7 17:02:14 CDT 2016 - dscudiero - Tweak colors
## Fri Apr  8 15:06:59 CDT 2016 - dscudiero - update defalt alert count
## Fri Apr  8 16:44:31 CDT 2016 - dscudiero - refactored the offline check to also check active flag
## Mon Apr 11 07:36:35 CDT 2016 - dscudiero - General syncing of dev to prod
## Mon Apr 11 07:43:20 CDT 2016 - dscudiero - Add message to hello if running from local directory
## Mon Apr 11 08:18:04 CDT 2016 - dscudiero - Add same return from copywithcheck
## Tue Apr 12 15:14:41 CDT 2016 - dscudiero - tweak how error processing is handled
## Wed Apr 13 08:18:12 CDT 2016 - dscudiero - Tweak signal processing
## Wed Apr 13 15:56:48 CDT 2016 - dscudiero - Fix bug in editCourseleafConsole where it was adding an extra line
## Wed Apr 13 16:47:04 CDT 2016 - dscudiero - General syncing of dev to prod
## Thu Apr 14 08:08:42 CDT 2016 - dscudiero - Move setting myName and myPath to callPgm
## Thu Apr 14 12:29:07 CDT 2016 - dscudiero - Fix setting of srcDir if client is internal
## Thu Apr 14 13:43:03 CDT 2016 - dscudiero - Tweak how srcDir is set for internal
## Thu Apr 14 14:33:40 CDT 2016 - dscudiero - Remove debug statements
## Fri Apr 15 07:04:39 CDT 2016 - dscudiero - Refactor SetSiteDirs
## Mon Apr 18 16:26:55 CDT 2016 - dscudiero - Fix problem with setsitedirs if no dev site exiss
## Wed Apr 20 07:58:17 CDT 2016 - dscudiero - Add Msg2
## Wed Apr 20 08:10:22 CDT 2016 - dscudiero - Add esamples to Msg2 documentaton
## Thu Apr 21 08:57:14 CDT 2016 - dscudiero - Add ability to prompt for multiple environments, refactor PadChar
## Thu Apr 21 13:48:39 CDT 2016 - dscudiero - Added RunSql function
## Fri Apr 22 11:27:48 CDT 2016 - dscudiero - General syncing of dev to prod
## Fri Apr 22 15:11:56 CDT 2016 - dscudiero - General syncing of dev to prod
## Fri Apr 22 16:25:57 CDT 2016 - dscudiero - Added GetPgmFile function
## Fri Apr 22 16:28:23 CDT 2016 - dscudiero - Added GetPgmFile function
## Mon Apr 25 07:38:45 CDT 2016 - dscudiero - cleanup ParseArgs a bt
## Mon Apr 25 07:47:37 CDT 2016 - dscudiero - Added parseQuiet control in ParseArgs
## Mon Apr 25 13:16:49 CDT 2016 - dscudiero - Fix a problem assigning the src and tgt dirs in Init
## Mon Apr 25 13:32:22 CDT 2016 - dscudiero - Fix messages from Init
## Mon Apr 25 16:47:39 CDT 2016 - dscudiero - General syncing of dev to prod
## Tue Apr 26 16:28:26 CDT 2016 - dscudiero - Many changes
## Wed Apr 27 07:20:38 CDT 2016 - dscudiero - Fix problem setting srcDir
## Wed Apr 27 07:21:32 CDT 2016 - dscudiero - Fix problem setting tgtDir
## Wed Apr 27 13:27:14 CDT 2016 - dscudiero - Fix problem with getting the idx from dbLog
## Wed Apr 27 15:00:53 CDT 2016 - dscudiero - Print out a message in Goodbye if DOIT flag is off
## Wed Apr 27 16:35:04 CDT 2016 - dscudiero - Switched to use RunSql
## Wed Apr 27 16:59:30 CDT 2016 - dscudiero - Fix problem where some messages included chars escaping quotes
## Thu Apr 28 07:40:12 CDT 2016 - dscudiero - Fix problem with client being parsed incorrectl
## Thu Apr 28 10:18:21 CDT 2016 - dscudiero - Fix spelling
## Thu Apr 28 10:49:47 CDT 2016 - dscudiero - Change scripts to object in viewedNews calls
## Thu Apr 28 13:35:06 CDT 2016 - dscudiero - Added -forUser argument avaiable to only admins
## Thu Apr 28 14:13:23 CDT 2016 - dscudiero - General syncing of dev to prod
## Thu Apr 28 16:28:11 CDT 2016 - dscudiero - Fixed problem with srcEnv and tgtEnv processing in INIT
## Thu Apr 28 16:36:08 CDT 2016 - dscudiero - Fix problem with checking forUser
## Fri Apr 29 07:19:56 CDT 2016 - dscudiero - General syncing of dev to prod
## Fri Apr 29 10:30:19 CDT 2016 - dscudiero - Fixed DisplayNews
## Fri Apr 29 12:36:41 CDT 2016 - dscudiero - Fixed problems with BackupCourseleafFile
## Fri Apr 29 14:07:17 CDT 2016 - dscudiero - Tweak WriteChangelogEntry to add a blank line seperator if the current last line is not blank
## Tue May  3 07:14:10 CDT 2016 - dscudiero - Fix problem setting default warehouse scheme name
## Wed May  4 08:31:18 CDT 2016 - dscudiero - Set mysqlConnectString
## Thu May  5 08:54:20 CDT 2016 - dscudiero - Many changes
## Fri May 13 07:55:06 CDT 2016 - dscudiero - Added the ability to allow the user to specify a product value that is not on the clients product list
## Tue May 17 10:58:11 CDT 2016 - dscudiero - Fix problem parsing switch# type arguments
## Tue May 17 13:22:39 CDT 2016 - dscudiero - General syncing of dev to prod
## Wed May 25 07:53:42 CDT 2016 - dscudiero - Added pragama statement type to RunSql
## Wed Jun  1 10:27:06 CDT 2016 - dscudiero - fixed problem passing myName with a hypens to readnews
## Wed Jun  1 14:00:30 CDT 2016 - dscudiero - Added ignoreList as an named argument
## Thu Jun  2 11:46:25 CDT 2016 - dscudiero - Swithc to Msg2 in Goodbye
## Thu Jun  2 13:13:36 CDT 2016 - dscudiero - Changed minimum abbreviation for IgnoreList to 7 chars
## Thu Jun  2 15:35:52 CDT 2016 - dscudiero - Tweaked Goodbye messaging
## Fri Jun  3 08:04:42 CDT 2016 - dscudiero - Removed the initialization of allCims to false in Init
## Fri Jun  3 08:28:58 CDT 2016 - dscudiero - Removed adding the blank line before a Prompt
## Mon Jun  6 09:30:57 CDT 2016 - dscudiero - Added function name to RunSql messages
## Mon Jun  6 12:43:15 CDT 2016 - dscudiero - Updated RunSql to add a semicolon at the end of sql if not present
## Wed Jun  8 09:53:23 CDT 2016 - dscudiero - Switched from Msg to Msg2 in SelectFile and also return selection if only a single file is avaiable.
## Thu Jun  9 10:59:23 CDT 2016 - dscudiero - Fix problem in SelectClient
## Thu Jun  9 14:01:39 CDT 2016 - dscudiero - Set variable siteDir to srcDor for convienence
## Tue Jun 14 15:33:06 CDT 2016 - dscudiero - Updates to Init for getsrc/tgtEnv, Changed defaultVar color
## Thu Jun 16 07:57:47 CDT 2016 - dscudiero - Tweaked messages
## Thu Jun 16 08:00:02 CDT 2016 - dscudiero - Tweaked messages
## Thu Jun 16 15:56:17 CDT 2016 - dscudiero - Change colors for menus
## Fri Jun 17 13:24:11 CDT 2016 - dscudiero - General syncing of dev to prod
## Tue Jun 21 08:30:38 CDT 2016 - dscudiero - Fix problem with Help messages not formatting correctly
## Tue Jun 21 14:23:07 CDT 2016 - dscudiero - Updated Init to properly handle envs when client=all
## Wed Jun 22 10:27:42 CDT 2016 - dscudiero - Added a blank line before fatal messages
## Thu Jun 23 08:30:42 CDT 2016 - dscudiero - Fix for CheckRun to ignore the online/offline if nothing returned from sql query
## Thu Jun 23 10:12:07 CDT 2016 - dscudiero - Tweak Help to use the validArgs string to only show valid arguments for the script
## Thu Jun 23 10:31:30 CDT 2016 - dscudiero - Tweak help messages again
## Thu Jun 23 10:47:10 CDT 2016 - dscudiero - Tweak help messages again
## Tue Jul  5 08:41:03 CDT 2016 - dscudiero - Add prior to SetSiteDirs
## Fri Jul  8 10:09:07 CDT 2016 - dscudiero - Tweak Help formatting
## Fri Jul  8 15:40:08 CDT 2016 - dscudiero - Add message to goodbye showing the logFile
## Tue Jul 12 09:38:15 CDT 2016 - dscudiero - update minor release
## Tue Jul 12 11:28:11 CDT 2016 - dscudiero - Tweak offline logic
## Tue Jul 12 11:33:44 CDT 2016 - dscudiero - General syncing of dev to prod
## Tue Jul 12 11:51:16 CDT 2016 - dscudiero - remove debug satements
## Tue Jul 12 12:06:30 CDT 2016 - dscudiero - Tweaked offline logic
## Tue Jul 12 13:03:01 CDT 2016 - dscudiero - Updated Prompt routien to expand ^ tabs
## Tue Jul 12 17:00:53 CDT 2016 - dscudiero - use a unique counter inside of Msg2
## Wed Jul 13 09:53:30 CDT 2016 - dscudiero - Fix issue in Help function
## Wed Jul 13 10:34:44 CDT 2016 - dscudiero - Tweak menuListNew formats
## Wed Jul 13 11:15:17 CDT 2016 - dscudiero - Tweaked setting of the prompt text in Prompt
## Thu Jul 14 15:08:22 CDT 2016 - dscudiero - Switch LOGNAME for userName
## Thu Jul 14 16:34:06 CDT 2016 - dscudiero - Removed the restart from ValidateContinue
## Fri Jul 15 10:01:44 CDT 2016 - dscudiero - Update BackupGoogle to pass tarOptions, renamed to BackupExternal
## Fri Jul 15 15:15:14 CDT 2016 - dscudiero - Updated GetCims to fix problem if user answeres a for all cims
## Mon Jul 18 14:06:40 EDT 2016 - dscudiero - Tweak messages
## Mon Jul 18 14:48:32 EDT 2016 - dscudiero - Set command return code in ProtectedCall
## Mon Jul 18 16:35:05 CDT 2016 - dscudiero - Tweaked messages
## Wed Jul 20 07:58:37 CDT 2016 - dscudiero - Added setting warning and error message arrays into Msg2
## Wed Jul 20 08:07:08 CDT 2016 - dscudiero - Reformatted startu messages
## Wed Jul 20 08:58:10 CDT 2016 - dscudiero - Added onlyCimsWithTestFiles to GetCims
## Wed Jul 20 10:13:55 CDT 2016 - dscudiero - Added on all hosts checking to semaphore
## Thu Jul 21 08:28:21 CDT 2016 - dscudiero - Fix problem in Msg2 where alerts were not being added to error messages
## Fri Jul 22 16:40:56 CDT 2016 - dscudiero - Refactored InsertLineInFile function
## Wed Aug  3 12:21:31 CDT 2016 - dscudiero - Tweak a few things in Init for internal
## Wed Aug  3 14:58:23 CDT 2016 - dscudiero - General syncing of dev to prod
## Wed Aug  3 15:59:28 CDT 2016 - dscudiero - Change WriteCourseleafLog to create a logfile if one is not present
## Thu Aug  4 11:01:40 CDT 2016 - dscudiero - Added displayGoodbyeSummaryMessages=true
## Fri Aug  5 07:26:34 CDT 2016 - dscudiero - Add the -asUser flag
## Tue Aug  9 10:00:06 CDT 2016 - dscudiero - Comment out administrator check for the foruser flag
## Thu Aug 11 12:44:06 CDT 2016 - dscudiero - Make sure when using i as a cntr token that it is declared local
## Tue Aug 23 11:23:12 CDT 2016 - dscudiero - Updated selectMenuNew to return the entire menu line selected
## Thu Aug 25 12:53:50 CDT 2016 - dscudiero - Added DumpHash procedure, updated Dump
## Fri Aug 26 09:21:09 CDT 2016 - dscudiero - Rewrote DumpArray
## Tue Sep  6 15:33:23 CDT 2016 - dscudiero - Tweak GetEnv code for internal site
## Fri Sep 16 07:42:06 CDT 2016 - dscudiero - Updated messaging, switch everything to Msg2
## Fri Sep 16 10:34:19 CDT 2016 - dscudiero - Updated GetDefaultsData to read the columns from the scripts table to set the variables
## Mon Sep 19 16:01:59 CDT 2016 - dscudiero - Updated EditTcfFile to fix problem parsing output of parseCourseleafFile
## Tue Sep 20 09:56:54 CDT 2016 - dscudiero - only set indentLevel if it is not aready set
## Wed Sep 21 07:09:07 CDT 2016 - dscudiero - Fix Lower
## Wed Sep 21 07:16:36 CDT 2016 - dscudiero - Fix Lower
## Fri Sep 23 11:02:04 CDT 2016 - dscudiero - Updated BackupCourseleafFile to change backup directory name
## Fri Sep 23 12:50:42 CDT 2016 - dscudiero - Tweaked help output formats
## Mon Sep 26 07:32:40 CDT 2016 - dscudiero - General syncing of dev to prod
## Tue Sep 27 15:13:42 CDT 2016 - dscudiero - filter out the vanity product names from product selection
## Thu Sep 29 12:54:17 CDT 2016 - dscudiero - Do not clear screen if TERM=dumb
## Thu Sep 29 13:02:42 CDT 2016 - dscudiero - Fix problem with client validation
## Thu Sep 29 15:09:05 CDT 2016 - dscudiero - Fix problem with verifying client
## Thu Sep 29 15:16:51 CDT 2016 - dscudiero - Fix problem with verifying client
## Thu Sep 29 16:12:28 CDT 2016 - dscudiero - Backout all changes to VerifyPromptVal
## Thu Oct  6 07:09:31 CDT 2016 - dscudiero - Refactored client checking and db connection
## Thu Oct  6 08:48:54 CDT 2016 - dscudiero - Add a timeout option to Prompt function
## Thu Oct  6 16:59:09 CDT 2016 - dscudiero - General syncing of dev to prod
## Fri Oct  7 07:59:11 CDT 2016 - dscudiero - Build dbAcc switching into RunSql
## Fri Oct  7 08:03:23 CDT 2016 - dscudiero - Fix syntax error
## Fri Oct  7 15:17:24 CDT 2016 - dscudiero - Fixes for the sqlconnection fiascio
## Fri Oct  7 15:51:40 CDT 2016 - dscudiero - Remove debug statement
## Fri Oct  7 15:55:06 CDT 2016 - dscudiero - Remove debug statement
## Mon Oct 10 14:31:57 CDT 2016 - dscudiero - Define colorTerminate
## Tue Oct 11 09:25:54 CDT 2016 - dscudiero - Fix Lower and Upper , switch back to printf since echo was absorbing -n chars
## Tue Oct 11 10:50:19 CDT 2016 - dscudiero - Remove debug line
## Tue Oct 11 16:30:40 CDT 2016 - dscudiero - Make mysql the default dbtype in RunSql
## Wed Oct 12 11:16:09 CDT 2016 - dscudiero - Update BackupExternal to support multiple types
## Thu Oct 13 13:08:32 CDT 2016 - dscudiero - Added SetupInterpreterExecutionEnv
## Fri Oct 14 11:39:03 CDT 2016 - dscudiero - Refactored GoodBye and read timeout in Prompt
## Fri Oct 14 11:51:42 CDT 2016 - dscudiero - Added main module name to GetCallStack output
## Fri Oct 14 16:37:11 CDT 2016 - dscudiero - Added ACD to BackupExternal
## Mon Oct 17 11:31:33 CDT 2016 - dscudiero - Fix problem with VerifyPromptResponse processsing *dir* types
## Tue Oct 18 13:25:49 CDT 2016 - dscudiero - Tweaked messages in the signal handler
## Wed Oct 19 09:29:10 CDT 2016 - dscudiero - Add debug messages in backupExternal
## Wed Oct 19 14:23:29 CDT 2016 - dscudiero - Remove backupExternal
