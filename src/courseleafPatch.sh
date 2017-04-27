#!/bin/bash
# XO NOT AUTOVERSION
#=======================================================================================================================
version=5.0.125 # -- dscudiero -- Thu 04/27/2017 @ 11:09:55.64
#=======================================================================================================================
TrapSigs 'on'
includes='GetDefaultsData ParseArgs ParseArgsStd Hello Init Goodbye RunCourseLeafCgi WriteChangelogEntry GetCims GetSiteDirNoCheck'
includes="$includes GetExcel EditTcfValue BackupCourseleafFile ParseCourseleafFile GetCourseleafPgm CopyFileWithCheck"
includes="$includes ArrayRef"
Import "$includes"
originalArgStr="$*"
scriptDescription="Refresh a courseleaf product"

#=======================================================================================================================
# Refresh a Courseleaf component from the git repo
#=======================================================================================================================
#=======================================================================================================================
## Copyright ©2015 David Scudiero -- all rights reserved.
## 07-09-15 -- 	dgs - Initial coding
## 07-28-15 -- 	dgs - Use my own select function
#=======================================================================================================================
#=======================================================================================================================
# Standard call back functions
#=======================================================================================================================
	function parseArgs-courseleafPatch {
		# argList+=(argFlag,minLen,type,scriptVariable,exCmd,helpSet,helpText)  #type in {switch,switch#,option,help
		argList+=(-advance,3,switch,catalogAdvance,,script,"Advance the catalog")
		argList+=(-noAdvance,4,switch,catalogAdvance=false,"catalogAdvance=false",script,"Do not advance the catalog")
		argList+=(-fullAdvance,5,switch,fullAdance,,script,"Do a full catalog advance")
		argList+=(-newest,3,switch,newest,,script,"Update each product to the newest named version of each product")
		argList+=(-master,3,switch,master,,script,"Update each product to the master version of each product")
		argList+=(-edition,2,option,edition,,script,'The new edition value')
		argList+=(-catalogAudit,2,switch,catalogAudit,,script,"Run the catalog audit report as part of the process")
		argList+=(-noAudit,4,switch,catalogAudit=false,"catalogAudit=false",script,"Do not run the catalog audit report as part of the process")
		argList+=(-listOnly,1,switch,listOnly,,script,"Do not do copy, only list out files that would be copied")
		argList+=(-noBackup,3,switch,backup,backup=false,script,"Do not create a backup of the target site before any actions")
		#argList+=(-offline,3,switch,offline,,script,"Take the target site offline during processing")
	}
	function Goodbye-courseleafPatch  {
		[[ -f /tmp/$userName.$myName.rsyncErr.out ]] && rm -f /tmp/$userName.$myName.rsyncErr.out
		[[ -f $rsyncFilters ]] &&  rm -rf $rsyncFilters
		## If we took the site offline, then put it back online
		if [[ $offline == true ]]; then
			## uncomment the user records, remove the siteadmin: record from the bottoms
			Msg2 "Bringing the site back online"
			editFile="$tgtDir/courseleaf.cfg"
			sed -e '/user:/ s|^//||' -i "$editFile"
			line=$(tail -1 "$editFile")
			[[ $line == 'sitereadonly:true' ]] && sed -i '$ d' "$editFile"
			offline=false
		fi
	}
	#export -f Goodbye-courseleafPatch
	function testMode-courseleafPatch {
		client='none'
		env='next'
		siteDir="$HOME/testData/next"
		[[ -z $products ]] && products='all'
		noCheck=true
	}

#=======================================================================================================================
# local functions
#=======================================================================================================================
	#==============================================================================================
	# Get the version of a product
	#==============================================================================================
	function GetVersion {
		local product=$1
		local siteDir=$2
		local verFile prodVer

		case "$product" in
			cat)
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
	} #GetVersion

	#==============================================================================================
	#=Run rsync
	## Returns 	'true' <rsync output file>	if files where updated
	##			'false' 					if files where not updated
	##			'error' <rsync output file>	if rsync has an error
	## via variable rsyncResults
	#==============================================================================================
	function RunRsync {
		local product="$1"; shift
		local rsyncSrc="$1"; shift
		local rsyncTgt="$1"; shift
		local rsyncBackup="${1:-/dev/null}"
		local token rsyncOpts rsyncSrc rsyncTgt rsyncBackup rsyncOut rsyncFilters rsyncVerbose rsyncListonly rc
		dump -2 product rsyncSrc rsyncTgt rsyncOpts
		local rsyncErr="$tmpRoot/$myName.$product.rsyncErr.out"
		[[ -r $rsyncErr ]] && rm "$rsyncErr"

		## Set rsync options
			[[ ! -d $rsyncBackup && $rsyncBackup != '/dev/null' ]] && $DOIT mkdir -p $rsyncBackup
			[[ $quiet == true ]] && rsyncVerbose='' || rsyncVerbose='v'
			[[ $listOnly == true ]] && rsyncListonly="--dry-run" || unset rsyncListonly
			rsyncFilters=$tmpRoot/$myName.$product.rsyncFilters.txt
			rsyncOut=$tmpRoot/$myName.$product.rsync.out
			rsyncOpts="-rptb$rsyncVerbose --backup-dir $rsyncBackup --prune-empty-dirs $rsyncListonly --include-from $rsyncFilters"
			echo > $rsyncFilters
			SetFileExpansion 'off'
			for token in $(tr '|' ' ' <<< "$specIgnoreList"); do echo "- $token" > $rsyncFilters; done
			echo '+ *.*' >> $rsyncFilters
			SetFileExpansion

		## Do copies
			local indentLevelSave=$indentLevel
			indentLevel=1
			if [[ -z $DOIT ]]; then
				if [[ $verboseLevel -eq 0 ]]; then
					rsync $rsyncOpts "$rsyncSrc" "$rsyncTgt" 2>$rsyncErr | Indent > "$rsyncOut"; rc=$?
					cat "$rsyncOut" | Indent >> $logFile
				else
					rsync $rsyncOpts "$rsyncSrc" "$rsyncTgt" 2>$rsyncErr | Indent | tee "$rsyncOut"; rc=$?
				fi
			    if [[ $rc -eq 0 ]]; then
			       [[ $(wc -l < $rsyncOut) -gt 4 ]] && rsyncResults="true" || rsyncResults="false"
					rm -f "$rsyncOut"
		    	else
					Msg2 "^Errors reported from the rsync operation:"
					Msg2 "^^Source: '$rsyncSrc'"
					Msg2 "^^Target: '$rsyncTgt'"
					Msg2 "^^Rsync Options: '$rsyncOpts'\n"
					indentLevel=2
					cat "$rsyncErr" | Indent
					rm -f "$rsyncOut"
					Terminate "Stopping processing"
			    fi
			fi ##[[ -z $DOIT ]]
			indentLevel=$indentLevelSave
		return 0
	} #RunRsync

#=======================================================================================================================
# Declare local variables and constants
#=======================================================================================================================
unset backup backupSite
cleanDirs=${scriptData3##*:}
cleanFiles=${scriptData4##*:}
tmpFile=$(mkTmpFile)

#=======================================================================================================================
# Standard argument parsing and initialization
#=======================================================================================================================
	helpSet='script,client,env'
	helpNotes+=('For refreshVersion = "master" the source files are refreshed from the git repo at midnight and noon so the data may be as much as 12 hours old.' )
	scriptHelpDesc="This script can be used to refresh a CourseLeaf product code/configuration files."

	GetDefaultsData $myName
	ParseArgsStd
	displayGoodbyeSummaryMessages=true
	Hello

	[[ $listOnly == true ]] && Warning 0 1 "The 'listOnly' flag is turned on, files will not be copied"
	if [[ $noCheck == true ]]; then
		Init 'getClient'
		GetSiteDirNoCheck $client
		[[ -z $siteDir ]] && Terminate "Nocheck option active, could not resolve target site directory"

	else
		Init 'getClient getEnv getDirs checkDirs noPreview noPublic'
	fi

	[[ $allItems == true && -z $products ]] && products='all'

	# Read in the control file, build the product arrays
	workbookFile="$HOME/tools/workbooks/$(basename $courseleafPatchControlFile)"
	[[ -r $workbookFile ]] && Note 0 1 "Using workbook: '$workbookFile'" || workbookFile="$courseleafPatchControlFile"
	## Get the list of sheets in the workbook
		GetExcel "$workbookFile" 'GetSheets' > $tmpFile
		sheets=$(tail -n 1 $tmpFile | tr '|' ' ')
		#dump -t sheets

	## Read in the data for each product into a hash table
		unset productList
		for sheet in $sheets; do
			sheet=$(Lower "$sheet")
			[[ ${sheet:0:1} == '-' ]] && continue
			GetExcel "$workbookFile" "$sheet" > $tmpFile
			arrayName="$(tr -d '-' <<< $sheet)"
			unset $arrayName ## Unset the sheet array
			[[ $sheet != 'all' && ${sheet:0:8} != 'include-' ]] && productList="$productList,$sheet"
			while read line; do
				[[ -z $line || $line == '|||' ]] && continue
				token="$(Lower "$(cut -d'|' -f1 <<< "$line")")"
				[[ $token == '' || $token == 'source' || $token == 'note:' || ${token:0:1} == '#' || ${token:0:2} == '//' ]] && continue
				dump -2 -t -t line
				eval "$arrayName+=(\"$line\")"
			done < "$tmpFile"
		done
		productList="${productList:1}"

	## Get the products to patch
	[[ -n $products ]] && patchProds="$products"
	dump -2 productList

	unset purchasedProducts
	if [[ $noCheck != true ]]; then
		sqlStmt="select products from $clientInfoTable where name=\"$client\""
		RunSql2 $sqlStmt
		[[ ${#resultSet[@]} -gt 0 ]] && purchasedProducts="$Lower "${resultSet[0]}")"
	fi

	Prompt patchProds "What products do you wish to work with (comma separated)" "$productList,all" "$purchasedProducts"; patchProds="$(Lower "$patchProds")"
	[[ $patchProds == 'all' ]] && patchProds="$productList"
	## Check the products to make sure the client has them installed
		unset patchProducts
		[[ $noCheck != true  && -z $purchasedProducts ]] && Warning "The specified client ($client) does not have any products registered for it in the clients database."
		if [[ -n $purchasedProducts ]]; then
			for token in $(tr ',' ' ' <<< "$patchProds"); do
				found=false
				[[ ${token:0:2} == 'ca' ]] && token='cat'
				[[ ${token:0:2} == 'ci' ]] && token='cim'
				[[ $token == 'cgis' ]] && found=true
				for token2 in $(tr ',' ' ' <<< "$purchasedProducts"); do
					[[ $token == ${token2:0:${#token}} ]] && found=true && break
				done
				[[ $found != true ]] && Error "This client does not have product '$token' registered in the clients database, skipping" || patchProducts="$patchProducts,$token"
			done
			patchProducts="${patchProducts:1}"
		else
			patchProducts="$patchProds"
		fi

	tgtDir="$siteDir"
	[[ $client == 'internal' ]] && courseleafProgDir='pagewiz' || courseleafProgDir='courseleaf'

#=======================================================================================================================
## Main
#=======================================================================================================================
	[[ $client == 'internal' ]] && Terminate "Sorry, the internal site is not supported at this time"
	[[ -z $tgtDir ]] && tgtDir="$siteDir"
	[[ -z $tgtEnv ]] && tgtEnv="$env"
	dump -2 client env tgtEnv tgtDir patchProducts
	## Get the products that the user wants to patch
	unset processControl betaProducts
	for product in $(tr ',' ' ' <<< $(Upper "$patchProducts")); do
		productLower="$(Lower "$product")"
		## Get the version
		[[ $productLower == 'cat' ]] && srcDir=$gitRepoShadow/courseleaf || srcDir=$gitRepoShadow/$productLower
		[[ ! -d $srcDir ]] && continue
		unset fileList prodShadowVer prodMasterDate
		fileList="$(ls -t $srcDir | grep -v .bad | grep -v master | tr "\n" " ")"
		prodShadowVer=${fileList%% *}
		[[ ! -f $srcDir/master/.syncDate ]] && Terminate "Could not locate '$srcDir/master/.syncDate'. The skeleton shadow is probably being updated, please try again later"
		prodMasterDate=$(date +"%m-%d-%Y @ %H.%M.%S" -r $srcDir/master/.syncDate)
		if [[ -z $newest && -z $master ]]; then
			echo
			Msg2 "For '$(ColorK $product)', do you wish to apply the latest named version ($prodShadowVer) or the skeleton ($prodMasterDate)"
			unset ans; Prompt ans "^'Yes' for the named version, 'No' for the skeleton" 'Yes,No' 'Yes'; ans=$(Lower "${ans:0:1}")
			[[ $ans != 'y' ]] && prodShadowVer='master'
		else
			[[ -n $master ]] && prodShadowVer='master'
			Note 0 1 "Using specified value of '$prodShadowVer' for $product 'prodShadowVer'"
		fi
		if [[ $prodShadowVer == 'master' ]]; then
			token="$(Lower "$(cat "$srcDir/master/$(basename $srcDir)/clver.txt")")"
			[[ ${token: -2} == 'rc' ]] && betaProducts="$betaProducts, $product"
		fi
		processControl="$processControl,$productLower|$prodShadowVer|$srcDir"
	done

	betaProducts=${betaProducts:2}
	processControl=${processControl:1}
	dump -2 processControl betaProducts

## If cat is one of the products, should we advance the edition, should we audit the catalog
	if [[ $(Contains "$patchProducts" 'cat') == true ]]; then
		if [[ $env == 'next' || $env == 'pvt' ]]; then
			if [[ -z $catalogAdvance ]]; then
				echo
				unset ans; Prompt ans 'Do you wish to advance the catalog edition?' 'No Yes' 'No'; ans="$(Lower ${ans:0:1})"
				[[ $ans == 'y' ]] && catalogAdvance=true
			else
				Note 0 1 "Using specified value of '$catalogAdvance' for 'catalogAdvance'"
				[[ $verify != true && $catalogAdvance == true ]] && Info 0 1 "Specifying -noPrompt and -catalogAdvance is not allowed, continuing with prompting active" && verify=true
			fi
			if [[ $catalogAdvance == true ]]; then
				catalogAdvance=true
				[[ $verify == false && $edition == '' ]] && Msg2 $T "New edition has not been set and '-noPrompt' flag was specified on the call"
				if [[ -z $edition ]]; then
					## Get the current edition from the defults.tcf file
					unset grepStr
					currentEdition=$(ProtectedCall "grep "^edition:" $siteDir/web/courseleaf/localsteps/default.tcf" | cut -d':' -f2)
					currentEdition=$(tr -d '\040\011\012\015' <<< "$currentEdition")
					## Set the new edition and prompt user
					Msg2; Msg2 "Current CAT edition is: '$currentEdition'."
					unset newEdition
					if [[ $currentEdition != '' && $currentEdition != *'migration'* ]]; then
						if [[ $(Contains "$currentEdition" '-') == true ]]; then
							fromYear=$(echo $currentEdition | cut -d'-' -f1)
							toYear=$(echo $currentEdition | cut -d'-' -f2)
							[[ $(IsNumeric $fromYear) == true  && $(IsNumeric $toYear) == true ]] && (( fromYear++ )) && (( toYear++ )) && newEdition="$fromYear-$toYear"
						elif [[ $(Contains "$currentEdition" '_') == true ]]; then
							fromYear=$(echo $currentEdition | cut -d'_' -f1)
							toYear=$(echo $currentEdition | cut -d'_' -f2)
							[[ $(IsNumeric $fromYear) == true  && $(IsNumeric $toYear) == true ]] && (( fromYear++ )) && (( toYear++ )) && newEdition="$fromYear-$toYear"
						else
							[[ $(IsNumeric $currentEdition) == true ]] && newEdition=$currentEdition && (( newEdition++ ))
						fi
					fi
					[[ -n $newEdition ]] && Prompt newEdition "Please specify the new edition value" "$newEdition,*any*" "$newEdition" || Prompt newEdition "Please specify the new edition value" "*any*"
				else
					newEdition="$edition"
				fi
				[[ -z $newEdition ]] && Msg2 $T "New edition variable has not been set"
				echo
				unset ans; Prompt ans '^Do you wish to do a full advance (copy NEXT to CURR sans CLSS & CIMs, etc.)' 'Yes No' 'Yes'; ans="$(Lower ${ans:0:1})"
				[[ $ans == 'y' ]] && fullAdvance=true || fullAdvance=false
			else
				catalogAdvance=false
				fullAdvance=false
			fi ## [[ $catalogAdvance == true ]]
		fi ##[[ $env == 'next' ]]
		if [[ -z $catalogAudit ]]; then
			echo
			unset ans; Prompt ans "Do you wish to run the catalog audit report" "No Yes" "No"; ans=$(Lower ${ans:0:1})
			[[ $ans == 'y' ]] && catalogAudit=true
		else
			Note 0 1  "Using specified value of '$catalogAudit' for 'catalogAudit'"
		fi
	fi ##[[ $(Contains "$products" 'cat') == true ]]


## Should we backup the target site
	if [[ $env == 'next' || $env == 'curr' ]]; then
		[[ $backup == true ]] && backup='Yes' ; [[ $backup == false ]] && backup='No'
		Prompt backup "Do you wish to make a backup of the tartet site before patching" 'Yes No' 'Yes'; backup=$(Lower ${backup:0:1})
		[[ $backup == 'y' ]] && backup=true || backup=false
		# [[ $offline == true ]] && offline='Yes' ; [[ $offline == false ]] && offline='No'
		# Prompt offline "Do you wish to take the site offline during the patching process" 'Yes No' 'Yes'; offline=$(Lower ${offline:0:1})
		# [[ $offline == 'y' ]] && offline=true || offline=false
	fi

## Get the cgisDir
	cgisDirRoot=$cgisRoot/rhel${myRhel:0:1}
	[[ ! -d $cgisDirRoot ]] && Terminate "Could not locate cgi source directory:\n\t$cgiRoot"
	cwd=$(pwd)
	cd $cgisDirRoot
	cgisDir=$(ls -t | tr "\n" ' ' | cut -d ' ' -f1)
	cgisDir=${cgisDirRoot}/$cgisDir
	[[ ! -d $cgisDir ]] && Terminate "Could not find cgis directory: $cgisDir"
	cd $cwd
	cgiVer="$($cgisDir/courseleaf.cgi -v  2> /dev/null | cut -d" " -f3)"

## Get the daily.sh version
	grepFile="$skeletonRoot/release/bin/daily.sh"
	dailyShVer=$(ProtectedCall "grep -m 1 \"^version=\" $grepFile")
	dailyShVer=${dailyShVer%% *}; dailyShVer=${dailyShVer##*=};
	dump -2 dailyShVer

## Backup root
	backupRootDir="$tgtDir/attic/$myName.$(date +"%m-%d-%Y").prePatch"
	mkdir -p "$backupRootDir"

#=======================================================================================================================
# Verify continue
#=======================================================================================================================
[[ -z $processControl ]] && Terminate "No process control records selected, more likely than not the value specified for product, '$product', is not valid."
unset verifyArgs
if [[ $noCheck == true ]]; then
	verifyArgs+=("Target Path:$tgtDir")
else
	verifyArgs+=("Client:$client")
    verifyArgs+=("Target Env:$(TitleCase $env) ($tgtDir)")
fi
verifyArgs+=("Products:$(Upper $patchProducts)")
for token in $(tr ',' ' ' <<< $processControl); do
	verifyArgs+=("$(Upper "$(cut -d '|' -f1 <<< $token)") version:$(cut -d '|' -f2 <<< $token)") 	## (from: '$(cut -d '|' -f3 <<< $token)/$(cut -d '|' -f2 <<< $token)')")
done

[[ $catalogAdvance == true ]] && verifyArgs+=("New catalog edition:$newEdition, fullAdvance=$fullAdvance")
[[ $catalogAudit == true ]] && verifyArgs+=("Catalog Edit:$catalogAudit")

verifyArgs+=("CGIs version:$cgiVer") 	## (from: '$cgisDir')")
verifyArgs+=("Daily.sh version:$dailyShVer") 	## (from: '$skeletonRoot/release')")
[[ $backup == true ]] && verifyArgs+=("Backup site:$backup") 	## (from: '$skeletonRoot/release')")
[[ $offline == true ]] && verifyArgs+=("Take site offline:$offline") 	## (from: '$skeletonRoot/release')")

[[ -n $betaProducts ]] && [[ $env == 'next' || $env == 'curr' ]] && Warning "You are asking to refresh to beta version of the software for: $betaProducts\n"

VerifyContinue "You are asking to refresh CourseLeaf code files for:"

#=======================================================================================================================
# Log run
myData="Client: '$client', Products: '$patchProducts', tgtEnv: '$env' $processControl"
[[ $noCheck == true ]] && myData="Target Path, $tgtDir, Products: '$patchProducts' $processControl"
[[ $catalogAdvance == true ]] && myData="$myData New Edition: $newEdition"
[[ $catalogAudit == true ]] && myData="$myData catalog audit"
myData="$myData $processControl"
[[ $logInDb != false && $myLogRecordIdx != "" && $testMode != true ]] && ProcessLogger 'Update' $myLogRecordIdx 'data' "$myData"
dump -2 -p client products catRefreshVersion cimRefreshVersion clssRefreshVersion srcDir tgtDir cgisDir

#=======================================================================================================================
## Main
#=======================================================================================================================
if [[ $offline == true ]]; then
	## comment out the user records in courseleaf.cfg, keep leepfrog and cl* accounts
	Msg2 "Taking the site offline"
	editFile="$tgtDir/courseleaf.cfg" 
	sed -e '/user:/ s|^|//|' -i "$editFile"
	for user in leepfrog cladmin- clmig-; do
		fromStr="^//user:$user" ; toStr="user:$user"
		sed -i s"_${fromStr}_${toStr}_"g "$editFile"
	done
	## Add a sitereadonly: record
	echo 'sitereadonly:true' >> $editFile
fi

if [[ $backup == true ]]; then
	[[ $env == 'next' || $env == 'curr' ]] && backupSite="$(dirname $tgtDir)" || backupSite="$tgtDir"
	backupSite="$backupSite.$myName.$(date +"%m-%d-%y")"
	Msg2 "Backing up the target site to '$backupSite' (this may take a while)..."
	sourceSpec="$tgtDir/"
	targetSpec="$backupSite"
	[[ ! -d "$targetSpec" ]] && mkdir -p "$targetSpec"
	unset rsyncResults
	RunRsync 'tgtSiteBackup' "$sourceSpec" "$targetSpec"
	Msg2 "^Backup completed"
	Alert 1
else
	backup=false
fi

if [[ $catalogAdvance == true || $fullAdvance == true ]]; then
	Msg2 "Catalog advance is active, advancing the '$(Upper $env)' site"
	# # Turn off publishing
	# 	Msg2 "^^Turn off Publishing..."
	# 	editFile="$tgtDir/$courseleafProgDir.cfg"
	# 	sed -i s'_^mapfile:production_//mapfile:production_'g "$editFile"
	# 	sed -i s'_^//mapfile:production|/dev/null_mapfile:production|/dev/null_' "$editFile"

	# Full advance, create a new curr site
	if [[ $fullAdvance == true ]]; then
		# Make a copy of next sans CLSS/WEN
		sourceSpec="$tgtDir/"
		targetSpec="$(dirname $tgtDir)/$env.$(date +"%m-%d-%y")"
		Msg2 "^Making a backup copy of 'NEXT' to '$(basename $targetSpec)' sans CLSS/WEN (this will take a while)..."
		specIgnoreList="/db/clwen*|/bin/clssimport-log-archive/|/web/$progDir/wen/|/web/wen/"
		sourceSpec="$tgtDir/"
		targetSpec="$(dirname $tgtDir)/$env.$(date +"%m-%d-%y")"
		[[ ! -d "$targetSpec" ]] && mkdir -p "$targetSpec"
		unset rsyncResults
		RunRsync "$product" "$sourceSpec" "$targetSpec"
		Msg2 "^^Backup completed"
		Alert 1

		# Edit the coursleaf/index.tcf to remove clss/wen stuff
		editFile="$targetSpec/web/$courseleafProgDir/index.tcf"
		Msg2 "^Editing the /$courseleafProgDir/index.tcf file..."
		sed -i s'_^sectionlinks:WEN|_//sectionlinks:WEN|_'g "$editFile"
		sed -i s'_^navlinks:WEN|_//navlinks:WEN|_'g "$editFile"

		# Edit the coursleaf/index.tcf to comment out courseadmin lines
		sed -e '/courseadmin/ s_^_//_' -i "$editFile"

		# Rename courseadmin so it is no longer visible
		[[ -d $tgtDir/web/courseadmin ]] && $DOIT mv -f "$tgtDir/web/courseadmin" "$tgtDir/web/courseadmin.$(basename $targetSpec)"

		## Swap our copy of the next site with the curr site
		Msg2 "^Full backup is active, swapping our copy of the NEXT site with the CURR site"
		[[ -d $(dirname $tgtDir)/curr ]] && $DOIT mv -f "$(dirname $tgtDir)/curr" "$(dirname $tgtDir)/curr.$(cut -d '.' -f2 <<< $(basename $targetSpec))"
		$DOIT mv -f "$targetSpec" "$(dirname $tgtDir)/curr"
		## Fix the editcl login accounts
		editFile="$(dirname $tgtDir)/curr/$courseleafProgDir.cfg"
		sed -i s"_$client-next_$client-curr_"g "$editFile"
		# Turn off pencils from the structured content draw
		if [[ -f "$editFile" ]] ; then
			Msg2 "^Editing the /localsteps/structuredcontentdraw.html file..."
			editFile="$tgtDir/web/$courseleafProgDir/localsteps/structuredcontentdraw.html"
			sed -e '/pencil.png/ s|html|//html|' -i "$editFile"
		fi
		Msg2 "^*** The new CURR site has been created"
	fi #[[ $fullAdvance == true ]]

	## Set the new edtion value
		Msg2 "^Setting edition variable..."
		$DOIT BackupCourseleafFile $tgtDir/web/$courseleafProgDir/localsteps/default.tcf
		fromStr=$(ProtectedCall "grep "^edition:" $tgtDir/web/$courseleafProgDir/localsteps/default.tcf")
		toStr="edition:$newEdition"
		sed -i s"_^${fromStr}_${toStr}_" $tgtDir/web/$courseleafProgDir/localsteps/default.tcf
		Msg2 "^^$fromStr --> $toStr"

	# Reset coursleaf statuses
		Msg2 "^Reseting console status (this may take a while)..."
		Msg2 "^^wfstatinit..."
		RunCourseLeafCgi $tgtDir "wfstatinit /index.html"
		Msg2 "^^wfstatbuild..."
		RunCourseLeafCgi $tgtDir "-e wfstatbuild /"
		Alert 1

	# Archive request logs
		Msg2 "^Archiving request logs..."
		if [[ -d $tgtDir/requestlog ]]; then
			cd $tgtDir/requestlog
			if [[ $(ls) != '' ]]; then
				Msg2 "^Archiving last requestlog directory..."
				SetFileExpansion 'on'
				[[ ! -d "$tgtDir/requestlog-archive/" ]] && mkdir "$tgtDir/requestlog-archive/"
				$DOIT tar -cJf $tgtDir/requestlog-archive/requestlog-$(date "+%Y-%m-%d").tar.bz2 * --remove-files
				SetFileExpansion
			fi
		fi
		if [[ -d $tgtDir/requestlog-archive ]]; then
			cd $tgtDir/requestlog-archive
			if [[ $(ls | grep -v 'archive') != '' ]]; then
				Msg2 "^Taring up the requestlog-archive directory..."
				cd $tgtDir/requestlog-archive
				SetFileExpansion 'on'
				$DOIT tar -cJf $tgtDir/requestlog-archive/archive-$(date "+%Y-%m-%d").tar.bz2 *  --exclude '*archive*' --remove-files
				SetFileExpansion
			fi
		fi

	# Genaral cleanup
		Msg2 "^Emptying files"
		for file in $(echo $cleanFiles | tr ',' ' '); do
			Msg2 "^^$file"
			[[ $DOIT == '' ]] && echo > $tgtDir/$file
		done
		Msg2 "^Emptying directories (this may take a while)"
		for dir in $(echo $cleanDirs | tr ',' ' '); do
			Msg2 "^^$dir"
			if [[ -d $tgtDir/$dir ]]; then
				cd $tgtDir/$dir
				SetFileExpansion 'on'
				$DOIT rm -rf *
				SetFileExpansion
			fi
		done
		Msg2 "^Removing .git files/directories (relative to '$tgtDir')"
		cd $tgtDir
		for dirFile in $(find -maxdepth 4 -name '*.git*'); do
			Msg2 "^\t$dirFile"
			$DOIT rm -rf $dirFile
		done

		Msg2 "Catalog advance completed"

fi #[[ $catalogAdvance == true || $fullAdvance == true ]]

unset changeLogRecs processedDailysh
declare -A processedSpecs
## Refresh proucts
	for processSpec in $(tr ',' ' ' <<< $processControl); do
		dump -2 -n processSpec
		product=$(cut -d '|' -f1 <<< $processSpec)
		prodVer=$(cut -d '|' -f2 <<< $processSpec)
		srcDir=$(cut -d '|' -f3 <<< $processSpec)
		dump -2 -n -n processSpec product prodVer srcDir tgtDir
		[[ $product == 'cim' ]] && allCims=true && GetCims $tgtDir
		Msg2 "\nProcessing: $(Upper "$product")..."
		## Check Versions
			if [[ $(Lower $prodVer) != 'master' && $force != true ]]; then
				srcVer=$(GetVersion "$product" "$srcDir/$prodVer"); srcVer="${srcVer%% *}"
				tgtVer=$(GetVersion "$product" "$tgtDir"); tgtVer="${tgtVer%% *}"
				#if [[ -n $srcVer && -n $tgtVer ]]; then
					if [[ $(CompareVersions "$srcVer" 'le' "$tgtVer") == true ]]; then
						 Warning 0 1 "Source clver ($srcVer) is less than or equal than the target clver ($tgtVer), skipping '$(Upper "$product")' refresh"
						 continue
					fi
				#fi
			fi
		changesMade=false
		## Run through the action records for the product
			productSpecArrayName="$product[@]"
			productSpecArray=("${!productSpecArrayName}")
			[[ ${#productSpecArray[@]} -le 0 ]] && Msg2 $WT1 "No patch file specs found for '$product', skipping" && continue
			for ((i=0; i<${#productSpecArray[@]}; i++)); do
				specLine="${productSpecArray[$i]}"
				mapKey="$(tr -d ' ' <<< "$specLine")"
				## Check to see if we have already processed this spec
				[[ ${processedSpecs["$mapKey"]+abc} ]] && continue
				processedSpecs["$mapKey"]=true
				specSource="$(cut -d'|' -f1 <<< "$specLine")"
				specPattern="$(cut -d'|' -f2 <<< "$specLine")"
				specTarget="$(cut -d'|' -f3 <<< "$specLine")"
				specIgnoreList="$(cut -d'|' -f4 <<< "$specLine")"
				## Perform string substitutions
					specPattern=$(sed "s/<release>/$prodVer/g" <<< $specPattern)
					specTarget=$(sed "s/<release>/$prodVer/g" <<< $specTarget)
					specPattern=$(sed "s/<progDir>/$courseleafProgDir/g" <<< $specPattern)
					specTarget=$(sed "s/<progDir>/$courseleafProgDir/g" <<< $specTarget)
					dump -2 -t specLine -t specSource specPattern specTarget specIgnoreList backupDir
				## Process record
					backupDir=$backupRootDir/${product}${specTarget}
					case "$(Lower "$specSource")" in
						git)
							Msg2 "\n^Processing '$specSource' record: '${specPattern%% *} --> ${specTarget}'"
							sourceSpec="${gitRepoShadow}/${specPattern%% *}${specPattern##* }"
							targetSpec="${tgtDir}${specTarget}"
							unset rsyncResults
							RunRsync "$product" "$sourceSpec" "$targetSpec" "$backupDir"
							if [[ $rsyncResults == 'false' ]]; then
								Msg2 "^^All files are current, no files updated"
							else
								Msg2 "^^Files updated, check log for additional information"
								[[ $verboseLevel -eq 0 ]] && Msg2 "^^Please check log for additional information"
								changeLogRecs+=("${specPattern%% *} refreshed from ${specPattern##* } ")
								changesMade=true
							fi
							;;
						formbuilder)
							Msg2 "\n^Processing '$specSource' record: '${specPattern%% *} --> ${specTarget}'"
							sourceSpec="${gitRepoShadow}/${specPattern%% *}${specPattern##* }"
							if [[ -n $cimStr ]]; then
								for cim in $(echo $cimStr | tr ',' ' '); do
									Msg2 "^^Refreshing $cim..."
									targetSpec=$(sed "s/<cimInstance>/$cim/" <<< $specTarget)
									unset rsyncResults
									RunRsync "$product" "$sourceSpec" "$targetSpec" "$backupDir"
									if [[ $rsyncResults == 'false' ]]; then
										Msg2 "^^All files are current, no files updated"
									else
										Msg2 "^^Files updated, check log for additional information"
										[[ $verboseLevel -eq 0 ]] && Msg2 "^^Please check log for additional information"
										changeLogRecs+=("${specPattern%% *} refreshed from ${specPattern##* }")
										changesMade=true
									fi
								done
							else
								Msg2 "^^No CIM instances found, skipping refresh"
							fi
									;;
						skeleton)
							Msg2 "\n^Processing '$specSource' record: '${specPattern} --> ${specTarget}'"
							sourceSpec="$skeletonRoot/release${specPattern%% *}"
							targetSpec="${tgtDir}${specTarget}"
							unset rsyncResults
							RunRsync "$product" "$sourceSpec" "$targetSpec" "$backupDir"
							if [[ $rsyncResults == 'false' ]]; then
								Msg2 "^^All files are current, no files updated"
							else
								Msg2 "^^Files updated, check log for additional information"
								[[ $verboseLevel -eq 0 ]] && Msg2 "^^Please check log for additional information"
								changeLogRecs+=("${specPattern%% *} refreshed from the skeleton")
								changesMade=true
							fi
							;;
						daily.sh)
							[[ $processedDailysh == true ]] && break
							Msg2 "\n^Processing '$specSource' record: '${specPattern} --> ${specTarget}'"
							grepFile="${tgtDir}${specPattern}"
							if [[ -r $grepFile ]]; then
								grepStr=$(ProtectedCall "grep '## Nightly cron job for client' $grepFile")
								if [[ $grepStr != '' ]]; then
									sourceSpec="$skeletonRoot/release${specPattern%% *}"
									targetSpec="${tgtDir}${specTarget}"
									unset rsyncResults
									RunRsync "$product" "$sourceSpec" "$targetSpec" "$backupDir"
									if [[ $rsyncResults == 'false' ]]; then
										Msg2 "^^All files are current, no files updated"
									else
										Msg2 "^^Files updated, check log for additional information"
										[[ $verboseLevel -eq 0 ]] && Msg2 "^^Please check log for additional information"
										changeLogRecs+=("${specPattern%% *} refreshed from the skeleton")
										changesMade=true
									fi
								else
									Msg2 "^^The daily.sh file is not the common daily.sh, skipping update"
								fi
							else
								Msg2 "^^No daily.sh file was found"
							fi
							processedDailysh=true
							;;
						cgi)
							Msg2 "\n^Processing '$specSource' record: '${specPattern} --> ${specTarget}'"
							result=$(CopyFileWithCheck "$cgisDir/$specPattern" "${tgtDir}${specTarget}" 'courseleaf')
							if [[ $result == true ]]; then
								$DOIT chmod 755 ${tgtDir}${specTarget}
								currentCgiVer=$(${tgtDir}${specTarget} -v | cut -d" " -f 3)
								Msg2 "^^Updated: '$specPattern' to version $currentCgiVer"
								changeLogRecs+=("courseleaf cgi updated (to $currentCgiVer)")
								changesMade=true
							elif [[ $result == same ]]; then
								Msg2 "^^'$specPattern' is current"
							else
								Error 0 2 "Could not copy courseleaf.cgi,\n^^$result"
							fi
							;;
						cgicommand)
							if [[ $(Lower "${specTarget}") == 'always' ]] || [[ $(Lower "${specTarget}") == 'onchangeonly' || -z ${specTarget}  && $changesMade == true ]]; then
								Msg2 "\n^Processing '$specSource' record: '${specPattern} ${specTarget}'"
								cwd="$(pwd)"
								cd "$tgtDir/web/$courseleafProgDir"
								indentLevelSave=$indentLevel
								indentLevel=2
								RunCourseLeafCgi "$tgtDir" "$specPattern"
								indentLevel=$indentLevelSave
								cd "$cwd"
							fi
							;;
						command)
							if [[ $(Lower "${specTarget}") == 'always' ]] || [[ $(Lower "${specTarget}") == 'onchangeonly' || -z ${specTarget}  && $changesMade == true ]]; then
								Msg2 "\n^Processing '$specSource' record: '${specPattern} ${specTarget}'"
								cwd="$(pwd)"
								cd "$tgtDir"
								indentLevelSave=$indentLevel
								indentLevel=2
								eval "$specPattern"
								[[ $? -eq 0 ]] && changeLogRecs+=("Executed unix command: '$specPattern'")
								indentLevel=$indentLevelSave
								cd "$cwd"
							fi
							;;
						include)
							## Insert the include process steps into the current productSpec Array
							includeArrayName="$(Lower "include${specPattern%% *}")"
							eval "includeArray=("\${$includeArrayName[@]}")"
							tmpArray=("${productSpecArray[@]:0:$i+1}")
							tmpArray+=(${includeArray[@]})
							tmpArray+=("${productSpecArray[@]:$i+1}")
							productSpecArray=("${tmpArray[@]}")
							;;
						*) Terminate "^Encountered and invalid processing type '$specSource'\n^$specLine"
							;;
					esac
			done #Process records

			case $product in
				cat)
					## Republish the site message
					echo
					Note 0 1 "The target site needs to be republished, please goto $client's 'CourseLeaf Console' and use the 'Republish Site' action to rebuild the site."
					;;
				cim)
					## Rebuild cims as necessary
					allCims=true
					GetCims $tgtDir
					if [[ -n $cimStr ]]; then
						Msg2 "\n^Republishing /<CIM>/index.tcf pages..."
						for cim in $(echo $cimStr | tr ',' ' '); do
							Msg2 "^^Republishing /$cim/index.tcf..."
							RunCourseLeafCgi "$tgtDir" "-r /$cim/index.tcf" | Indent | Indent
						done
					fi
					;;
			esac
	done ## processSpec (aka products)

#=======================================================================================================================
## Cross product checks / updates
#=======================================================================================================================
## Check /ribbit/getcourse.rjs file
	checkFile="$tgtDir/web/ribbit/getcourse.rjs"
	if [[ -f "$checkFile" ]]; then
		skelDate=$(date +%s -r $skeletonRoot/release/web/ribbit/getcourse.rjs)
		fileDate=$(date +%s -r $tgtDir/web/ribbit/getcourse.rjs)
		if [[ $skelDate -gt $fileDate ]]; then 
			echo
			text="The time date stamp of the file '$tgtDir/web/ribbit/getcourse.rjs' is less "
			text="$text than the time date stamp of the file in the skeleton, you should complare the files and merge"
			text="$text any required changes into '$tgtDir/web/ribbit/getcourse.rjs'."
			Warning 0 1 "$text"
			# echo
			# Msg2 "^^^\n* * * DIFF Output start * * *"
			# Msg2 "^^^${colorRed}< is $skeletonRoot/release/web/ribbit/getcourse.rjs${colorDefault}"
			# Msg2 "^^^${colorBlue}> is $tgtDir/web/ribbit/getcourse.rjs${colorDefault}"
			# indentLevelSave=$indentLevel
			# indentLevel=3
			# printf '=%.0s' {1..80} | Indent
			# colordiff "$tgtDir/web/ribbit/getcourse.rjs" "$skeletonRoot/release/web/ribbit/getcourse.rjs" | Indent
			# indentLevel=$indentLevelSave
			# echo
		fi
	fi

## Edit the console page, change title to 'CourseLeaf Console' (requested by Mike 02/09?)
	rebuildConsole=false
	editFile="$tgtDir/web/courseleaf/index.tcf"
	if [[ -w "$editFile" ]]; then
		fromStr='title:Catalog Console'
		toStr='title:CourseLeaf Console'
		grepStr=$(ProtectedCall "grep '^$fromStr' $editFile")
		if [[ $grepStr != '' ]]; then
			sed -i s'/^fromStr/$toStr/' $editFile
			updateFile="/courseleaf/index.tcf"
			changeLogRecs+=("$updateFile updated to change title")
			Msg2; Msg2 "^Updated '$updateFile' to change 'title:Catalog Console' to 'title:CourseLeaf Console'"
			rebuildConsole=true
		fi
	else
		echo
		Warning 0 1 "Could not locate '$editFile', please check the target site"
	fi

## Rebuild console & approve pages
	if [[ $rebuildConsole == true ]]; then
		Msg2 "\n^Republishing CourseLeaf console & approve pages..."
		RunCourseLeafCgi "$tgtDir" "-r /courseleaf/index.html" | Indent
		RunCourseLeafCgi "$tgtDir" "-r /courseleaf/approve/index.html" | Indent
	fi

## Check to see if there are any 'special' cgis installed, see if they are still necessary
	tgtVer="$($tgtDir/web/$courseleafProgDir/$courseleafProgDir.cgi -v 2> /dev/null | cut -d" " -f3)"
	for checkDir in tcfdb; do
		if [[ -f $tgtDir/web/courseleaf/$checkDir/courseleaf.cgi ]]; then
			checkCgiVer="$($tgtDir/web/$courseleafProgDir/$checkDir/$courseleafProgDir.cgi -v 2> /dev/null | cut -d" " -f3)"
			if [[ $(CompareVersions "$checkCgiVer" 'le' "$tgtVer") == true ]]; then
				Msg2 "\n^Found a 'special' courseleaf cgi directory ($checkDir) and the version of that cgi ($checkCgiVer) is less than the target version ($tgtVer).  Remove directory"
				[[ ! -d $backupDir/web/$courseleafProgDir/$checkDir ]] && mkdir -p $backupDir/web/$courseleafProgDir/$checkDir
				mv -f $tgtDir/web/$courseleafProgDir/$checkDir $backupDir/web/$courseleafProgDir
				changeLogRecs+=("Removed '$tgtDir/web/$courseleafProgDir/$checkDir'")
			fi
		fi
	done

## If we took the site offline, then put it back online
	if [[ $offline == true ]]; then
		## uncomment the user records, remove the siteadmin: record from the bottoms
		Msg2 "Bringing the site back online"
		editFile="$tgtDir/courseleaf.cfg" 
		sed -e '/user:/ s|^//||' -i "$editFile"
		line=$(tail -1 "$editFile")
		[[ $line == 'sitereadonly:true' ]] && sed -i '$ d' "$editFile"
		offline=false
	fi

## log updates in changelog.txt
	WriteChangelogEntry 'changeLogRecs' "$tgtDir/changelog.txt"

## tar up the backup files
	tarFile="$myName-$(date +%D | tr '/' '-').tar.gz"
	cd $backupRootDir
	PushSettings
	set +f
	$DOIT tar -czf $tarFile * --exclude '*.gz' --remove-files
	PopSettings
	[[ -f ../$tarFile ]] && rm -f ../$tarFile
	$DOIT mv $tarFile ..
	cd ..
	$DOIT rm -rf $backupRootDir

## Tell the user what to do if there are problems
	echo
	Note "Should you need to restore the site to its previous state you will find a tar file in the attic called '$tarFile', copy the directories and files from the tar file to their corresponding location under the web directory for the site ($tgtDir/web)"

	[[ $backup == true ]] && echo && Note "A backup copy was made of the $(Upper $env) site, once you have verified that the patch results are satisfactory you should delete the backup site '$backupSite'"

## Done
#=======================================================================================================================
#if [[ -f $myTempFile ]]; then rm $myTempFile; fi
[[ $noCheck == true ]] && Goodbye 0 "Applied refresh '$refreshVersion' to '$tgtDir'" || Goodbye 0 "Applied refresh '$refreshVersion' to $Upper($client/$env)"

#=======================================================================================================================
## Check-in Log
#=======================================================================================================================
## Fri Mar 25 10:42:15 CDT 2016 - dscudiero - If CIM then also refresh workflow.atj if necessary
## Fri Apr  1 09:16:20 CDT 2016 - dscudiero - Make sure we cleanup the rsyncfilters file
## Mon Apr 11 08:18:33 CDT 2016 - dscudiero - Do not copy files if they are the same
## Tue Apr 12 15:13:40 CDT 2016 - dscudiero - Use SelectMenuNew, added rebuild of CIMs index.tcf pages if cim product selected
## Wed Apr 13 16:30:20 CDT 2016 - dscudiero - Update because of name change for courseleafFeature
## Tue Apr 26 16:27:55 CDT 2016 - dscudiero - Fixed problem with the menus not showing master
## Thu Apr 28 10:18:09 CDT 2016 - dscudiero - Fix spelling
## Fri Apr 29 08:41:52 CDT 2016 - dscudiero - Tweak some messages
## Fri May 13 07:55:27 CDT 2016 - dscudiero - Added the ability to allow the user to specify a product value that is not on the clients product list
## Fri May 13 13:38:05 CDT 2016 - dscudiero - Set the permissions of any .cgi files to 755
## Tue May 17 14:14:40 CDT 2016 - dscudiero - Set the parent directory of any .cgi file to 755
## Mon Jun  6 07:30:37 CDT 2016 - dscudiero - Fix wording of messages
## Thu Jun 16 15:37:48 CDT 2016 - dscudiero - Fix problem with getting the release date of the source
## Tue Jun 21 12:49:50 CDT 2016 - dscudiero - Updated messaging, cgi directory selection, and moved to msg2
## Fri Jun 24 07:34:06 EDT 2016 - dscudiero - Added ignore lists to the release selection
## Tue Jul  5 07:23:16 CDT 2016 - dscudiero - Add error message if there are no releases to install.
## Tue Jul  5 07:23:53 CDT 2016 - dscudiero - Add error message if there are no releases to install.
## Tue Jul  5 07:26:24 CDT 2016 - dscudiero - Tweak messaging
## Tue Jul  5 07:26:39 CDT 2016 - dscudiero - Tweak messaging
## Fri Jul  8 13:21:58 CDT 2016 - dscudiero - Updated help text
## Mon Jul 11 14:12:40 CDT 2016 - dscudiero - Add refreshing daily.sh
## Tue Jul 12 09:27:03 CDT 2016 - dscudiero - Fix problem witn mkdir statement being commented out for daily.sh
## Fri Jul 15 13:12:07 CDT 2016 - dscudiero - General syncing of dev to prod
## Mon Jul 18 16:36:06 CDT 2016 - dscudiero - Added -noCheck to allow full specificaiton of the target directory
## Wed Aug  3 12:21:10 CDT 2016 - dscudiero - Do not allow client=internal
## Thu Aug  4 11:01:19 CDT 2016 - dscudiero - Added displayGoodbyeSummaryMessages=true
## Tue Aug 23 11:22:03 CDT 2016 - dscudiero - Updated to correctly parse output of selectMenuNew
## Tue Aug 23 12:54:48 CDT 2016 - dscudiero - Use the authgroup to determin if user should be able to see new repos
## Fri Sep  9 10:04:15 CDT 2016 - dscudiero - Fix bug shown -new releases to not QA folks
## Mon Sep 19 16:02:49 CDT 2016 - dscudiero - Added updates to courseleaf.cfg to add anyreadonly if not set
## Fri Sep 23 07:53:02 CDT 2016 - dscudiero - General syncing of dev to prod
## Fri Sep 23 12:43:51 CDT 2016 - dscudiero - Update to handle clver of the form version beta
## Tue Sep 27 16:50:33 CDT 2016 - dscudiero - Changed republish site verbiage as per Ben, use Republish Site
## Wed Sep 28 08:03:18 CDT 2016 - dscudiero - tweak messaging
## Fri Oct 14 13:41:07 CDT 2016 - dscudiero - General syncing of dev to prod
## Fri Oct 14 13:47:27 CDT 2016 - dscudiero - General syncing of dev to prod
## Wed Jan 11 10:42:18 CST 2017 - dscudiero - Do not check the daily.sh file if it is not present
## Thu Jan 12 10:25:02 CST 2017 - dscudiero - Add logic to get siteDir if nocheck flag is on, Resolve cgiVersion fully
## Wed Jan 18 15:00:15 CST 2017 - dscudiero - General syncing of dev to prod
## Fri Jan 20 09:52:15 CST 2017 - dscudiero - remove debug statement
## 04-17-2017 @ 10.31.31 - (5.0.124)   - dscudiero - fixed for selectMenuNew changes
## 04-27-2017 @ 11.10.21 - (5.0.125)   - dscudiero - Fixed error reporting rsync errors
