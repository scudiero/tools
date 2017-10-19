## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.49" # -- dscudiero -- Thu 10/19/2017 @  9:12:18.93
#===================================================================================================
## Standard argument parsing
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
function ParseArgsStd {
	myIncludes="StringFunctions ParseArgs"
	Import "$myIncludes"

	local myArgs="$*"
	[[ -z $myArgs ]] && myArgs="$originalArgStr"

	unset argList
	## If there is a local function defined to parse script specific arguments then call it
		[[ $(type -t parseArgs-$myName) == 'function' ]] && parseArgs-$myName ## Old way
		[[ $(type -t $FUNCNAME-$myName) == 'function' ]] && $FUNCNAME-$myName
		[[ $(type -t $myName-$FUNCNAME) == 'function' ]] && $myName-$FUNCNAME

	## Help argument
		help=false;
		argList+=(-hh,2,helpExtended,,,common,"Display help expanded text")
		argList+=(-help,1,help,,,common,"Display help text")

	## process these before the regular envs, conflicts with names
		argList+=(-envs,4,option,envs,,envs,"Environment or Environments (e.g. {$courseleafDevEnvs,$courseleafProdEnvs} or comma separated multiples 'test,next'")
		argList+=(-products,4,option,products,,prod,"Product or products (e.g. 'cat' or 'cim' or 'clss' or 'cat,cim')")
		argList+=(-srcEnv,3,option,srcEnv,,src,"Source Environment (e.g. $courseleafDevEnvs,$courseleafProdEnvs)")
		argList+=(-tgtEnv,3,option,tgtEnv,,tgt,"Target Environment (e.g. $courseleafDevEnvs,$courseleafProdEnvs)")

	## cims
		cimc=false; cimp=false; cimm=false; cims=false; allCims=false; unset cims; unset cimStr
		argList+=(-cimc,4,switch,cimc,"cims+=('courseadmin')",cim,"CIM Courses")
		argList+=(-cimp,4,switch,cimp,"cims+=('programadmin')",cim,"CIM Programs")
		argList+=(-cimm,4,switch,cimm,"cims+=('miscadmin')",cim,"CIM Miscellanious")
		argList+=(-cims,4,switch,cims,"cims+=('syllubusadmin')",cim,"CIM Syllabi")
		argList+=(-cima,4,switch,allCims,,cim,"Use all CIMs found")

		argList+=(-cat,3,switch,cat,,cat,"Product is CAT")
		argList+=(-cim,3,switch,cim,,cim,"Product is CIM")
		argList+=(-clss,4,switch,clss,,clss,"Product is CLSS/WEN")

	## Standard arguments
		#for arg in "${argList[@]}"; do dump -l arg; done
		#trueVars="verify"
		#local var; for var in $trueVars; do eval $var=true; done
		#falseVars="testMode noEmails noHeaders noCheck traceLog verbose quiet"
		#local var; for var in $falseVars; do eval $var=false; done
		#argList+=(argFlag,minLen,type,scriptVariable,extraToken/exCmd,helpSet,helpText)

		argList+=(-batchMode,9,switch,batchMode,,common,"Run in batch mode")
		argList+=(-noBanners,3,switch,noBanners,,common,"Abbreviated messaging from Hello")
		argList+=(-noClear,4,switch,noClear,,common,"Do not clear the screen on script start")
		argList+=(-noEmails,3,switch,noEmails,,common,"Turn off emails")
		argList+=(-noHeaders,3,switch,noHeaders,,common,"Turn off Hello and Goodbye messaging")
		argList+=(-noLog,3,switch,traceLog,,common,"Turn off logging")
		argList+=(-noNews,3,switch,noNews,,common,"Do not display the news")
		argList+=(-quiet,1,switch,quiet,,common,"Turn off all status messages")
	 	argList+=(-secondaryMessagesOnly,3,switch,secondaryMessagesOnly,,common,'Only display secondary messages from child scripts.')
		argList+=(-testMode,5,switch,testMode,,common,"Test mode, use test data")
		argList+=(-x,1,switch,DOIT,DOIT='echo',common,"eXperimental mode - no data will be change/committed")
		argList+=(-autoRemote,4,switch,autoRemote,,common,"Automatically launch remote ssh session if the client is not hosted on the current host")

		argList+=(-allItems,3,switch,allItems,,common,"Perform action on all items in the context of the script, e.g all envs")
		argList+=(-force,5,switch,force,,common,"Perform action even if it has already been done on the site")
		argList+=(-fork,4,switch,fork,,common,"Fork off sub-process if supported by script")
		argList+=(-forUser,4,option,forUser,,common,'Run on behalf of another user (admins only)')
	 	argList+=(-ignoreList,7,option,ignoreList,,common,'Comma seperated list if items to ignore, items are based on the script')
	 	argList+=(-informationOnly,4,switch,informationOnlyMode,,common,'Only analyze data and print error messages, do not change any data')
		argList+=(-noPrompt,3,switch,verify,"verify=false",common,"Turn off prompt mode, all data needs to be specified on command string")
		argList+=(-noCheck,4,switch,noCheck,,common,"Do not validate the client data in the $warehouseDb.$clientInfoTable table")
		argList+=(-verbose,1,switch#,verbose,verboseLevel,common,"Additional messaging, -V# sets verbosity level to #")
		argList+=(-go,2,switch,go,,common,"Skip the verify continue y/n prompt")

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

	# echo;echo
	# for ((i=0; i<${#argList[@]}; i++)); do
	# 	echo "argList[$i] = >${argList[$i]}<"
	# done
	# Pause

	## Call arg parser
		ParseArgs $myArgs

	## Misc stuff
		[[ $fork == true ]] && forkStr='&' || unset forkStr
		if [[ -n $forUser ]]; then
			if [[ $(Contains "$forUser" '/') == false ]]; then
				[[ -d /home/$forUser ]] && userName=$forUser || Error "Userid specified as -forUser ($forUser) is not valid, ignoring directive"
			fi
		fi

	return 0
} #ParseArgsStd
export -f ParseArgsStd

#===================================================================================================
# Check-in Log
#===================================================================================================
## Wed Jan  4 13:54:04 CST 2017 - dscudiero - General syncing of dev to prod
## Thu Jan 19 10:05:01 CST 2017 - dscudiero - misc cleanup
## Thu Jan 19 12:47:02 CST 2017 - dscudiero - Moved CIMS above envs
## Fri Jan 20 10:17:29 CST 2017 - dscudiero - switch order when searching for arguments
## Mon Feb 20 12:54:04 CST 2017 - dscudiero - Removed the asUser variable, replaced with forUser
## Wed Feb 22 07:24:53 CST 2017 - dscudiero - Only check forUser value if forUser does not contain a '/'
## 04-10-2017 @ 09.36.37 - ("2.0.23")  - dscudiero - tweak messaging
## 04-25-2017 @ 08.38.13 - ("2.0.26")  - dscudiero - Added -go switch
## 09-01-2017 @ 09.28.04 - ("2.0.27")  - dscudiero - Add call to myname-FUNCNAME if found
## 09-01-2017 @ 13.44.46 - ("2.0.29")  - dscudiero - run the previously named local function if found
## 09-07-2017 @ 07.56.18 - ("2.0.35")  - dscudiero - Move the parsing of the client name to the end if no other arg matches have been found
## 10-02-2017 @ 13.46.58 - ("2.0.45")  - dscudiero - General syncing of dev to prod
## 10-17-2017 @ 14.08.19 - ("2.0.46")  - dscudiero - Added shortHello option to streamline output in batch
## 10-19-2017 @ 09.06.31 - ("2.0.48")  - dscudiero - Switch to Msg3
## 10-19-2017 @ 09.39.23 - ("2.0.49")  - dscudiero - Replaced -shortHello with -noBanners
