#!/bin/bash
#==================================================================================================
version=1.0.97 # -- dscudiero -- 12/14/2016 @ 11:24:38.26
#==================================================================================================
TrapSigs 'on'
imports='GetDefaultsData ParseArgs ParseArgsStd Hello Init Goodbye'
imports="$imports WriteChangelogEntry"
Import "$imports"
originalArgStr="$*"
scriptDescription=""

#= Description +===================================================================================
#
#
#==================================================================================================
#==================================================================================================
# Standard call back functions
#==================================================================================================
function parseArgs-courseleafSyncClientFiles  { # or parseArgs-local
	argList+=(-buildPages,5,switch,buildPages,,script,'Rebuild the pages database in line with script execution')
	return 0
}
function Goodbye-courseleafSyncClientFiles  { # or Goodbye-local
	rm -rf $tmpRoot > /dev/null 2>&1
	return 0
}
function testMode-courseleafSyncClientFiles  { # or testMode-local
	return 0
}

#==================================================================================================
# local functions
#==================================================================================================
#==================================================================================================
# Resolve the CAT courses database file name from the map file data
#==================================================================================================
function GetDbFile {
	local siteDir=$1; shift
	local mapKey=$1; shift
	local baseDbFile grepStr dbFile

	# Find the base database file, look in the config file
		unset baseDbFile
		grepStr=$(grep "^db:$mapKey|" $siteDir/courseleaf.cfg | tr -d '\040\011\012\015')
		if [[ $grepStr != '' ]]; then
			dbFile=$(cut -d'|' -f3 <<< $grepStr)
			[[ -r ${siteDir}${dbFile} ]] && echo "${siteDir}${dbFile}" && return 0
			[[ -r ${siteDir}/web${dbFile} ]] && echo "${siteDir}/web${dbFile}" && return 0
		fi
	return 0
} #GetCatCourseDb

#==================================================================================================
# Resolve the CIM database file name from the map file data
#==================================================================================================
function GetCimCourseDb {
	local siteDir=$1; shift
	local cimStr="$1"
	local baseDbFile grepStr dbFile dbTable sql

	# Find the base database file, look in the cims
		unset baseDbFile
		for cim in $(tr ',' ' ' <<< $cimStr); do
			## Get the dbname field from the cimconfig.cfg file, parse of the dbname
			grepStr=$(CleanString "$(ProtectedCall "grep '^dbname:' $siteDir/web/$cim/cimconfig.cfg")")
			if [[ $grepStr != '' ]]; then
				dbName=$(echo $grepStr | cut -d':' -f2)
				## Lookup dbname mapping in courseleaf.cfg
				grepStr=$(CleanString "$(ProtectedCall "grep "^db:$dbName" $siteDir/courseleaf.cfg")")
				if [[ $grepStr != '' ]]; then
					dbFile=$(echo $grepStr | cut -d'|' -f3)
					## If the file exists then check to see if there is any data
					if [[ -r ${siteDir}${dbFile} ]]; then
						## Get the base table name from the cimconfig .cfg file, see if there is any data in the table
							grepStr=$(CleanString "$(ProtectedCall "grep '^dbbasetable:' $siteDir/web/$cim/cimconfig.cfg")")
						if [[ $grepStr != '' ]]; then
							dbTable=$(echo $grepStr | cut -d':' -f2)
							sql="select count(*) from $dbTable;"
							RunSql 'sqlite' "$srcDir/$dbFile" $sql
							[[ ${resultSet[0]} -gt 0 ]] && baseDbFile="${siteDir}${dbFile}" && break
						fi
					fi
				fi
			fi
		done

	## If baseDbFile is set then we found a viable sqlite file, otherwise use the coursedb file
		if [[ $baseDbFile == '' ]]; then
		grepStr=$(grep "^db:coursedb|" $siteDir/courseleaf.cfg | tr -d '\040\011\012\015')
		if [[ $grepStr != '' ]]; then
			dbFile=$(echo $grepStr | cut -d'|' -f3)
			[[ -r ${siteDir}${dbFile} ]] && baseDbFile="${siteDir}${dbFile}"
		fi
		fi

	## Return the database name
	echo "$baseDbFile"

} #GetCimCourseDb


#==================================================================================================
# Declare local variables and constants
#==================================================================================================
tmpFile=$(mkTmpFile)
rsyncCtl=$tmpFile.rsyncCtl
[[ -f $rsyncCtl ]] && rm -f $rsyncCtl
copyDbs="$scriptData1"
copySkelDirs="$scriptData2"

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
helpSet='script,client,src,tgt'
validArgs='-noPrompt,-verbose,-help,-srcEnv,-tgtEnv,-buildPages'
scriptHelpDesc="This script can be used to synchronize the client data files under the web directory \
between two Courseleaf client environments.  Only client data files will be effected, both CIM and CAT \
files will be synchronized.  The cimcourses database will also be refreshed."

GetDefaultsData $myName
ParseArgsStd
displayGoodbyeSummaryMessages=true
Hello
Init "getClient getSrcEnv getTgtEnv getDirs checkEnvs"

unset verifyArgs
verifyArgs+=("Client:$client")
verifyArgs+=("Source Env:$(TitleCase $srcEnv) ($srcDir)")
verifyArgs+=("Target Env:$(TitleCase $tgtEnv) ($tgtDir)")
VerifyContinue "You are asking to sychronize the client data from '$srcEnv' to '$tgtEnv'"

if [[ $tgtEnv == 'next' || $tgtEnv == 'curr' ]]; then
	#Prompt ans "You have selected '$tgtEnv' as the target environment, are you sure?" "Yes No" 'No'; ans=$(Lower ${ans:0:1})
	#[[ $ans != 'y' ]] && Goodbye
	Terminate "You cannot specify a target of 'next' or 'curr'"
fi

myData="Client: '$client', SrcEnv: '$srcEnv', TgtEnv: '$tgtEnv' "
[[ $logInDb != false && $myLogRecordIdx != "" ]] && dbLog 'data' $myLogRecordIdx "$myData"

#===================================================================================================
# Main
#===================================================================================================
## Get the CIMS
	allCims=true
	unset cimStr cims; GetCims $tgtDir; tgtCims="$cimStr"
	unset cimStr cims; GetCims $srcDir; srcCims="$cimStr"

# ## CAT -- Get the courseleaf dirs under web from the skeleton -- dont sync these
	## initialize the rsync control file, skip cims for now
		echo '- *.git*' >> $rsyncCtl
		echo '- *.gz' >> $rsyncCtl
		echo '- *.bak' >> $rsyncCtl
		echo '- *.old' >> $rsyncCtl
		echo '- * - Copy*' >> $rsyncCtl
	## Skip cims for now
		for cim in $(tr -d ',' <<< $srcCims); do
			echo "- */$cim" >> $rsyncCtl
		done
	## Add records for the skeleton directories we want to include
		for dir in $(tr ',' ' ' <<< $copySkelDirs); do
			echo "+ *${dir}" >> $rsyncCtl
		done
	## Add records for the 'courseleaf' directories we want to skip
		cwd=$(pwd)
		cd $skeletonRoot/release/web
		courseleafWebDirs=($(ProtectedCall "find -maxdepth 1 -mindepth 1 -type d  \( ! -iname \"attic\" \) -printf \"%f \""))
		for courseleafWebDir in "${courseleafWebDirs[@]}"; do
			#echo "- */$courseleafWebDir/" >> $rsyncCtl
			echo "- */$courseleafWebDir" >> $rsyncCtl
		done

	## sync
		Msg2 "Sychronizing CAT..."
		[[ $informationOnlyMode == true ]] && listOnly='--list-only' || unset listOnly
		[[ $quiet == true ]] && rsyncVerbose='' || rsyncVerbose='vh'
		rsyncOpts="-a$rsyncVerbose --delete-after --prune-empty-dirs --force $listOnly --include-from $rsyncCtl"
		Msg2 "^Calling rsync..."
		if [[ $verboseLevel -ge 1 ]]; then
			echo
			cat $rsyncCtl | xargs -I {} echo -e "\t{}"
			echo
			$DOIT rsync $rsyncOpts $srcDir/web $tgtDir/ 2>&1 | xargs -I {} echo -e "\t{}"
		else
			echo >> $logFile
			cat $rsyncCtl >> $logFile
			echo >> $logFile
			$DOIT rsync $rsyncOpts $srcDir/web $tgtDir/ 2>&1 | xargs -I {} echo -e "\t{}" >> $logFile
		fi

	## Copy the non-CIM db files
		for dbKey in $(tr ',' ' ' <<< $copyDbs ); do
			srcDbFile="$(GetDbFile "$srcDir" "$dbKey")"
			tgtDbFile="$(GetDbFile "$tgtDir" "$dbKey")"
			Msg2 "^Copying $dbKey ($srcDbFile)"
			[[ $informationOnlyMode != true ]] && $DOIT cp -fp $srcDbFile $tgtDbFile
		done

	## Copy the courseleaf console
		if [[ $informationOnlyMode != true ]]; then
			SetFileExpansion 'on'
			Msg2 "^Copying /courseleaf/index.\*"
			$DOIT cp $srcDir/web/courseleaf/index.* $tgtDir/web/courseleaf
			SetFileExpansion
		fi

## CIM
	## Clean out the cim directories in the target env, copy over new ones from the source
		if [[ $srcCims != '' ]]; then
			Msg2; Msg2 "Sychronizing CIM(s)..."
			cwd="$(pwd)"
			unset oldsrcCimCoursesDbFile oldtgtCimCoursesDbFile
			for cim in $(tr -d ',' <<< $srcCims); do
				Msg2 "^$cim"
				## Delete the target proposal folders
				if [[ -d $tgtDir/web/$cim ]]; then
					cd $tgtDir/web/$cim
					Msg2 "^^Removing proposal directories from target..."
					$DOIT find . -maxdepth 1 -mindepth 1 -type d -exec rm -rf {} \;
					## Copy the source proposal folders
					cd $srcDir/web/$cim
					Msg2 "^^Copying proposal directories to target..."
					$DOIT find . -maxdepth 1 -mindepth 1 -type d -exec cp -rfp {} $tgtDir/web/$cim \;
					## Copy the cimcourses databaser
					srcCimCoursesDbFile="$(GetCimCourseDb "$srcDir" "$cim")"
					tgtCimCoursesDbFile="$(GetCimCourseDb "$tgtDir" "$cim")"
					[[ $srcCimCoursesDbFile == $oldsrcCimCoursesDbFile && $tgtCimCoursesDbFile == $oldtgtCimCoursesDbFile ]] && continue
					Msg2 "^^Copying '$srcCimCoursesDbFile' "
					$DOIT cp -fp $srcCimCoursesDbFile $tgtCimCoursesDbFile
					oldsrcCimCoursesDbFile=$srcCimCoursesDbFile
					oldtgtCimCoursesDbFile=$tgtCimCoursesDbFile
				else
					Msg2 $W "^^CIM instance '$cim' not avaiable in the source environment, skipping"
				fi
			done
		else
			Msg2; Msg2 "Source environment does not have any CIM instances, skipping CIM sync"
		fi

Msg2
[[ $buildPages == true ]] && buildPages=Yes
Prompt 'buildPages' "The pages database needs to be rebuilt, do you wish to do that now?" 'Yes No' 'Yes'; buildPages=$(Lower "${buildPages:0:1}")
if [[ $buildPages = 'y' ]]; then
	Msg2 "Rebuilding the pages database..."
	RunCoureleafCgi "$tgtDir" "-p"
else
	Msg2 "Please remember to rebuild the pages database from the console before using the refreshed site."
fi

## Write out a log entry in the target
	changeLogRecs+=("Refreshed from $(TitleCase "$srcEnv")")
	WriteChangelogEntry 'changeLogRecs' "$tgtDir/changelog.txt"

#===================================================================================================
## Done
#===================================================================================================
Goodbye 0 'alert' "$(ColorK "$(Upper $client) -- Refreshed $(Upper $srcEnv) from $(Upper $tgtEnv)")"

#===================================================================================================
## Check-in log
#===================================================================================================
## Fri Jun 24 09:54:30 CDT 2016 - dscudiero - Script to sychronize client files across envs
## Fri Jul  8 15:18:03 CDT 2016 - dscudiero - Many updates as per Mike 6/24
## Fri Jul  8 15:27:43 CDT 2016 - dscudiero - General syncing of dev to prod
## Fri Jul  8 15:32:55 CDT 2016 - dscudiero - General syncing of dev to prod
## Tue Jul 12 10:12:51 CDT 2016 - dscudiero - Fix problem if the source does not have any CIMs
## Thu Aug  4 11:01:28 CDT 2016 - dscudiero - Added displayGoodbyeSummaryMessages=true
