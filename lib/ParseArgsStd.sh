## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.26" # -- dscudiero -- Tue 04/25/2017 @  8:15:56.18
#===================================================================================================
## Standard argument parsing
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function ParseArgsStd {
	Msg2 $V3 "*** $FUNCNAME -- Starting ***"
	local myArgs="$*"
	[[ -z $myArgs ]] && myArgs="$originalArgStr"

	## If there is a local function defined to parse script specific arguments then call it
		unset argList
		[[ -n "$(type -t parseArgs-$myName)"  && "$(type -t parseArgs-$myName)" = function ]] && parseArgs-$myName
		[[ -n "$(type -t parseArgs-local)"  && "$(type -t parseArgs-local)" = function ]] && parseArgs-local

	## Help argument
		help=false;
		argList+=(-help,1,help,,,,"Display help text")

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
		argList+=(-force,5,switch,force,,script,"Perform action even if it has already been done on the site")
		argList+=(-fork,4,switch,fork,,script,"Fork off sub-process if supported by script")
		argList+=(-forUser,4,option,forUser,,script,'Run on behalf of another user (admins only)')
	 	argList+=(-ignoreList,7,option,ignoreList,,script,'Comma seperated list if items to ignore, items are based on the script')
	 	argList+=(-informationOnly,4,switch,informationOnlyMode,,script,'Only analyze data and print error messages, do not change any data')
		argList+=(-noPrompt,3,switch,verify,"verify=false",script,"Turn off prompt mode, all data needs to be specified on command string")
		argList+=(-noCheck,4,switch,noCheck,,script,"Do not validate the client data in the $warehouseDb.$clientInfoTable table")
		argList+=(-verbose,1,switch#,verbose,verboseLevel,script,"Additional messaging, -V# sets verbosity level to #")
		argList+=(-go,2,switch,go,,script,"Skip the verify continue y/n prompt")

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

	## Call arg parser
		ParseArgs $myArgs

	## Misc stuff
		[[ $fork == true ]] && forkStr='&' || unset forkStr
		if [[ -n $forUser ]]; then
			if [[ $(Contains "$forUser" '/') == false ]]; then
				[[ -d /home/$forUser ]] && userName=$forUser || Error "Userid specified as -forUser ($forUser) is not valid, ignoring directive"
			fi
		fi

	Msg2 $V3 "*** $FUNCNAME -- Completed ***"
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
