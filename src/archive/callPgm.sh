#!/bin/bash
version=3.2.13 # -- dscudiero -- 10/20/2016 @ 15:57:25.68
originalArgStr="$*"

#==================================================================================================
## Make sure we have a value for TOOLSPATH
#==================================================================================================
[[ $TOOLSPATH == '' || ! -d $TOOLSPATH ]] && export TOOLSPATH="/steamboat/leepfrog/docs/tools"

#==================================================================================================
# Load the script framework and execute script/program
# supports scripts, Perl, and Python programs
#==================================================================================================
## Copyright ©2016 David Scudiero -- all rights reserved.
## 07-17-15 -- 	dgs - Initial coding
#==================================================================================================


#==================================================================================================
# Debug routien
#==================================================================================================
	function IfMe {
		[[ $TOOLSDEBUG != true && $MYDEBUG != true ]] && return 0
		[[ $TOOLSDEBUG != true && $MYDEBUG != true && $LOGNAME != $ME ]] && return 0

		[[ $stdout == '' ]] && stdout=/dev/tty
		[[ $* == 'clear' ]] && echo > $stdout && return 0
		$* >> $stdout
		return 0
	}
	IfMe 'clear'

#==================================================================================================
# Process call requests
#==================================================================================================
function Call.shPgm {
	IfMe echo ">>> callPgm.$FUNCNAME -- Starting <<<"
	IfMe dump -t executeFile inArgs addArgs logFile
	# source the file so it inherits the framework
		shellCmd="$executeFile $inArgs $addArgs"
		[[ $verboseLevel -ge 2 ]] && echo && echo ". $shellCmd" && echo && Pause
		IfMe echo -e "\t. $shellCmd"
		[[ $noLog == false ]] && . $shellCmd 2>&1 | tee -a $logFile || . $shellCmd
		rc=$?
	return $rc
}

#==================================================================================================
function Call.patchPgm {
	IfMe echo ">>> callPgm.$FUNCNAME -- Starting <<<"
	IfMe dump -t executeFile inArgs logFile
	Call.shPgm $*
}

# #==================================================================================================
# function Call.pyPgm {
# 	IfMe echo ">>> callPgm.$FUNCNAME -- Starting <<<"
# 	IfMe dump -t executeFile inArgs addArgs logFile
# 	interpreter='python'
# 	## Find the interpreter
# 		for dir in $(env | grep ^PATH | sed s'_PATH=__'g | tr ':' ' ') $TOOLSPATH; do
# 	 		dir=$dir/$(Upper ${interpreter:0:1})${interpreter:1}/$osName/current-$osVer/bin
# 		    if [[ -d $dir ]]; then interpreterBin=$dir; break; fi
# 		done
# 		export PYTHONPATH=$(dirname $interpreterBin)/lib/python2.7/site-packages
# 		IfMe dump -t interpreterBin PYDIR PYTHONPATH

# 	## Call the interpreter
# 		pythonCmd="$interpreterBin/$interpreter -u $executeFile $inArgs" #$addArgs"
# 		[[ $verboseLevel -ge 2 ]] && echo && echo "$pythonCmd" && echo && Pause
# 		[[ $noLog == false ]] && $pythonCmd 2>&1 | tee -a $logFile || $pythonCmd
# 	return 0
# }

#==================================================================================================
function Call.pyPgm {
	IfMe echo ">>> callPgm.$FUNCNAME -- Starting <<<"
	IfMe dump -t executeFile inArgs addArgs logFile

	## Setup the environment
		SetupInterpreterExecutionEnv
		IfMe dump -t PYDIR PYTHONPATH
		savePath="$PATH"
		export PATH="$PYDIR:$PATH"

	## Call the interpreter
		pythonCmd="$PYDIR/bin/python -u $executeFile $inArgs" #$addArgs"
		[[ $verboseLevel -ge 2 ]] && echo && echo "$pythonCmd" && echo && Pause
		[[ $noLog == false ]] && $pythonCmd 2>&1 | tee -a $logFile || $pythonCmd
		[[ $savePath != '' ]] && export PATH="$savePath"

	return 0
}

#==================================================================================================
function Call.plPgm {
	IfMe echo ">>> callPgm.$FUNCNAME -- Starting <<<"
	IfMe dump -t executeFile inArgs addArgs logFile
	interpreter='perl'
	## Find the interpreter
		for dir in $(env | grep ^PATH | sed s'_PATH=__'g | tr ':' ' ') $TOOLSPATH; do
	 		dir=$dir/$(Upper ${interpreter:0:1})${interpreter:1}/$osName/current-$osVer/bin
 			dump -2 -t -t dir
		    if [[ -d $dir ]]; then interpreterBin=$dir; break; fi
		done

	## Set library path from PATH
		unset libs
		for scriptSrcDir in ${scriptSrcDirs[@]} "$dir"; do
				libs=$libs:$scriptSrcDir
		done
		libs=$libs:$TOOLSPATH/libs/$(Upper ${interpreter:0:1})${interpreter:1}/sitelib
		libs=$libs:$TOOLSPATH/libs/$(Upper ${interpreter:0:1})${interpreter:1}/lib
		libs=$libs:$(dirname $interpreterBin)/site/lib
		libs=$libs:$(dirname $interpreterBin)/lib
		export PERLLIB="$libs"

	## Call the interpreter
		#dump -n -t executeFile interpreterBin libs logFile
		pathSave=$(echo $PATH)
		export PATH=$interpreterBin:$PATH
		perlCmd="$interpreterBin/$interpreter $executeFile $inArgs $addArgs"
		[[ $verboseLevel -ge 2 ]] && echo && echo "$perlCmd" && echo && Pause
		[[ $noLog == false ]] && $perlCmd 2>&1 | tee -a $logFile || $perlCmd
		export PATH=$pathSave
	return 0
}

#==================================================================================================
# Process the exit from the sourced script
#==================================================================================================
function CleanUp {
	local rc=$1
	IfMe echo ">>> callPgm.$FUNCNAME -- Starting <<<"
	trap - ERR EXIT

	## Cleanup log file
		 if [[ $logFile != /dev/null ]]; then
		 	mv $logFile $logFile.bak
		 	cat $logFile.bak | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g" > $logFile
			chmod ug+rwx "$logFile"
		 	rm $logFile.bak
		 fi

	## Cleanup semaphore and dblogging
		IfMe dump -t setSemaphore semaphoreProcessing semaphoreId
		[[ $semaphoreProcessing == true && $(Lower $setSemaphore) == 'yes' && $semaphoreId != "" ]] && Semaphore 'clear' $semaphoreId
		[[ $logInDb != false && $myLogRecordIdx != "" ]] && dbLog 'End' $myLogRecordIdx
		SetFileExpansion 'on'
		rm -rf /tmp/$LOGNAME.$exName.* > /dev/null 2>&1
		SetFileExpansion

	IfMe echo ">>> callPgm.$FUNCNAME Ending <<<"
	exit $rc
} #CleanUp

#==================================================================================================
# Declare local variables and constants, pars args
#==================================================================================================
	trueVars='semaphoreProcessing myLogInDb'
	falseVars='myUseLocal noLogRedirect myBatchMode myNoLog myVerbose useDevDB noRunCheck noAuthCheck'
	for var in $trueVars; do eval $var=true; done
	for var in $falseVars; do eval $var=false; done

	[[ $TOOLSPATH != '' && -d $TOOLSPATH ]] && TOOLSPATH="$TOOLSPATH" || unset TOOLSPATH

	IfMe echo -e ">>>> Starting callPgm.sh\t$version\t$(date) <<<<"
	IfMe echo -e "\t0 = >$0<"
	IfMe echo -e "\toriginalArgStr = >$originalArgStr<"
	#IfMe echo -e '\tcallPgm - PATH =\n\t'$PATH

	#==================================================================================================
	## Loop through arguments looking for callPgm directives (--xxx)
	#==================================================================================================
	inArgs="$*"; unset myArgs
	IfMe echo -e '\tinArgs = >'$inArgs'<'
	while [[ $@ != '' ]]; do
		if [[ ${1:0:2} == '--' ]]; then
			myArg=$(echo ${1:2} | tr '[:upper:]' '[:lower:]')
			IfMe echo -e '\t\tmyArg = >'$myArg'<'
			[[ $myArg == 'v' ]] && myVerbose=true && verboseLevel=3
			[[ $myArg == 'uselocal' ]] && myUseLocal=true
			[[ $myArg == 'nosemaphore' ]] && semaphoreProcessing=false
			[[ $myArg == 'nolog' ]] && myNoLog=true
			[[ $myArg == 'nologredirect' ]] && noLogRedirect=true
			[[ $myArg == 'nologindb' ]] && myLogInDb=false
			[[ $myArg == 'batchmode' ]] && myBatchMode=true
			[[ $myArg == 'noruncheck' ]] && noRunCheck=true
			[[ $myArg == 'noauthcheck' ]] && noAuthCheck=true
		else
		 	myArgs="$myArgs $1"
		fi
		shift
	done
			[[ $myArg == 'usedevdb' ]] && useDevDB=true

	## Set myName and reset inArgs to unparsed arguments
		myArgs="$(echo $myArgs | sed 's/^[ \t]*//;s/[ \t]*$//')"
		myName=$(cut -d' ' -f1 <<< "$myArgs")
		inArgs=$(cut -d' ' -f2- <<< "$myArgs")
		[[ $inArgs == $myName ]] && unset inArgs
		IfMe echo -e "\tmyName = >$myName<"
		IfMe echo -e "\tinArgs after parse = >$inArgs<"

	## Set overrides based on name and/or globals
		[[ ${myName:0:4} == 'test' ]] && noLog=true && logInDb=false && myUseLocal=true
		[[ $USEDEVDB == true ]] && useDevDB=true
		[[ $useDevDB == true ]] && echo -e "\e[0;31m*Warning* (callPgm.sh.$LINENO) -- Using the development data warehouse\e[m\a"


	#varList="originalArgStr myVerbose myUseLocal useDevDB semaphoreProcessing myNoLog noLogRedirect myLogInDb myBatchMode noRunCheck noAuthCheck myArgs myName inArgs"
	#for var in $varList; do
	#	echo -e "\t$var = >${!var}<"
	#done

#==================================================================================================
# Main
#==================================================================================================
# Load the framework file from the first one found in the users PATH, set scriptSrcDirs
	unset frameworkFile foundFile scriptSrcDirs foundFrameworkFile useDb
	prodFile=$TOOLSPATH/src/framework.sh
	[[ -r $prodFile ]] && prodFileMd5=$(md5sum $prodFile | cut -f1 -d" ") || unset prodFileMd5

	pathDirs=($(env | grep ^PATH | sed s'_PATH=__'g | tr ':' ' ') $TOOLSPATH $TOOLSPATH/src)
	[[ -d $HOME/tools ]] && pathDirs+=($HOME/.tools)
	IfMe echo "*callPgm.sh* -- Searching for framework flie, myUseLocal = $myUseLocal"

	## Make sure the script source directory is in the path
		for dir in ${pathDirs[@]}; do
			[[ ${dir:0:5} == '/usr/' || $dir == '/bin' || $dir == '/sbin' ]] && continue
			foundFile=false
			IfMe echo -e '\tChecking: '$dir'<'
			if [[ -r $dir/framework.sh ]]; then
				scriptSrcDirs+=($dir)
				foundFile=true
			elif [[ -r $(dirname $dir)/src/framework.sh ]]; then
				scriptSrcDirs+=($(dirname $dir)/src)
				dir=$(dirname $dir)/src
				foundFile=true
			fi
			[[ $foundFile != true ]] && continue
			IfMe echo -e "Found framework in dir: $dir"

			if [[ ${dir:0:6} == '/home/' ]]; then
				[[ $myUseLocal == true ]] && frameworkFile="$dir/framework.sh" && foundFrameworkFile=true && continue
				prodFile=$TOOLSPATH/src/framework.sh
				localFileMd5=$(md5sum $dir/framework.sh | cut -f1 -d" ")
				IfMe echo -e "\tprodFileMd5 = >$prodFileMd5<, localFileMd5 = >$localFileMd5<"
				if [[ $prodFileMd5 != $localFileMd5 ]]; then
					frameworkFile="$dir/framework.sh"
					frameworkVersion=$(grep 'frameworkVersion=' $frameworkFile | cut -d'=' -f2 | cut -d' ' -f1)
					[[ $batchMode != true ]] && echo -e "\e[32m*Info*\e[m (callPgm.sh.$LINENO) -- using local framework file: '$dir/framework.sh' ($frameworkVersion)"
					foundFrameworkFile=true
					continue
				else
					IfMe echo -e '\tFile same as production file, skipping'
				fi
			else
				[[ $foundFrameworkFile == true ]] && continue
				frameworkFile="$dir/framework.sh"
				foundFile=true
			fi
		done
		## Set default value if file not found
			if [[ $foundFrameworkFile != true ]]; then
				[[ $TOOLSPATH != '' ]] && frameworkFile="$TOOLSPATH/src/framework.sh" || \
					printf "\n\e[0;31m*Error* -- Sorry cannot execute this script, could not load framework\e[m\a\n\n" || exit -1
			fi

## Set the default mysql connect string
	[[ $useDevDB == true ]] && warehouseDb='dev' || warehouseDb='warehouse'
	dbAcc='Read'
	mySqlUser="leepfrog$dbAcc"
	mySqlHost='duro'
	mySqlPort=3306

	[[ -r "$TOOLSPATH/src/.pw1" ]] && mySqlPw=$(cat "$TOOLSPATH/src/.pw1")
	if [[ $mySqlPw != '' ]]; then
		unset sqlHostIP mySqlConnectString
		sqlHostIP=$(dig +short $mySqlHost.inside.leepfrog.com)
		[[ $sqlHostIP == '' ]] && sqlHostIP=$(dig +short $mySqlHost.leepfrog.com)
		[[ $sqlHostIP != '' ]] && mySqlConnectString="-h $sqlHostIP -port=$mySqlPort -u $mySqlUser -p$mySqlPw $warehouseDb"
	fi

## Source the frameworkFile and load the mySql connection information
	IfMe echo -e 'loading frameworkFile = >'$frameworkFile'<\nTOOLSPATH = >'$TOOLSPATH'<'
	. $frameworkFile

## Debug Stuff
	for scriptSrcDir in ${scriptSrcDirs[@]}; do IfMe dump scriptSrcDir; done

## Apply local override values if necessary
	[[ $myNoLog != $noLog ]] && noLog=$myNoLog
	[[ $myLogInDb != $logInDb ]] && logInDb=$myLogInDb
	[[ $myVerbose != $verbose ]] && verbose=$myVerbose
	[[ $myVerboseLevel != $verboseLevel ]] && verboseLevel=$myVerboseLevel
	[[ $myBatchMode != $batchMode ]] && batchMode=$myBatchMode

## Find execution name if overridden in the scripts table
	unset tmpStr setSemaphore waitOn addArgs
	exName=$myName
	sqlStmt="select exec,setSemaphore,waitOn from $scriptsTable where name =\"$myName\" "
	RunSql 'mysql' $sqlStmt
	if [[ ${#resultSet[0]} -ne 0 ]]; then
	 	resultString=${resultSet[0]}; resultString=$(echo "$resultString" | tr "\t" "|" )
		tmpStr="$(echo $resultString | cut -d'|' -f1)"
		setSemaphore="$(echo $resultString | cut -d'|' -f2)"
		waitOn="$(echo $resultString | cut -d'|' -f3)"
		exec="$(echo $tmpStr | cut -d' ' -f1)"
		addArgs="$(echo $tmpStr | cut -d' ' -f2-)"
		if [[ $exec != $exName && $exec != 'NULL' ]]; then
			exName=$exec
			[[ $addArgs != '' ]] && inArgs="$addArgs $inArgs"
		fi
	fi
	unset addArgs
	IfMe dump myName exName

## Load defaults value
	[[ $exName != $myName ]] && GetDefaultsData $exName
## Get a list of sub dirs to look for the executable in
	scriptDirs=($(find $(dirname $frameworkFile) -maxdepth 1 -type d \( ! -iname '.*' \) -printf "%f " ))
	IfMe printf 'scriptDirs=>%s<\n' "${scriptDirs[@]}"

## Get a list of file extensions to search fo
	unset searchForFileExtensions
	sqlStmt="select scriptData1 from $scriptsTable where name =\"callPgm\" "
	RunSql 'mysql' $sqlStmt
	[[ ${#resultSet[0]} -ne 0 ]] && searchForFileExtensions="$(echo ${resultSet[0]} | tr ',' ' ')"
	IfMe dump searchForFileExtensions

## find execute file in the path
	unset executeFile executeType foundFile
	IfMe echo -e ">>> Searching for executable file for '$exName' in PATH"
	for dir in ${pathDirs[@]}; do
		[[ ${dir:0:5} == '/usr/' || $dir == '/bin' || $dir == '/sbin' ]] && continue
		IfMe dump -n -t dir
		for fileExt in $searchForFileExtensions; do
			fileExt=".$fileExt"
			IfMe echo -e "\t\t$dir/$exName$fileExt"
			[[ -r $dir/$exName$fileExt ]] && executeFile=$dir/$exName$fileExt && foundFile=true && break
			for scriptDir in "${scriptDirs[@]}"; do
				IfMe echo -e "\t\t$(pwd)/$scriptDir/$exName$fileExt"
				[[ -r $dir/$scriptDir/$exName$fileExt ]] && executeFile=$dir/$scriptDir/$exName$fileExt && foundFile=true && break
			done
			[[ $foundFile == true ]] && break
		done
		[[ $foundFile == true ]] && break
	done
	if [[ $foundFile != true ]]; then
		Msg2 $E "(callPgm.sh.$LINENO) Execute file for '$exName' not found."
		dump searchForFileExtensions
		Msg2 "^Path Dirs:"; for dir in ${pathDirs[@]}; do Msg2 "^^$dir"; done
		Msg2 "^Script Dirs:"; for dir in ${scriptDirs[@]}; do Msg2 "^^$dir"; done
		Goodbye -1
	fi

	executeType=${executeFile##*.}
	IfMe dump -n executeFile executeType TOOLSPATH -n

## If a local script then prompt user if myUseLocal is not set
	usingLocal=false
	if [[ ${executeFile:0:6} == '/home/' ]]; then
		prodFile=$TOOLSPATH/src/$(basename $executeFile)
		[[ -r $prodFile ]] && prodMd5=$(md5sum $prodFile | cut -f1 -d" ") || unset prodMd5
		localMd5=$(md5sum $executeFile | cut -f1 -d" ")
		IfMe dump prodFile prodMd5 executeFile localMd5
		if [[ $prodMd5 != '' ]]; then
			if [[ $prodMd5 != $localMd5 ]]; then
				#if [[ $myUseLocal != true ]] && [[ $batchMode != true ]] && [[ $verify == true ]]; then
				if [[ $myUseLocal != true && $batchMode != true && $verify == true ]]; then
					unset ans
					Msg2 "\a\nFound a local/dev copy of the execution file in: '$(dirname $executeFile)'"
					[[ $batchMode != true ]] && Prompt ans 'Do you want to use the dev/local copy ?' 'Yes No' 'Yes' '3'; ans=$(Lower ${ans:0:1}) || ans='y'
				else
					ans='y'
				fi
				if [[ $ans == 'y' ]]; then
					usingLocal=true
					[[ $batchMode != true ]] && Msg2 "$(ColorI "*Info*") (callPgm.sh.$LINENO) -- Using local script: '$executeFile', logging disabled\n" >&2
				else
					executeFile="$prodFile"
					Msg2 "\tCalling: $executeFile"
				fi
			else
				executeFile="$prodFile"
			fi
		else
			usingLocal=true
		fi
	fi
	[[ $usingLocal == true ]] && noLog=true && logInDb=false && addArgs='-noLog -noLogInDb'

	IfMe dump executeFile

## Do we have a viatable script
	[[ ! -f $executeFile ]] && Msg2 $T "callPgm.sh.$LINENO: Could not resolve the script source file:\n\t$executeFile"
	[[ $executeType == '' ]] && Msg2 $T "callPgm.sh.$LINENO: Could not resolve the execution file type:\n\t$executeType"

## Get the ignore logging list from the scripts db
	unset myIgnoreList
	sqlStmt="select ignoreList from $scriptsTable where name =\"callPgm\""
	RunSql 'mysql' $sqlStmt
	myIgnoreList=${resultSet[0]}
	[[ $(Contains ",$myIgnoreList," ",$exName," ) == true ]] && noLog=true

## Initialize the log file
	IfMe echo "callPgm: Initializing logFile"
	logFile=/dev/null
	if [[ $noLogRedirect == false ]]; then
		if [[ $noLog == false ]]; then
			logFile=$logsRoot$exName/$userName--$backupSuffix.log
			if [[ ! -d $(dirname $logFile) ]]; then
				mkdir -p "$(dirname $logFile)"
				chown -R "$userName:leepfrog" "$(dirname $logFile)"
				chmod -R ug+rwx "$(dirname $logFile)"
			fi
			touch "$logFile"
			chmod ug+rwx "$logFile"
			Msg2 "callPgm ($executeType) : $executeFile\n\t$(date)\n\t$exName $inArgs" > $logFile
			Msg2 "$(PadChar)" >> $logFile
		fi
	fi
	IfMe echo -e "\t logFile: $logFile"

## Check semaphore
	IfMe echo "callPgm: Checking Semaphore"
	if [[ $semaphoreProcessing == true && $(Lower $setSemaphore) == 'yes' ]]; then
		unset okToRun okToRunWaiton
		okToRun=$(Semaphore 'check' $myName)
		## Check to see if we are running or any waitOn process are running
		[[ $okToRun == false && $(Contains ",$waitOn," ',self,') != true ]] && Msg2 && Msg2 $T "CallPgm: Another instance of this script ($myName) is currently running.\n"
		if [[ $waitOn != '' ]]; then
			for pName in $(echo $waitOn | tr ',' ' '); do
				waitonMode=$(cut -d':' -f2 <<< $pName)
				pName=$(cut -d':' -f1 <<< $pName)
				[[ $(Lower $waitonMode) == 'g' ]] && checkAllHosts='checkAllHosts' || unset checkAllHosts
				okToRun=$(Semaphore 'check' $pName $checkAllHosts)
				if [[ $okToRun == false ]]; then
					[[ $batchMode != true ]] && Msg2 "CallPgm: Waiting for process '$pName' to finish..."
					Semaphore 'waiton' "$pName" $checkAllHosts
				fi
			done
		fi
		## Set our semaphore
		semaphoreId=$(Semaphore 'set')
	fi
	IfMe echo -e "\t semaphoreId: $semaphoreId"

## Call the program initiator function (see above)
	unset warningMsgs
	unset forkedProcesses

## Check to make sure we can run and are authorized
	if [[ $noRunCheck != true ]]; then
		IfMe echo "callPgm: Checking Run"
		checkMsg=$(CheckRun)
		if [[ $checkMsg != true ]]; then
			[[ $LOGNAME != 'dscudiero' ]] && Msg2 && Msg2 $T "$checkMsg"
			[[ $exName != 'testsh' ]] && Msg2 "$(ColorW "*** $checkMsg ***")"
		fi
	fi
	if [[ $noAuthCheck != true ]]; then
		IfMe echo "callPgm: Checking Auth"
		checkMsg=$(CheckAuth)
		[[ $checkMsg != true ]] && Msg2 && Msg2 "$checkMsg" && Msg2 && Goodbye 'quiet'
	fi

## Log Start in process log database
	[[ $logInDb != false ]] && myLogRecordIdx=$(dbLog 'Start' "$exName" "$inArgs")

## Who we are, where we are
	myName=$exName
	myPath="$(dirname $executeFile)"
	if [[ "$0" = "-bash" ]]; then
		myName=bashShell
		myPath=$TOOLSPATH
		batchMode=true
	fi
	IfMe dump myName myPath

## Call program function
	trap "CleanUp" EXIT
	IfMe dump -n executeFile executeType TOOLSPATH PATH setSemaphore semaphoreProcessing semaphoreId
	Call.${executeType}Pgm
	rc=$?

exit

## Should never get here but just in case
	CleanUp $rc

#==================================================================================================
## Wed Mar 16 15:24:46 CDT 2016 - dscudiero - Add features directory
## Wed Mar 16 16:31:09 CDT 2016 - dscudiero - Pull list of subdirectory names to search for executable from scriptData1 field in the db
## Thu Mar 17 08:57:21 CDT 2016 - dscudiero - ignore archive directory when looking for executable
## Thu Mar 17 12:22:53 CDT 2016 - dscudiero - add debug msgs
## Thu Mar 17 12:25:40 CDT 2016 - dscudiero - add debug msgs
## Thu Mar 17 12:27:39 CDT 2016 - dscudiero - Fix problem finding executable
## Tue Mar 22 15:10:02 CDT 2016 - dscudiero - Enhanced semaphore checking
## Wed Mar 23 08:52:04 CDT 2016 - dscudiero - Fix --noSemaphore logic
## Wed Mar 23 11:15:37 CDT 2016 - dscudiero - General syncing of dev to prod
## Fri Mar 25 07:52:45 CDT 2016 - dscudiero - Change the way we call the sub shell based on if noLog is set
## Fri Mar 25 09:57:22 CDT 2016 - dscudiero - General syncing of dev to prod
## Fri Mar 25 13:21:46 CDT 2016 - dscudiero - Refactor to fix call back on called script exit
## Mon Mar 28 07:21:26 CDT 2016 - dscudiero - General syncing of dev to prod
## Mon Mar 28 10:45:37 CDT 2016 - dscudiero - source target script
## Tue Mar 29 11:22:58 CDT 2016 - dscudiero - Add - to the Msg calls for PadChar
## Tue Mar 29 14:36:15 CDT 2016 - dscudiero - Tweak message used when local file is found
## Wed Mar 30 13:45:13 CDT 2016 - dscudiero - prefix Msg calls with -
## Thu Mar 31 09:49:33 CDT 2016 - dscudiero - Turn off unnecessary messages in batch mode
## Thu Mar 31 16:51:39 CDT 2016 - dscudiero - set overrride values if necesssary after the framework call
## Thu Mar 31 16:52:50 CDT 2016 - dscudiero - remove debug statements
## Fri Apr  1 10:44:16 CDT 2016 - dscudiero - Tweaked messaging
## Fri Apr  1 10:47:18 CDT 2016 - dscudiero - Tweaked messaging
## Fri Apr  1 13:20:30 CDT 2016 - dscudiero - localize the useLocal variable
## Wed Apr  6 11:09:22 CDT 2016 - dscudiero - Remove localFile from CheckRun and CheckAuth calls
## Wed Apr  6 16:10:14 CDT 2016 - dscudiero - Add useDevDB flag
## Wed Apr  6 16:15:39 CDT 2016 - dscudiero - General syncing of dev to prod
## Thu Apr  7 07:10:55 CDT 2016 - dscudiero - Look at global variable USEDEVDB
## Fri Apr  8 16:43:39 CDT 2016 - dscudiero - Fixed problem with the RunCheck results processing
## Wed Apr 13 08:18:24 CDT 2016 - dscudiero - Tweak signal processing
## Wed Apr 13 16:26:28 CDT 2016 - dscudiero - Do not prompt about using local file if verify is not true
## Thu Apr 14 08:08:19 CDT 2016 - dscudiero - Move setting myName and myPath in from framework
## Thu Apr 14 13:42:27 CDT 2016 - dscudiero - Set myName from the execFile name
## Thu Apr 14 16:05:04 CDT 2016 - dscudiero - General syncing of dev to prod
## Fri Apr 15 07:19:21 CDT 2016 - dscudiero - Do not show offline message for testsh
## Mon Apr 18 13:33:18 CDT 2016 - dscudiero - Remove the setting of userName, moved back into the framework
## Wed Apr 20 07:57:36 CDT 2016 - dscudiero - Tweek logic when looking for framework file
## Thu Apr 21 08:13:14 CDT 2016 - dscudiero - Tweak debug messages
## Wed Apr 27 13:26:38 CDT 2016 - dscudiero - General syncing of dev to prod
## Wed Apr 27 15:16:06 CDT 2016 - dscudiero - Switch to use RunSql
## Thu Apr 28 13:33:37 CDT 2016 - dscudiero - Force -noLogDb if running local
## Fri Apr 29 10:30:00 CDT 2016 - dscudiero - Added line number to callPgm.sh messages
## Tue May 17 10:37:15 CDT 2016 - dscudiero - Fix problem using Msg vs Msg2
## Mon Jun  6 09:03:50 CDT 2016 - dscudiero - Turn off messaging for local framework if batchmode
## Tue Jun  7 10:14:31 CDT 2016 - dscudiero - Remove extra arguments if calling a python pgm
## Mon Jul 11 16:43:04 CDT 2016 - dscudiero - General syncing of dev to prod
## Mon Jul 11 16:59:51 CDT 2016 - dscudiero - General syncing of dev to prod
## Mon Jul 11 17:02:08 CDT 2016 - dscudiero - General syncing of dev to prod
## Mon Jul 11 17:06:31 CDT 2016 - dscudiero - General syncing of dev to prod
## Tue Jul 12 10:25:25 CDT 2016 - dscudiero - Add debug statements
## Tue Jul 12 12:06:16 CDT 2016 - dscudiero - Refactored argument parsing
## Thu Jul 14 13:29:40 CDT 2016 - dscudiero - Added --noAuthCheck and --noRunCheck directives
## Thu Jul 14 14:40:22 CDT 2016 - dscudiero - Add IfMe debug statment to dump inArgs
## Wed Jul 20 07:57:55 CDT 2016 - dscudiero - Reformat offline message
## Wed Jul 20 10:13:20 CDT 2016 - dscudiero - Added on all hosts checking to check semaphore
## Thu Jul 21 10:47:29 CDT 2016 - dscudiero - Add some debug statements
## Wed Sep 28 09:37:31 CDT 2016 - dscudiero - Fix problem prompting for local script execution
## Thu Sep 29 10:32:04 CDT 2016 - dscudiero - Do not check path directories that start with /usr/ or are /bin, or /sbin
## Tue Oct  4 11:47:18 CDT 2016 - dscudiero - removed blank lines
## Thu Oct  6 07:08:35 CDT 2016 - dscudiero - Update to set db connection information using .connect
## Thu Oct  6 08:49:21 CDT 2016 - dscudiero - Add a timeout to the prompt call if local script is found
## Thu Oct  6 15:39:17 CDT 2016 - dscudiero - Pass access level to .connect
## Fri Oct  7 15:17:13 CDT 2016 - dscudiero - Fixes for the sqlconnection fiascio
## Fri Oct  7 15:57:06 CDT 2016 - dscudiero - Remove dump -r from the shell rprocessor
## Fri Oct  7 16:31:27 CDT 2016 - dscudiero - Remove extra message
## Fri Oct  7 16:32:08 CDT 2016 - dscudiero - Remove extra message
## Tue Oct 11 16:31:08 CDT 2016 - dscudiero - Add debug messages if we cannot find the script
## Tue Oct 11 16:50:43 CDT 2016 - dscudiero - Add TOOLSPATH/src to the pathDirs searched for scripts
## Wed Oct 12 07:05:03 CDT 2016 - dscudiero - allways add TOOLSPATH and TOOLSPATH/src to the list of dirs searched
## Thu Oct 13 13:11:55 CDT 2016 - dscudiero - Switch to use
## Thu Oct 13 13:12:45 CDT 2016 - dscudiero - Switch to use SetupInterpreterExecutionEnv for python programs
## Thu Oct 20 15:58:05 CDT 2016 - dscudiero - Set / Reset PATH before / after python call
