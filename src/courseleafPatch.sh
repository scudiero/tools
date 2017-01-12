#!/bin/bash
#XO NOT AUTOVERSION
#==================================================================================================
version=4.10.101 # -- dscudiero -- 01/12/2017 @ 10:23:15.51
#==================================================================================================
TrapSigs 'on'
includes='GetDefaultsData ParseArgs ParseArgsStd Hello Init Goodbye RunCoureleafCgi WriteChangelogEntry GetCims GetSiteDirNoCheck'
includes="$includes SelectMenuNew EditTcfValue BackupCourseleafFile ParseCourseleafFile GetCourseleafPgm CopyFileWithCheck"
Import "$includes"
originalArgStr="$*"
scriptDescription="Refresh a courseleaf product"

#==================================================================================================
# Refresh a Courseleaf component from the git repo
#==================================================================================================
#==================================================================================================
## Copyright ©2015 David Scudiero -- all rights reserved.
## 07-09-15 -- 	dgs - Initial coding
## 07-28-15 -- 	dgs - Use my own select function
#==================================================================================================
#==================================================================================================
# Standard call back functions
#==================================================================================================
	function parseArgs-courseleafPatch {
		# argList+=(argFlag,minLen,type,scriptVariable,exCmd,helpSet,helpText)  #type in {switch,switch#,option,help
		argList+=(-listOnly,1,switch,listOnly,,script,"Do not do copy, only list out files that would be copied")
		argList+=(-refreshVersion,2,option,refreshVersion,,script,"The refresh version to apply")
	}
	function Goodbye-courseleafPatch  {
		[[ -f /tmp/$userName.$myName.rsyncErr.out ]] && rm -f /tmp/$userName.$myName.rsyncErr.out
		[[ -f $rsyncFilters ]] &&  rm -rf $rsyncFilters
	}
	function testMode-courseleafPatch {
		[[ $userName != 'dscudiero' ]] && Terminate "You do not have sufficient permissions to run this script in 'testMode'"
		client='none'
		env='dev'
		tgtDir="$HOME/testData/$env"
		products='cat,cim'
		catRefreshVersion='3.5.8'
		cimRefreshVersion='3.5.2'
		verify=false
		noCheck=true
	}

#==================================================================================================
# local functions
#==================================================================================================
function CheckVersion {
	local product=$1
	local srcDir=$2
	local tgtDir=$3
	local clverFile defaultTcfFile clver srcClverNum tgtClverNum verFile

	verFile='clver.txt'
	Msg2 $V2 "\n** Starting $FUNCNAME **"
	dump -2 srcDir tgtDir product productDir verFile

	## Get the source cl version
		verFile="$srcDir/clver.txt"
		defaultTcfFile=$srcDir/default.tcf
		dump -2 -t verFile defaultTcfFile
		if [[ -r $verFile ]]; then
			clver=$(cut -d":" -f2 <<< $(cat $verFile));
		elif [[ -f $defaultTcfFile ]]; then
			clver=$(ProtectedCall "grep '^clver:' $defaultTcfFile");
			clver=$(cut -d":" -f2 <<< $clver);
		fi
		dump -2 clver
		[[ $clver != '' ]] && clver=$(cut -d' ' -f1 <<< $clver) || Note 0 1 "Could not resolve source version for '$product', allowing refresh"
		srcClverNum=$(tr -d '.' <<< $clver); srcClverNum=${srcClverNum}000000; srcClverNum=${srcClverNum:0:6}

	## Get the target cl version
		verFile="$tgtDir/clver.txt"
		defaultTcfFile=$srcDir/default.tcf
		dump -2 -t verFile defaultTcfFile
		if [[ -r $verFile ]]; then
			clver=$(cut -d":" -f2 <<< $(cat $verFile));
		elif [[ -f $defaultTcfFile ]]; then
			clver=$(ProtectedCall "grep '^clver:' $defaultTcfFile");
			clver=$(cut -d":" -f2 <<< $clver);
		fi
		dump -2 clver
		[[ $clver != '' ]] && clver=$(cut -d' ' -f1 <<< $clver) || Note 0 1 "Could not resolve target version for '$product', allowing refresh"
		tgtClverNum=$(tr -d '.' <<< $clver); tgtClverNum=${tgtClverNum}000000; tgtClverNum=${tgtClverNum:0:6}


	## Compare versions as numbers of we have a target version
	if [[ $srcClverNum -ne 0 && $tgtClverNum -ne 0 ]]; then
		dump -2 srcClver srcClverNum tgtClver tgtClverNum
		if [[ $tgtClverNum -ge $srcClverNum ]]; then
			[[ $force == false ]] && Terminate "Source clver ($srcClver) is less than or equal than the target clver ($tgtClver)" || \
			 						 Note 0 1 "Source clver ($srcClver) is less than or equal than the target clver ($tgtClver) and force option is active, allowing refresh"
		fi
	fi

	return 0
} #SelectMenuNew


#==================================================================================================
# Declare local variables and constants
#==================================================================================================
myTempFile=/tmp/$userName.$myName.out
[[ -f $myTempFile ]] && rm $myTempFile

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
helpSet='script,client,env'
helpNotes+=('For refreshVersion = "master" the source files are refreshed from the git repo at midnight and noon so the data may be as much as 12 hours old.' )
scriptHelpDesc="This script can be used to refresh the couseleaf directories will be refreshed from either the master version or a named courseleaf release.\
\nThe following actions will be performed: \n\
\n^ 1) The /courseleaf, /navmaster, and /pdf directories will be refreshed from the .git repository, \
/courseleaf/local* files/directory will not be touched.\
\n^ 2) The 'courseleaf.cgi' and 'ribbit.cgi' will be refrehsed from the current version.
\n\nEdited/changed files will be backed up to the /attic and actions will be logged in the /changelog.txt file."

GetDefaultsData $myName
ParseArgsStd

refreshVersion=$(Lower $refreshVersion)
displayGoodbyeSummaryMessages=true
Hello
[[ $listOnly == true ]] && Warning 0 1 "the 'listOnly' flag is turned on, files will not be copied"
allowExtraProducts=true

if [[ $noCheck == true ]]; then
	Init 'getClient'
	GetSiteDirNoCheck $client $env
	[[ -n $siteDir ]] && tgtDir="$siteDir" || Terminate "Could not resolve target site directory"
else
	Init 'getClient getProducts getEnv getDirs checkDirs noPreview noPublic'
fi

[[ $client == 'internal' ]] && Terminate "Sorry, the internal site is not supported at this time"

[[ $tgtDir == '' ]] && tgtDir="$srcDir"

## Process products to get rid of the product modifiers (e.g. cati, cimc, etc.)
	tempData="$(Lower $products)"
	unset products
	[[ $(Contains "$tempData" 'cat') == true ]] && products="$products,cat"
	[[ $(Contains "$tempData" 'cim') == true ]] && products="$products,cim"
	[[ $(Contains "$tempData" 'clss') == true ]] && products="$products,clss"
	products=${products:1}

dump -1 client srcDir tgtDir env product products
[[ $secondaryMessagesOnly != true ]] && Msg2
ignoreCatReleases="$(cut -d':' -f2 <<< $scriptData1)"
ignoreCimReleases="$(cut -d':' -f2 <<< $scriptData2)"
dump -1 ignoreCatReleases ignoreCimReleases

#==================================================================================================
## Main
#==================================================================================================
## Get QA group members
	unset qaGroupMembers
	sqlStmt="select members from $authGroupsTable where code=\"qa\""
	RunSql2 $sqlStmt
	qaGroupMembers="${resultSet[0]}"

## Get refreshVersion(s)
	if [[ $refreshVersion != '' ]]; then
		[[ $products == '' ]] && Terminate "You cannot specify a refreshVersion without specifying a product"
		[[ $(Contains "$products" ',') == true ]] && Terminate "You cannot specify multiple products if you specify refreshVersion"
		[[ $products == 'cat' ]] && catRefreshVersion=$refreshVersion && cimRefreshVersion='n/a'
		[[ $products == 'cim' ]] && cimRefreshVersion=$refreshVersion && catRefreshVersion='n/a'
	else
		if [[ $testMode != true ]]; then
			for product in $(echo $products | tr ',' ' '); do
				[[ $product == 'cat' ]] && srcDir=$gitRepoShadow/courseleaf || srcDir=$gitRepoShadow/$product
				unset ignoreList
				eval ignoreList="\$ignore$(TitleCase $product)Releases"
				dump -1 product srcDir ignoreList

				[[ ! -d $srcDir ]] && Msg2 && Terminate "Could not locate source repo\n\t$srcDir"
				[[ $verify != true ]] && Msg2 && Terminate "No value specified for refresh version and verify is off"
				unset menuList fileList
				menuList+=("|Release|Extraction date")
				if [[ $(Contains "$qaGroupMembers" ",$userName,") == true ]]; then
					fileList="$(ls -t $srcDir | grep -v .bad | grep -v master | tr "\n" " ")"
				else
					fileList="$(ls -t $srcDir | grep -v .bad | grep -v master | grep -v '-new' | tr "\n" " ")"
				fi
				cntr=0
				for item in $fileList; do
					[[ $(Contains ",$ignoreList," ",$item,") == true ]] && continue
					#[[ $(Contains "$(Lower "$item")" '-new') == true && $(Contains "$qaGroupMembers" ",$userName,") == false ]] && continue
					if [[ -f $srcDir/$item/.syncDate ]]; then
						releaseDate=$(stat -c %y $srcDir/$item/.syncDate | cut -d'.' -f1 | awk 'BEGIN {FS=" "}{printf "%s at %s", $1,$2}')
						menuList+=("|$item|$releaseDate")
					fi
					(( cntr+=1 ))
					[[ $cntr -ge 5 ]] && break
				done
				if [[ -f $srcDir/master/.syncDate ]]; then
					releaseDate=$(stat -c %y $srcDir/master/.syncDate | cut -d'.' -f1 | awk 'BEGIN {FS=" "}{printf "%s at %s", $1,$2}')
					menuList+=("|master|$releaseDate")
				fi
				[[ ${#menuList[@]} -eq 1  ]] && Msg2 && Terminate "At the current time there are no avaiable releases for refresh, please try again later."
				if [[ ${#menuList[@]} -gt 2 ]]; then
					Msg2
					Msg2 "Please specify the ordinal number of the release of $(ColorK $(Upper $product)) you wish to install:"
					Note "The 'master' (sometimes refered to x.x.x beta) contains the latest commited modules and does not necessarily represent a 'consistent' release.  If 'master' does not appear in the list that means it is currently being updated from the git repository.\n"
					SelectMenuNew 'menuList' 'refreshVersion' '\nVersion ordinal (or 'x' to quit) > '
					[[ $refreshVersion == '' ]] && Goodbye 'quickquit' || refreshVersion=$(cut -d'|' -f1 <<< $refreshVersion)
				else
					refreshVersion="$(cut -d'|' -f2 <<< ${menuList[1]})"
					Note 0 1 "Only one refresh version is avaiable for '$(Upper $product)' at this time, using '$refreshVersion'"
				fi
				refreshVersion="$(echo $refreshVersion | cut -d' ' -f1)"
				eval ${product}RefreshVersion=$refreshVersion
			done
			dump -1 catRefreshVersion cimRefreshVersion
		fi
	fi

## Set cgis dir

	cgisDirRoot=$cgisRoot/rhel${myRhel:0:1}
	[[ ! -d $cgisDirRoot ]] && Terminate "Could not locate cgi source directory:\n\t$cgiRoot"
	cwd=$(pwd)
	cd $cgisDirRoot
	cgisDir=$(ls -t | tr "\n" ' ' | cut -d ' ' -f1)
	cgisDir=${cgisDirRoot}/$cgisDir
	[[ ! -d $cgisDir ]] && Terminate "Could not find skeleton directory: $cgisDir"
	cd $cwd
	[[ -r "$cgisDir/courseleaf.log" ]] && cgiVer="$(cat "$cgisDir/courseleaf.log" | cut -d'|' -f5)" || cgiVer="$(basename $cgisDir).xx"
	dump -1 cgisDir cgiVer

#==================================================================================================
# Verify continue
#==================================================================================================
unset verifyArgs
[[ $noCheck == true ]] && verifyArgs+=("Target Path:$tgtDir") || verifyArgs+=("Client:$client")
verifyArgs+=("Products:$products")
unset prodVersions
if [[ $(Contains "$products" 'cat') == true ]]; then
	verifyArgs+=("CAT version:$catRefreshVersion") && prodVersions="$prodVersions, CAT version:$catRefreshVersion"
	verifyArgs+=("NAVMASTER version:master") && prodVersions="$prodVersions, NAVMASTER version:master"
	verifyArgs+=("PDFGEN version:master") && prodVersions="$prodVersions, PDFGEN version:master"
fi
[[ $cimRefreshVersion != '' ]] && verifyArgs+=("CIM version:$cimRefreshVersion") && prodVersions="$prodVersions, CIM version:$catRefreshVersion"
[[ $clssRefreshVersion != '' ]] && verifyArgs+=("CLSS version:$clssRefreshVersion") prodVersions="$prodVersions, CLSS version:$clssRefreshVersion"
[[ $noCheck != true ]] && verifyArgs+=("Target Env:$(TitleCase $env) ($tgtDir)")
verifyArgs+=("CGIs Version:$cgiVer (from: '$cgisDir')")
VerifyContinue "You are asking to refresh courseleaf code files:"

myData="Client: '$client', Products: '$products', tgtEnv: '$env' $prodVersions"
[[ $noCheck == true ]] && myData="Target Path, $tgtDir, Products: '$products' $prodVersions"
[[ $logInDb != false && $myLogRecordIdx != "" && $testMode != true ]] && dbLog 'data' $myLogRecordIdx "$myData"
dump -1 -p client products catRefreshVersion cimRefreshVersion clssRefreshVersion srcDir tgtDir cgisDir

## Backup root
	backupRootDir=$tgtDir/attic/$myName.$$

unset changeLogRecs

## Install release
	#[[ $products = 'cat' ]] && products="$products,"
	[[ $(Contains "$products" 'cat' == true) ]] && products=$(sed "s/cat,/cat,navmaster,pdfgen,/" <<< $products)
	dump -1 products
	for product in $(echo $products | tr ',' ' '); do
		eval refreshVersion=\$${product}RefreshVersion
		[[ $refreshVersion == '' ]] && refreshVersion='master'
		## Set repos dir
			srcDir=$gitRepoShadow/$product/$refreshVersion
			[[ $product == 'cat' ]] && srcDir=$gitRepoShadow/courseleaf/$refreshVersion
			[[ ! -d $srcDir ]] && Terminate "Could not locate source directory:\n\t$srcDir"
			[[ ! -f $srcDir/.syncDate ]] && Msg2 $T "$srcDir \n^Is in the process of being updated, please try again later"
			releaseDate=$(stat -c %y $srcDir/.syncDate | cut -d'.' -f1 | awk 'BEGIN {FS=" "}{printf "%s at %s", $1,$2}')

			if [[ $product == 'cat' ]]; then srcDir=$srcDir/courseleaf
			elif [[ $product == 'pdfgen' ]]; then srcDir=$srcDir/pdf
			else srcDir=$srcDir/$product
			fi

			if [[ $product == 'cat' ]]; then
				productDir='courseleaf'
			elif [[ $product == 'cim' || $product == 'navmaster' ]]; then
				productDir="courseleaf/$product"
			elif [[ $product == 'clss' ]]; then
				productDir='wen'
			elif [[ $product == 'pdfgen' ]]; then
				productDir='courseleaf/pdf'
			else
				productDir="$product"
			fi
			dump -1 srcDir productDir refreshVersion

		## Set backup directory
			backupDir=$backupRootDir/${product}-pre-$refreshVersion/web/$productDir
			[[ ! -d $backupDir ]] && $DOIT mkdir -p $backupDir
			dump -1 -n backupRootDir backupDir

		Msg2; Msg2 "$(ColorK "Refreshing product: $(Upper $product) from git tag: '$refreshVersion' (Date: $releaseDate)...")"
		Msg2 "^Source: $srcDir/"
		Msg2 "^Target: $tgtDir/web/${productDir}/"
		Msg2 "^Backup: $backupDir/"
		[[ $(Lower $refreshVersion) != 'master' ]] && CheckVersion "$product" "$srcDir" "$tgtDir"

		## Copy files using rsync
			[[ $quiet == true || $quiet == 1 ]] && rsyncVerbose='' || rsyncVerbose='v'
			[[ $listOnly == true ]] && rsyncListonly="--dry-run" || unset rsyncListonly
			## Setup copy
				rsyncFilters=/tmp/$userName.rsyncFilters.txt
				printf "%s\n" '- *.git*' > $rsyncFilters
				printf "%s\n" '+ *.*' >> $rsyncFilters
				rsyncOpts="-rptb$rsyncVerbose --backup-dir $backupDir --prune-empty-dirs $rsyncListonly --include-from $rsyncFilters"
			## Do Copy
				Msg2 "^Syncing directories..."
				tmpErr=/tmp/$userName.$myName.rsyncErr.out
				$DOIT rsync $rsyncOpts $srcDir $(dirname $tgtDir/web/${productDir}) 2>$tmpErr | xargs -I{} printf "\\t%s\\n" "{}"
				[[ $(cat $tmpErr | wc -l) -gt 0 ]] && Terminate "rsync process failed, please review messages:\n$(cat $tmpErr)\n"
			## Make sure permissions on the directory are correct
				$DOIT chmod 755 $tgtDir/web/${productDir}
			Msg2 "^** $(Upper $product) refresh completed **"

		verFile="${product}ver.txt"
		## Special processing for products
			if [[ $product == 'cat' ]]; then
				verFile='clver.txt'
				## Make sure we have a clver.txt file
				[[ -f $srcDir/$verFile ]] && cp -fp $srcDir/$verFile $(dirname $tgtDir/web/${productDir}/$verFile) || Warning 0 1 "No '$verFile' found in source, skipping update."
				## Make sure there is a 'anyreadonly' variable defined in courseleaf.cfg
				tcfVar="anyreadonly"
				tcfVarVal="Read only. You are not currently listed as an owner of this page."
				tcfFile="$tgtDir/courseleaf.cfg"
				editMsg=$(EditTcfValue "$tcfVar" "$tcfVarVal" "$tcfFile")
				if [[ $editMsg == true ]]; then
					changeLogRecs+=("Added '$tcfVar' variable to $(basename $tcfFile)")
				else
					Error "Adding/checking '$tcfFile'\nfor variable: '$tcfVar'\n^$editMsg"
				fi
			elif [[ $product == 'cim' ]]; then
				## If CIM, then also copy /courseleaf/stdhtml/workflow.atj
				updateFile="/courseleaf/stdhtml/workflow.atj"
				Msg2; Msg2 "$(ColorK "Checking '$updateFile")"
				srcFile="$skeletonRoot/release/web/$updateFile"
				[[ $catRefreshVersion != '' ]] && srcFile="$gitRepoShadow/courseleaf/${catRefreshVersion}${updateFile}"
				srcMd5=$(md5sum $srcFile | cut -f1 -d" ")
				tgtFile="$tgtDir/web/courseleaf/stdhtml/workflow.atj"
				tgtMd5=$(md5sum $tgtFile | cut -f1 -d" ")
				#dump catRefreshVersion cimRefreshVersion srcFile srcMd5 tgtFile tgtMd5
				if [[ $srcMd5 != $tgtMd5 ]]; then
					if [[ -f "$tgtFile" ]]; then
						[[ ! -d $backupRootDir/web/$(dirname $updateFile) ]] && mkdir -p "$backupRootDir/web/$(dirname $updateFile)"
						cp -fp "$tgtFile" "$backupRootDir/web/$updateFile"
					fi
					cp -fp $srcFile $tgtFile
					Msg2 "^Upated '$updateFile'"
				else
						Msg2 "^File is current"
				fi
			fi
		## Add a log record
			eval refreshVersion=\$${product}RefreshVersion
			[[ $refreshVersion == '' ]] && refreshVersion='master'
			changeLogRecs+=("Updated product: '$product' (to $refreshVersion)")
 ## products loop
	done

## Copy the cgi files
	Msg2; Msg2 "$(ColorK "Checking cgis...")"
	## /courseleaf/courseleaf.cgi
		unset courseleafCgiVer
		if [[ -f $cgisDir/courseleaf.cgi ]]; then
			if [[ -f "$tgtDir/web/courseleaf/courseleaf.cgi" ]]; then
				[[ ! -d $backupRootDir/web/courseleaf ]] && mkdir -p "$backupRootDir/web/courseleaf"
				$DOIT cp -fp "$tgtDir/web/courseleaf/courseleaf.cgi" "$backupRootDir/web/courseleaf/courseleaf.cgi"
			fi
			result=$(CopyFileWithCheck "$cgisDir/courseleaf.cgi" "$tgtDir/web/courseleaf/courseleaf.cgi" 'courseleaf')
			if [[ $result == true ]]; then
				$DOIT chmod 755 $tgtDir/web/courseleaf/courseleaf.cgi
				courseleafCgiVer=$($tgtDir/web/courseleaf/courseleaf.cgi -v | cut -d" " -f 3)
				Msg2 "^Updated: 'courseleaf.cgi' ($courseleafCgiVer)"
				changeLogRecs+=("courseleaf cgi updated (to $courseleafCgiVer)")
			elif [[ $result == same ]]; then
				Msg2 "^'courseleaf.cgi' is current"
			else
				Error 0 1 "Could not copy courseleaf.cgi,\n^$result"
			fi
		else
			Error 0 1 "Could not locate source courseleaf.cgi,\n^$cgisDir/courseleaf.cgi\ncourseleaf cgi not refreshed."
		fi

	## /ribbit/index.cgi
		unset ribbitCgiVer
		if [[ -f $cgisDir/index.cgi ]]; then
			if [[ -f "$tgtDir/web/ribbit/index.cgi" ]]; then
				[[ ! -d $backupRootDir/web/ribbit ]] && mkdir -p "$backupRootDir/web/ribbit"
				$DOIT cp -fp "$tgtDir/web/ribbit/index.cgi" "$backupRootDir/web/ribbit/index.cgi"
			fi
			result=$(CopyFileWithCheck "$cgisDir/index.cgi" "$tgtDir/web/ribbit/index.cgi" 'courseleaf')
			if [[ $result == true ]]; then
				$DOIT chmod 755 $tgtDir/web/ribbit/index.cgi
				ribbitCgiVer=$($tgtDir/web/ribbit/index.cgi -v | cut -d" " -f 3)
				Msg2 "^Updated: index.cgi ($ribbitCgiVer)"
				changeLogRecs+=("ribbit cgi updated (to $ribbitCgiVer)")
			elif [[ $result == same ]]; then
				Msg2 "^'index.cgi' is current"
			else
				Error 0 1 "Could not copy index.cgi.\n^$result"
			fi
		elif [[ -f $cgisDir/ribbit.cgi ]]; then
			if [[ -f "$tgtDir/web/ribbit/ribbit.cgi" ]]; then
				[[ ! -d $backupRootDir/web/ribbit ]] && mkdir -p "$backupRootDir/web/ribbit"
				$DOIT cp -fp "$tgtDir/web/ribbit/ribbit.cgi" "$backupRootDir/web/ribbit/index.cgi"
			fi
			result=$(CopyFileWithCheck "$cgisDir/ribbit.cgi" "$tgtDir/web/ribbit/ribbit.cgi" 'courseleaf')
			if [[ $result == true ]]; then
				$DOIT chmod 755 $tgtDir/web/ribbit/ribbit.cgi
				ribbitCgiVer=$($tgtDir/web/ribbit/ribbit.cgi -v | cut -d" " -f 3)
				Msg2 "^Updated: ribbit.cgi ($ribbitCgiVer)"
				changeLogRecs+=("ribbit cgi updated (to $ribbitCgiVer)")
			elif [[ $result == same ]]; then
				Msg2 "^'ribbit.cgi' is current"
			else
				Error 0 1 "Could not copy ribbit.cgi,\n^$result"
			fi
		else
			Error 0 1 "Could not locate source ribbit.cgi or index.cgi,\n^$cgisDir/ribbit.cgi^ribbit cgi not refreshed."
		fi

## Make sure that all.cgi files are executable
	cgiFiles=($(find $tgtDir/web/courseleaf -name \*.cgi) $(find $tgtDir/web/ribbit -name \*.cgi))
	for file in "${cgiFiles[@]}"; do
		$DOIT chmod 755 $file
		$DOIT chmod 755 $(dirname $file)
	done

## Copy /bin/daily.sh if this client is using the new common version
	unset grepStr
	grepFile="$tgtDir/bin/daily.sh"
	if [[ -r $grepFile ]]; then
		grepStr=$(ProtectedCall "grep '## Nightly cron job for client' $grepFile")
		if [[ $grepStr != '' ]]; then
			updateFile="/bin/daily.sh"
			Msg2; Msg2 "$(ColorK "Checking '$updateFile")"
			srcFile="$skeletonRoot/release${updateFile}"
			srcMd5=$(md5sum $srcFile | cut -f1 -d" ")
			tgtFile="$tgtDir$updateFile"
			tgtMd5=$(md5sum $tgtFile | cut -f1 -d" ")
			if [[ $srcMd5 != $tgtMd5 ]]; then
				if [[ -f "$tgtFile" ]]; then
					[[ ! -d ${backupRootDir}$(dirname $updateFile) ]] && $DOIT mkdir -p "${backupRootDir}$(dirname $updateFile)"
					$DOIT cp -fp "$tgtFile" "${backupRootDir}${updateFile}"
				fi
				$DOIT cp -fp $srcFile $tgtFile
				Msg2 "^Upated '$updateFile'"
				changeLogRecs+=("daily.sh updated")
			else
				Msg2 "^'$updateFile' is current"
			fi
		fi
	fi

## Check /ribbit/getcourse.rjs file
	skelDate=$(date +%s -r $skeletonRoot/release/web/ribbit/getcourse.rjs)
	fileDate=$(date +%s -r $tgtDir/web/ribbit/getcourse.rjs)
	[[ $skelDate -gt $fileDate ]] && Warning 0 1 "The time date stamp of the file '$tgtDir/web/ribbit/getcourse.rjs' is less \
	than the time date stamp of the same file in the skeleton, any required changes should be manualy merged into the target env."

## Rebuild cims as necessary
	allCims=true
	GetCims $tgtDir
	if [[ $(Contains "$products" 'cim') == true && $cimStr != '' ]]; then
		Msg2; Msg2 "$(ColorK "Republishing /<CIM>/index.tcf pages...")"
		for cim in $(echo $cimStr | tr ',' ' '); do
			Msg2 "^Republishing /$cim/index.tcf..."
			RunCoureleafCgi "$tgtDir" "-r /$cim/index.tcf"
		done
		Msg2 "^Done"
	fi

## Rebuild console
	if [[ $(Contains "$products" 'cat') == true ]]; then
		Msg2; Msg2 "$(ColorK "Republishing CourseLeaf console & approve pages...")"
		RunCoureleafCgi "$tgtDir" "-r /courseleaf/index.html"
		RunCoureleafCgi "$tgtDir" "-r /courseleaf/approve/index.html"
		Msg2 "^Done"
	fi

## Republish the site
	if [[ $(Contains "$products" 'cat') == true && $secondaryMessagesOnly != true ]]; then
		Msg2; Msg2 "$(ColorK "The target site needs to be republished.")"
		Msg2
		Msg2 "^Please goto $client's CourseLeaf Console and use the 'Republish Site' tool/action"
		Msg2 "^to rebuild the site."
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
	Msg2
	Note "Should you need to restore the site to its pre $refreshVersion state you will find a"
	Note "tar file in the attic called '$tarFile', copy the"
	Note "directories and files from the tar file to their corresponding location"
	Note "under the web directory for the site ($tgtDir/web)"

## Done
##=================================================================================================
if [[ -f $myTempFile ]]; then rm $myTempFile; fi
[[ $noCheck == true ]] && Goodbye 0 "Applied refresh '$refreshVersion' to '$tgtDir'" || Goodbye 0 "Applied refresh '$refreshVersion' to $Upper($client/$env)"

##=================================================================================================
## Check-in Log
##=================================================================================================
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
