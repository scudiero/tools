#!/bin/bash
# XO NOT AUTOVERSION
#=======================================================================================================================
version=6.0.21 # -- dscudiero -- Thu 05/17/2018 @ 10:28:55.12
#=======================================================================================================================
TrapSigs 'on'
myIncludes='ExcelUtilities CourseleafUtilities RsyncCopy SelectMenuNew GitUtilities Alert ProtectedCall'
myIncludes="$myIncludes SetSiteDirs WriteChangelogEntry"
Import "$standardInteractiveIncludes $myIncludes"

originalArgStr="$*"
scriptDescription="Refresh courseleaf product(s) from the git repository shadows ($gitRepoShadow)"
cwdStart="$(pwd)"

#=======================================================================================================================
# Refresh/Patch Courseleaf component(s)
#=======================================================================================================================
#=======================================================================================================================
## Copyright ©2018 David Scudiero -- all rights reserved.
#=======================================================================================================================
#=======================================================================================================================
# Standard call back functions
#=======================================================================================================================
	function courseleafPatchNew-ParseArgsStd {
		#myArgs+=("shortToken|longToken|type|scriptVariableName|<command to run>|help group|help textHelp")

		myArgs+=("current|current|switch|current|source='current'|script|Update each product from the current released version")
		myArgs+=("named|namedrelease|option|namedRelease|source='named'|script|Update the product from the specific named version (i.e. git tag)")
		myArgs+=("tag|namedrelease|option|namedRelease|source='named'|script|Update the product from the specific named version (i.e. git tag)")
		myArgs+=("branch|branch|option|branch|source='branch'|script|Update the product from the specific git brach (git branch)")
		myArgs+=("master|master|switch|master|source='master'|script|Update each product from the current skeleton version (aka git tag 'master'")

		myArgs+=("advance|advance|switch|catalogAdvance||script|Advance the catalog")
		myArgs+=("noadv|noadvance|switch|catalogAdvance|catalogAdvance=false|script|Do not advance the catalog")
		myArgs+=("full|fulladvance|switch|fullAdvance||script|Do a full catalog advance (Copy next to curr and then advance")
		myArgs+=("ed|edition|option|newEdition||script|The new edition value (for advance)")

		myArgs+=("audit|audit|switch|catalogAudit||script|Run the catalog audit report as part of the process")
		myArgs+=("noaudit|noaudit|switch|catalogAudit|catalogAudit=false|script|Do not run the catalog audit report as part of the process")

		myArgs+=("back|backup|switch|backup|backup=true|script|Create a full backup of the target site before any actions")
		myArgs+=("noback|nobackup|switch|backup|backup=false|script|Do not create a backup of the target site before any actions")
		myArgs+=("build|buildpatchpackage|switch|buildPatchPackage||script|Build the remote patching package for remote sites")
		myArgs+=("rollback|rollback|switch|rollBack||script|Roll back the previous patch")
		#myArgs+=("offline|offline|switch|offline||script|Take the target site offline during processing")
	}

	function courseleafPatchNew-Goodbye  {
		SetFileExpansion 'on' ; rm -rf $tmpRoot/${myName}* >& /dev/null ; SetFileExpansion
		## If we took the site offline, then put it back online
		if [[ $offline == true ]]; then
			## uncomment the user records, remove the siteadmin: record from the bottoms
			Msg "Bringing the site back online"
			editFile="$tgtDir/$courseleafProgDir.cfg"
			sed -e '/user:/ s|^//||' -i "$editFile"
			line=$(tail -1 "$editFile")
			[[ $line == 'sitereadonly:true' ]] && sed -i '$ d' "$editFile"
			offline=false
		fi
	}

	function courseleafPatchNew-testMode {
		client='wisc'
		envs='pvt'
		siteDir="/mnt/dev6/web/wisc-dscudiero"
		products='all'
		buildPatchPackage=true
		backup=false
		catalogAdvance=false
		fullAdvance=false
		newEdition='2011-2021'
		catalogAudit=false
		source='master'
		#namedRelease='3.5.11'
	}

	function courseleafPatchNew-Help  {
		helpSet='client,env' # can also include any of {env,cim,cat,clss}, 'script' and 'common' automatically addeed
		[[ $1 == 'setVarsOnly' ]] && return 0

		echo -e "This script can be used to refresh/patch a product in a courseleaf site."
		echo -e "\nThe actions performed are:"
		bullet=1; echo -e "\t$bullet) If requested, backup the target site"
		(( bullet++ )) ; echo -e "\t$bullet) If 'Advance' is requested then"
		(( bullet++ )) ; bulletSave=$bullet ; bullet=1
		echo -e "\t\t$bullet) Backup the curr site"
		(( bullet++ )) ; echo -e "\t\t$bullet) Copy current NEXT site to new CURR site sans CIMs (other than programadmin) and CLSS"
		(( bullet++ )) ; echo -e "\t\t$bullet) Update edition variable"
		(( bullet++ )) ; echo -e "\t\t$bullet) Resets console statistics"
		(( bullet++ )) ; echo -e "\t\t$bullet) Archives the request logs"
		if [[ -n "$scriptData3$scriptData4" ]]; then
			(( bullet++ )) ; echo -e "\t\t$bullet) Empty files and directories:"
			for file in $(tr ',' ' ' <<< $scriptData3) $(tr ',' ' ' <<< $scriptData4); do
				echo -e "\t\t\t- $file"
			done
		fi
		bullet=$bulletSave
		echo -e "\t$bullet) Patch the products as per definitions in the patch control file:"
		echo -e "\t\t$courseleafpatchControlDbFile"
		echo -e "\t$bullet) Perform cross product checks in local site"
		(( bullet++ )) ; bulletSave=$bullet ; bullet=1
		(( bullet++ )) ; echo -e "\t\t$bullet) Check for old formbuilder widgets"
		(( bullet++ )) ; echo -e "\t\t$bullet) Warn if the target site ribbit/getcourse.rjs is different from the skeletion"
		(( bullet++ )) ; echo -e "\t\t$bullet) Check the mapfile entries for fsinjector.sqlite"
		(( bullet++ )) ; echo -e "\t\t$bullet) Remove any 'special' cgis in the courseleaf/tcfdb directory"
		bullet=$bulletSave
		echo -e "\t$bullet) If requested, generate a remote patch package"
		echo -e "\nTarget site data files potentially modified:"
		echo -e "\tAll CourseLeaf files, no client data files"

		return 0
	}


#=======================================================================================================================
# local functions
#=======================================================================================================================

#=======================================================================================================================
# Additional data prompts if the user is requesting to patch the catalog
# 1) Should we advance, Full Advance, New edition
# 2) Should we perform an data audit
#=======================================================================================================================
function AdditionalCatalogPrompts {
	if [[ $env == 'next' || $env == 'pvt' ]]; then
		if [[ -z $catalogAdvance ]]; then
			Msg
			unset ans; Prompt ans 'Do you wish to advance the catalog edition?' 'No Yes' 'No'; ans="$(Lower ${ans:0:1})"
			[[ $ans == 'y' ]] && catalogAdvance=true
		else
			Note 0 1 "Using specified value of '$catalogAdvance' for 'catalogAdvance'"
			[[ $verify != true && $catalogAdvance == true && $buildPatchPackage != true && -z $newEdition ]] && \
					Info 0 1 "Specifying -noPrompt and -catalogAdvance is not allowed, continuing with prompting active" && verify=true
		fi

		[[ $catalogAdvance == true && $buildPatchPackage == true ]] && addAdvanceCode=true
		if [[ $catalogAdvance == true ]]; then
			[[ -z $localstepsDir ]] && Terminate "Sorry, your are requesting a catalog advance and we could not locate the localsteps directory"
			[[ $verify == false && -z $newEdition ]] && Info 0 1 "'newEdition' does not have a value and the '-noPrompt' flag was included, continuing with prompting active" && verify=true
			if [[ -z $newEdition ]]; then
				## Get the current edition from the defults.tcf file
				if [[ -f $localstepsDir/default.tcf ]]; then
					unset grepStr
					currentEdition=$(ProtectedCall "grep "^edition:" $localstepsDir/default.tcf" | cut -d':' -f2)
					currentEdition=$(tr -d '\040\011\012\015' <<< "$currentEdition")
					Note 0 1 "^Current CAT edition is: '$currentEdition'."
				else
					Terminate "Sorry, your are requesting a catalog advance and we could not locate the /localsteps/default.tcf file"
				fi
					## Set the new edition and prompt user
				unset defaultNewEdition
				if [[ -n $currentEdition && $currentEdition != *'migration'* ]]; then
					if [[ $(Contains "$currentEdition" '-') == true ]]; then
						fromYear=$(echo $currentEdition | cut -d'-' -f1)
						toYear=$(echo $currentEdition | cut -d'-' -f2)
						[[ $(IsNumeric $fromYear) == true  && $(IsNumeric $toYear) == true ]] && (( fromYear++ )) && (( toYear++ )) && defaultNewEdition="$fromYear-$toYear"
					elif [[ $(Contains "$currentEdition" '_') == true ]]; then
						fromYear=$(echo $currentEdition | cut -d'_' -f1)
						toYear=$(echo $currentEdition | cut -d'_' -f2)
						[[ $(IsNumeric $fromYear) == true  && $(IsNumeric $toYear) == true ]] && (( fromYear++ )) && (( toYear++ )) && defaultNewEdition="$fromYear-$toYear"
					else
						[[ $(IsNumeric $currentEdition) == true ]] && defaultNewEdition=$currentEdition && (( defaultNewEdition++ ))
					fi
				fi
				Prompt newEdition "^Please specify the new edition value" "$defaultNewEdition,*any*" "$defaultNewEdition" || Prompt newEdition "Please specify the new edition value" "*any*"
			fi
			[[ -z $newEdition ]] && Terminate "New edition variable has not been set"
			Msg
			if [[ -z $fullAdvance && $env != 'pvt' && $testMode != true ]]; then
				unset ans; Prompt ans '^Do you wish to do a full advance (i.e. copy NEXT to CURR sans CLSS & CIMs, etc.)' 'Yes No' 'Yes'; ans="$(Lower ${ans:0:1})"
				[[ $ans == 'y' ]] && fullAdvance=true || fullAdvance=false
			fi
		else
			catalogAdvance=false
			fullAdvance=false
		fi ## [[ $catalogAdvance == true ]]
	fi ##[[ $env == 'next' || $env == 'pvt' ]]

	if [[ -z $catalogAudit ]]; then
		Msg
		unset ans; Prompt ans "Do you wish to run the catalog audit report" "No Yes" "No"; ans=$(Lower ${ans:0:1})
		[[ $ans == 'y' ]] && catalogAudit=true
	else
		Note 0 1  "Using specified value of '$catalogAudit' for 'catalogAudit'"
	fi
	return 0
} #AdditionalCatalogPrompts

#=======================================================================================================================
# Process a git patch record
# Usage processGitRecord <git repo name> <target directory> <git tag name>
#=======================================================================================================================
function processGitRecord {
	local repoName="$1"; shift || true
	local specTarget="$1"; shift || true
	local gitTag="$1"; shift || true
	local branch ans
	set gitResults=false

	[[ $gitTag == 'branch' ]] && { branch="$1"; shift || true; gitTag="$branch"; } ## Branches and tags are treated the same
	local checkRepoStatus gitCmd tmpCntr gitCmdOut gitFilesUpdated bCntr srcFile backupFile packageFile
	Dump 1 repoName specTarget gitTag branch -p

	Pushd "$tgtDir/${specTarget}"
	## Check to see if we have a .git directory for this directory, if not then copy from the skeleton
	if [[ ! -d $tgtDir/${specTarget}/.git ]]; then
		local srcGitFile="${skeletonRoot}${specTarget}/.git"
		Msg "The target site does not have a .git repository for '$repoName', creating from the skeleton, this will take a while..."
		[[ ! -d $srcGitFile ]] && Terminate 0 2 "Could not locate a source .git directory for this request, repository: $repoName\n^srcGitFile: $srcGitFile"
		cp -frp "${srcGitFile}" '.'
		[[ -f "${srcGitFile}ignore" ]] && cp -fp "${srcGitFile}ignore" '.'
		## Make the local git repo a real worktree, need to hack the config file since our git is so down level.  Need this for git diff to work
		sed -i s"/bare = true/bare = false/" "$tgtDir/${specTarget}/.git/config"
		Msg "^Local repository created"
	else
		## See if there are any modifications to files in the local git repo
		gitCmd="git status -s"
		unset gitCmdOut; gitCmdOut=$(ProtectedCall "$gitCmd")
		if [[ -n $gitCmdOut ]]; then
			local foundModified=false
			unset tmpArray; readarray -t tmpArray <<< "${gitCmdOut}"
			for ((tmpCntr=0; tmpCntr<${#tmpArray[@]}; tmpCntr++)); do
				local status="${tmpArray[$tmpCntr]}"
				if [[ ${status:0:2} != '??' ]]; then
					[[ $foundModified == false ]] &&Warning 0 2 "There are changes to tracked file(s) in the target git repository:"
					Msg 0 +1 "${tmpArray[$tmpCntr]}"
					foundModified=true
				fi
			done
			if [[ $foundModified == true ]]; then
				[[ $verify != true && $batchMode != true ]] && verify=true
				echo
				Prompt ans '^^Do you wish to continue, local mods will be lost?' 'Yes No' 'No'; ans=${ans:0:1}; ans=${ans,,[a-z]}
				[[ $ans != 'y' ]] && { Msg; Warning "Terminating early, the target site may inconsistent code"; Goodbye -3; }
			fi
		fi
	fi

	## Get the list of files that will change with the checkout
	gitCmd="git diff --name-only $gitTag"
	unset gitCmdOut; gitCmdOut=$(ProtectedCall "$gitCmd")
	## Do we have anything to update?
	if [[ -n $gitCmdOut ]]; then
		readarray -t gitFilesUpdated <<< "${gitCmdOut}"
		## Make backup copies of the files we are going to update
			Msg "Archiving ${#gitFilesUpdated[@]} files..."
			for ((bCntr=0; bCntr<${#gitFilesUpdated[@]}; bCntr++)); do
				srcFile="${tgtDir}${specTarget}/${gitFilesUpdated[$bCntr]}"
				# [[ -r $srcFile ]] && backupFile "$srcFile" "${backupRootDir}"
				Log "^$srcFile"
			done
		## Update local files from the git repo via checkout
			Msg "Updating ${#gitFilesUpdated[@]} files (via git checkout '$gitTag')..."
			gitCmd="git reset --hard --quiet"; ## Update git repo data
			ProtectedCall "$gitCmd" | Indent
			[[ $verboseLevel -eq 0 ]] && gitCmd="git checkout --force --quiet $gitTag &> /dev/null" || gitCmd="git checkout --force $gitTag"
			ProtectedCall "$gitCmd" | Indent;
			## If we are going to generate a patch package then write the changed files to the staging directory
			if [[ $buildPatchPackage == true ]]; then 
				for ((bCntr=0; bCntr<${#gitFilesUpdated[@]}; bCntr++)); do
					Msg L "\n\t\t$repoName.git ($gitTag) -- ${specTarget}/${gitFilesUpdated[$bCntr]}"
					cpToPackageDir "${tgtDir}${specTarget}/${gitFilesUpdated[$bCntr]}"
				done
			fi
		gitResults=true
	fi
	Popd
Pause
	return 0
} ## processGitRecord

#=======================================================================================================================
# Backup a file, maintain a list of backed-up / edited files
#=======================================================================================================================
function backupFile {
	local file=$1; shift || true
	local backupDir=$1

	## Check to see if we have processed this file already
	if [[ ! ${backedupFiles["$file"]+abc} ]]; then
		dump -ifMe file backupDir
		BackupCourseleafFile "$file" "$backupDir"
		backedupFiles["$file"]=true
	fi
	return 0

} ## backupFile

#=======================================================================================================================
# Copy a file to the remote patching collection
#=======================================================================================================================
function cpToPackageDir {
	local file="$1"; shift || true
	local packageDir="${1:-$packageRootDir}"

	## Parse the file name
	local data="$(ParseCourseleafFile "$file")"
	local client="${data%% *}"; data="${data#* }"
	local env="${data%% *}"; data="${data#* }"
	local clientRoot="${data%% *}"; data="${data#* }"
	local fileEnd="${data%% *}"; data="${data#* }"
	#dump -n file -t client env clientRoot fileEnd packageDir

	mkdir -p "$(dirname "${packageDir}${fileEnd}")"
	cp -fp "$file" "${packageDir}${fileEnd}"

	return 0

} ## cpToPackageDir

#=======================================================================================================================
#=======================================================================================================================
# MAIN
#=======================================================================================================================
#=======================================================================================================================
# Declare local variables and constants
#=======================================================================================================================
unset backup backupSite buildPatchPackage source
tmpFile=$(mkTmpFile)
rebuildConsole=false
removeGitReposFromNext=true
declare -A backedupFiles

#=======================================================================================================================
# Standard argument parsing and initialization
#=======================================================================================================================
Hello
GetDefaultsData -f "$myName"
ParseArgsStd $originalArgStr
skeletonRoot='/steamboat/leepfrog/clskel/release'

displayGoodbyeSummaryMessages=true
cleanDirs="${scriptData3##*:}"
cleanFiles="${scriptData4##*:}"
[[ $allItems == true && -z $products ]] && products='all'

[[ $informationOnlyMode == true ]] && Warning 0 1 "The 'informationOnlyMode' flag is turned on, files will not be copied"
if [[ $testMode != true ]]; then
	if [[ $noCheck == true ]]; then
		Init 'getClient checkProdEnv'
		GetSiteDirNoCheck $client
		[[ -z $siteDir ]] && Terminate "Nocheck option active, could not resolve target site directory"
	else
		Init 'getClient getEnv getDirs checkDirs noPreview noPublic checkProdEnv addPvt'
		SetSiteDirs
	fi
	[[ $env == 'next' || $env == 'curr' ]] && Init 'getJalot'
fi
eval "siteDir=\"\$${envs}Dir\""

Dump 1 originalArgStr -t client env envs products current namedRelease branch skeleton catalogAdvance fullAdvance newEdition \
		catalogAudit backup buildPatchPackage fastInit source rollBack siteDir -p

## Is this a rollback requests
	if [[ $rollBack == true && batchMode != true ]]; then
		SetFileExpansion 'on'
		tarFile="$(ls -t $siteDir/attic/*.prePatch.tar.gz | head -1)"
		SetFileExpansion
		patchDate=${tarFile#*$myName-}; patchDate=${patchDate%%@*};
		patchTime=${tarFile#*@}; patchTime=${patchTime%%.*}; patchTime=${patchTime//-/:};
		# Don't allow no prompt for rollback requestes
		[[ $verify != true ]] && verify=true
		Msg "The most recent patch to the site was applied on $patchDate at $patchTime."
		unset ans; Prompt ans "Are you sure you want to restore the site to this date/time ?" 'No,Yes' 'No'; ans="${ans:0:1}"; ans="${ans,,[a-z]}"
		if [[ $ans == 'y' ]]; then
			Msg; Msg "Restoring files from '$tarFile'"
			Pushd "$siteDir"
			Indent ++; tar -xvf "$tarFile" | Indent; Indent --
			changeLogRecs=("Restored site to before patch:")
			changeLogRecs+=("\t$tarFile")
			WriteChangelogEntry 'changeLogRecs' "$siteDir/changelog.txt"
			Popd
			Goodbye 0
		fi
	fi

if [[ $env == 'next' || $env == 'pvt' ]]; then
	sqlStmt="Select hosting from $clientInfoTable where name=\"$client\""
	RunSql $sqlStmt
	hosting=${resultSet[0]}; hosting="${hosting,,[a-z]}"
	if [[ -n $hosting && $hosting != 'leepfrog' ]]; then
		Prompt buildPatchPackage "This client ($client) is hosted off site, do you wish to build a remote patching package ?" 'Yes,No' 'Yes'
		ans="${buildPatchPackage:0:1}"; ans=${ans,,[a-z]}
		[[ $ans == 'y' ]] && buildPatchPackage=true
	fi
fi #[[ $env == 'next' ]]

## Get the patch-able products
	unset patchableProducts
	sqlStmt="select distinct product from $patchesTable"
	RunSql $sqlStmt
	for ((i=0; i<${#resultSet[@]}; i++)); do
		patchableProducts="$patchableProducts,${resultSet[$i]}"
	done
	patchableProducts="${patchableProducts:1}"

## Get the products to patch
	[[ $allItems == true ]] && products="$patchableProducts"
	[[ -z $products ]] && echo
	Prompt products "What products do you wish to patch (comma separated)" "${patchableProducts//,/ } all" "${patchableProducts%%,*}"
	
	products="${products//cgis/}"; products="${products// /,}"
	[[ ${products:0:1} == ',' ]] && products="${products:1}"
	[[ ${products:$((${#products}-1)):1} == ',' ]] && products="${products:0:$((${#products}-1))}"

	if [[ $(Contains "$products" ',') == true ]]; then
		[[($source == 'named' || $source == 'branch') ]] && \
		Terminate "Sorry, you cannot specify multiple products when asking to source the patch from 'Named Release' or 'Branch'" 
	fi

## Set the target information
	tgtDir="$siteDir"
	[[ -z $tgtEnv ]] && tgtEnv="$env"
	[[ $client == 'internal' ]] && courseleafProgDir='pagewiz' || courseleafProgDir='courseleaf'

	## Make sure the target config file is writable if we are advancing
	cfgFile="$tgtDir/$courseleafProgDir.cfg"
	[[ ! -w $cfgFile ]] && [[ $catalogAdvance == true || $fullAdvance == true || $offline == true ]] && \
		Terminate "*Error* -- Could not write to file: '$cfgFile'"

	## Find the target localsteps directory using the mapfile entry in courseleaf.cfg
	grepStr=$(ProtectedCall "grep '^mapfile:localsteps' \"$cfgFile\"")
	if [[ -n $grepStr ]]; then
		grepStr=${grepStr##*|}
		pushd $tgtDir/web/$courseleafProgDir >& /dev/null
		cd $grepStr
		localstepsDir="$(pwd)"
		popd >& /dev/null
	else
		localstepsDir="$tgtDir/web/$courseleafProgDir/localsteps"
	fi
	[[ ! -f $localstepsDir/default.tcf ]] && \
			{ Warning 0 1 "Could not resolve the 'localsteps' directory, updates and checks will be skipped"; unset localstepsDir; }

	## Find the target locallibs directory using the mapfile entry
	unset locallibsDir
	grepStr=$(ProtectedCall "grep '^mapfile:locallibs' \"$cfgFile\"")
	if [[ -n $grepStr ]]; then
		grepStr=${grepStr##*|}
		pushd $tgtDir/web/$courseleafProgDir >& /dev/null
		cd $grepStr
		locallibsDir="$(pwd)"
		popd >& /dev/null
	else
		locallibsDir=$tgtDir/web/$courseleafProgDir/locallibs
	fi
	[[ ! -d $locallibsDir && $client != 'internal' ]] && \
		{ Warning 0 1 "Could not resolve the 'locallibs' directory, updates and checks will be skipped"; unset locallibsDir; }

## Determine the source information
unset processControl sourceIn

for product in ${products//,/ }; do
	gitDir="/mnt/dev6/web/git/${product,,[a-z]}.git"
	if [[ $product == 'cat' ]]; then
		gitDir="/mnt/dev6/web/git/courseleaf.git"
		AdditionalCatalogPrompts
		[[ $advance == true && -z $localstepsDir ]] && Terminate "Requesting a catalog advance but the localsteps directory could not be located"
	fi

	[[ -n $sourceIn ]] && source="$sourceIn"
	if [[ -z $source ]]; then
		Msg "\nFor '$(ColorK ${product^^[a-z]})', What source data do you wish to use for the patch:"
		if [[ $(Contains "$products" ',') == true ]]; then
			Msg "^$(ColorK \'C\') for Current Release\n^$(ColorK \'M\') for the 'master' branch (aka what's in the skeleton)"
			unset ans; Prompt ans "Source" "C,M" "C"
		else
			Msg "^$(ColorK \'C\') for Current Release, \n^$(ColorK \'N\') for Specific named release, \
				\n^$(ColorK \'B\') for Specific git branch, or \n^$(ColorK \'M\') for the 'master' branch"
			unset ans; Prompt ans "Which source ?" "C,N,B,M" "C"
		fi
		ans="${ans:0:1}"
		if [[ ${ans,,[a-z]} == 'n' ]]; then
			source='named'
		elif [[ ${ans,,[a-z]} == 'b' ]]; then
			source='branch'
		elif [[ ${ans,,[a-z]} == 'm' ]]; then
			source='master'
		else
			source='current' 
		fi
	else 
		sourceIn="$source"
	fi	

	case "${source,,[a-z]}" in
		named)	## Get the named release
			if [[ -z $namedRelease ]]; then
				menuList=("|Git Release (tag)")
				for token in $(git --git-dir="$gitDir" tag | tr '\r\n' ' '); do
					[[ $token == '*' ]] && continue
					menuList+=("|${token}")
				done
				Msg "\nPlease select the release (tag) you wish to use for the patch source:"
				SelectMenuNew 'menuList' 'namedRelease' '\nGit tag ordinal (or 'x' to quit) > '
			fi
			;;
		branch)	## Get the git branches
			if [[ -z $branch ]]; then
				menuList=("|Git Branch")
				for token in $(git --git-dir="$gitDir" branch | tr '\r\n' ' '); do
					[[ $token == '*' ]] && continue
					menuList+=("|${token}")
				done
				Msg "\nPlease select the git branch you wish to use for the patch source:"
				SelectMenuNew 'menuList' 'branch' '\nGit tag ordinal (or 'x' to quit) > '		
			fi
			;;
		master)	## Master
			sourceDir=''
			source='branch'
			branch='master'
			;;
		*)	## Current release
			## Get the release tag from the patch control database
			sqlStmt="select concat(sourceSpec,targetSpec,option) from $patchesTable where product=\"$product\" and recordType=\"currentRelease\""
			RunSql $sqlStmt
			[[ ${#resultSet[@]} -eq 0 || -z ${resultSet[0]} ]] && \
				Terminate "Sorry, 'current' was requested as the source but could not lookup the version from the '$patchesTable' database."
			sourceDir=''
			source='current'
			namedRelease="${resultSet[0]}"
			;;
	esac
	## Get the target sites version, set processControl record
	eval ${product}Source=\"$source\" 
	eval "${product}VerBeforePatch=\"\$(GetProductVersion $product "$tgtDir")\""
	[[ -z \$${product}VerBeforePatch ]] && eval "${product}VerBeforePatch='00.00.00'"
	processControl+=("$product|$source|${namedRelease}${branch}")
	unset source namedRelease branch
done #products

if [[ $verboseLevel -ge 1 ]]; then
	dump source namedRelease branch catVerBeforePatch cimVerBeforePatch clssVerBeforePatch
	Msg "\${#processControl[@]} = '${#processControl[@]}'"
	for ((xx=0; xx<${#processControl[@]}; xx++)); do
		Msg "^processControl[$xx] = >${processControl[$xx]}<"
	done
	Pause
fi

## Should we backup the target site
	if [[ $env == 'next' || $env == 'curr' ]]; then
		[[ $backup == true ]] && backup='Yes' ; [[ $backup == false ]] && backup='No'
		Msg
		Prompt backup "Do you wish to make a full backup of the target site before patching" 'Yes No' 'No'; backup=$(Lower ${backup:0:1})
		[[ $backup == 'y' ]] && backup=true || backup=false
		# [[ $offline == true ]] && offline='Yes' ; [[ $offline == false ]] && offline='No'
		# Prompt offline "Do you wish to take the site offline during the patching process" 'Yes No' 'Yes'; offline=$(Lower ${offline:0:1})
		# [[ $offline == 'y' ]] && offline=true || offline=false
	fi

## Get the cgis information
	courseleafCgiDirRoot="$skeletonRoot/web/courseleaf"
	useRhel="rhel${myRhel:0:1}"
	courseleafCgiSourceFile="$courseleafCgiDirRoot/courseleaf.cgi"
	[[ -f "$courseleafCgiDirRoot/courseleaf-$useRhel.cgi" ]] && courseleafCgiSourceFile="$courseleafCgiDirRoot/courseleaf-$useRhel.cgi"
	courseleafCgiVer="$($courseleafCgiSourceFile -v  2> /dev/null | cut -d" " -f3)"
	dump -1 courseleafCgiSourceFile courseleafCgiVer

	ribbitCgiDirRoot="$skeletonRoot/web/ribbit"
	ribbitCgiSourceFile="$ribbitCgiDirRoot/index.cgi"
	[[ -f "$ribbitCgiDirRoot/index-$useRhel.cgi" ]] && ribbitCgiSourceFile="$ribbitCgiDirRoot/index-$useRhel.cgi"
	ribbitCgiVer="$($ribbitCgiSourceFile -v  2> /dev/null | cut -d" " -f3)"
	dump -1 ribbitCgiSourceFile ribbitCgiVer

## Get the daily.sh version
	dailyShourceFile="$skeletonRoot/bin/daily.sh"
	dailyShVer=$(ProtectedCall "grep -m 1 \"^version=\" $dailyShourceFile")
	dailyShVer=${dailyShVer%% *}; dailyShVer=${dailyShVer##*=};
	dump -1 dailyShourceFile dailyShVer

## Backup root
	backupRootDir="$tgtDir/attic/$myName.$(date +"%m-%d-%Y@%H.%M.%S").prePatch"
	mkdir -p "$backupRootDir"

## Remote package file collector
	[[ $buildPatchPackage == true ]] && { packageRootDir="$tgtDir/attic/$myName.$(date +"%m-%d-%Y@%H.%M.%S").remotePatch"; mkdir -p "$packageRootDir"; }

## Set the backup site
unset backupSite
if [[ $backup == true ]]; then
	backupSite="$tgtDir/$client.$userName.$(date +"%m-%d-%y").bak"
	[[ $env == "next" || $env == "curr" ]] && backupSite="$(dirname "$tgtDir")/${env}.$userName.$(date +"%m-%d-%y").bak"
fi

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
verifyArgs+=("Product(s):${products//,/, }")
for token in "${processControl[@]}"; do
	product="${token%%|*}"; token="${token#*|}"
	source="${token%%|*}"; token="${token#*|}"	
	[[ -z $token ]] && verifyArgs+=("^$product, source: $source") || verifyArgs+=("^$product, source: $source / $token")
done

if [[ $catalogAdvance == true ]]; then
	verifyArgs+=("New catalog edition:$newEdition, fullAdvance=$fullAdvance")
	#verifyArgs+=("^localstepsDir:$localstepsDir")
	#verifyArgs+=("^locallibsDir:$locallibsDir")
fi
[[ $catalogAudit == true ]] && verifyArgs+=("Catalog Audit:$catalogAudit")

[[ -n $courseleafCgiVer ]] && verifyArgs+=("New courseleaf.cgi version:$courseleafCgiVer")
[[ -n $ribbitCgiVer ]] && verifyArgs+=("New ribbit.cgi version:$ribbitCgiVer")
[[ -n $dailyShVer ]] && verifyArgs+=("New daily.sh version:$dailyShVer")
verifyArgs+=("skeleton Root:$skeletonRoot")
[[ $backup == true ]] && verifyArgs+=("Backup site:$backup, backup directory: '$backupSite'")
[[ $offline == true ]] && verifyArgs+=("Take site offline:$offline")
[[ $buildPatchPackage == true ]] && verifyArgs+=("Build Patch Package:$buildPatchPackage")
[[ -n $comment ]] && verifyArgs+=("Jalot:$comment")
[[ -n $forUser ]] && verifyArgs+=("For User:$forUser")
#[[ -n $betaProducts ]] && [[ $env == 'next' || $env == 'curr' ]] && Msg && Warning "You are asking to refresh to beta/rc version of the software for: $betaProducts"

VerifyContinue "You are asking to refresh CourseLeaf code files:"
ProtectedCall "clear"
Msg

#=======================================================================================================================
# Log run
#=======================================================================================================================
myData="Client: '$client', Products: '$products', tgtEnv: '$env' $processControl"
[[ $noCheck == true ]] && myData="Target Path, $tgtDir, Products: '$products' $processControl"
[[ $catalogAdvance == true ]] && myData="$myData New Edition: $newEdition"
[[ $catalogAudit == true ]] && myData="$myData catalog audit"
[[ $buildPatchPackage == true ]] && myData="$myData Build patchPackage"
myData="$myData $processControl"
[[ $logInDb != false && $myLogRecordIdx != "" && $testMode != true ]] && ProcessLogger 'Update' $myLogRecordIdx 'data' "$myData"
dump -2 -p client products catRefreshVersion cimRefreshVersion clssRefreshVersion tgtDir

#=======================================================================================================================
## Main
#=======================================================================================================================
unset filesEdited

if [[ $offline == true ]]; then
	## comment out the user records in courseleaf.cfg, keep leepfrog and cl* accounts
	Msg "Taking the site offline"
	editFile="$cfgFile"
	sed -e '/user:/ s|^|//|' -i "$editFile"
	for user in leepfrog cladmin- clmig-; do
		fromStr="^//user:$user" ; toStr="user:$user"
		sed -i s"_${fromStr}_${toStr}_"g "$editFile"
	done
	## Add a sitereadonly: record
	echo 'sitereadonly:true' >> $editFile
fi

if [[ $backup == true ]]; then
	Msg "Backing up the entire target site, this will take a while..."
	Msg "^(Fyi, id you are the impatient type, you can check the status, view/tail the log file: '$logFile')"
	sourceSpec="$tgtDir/"
	targetSpec="$backupSite"
	[[ ! -d "$targetSpec" ]] && mkdir -p "$targetSpec"
	Indent++; RsyncCopy "$sourceSpec" "$targetSpec"; Indent--
	Msg "^...Backup completed"
	Alert 1
fi
#=======================================================================================================================

##======================================================================================================================
## Advance catalog
##======================================================================================================================
if [[ $catalogAdvance == true || $fullAdvance == true ]]; then
	Msg "Catalog advance is active, advancing the '$(Upper $env)' site"
	AitemCntr=1
	# Full advance, create a new curr site
	if [[ $fullAdvance == true ]]; then
		FAitemCntr=1
		# Make a copy of next sans CIMs and CLSS/WEN
		sourceSpec="$tgtDir/"
		targetSpec="$(dirname $tgtDir)/${env}.${backupSuffix}"
		[[ $env == 'pvt' ]] && targetSpec="$tgtDir/$env.$(date +"%m-%d-%y")"
		ignoreList="/db/clwen*|/bin/clssimport-log-archive/|/web/$progDir/wen/|/web/wen/"
		# # Add the cim directories (except programadmin) to the ignore list
		# if [[ ${#cims[@]} -gt 0 ]]; then
		# 	for cim in ${cims[@]}; do
		# 		[[ $cim == 'programadmin' ]] && continue
		# 		ignoreList="$ignoreList|/web/$cim/"
		# 	done
		# fi
		[[ ! -d "$targetSpec" ]] && mkdir -p "$targetSpec"
		Msg "^$AitemCntr) Full advance requested making a copy of '$env' (this will take a while)..."
		Msg "^^$FAitemCntr) Making a copy of '$env' (this will take a while)..."
		Msg "^^^'$tgtDir' --> '$(basename $targetSpec)'"
		#Msg "^^(Fyi, you can check the status, view/tail the log file: '$logFile')"
		Indent++; RsyncCopy "$sourceSpec" "$targetSpec" "$ignoreList"; Indent--
		Msg "^^^Copy operation completed"
		Alert 1
		(( FAitemCntr++ ))
		# Move courseadmin the attic
		if [[ -d ${targetSpec}/web/courseadmin ]]; then
			[[ ! -d  ${targetSpec}/attic ]] && mkdir -p "${targetSpec}/attic"
			mv -f ${targetSpec}/web/courseadmin ${targetSpec}/attic/courseadmin.$(date +"%m-%d-%y")
			Msg "^^$FAitemCntr) 'courseadmin' moved to the attic in the new CURR site"
			editFile="$targetSpec/web/$courseleafProgDir/index.tcf"
			# Edit the courseleaf/index.tcf to comment out courseadmin lines
			backupFile "$editFile" "$backupDir"
			sed -e '/courseadmin/ s_^_//_' -i "$editFile"
			Msg "^^$FAitemCntr) 'courseadmin' removed from the courseleaf console"
			(( FAitemCntr++ ))
		fi

		# Edit the coursleaf/index.tcf to remove clss/wen stuff
		editFile="$targetSpec/web/$courseleafProgDir/index.tcf"
		backupFile "$editFile" "$backupDir"
		sed -i s'_^sectionlinks:WEN|_//sectionlinks:WEN|_'g "$editFile"
		sed -i s'_^navlinks:WEN|_//navlinks:WEN|_'g "$editFile"
		Msg "^^$FAitemCntr) WEN records commented out in the new CURR site(/web/$courseleafProgDir/index.tcf file)"
		(( FAitemCntr++ ))

		## Swap our copy of the next site with the curr site
		Msg "^^$FAitemCntr) Full advance is active, swapping our copy of the NEXT site with the CURR site"
		Msg "^^^'$targetSpec' --> '$(dirname $tgtDir)/curr'"
		if [[ -d $(dirname $tgtDir)/curr ]]; then
			$DOIT mv -f "$(dirname $tgtDir)/curr" "$(dirname $tgtDir)/curr-${backupSuffix}"
			Msg "^^^'$(dirname $tgtDir)/curr' --> '$(dirname $tgtDir)/curr-${backupSuffix}'"
		fi
		$DOIT mv -f "$targetSpec" "$(dirname $tgtDir)/curr"
		(( FAitemCntr++ ))

		## Fix the editcl login accounts
		editFile="$(dirname $tgtDir)/curr/$courseleafProgDir.cfg"
		backupFile "$editFile" "$backupDir"
		sed -i s"_$client-next_$client-curr_"g "$editFile"

		# Turn off pencils from the structured content draw
		editFile="$localstepsDir/structuredcontentdraw.html"
		if [[ -f "$editFile" ]] ; then
			backupFile "$editFile" "$backupDir"
			sed -e '/pencil.png/ s|html|//html|' -i "$editFile"
			Msg "^^$FAitemCntr) Pencils turned OFF in /web/courseleaf/localsteps/structuredcontentdraw.html in the new CURR site"
		fi
		(( FAitemCntr++ ))

		# Make sure that pdfererypage is set
		editFile="$localstepsDir/default.tcf"
		if [[ -f "$editFile" ]] ; then
			#Msg "^Editing the 'localsteps/default.tcf' file..."
			backupFile "$editFile" "$backupDir"
			sed -i s'_^//pdfeverypage:true_pdfeverypage:true_' "$editFile"
			sed -i s'_^pdfeverypage:false_pdfeverypage:true_' "$editFile"
			Msg "^^$FAitemCntr) pdfeverypage set ON (/web/courseleaf/localsteps/default.tcf) in the new CURR site"
		fi
		(( FAitemCntr++ ))

		editFile="$(dirname $tgtDir)/curr/$courseleafProgDir.cfg"
		#Msg "^Editing the '$courseleafProgDir.cfg' file..."
		backupFile "$editFile" "$backupDir"
		sed -i s'_^//sitereadonly:Admin Mode_sitereadonly:Admin Mode_g' "$editFile"
		Msg "^^$FAitemCntr) Site admin mode set ON (/$courseleafProgDir.cfg) in the new CURR site"
		(( FAitemCntr++ ))

		Msg "^^$FAitemCntr) Republishing the CURR Courseleaf Console"
		RunCourseLeafCgi "$(dirname $tgtDir)/curr" -r /index.tcf
		Msg "^^^New CURR site console republish completed"
		(( FAitemCntr++ ))

		RunCourseLeafCgi "$(dirname $tgtDir)/curr" -r &
		currRepublishPID=$!
		Msg "^*** Full advance completed, current NEXT site has been copied to a new CURR site and"
		Msg "^^the new CURR site is being republished in the background"
		Msg
		(( AitemCntr++ ))
	fi #[[ $fullAdvance == true ]]

	## Set the new edition value
		Msg "^$AitemCntr) Setting edition variable..."
		editFile="$localstepsDir/default.tcf"
		backupFile "$editFile" "$backupDir"
		fromStr=$(ProtectedCall "grep "^edition:" $localstepsDir/default.tcf")
		toStr="edition:$newEdition"
		sed -i s"_^${fromStr}_${toStr}_" "$editFile"
		Msg "^^$fromStr --> $toStr"
		rebuildConsole=true
		filesEdited+=("$editFile")
		(( AitemCntr++ ))

	# Reset courseleaf statuses
		Msg "^$AitemCntr) Reseting console status (again, this may take a while)..."
		Msg "^^wfstatinit..."
		RunCourseLeafCgi $tgtDir "wfstatinit /index.html"
		Msg "^^wfstatbuild..."
		RunCourseLeafCgi $tgtDir "-e wfstatbuild /"
		Alert 1
		(( AitemCntr++ ))

	# Archive request logs
		Msg "^$AitemCntr) Archiving request logs..."
		if [[ -d $tgtDir/requestlog ]]; then
			cd $tgtDir/requestlog
			if [[ $(ls) != '' ]]; then
				Msg "^Archiving last requestlog directory..."
				SetFileExpansion 'on'
				[[ ! -d "$tgtDir/requestlog-archive/" ]] && mkdir "$tgtDir/requestlog-archive/"
				$DOIT tar -cJf $tgtDir/requestlog-archive/requestlog-$(date "+%Y-%m-%d").tar.bz2 * --remove-files
				SetFileExpansion
			fi
		fi
		if [[ -d $tgtDir/requestlog-archive ]]; then
			cd $tgtDir/requestlog-archive
			if [[ $(ls | grep -v 'archive') != '' ]]; then
				Msg "^Taring up the requestlog-archive directory..."
				cd $tgtDir/requestlog-archive
				SetFileExpansion 'on'
				$DOIT tar -cJf $tgtDir/requestlog-archive/archive-$(date "+%Y-%m-%d").tar.bz2 *  --exclude '*archive*' --remove-files
				SetFileExpansion
			fi
		fi
		(( AitemCntr++ ))

	# Genaral cleanup
		Msg "^$AitemCntr) Emptying files"
		for file in $(echo $cleanFiles | tr ',' ' '); do
			Msg "^^$file"
			[[ $DOIT == '' ]] && echo > "${tgtDir}/${file}"
			#filesEdited+=("${tgtDir}/${file}")
		done
		rm -f "${tgtDir}/web/courseleaf/wizdebug.*"
		(( AitemCntr++ ))

		Msg "^$AitemCntr) Emptying directories (this may take a while)"
		for dir in $(echo $cleanDirs | tr ',' ' '); do
			Msg "^^$dir"
			if [[ -d $tgtDir/$dir ]]; then
				cd $tgtDir/$dir
				SetFileExpansion 'on'
				$DOIT rm -rf *
				SetFileExpansion
			fi
		done
		(( AitemCntr++ ))
		if [[ $removeGitReposFromNext == true ]]; then
			Msg "^$AitemCntr) Removing .git files/directories (relative to '$tgtDir')"
			cd $tgtDir
			for dirFile in $(find -maxdepth 4 -name '*.git*'); do
				Msg "^\t$dirFile"
				$DOIT rm -rf $dirFile
			done
		fi
		(( AitemCntr++ ))

		# Make sure that pdfererypage is set off 
		editFile="$localstepsDir/default.tcf"
		if [[ -f "$editFile" ]] ; then
			Msg "^$AitemCntr) Editing the 'localsteps/default.tcf' file..."
			backupFile "$editFile" "$backupDir"
			sed -i s'_^pdfeverypage:true_'//pdfeverypage:true_ "$editFile"
			sed -i s'_^pdfeverypage:true_'pdfeverypage:false_ "$editFile"
			Msg "^pdfeverypage set OFF (/web/courseleaf/localsteps/default.tcf') in the NEXT site"
		fi
		(( AitemCntr++ ))
		
		editFile="$tgtDir/$courseleafProgDir.cfg"
		#Msg "^Editing the '$courseleafProgDir.cfg' file..."
		backupFile "$editFile" "$backupDir"
		sed -i s'_^sitereadonly:Admin Mode_//sitereadonly:Admin Mode_'g "$editFile"
		Msg "^$AitemCntr) NEXT site admin mode set ON (/$courseleafProgDir.cfg)"

		Msg "*** Catalog advance completed in NEXT ***"
fi
#=======================================================================================================================

##======================================================================================================================
## Patch catalog
##======================================================================================================================
unset changeLogRecs processedDailysh skipProducts cgiCommands unixCommands 
[[ -n $comment ]] && changeLogRecs+=("$comment")
declare -A processedSpecs
## Refresh the products

for ((pcCntr=0; pcCntr<${#processControl[@]}; pcCntr++)); do
	processSpec="${processControl[$pcCntr]}"
	unset product source sourceModifier
	dump -1 -n processSpec
	product="${processSpec%%|*}"; processSpec="${processSpec#*|}"
	source="${processSpec%%|*}"; processSpec="${processSpec#*|}"
	[[ -n $processSpec ]] && sourceModifier="$processSpec"
	## Get the current product version
	prodVer="$(GetProductVersion $product "$tgtDir")"
	eval "${product}VerBefore=\"$prodVer\""
	dump -1 -t product ${product}VerBefore source processSpec sourceModifier

	Indent ++
	Msg; 
	if [[ -n $sourceModifier ]]; then
		Msg "Patching: $(ColorK "${product^^[a-z]}") (to $source / $sourceModifier) ..."
		changeLogRecs+=("${product^^[a-z]} (to $source / $sourceModifier)")
	else
		Msg "Patching: $(ColorK "${product^^[a-z]}") (to $source) ..."
		changeLogRecs+=("${product^^[a-z]} (to $source)")

	fi
	patchItemNum=1
	changesMade=false
	## Run through the action records for the product
		fields="recordType,sourceSpec,targetSpec,option"
		whereClause="lower(product)=\"$product\" and recordType<>\"currentRelease\" and status=\"Y\" order by orderInProduct"
		sqlStmt="select $fields from $patchesTable where $whereClause"
		RunSql $sqlStmt
		[[ ${#resultSet[@]} -le 0 || -z ${resultSet[0]} ]] && Warning 0 2 "No patch file specs found for '$product', skipping" && continue
		for ((ii=0; ii<${#resultSet[@]}; ii++)); do
			specLine="${resultSet[$ii]}"
			dump 2 -t -t specLine
			## Check to see if we have already processed this spec
				mapKey="${specLine// }"
				[[ ${processedSpecs["$mapKey"]+abc} ]] && continue

			processedSpecs["$mapKey"]=true
			recordType="${specLine%%|*}"; specLine="${specLine#*|}"
			specSource="${specLine%%|*}"; specLine="${specLine#*|}"
			specTarget="${specLine%%|*}"; specLine="${specLine#*|}"
			specOptions="${specLine%%|*}"; specLine="${specLine#*|}"
			## Perform string substitutions
			specSource=$(sed "s/<progDir>/$courseleafProgDir/g" <<< $specSource)
			specTarget=$(sed "s/<progDir>/$courseleafProgDir/g" <<< $specTarget)
			dump 2 -t -t -t recordType specSource specTarget specOptions

			## Process record
			Indent ++
			msgStr="$patchItemNum) Processing '$recordType' record: '${specSource}"
			performedAction=false
			case "${recordType,,[a-z]}" in
				git)
					msgStr="$msgStr --> ${specTarget}'"; [[ -n $specOptions ]] && msgStr="$msgStr ($specOptions)"
					Msg; Msg "$msgStr"; Indent ++
					[[ -z $specOptions ]] && specOptions="$sourceModifier"
					backupDir="$backupRootDir/${specTarget}"; mkdir -p "$backupDir"
					doit=true
					## Special processing if this is a dailysh request
					if [[ ${specSource,,[a-z]} == 'dailysh' && $processedDailysh != true ]]; then
						## Check to make sure we have a new daily.sh file in the target
						grepFile="${tgtDir}${specTarget}/daily.sh"
						if [[ -r $grepFile ]]; then
							grepStr=$(ProtectedCall "grep '## Nightly cron job for client' $grepFile")
							[[ -z $grepStr ]] && doit=false
						fi
						processedDailysh=true
					fi
					if [[ $doit == true ]]; then
						unset gitResults
						processGitRecord "${specSource}" "$specTarget" "$specOptions"
						[[ $gitResults == true ]] && Note "Files were updated, please check log for additional information" || \
													Msg "All files are current, no files updated"
						changesMade=true
					fi

					## If this is the primary repo then get the product version	
					if [[ $specSource == $product || $specSource == 'courseleaf' ]]; then
						prodVer="$(GetProductVersion $product "$tgtDir")"
						eval "${product}VerAfter=\"$prodVer\""
						if [[ $gitResults == true ]]; then
							tmpBefore="${product}VerBefore"; tmpBefore="${!tmpBefore}"; [[ -z $tmpBefore ]] && tmpBefore='N/A'
							tmpAfter="${product}VerAfter"; tmpAfter="${!tmpAfter}"
							Msg "Original '${product^^[a-z]}' version: $tmpBefore, New '${product^^[a-z]}' version: $tmpAfter" 
						fi
					fi
					performedAction=true
					;;
				rsync)
					[[ -z $specTarget ]] && specTarget="$specSource"
					msgStr="$msgStr --> ${specTarget}'"; [[ -n $specOptions ]] && msgStr="$msgStr ($specOptions)"
					Msg; Msg "$msgStr"; Indent ++
					[[ $specOptions == 'skeleton' ]] && specSource="${skeletonRoot}$specSource"
					if [[ ! -d "$specSource" ]]; then
						Error "'$specSource' is not a directory, rsync action is only valid for directories, skipping action"
					else
						backupDir="${backupRootDir}$(dirname "${specTarget}")"; mkdir -p "$backupDir"
						rsyncResults="$(RsyncCopy "$specSource" "$(dirname "${tgtDir}${specTarget}")" 'none' "$backupDir" )"
						if [[ $rsyncResults == true ]]; then
							Note "Files were synchronized, please check log for additional information"
							changesMade=true
						elif [[ $rsyncResults == false ]]; then
							Msg "All files are current, no files updated"
						else
							Msg "RsyncCopy ended with errors: $rsyncResults"
						fi
						[[ buildPatchPackage == true ]] && RsyncCopy "$specSource" "$(dirname "${packageRootDir}${specTarget}")" &
					fi
					performedAction=true
					;;
				cpfile)
					msgStr="$msgStr  ${specTarget}'"; Msg; Msg "$msgStr"; Indent ++
					unset srcFile srcFileVer
					if [[ $specOptions == 'cgi' ]]; then
						srcFile="$courseleafCgiSourceFile"; srcFileVer="$courseleafCgiVer"
						[[ $specSource != 'courseleaf' ]] && { srcFile="$ribbitCgiSourceFile"; srcFileVer="$ribbitCgiVer"; }
					elif [[ $specOptions == 'skeletion' ]]; then
						srcFile="${skeletonRoot}${specSource}"
					fi
					if [[ -f $srcFile ]]; then
						srcFileMd5=$(md5sum $srcFile);
						unset tgtFileMd5
						[[ -f ${tgtDir}${specTarget} ]] && tgtFileMd5=$(md5sum ${tgtDir}${specTarget})
						if [[ ${srcFileMd5%% *} != ${tgtFileMd5%% *} ]]; then
							backupDir="$(dirname "${backupRootDir}${specTarget}")"; mkdir -p "$backupDir"
							[[ -f ${tgtDir}${specTarget} ]] && cp -fp "${tgtDir}${specTarget}" "$backupDir"
							cp -fp "$srcFile" "${tgtDir}${specTarget}"
							[[ buildPatchPackage == true ]] && cpToPackageDir "${tgtDir}${specTarget}"
							[[ -n $srcFileVer ]] && Note "'${specTarget}' updated to version: $srcFileVer" || Note "'${specTarget}' updated"
							changesMade=true
						else
							Msg "All files are current, no files updated"
						fi
					else
						Warning "Source file '$srcFile' not found, skipping file copy"
					fi
					performedAction=true
					;;
				cgicommand)
					if [[ -z $specOptions ]] || [[ ${specOptions,,[a-z]} == 'always' ]] || \
						[[ ${specOptions,,[a-z]} == 'onchangeonly' && $changesMade == true ]]; then
						msgStr="$msgStr ${specTarget}"
						[[ -n $specOptions ]] && msgStr="$msgStr ($specOptions)"
						Msg; Msg "$msgStr"; Indent ++
						if [[ ${specTarget,,[a-z]} == '<allcims>' ]]; then
							GetCims "$tgtDir" -all
							if [[ -n $cimStr ]]; then
								for cim in $(echo $cimStr | tr ',' ' '); do
									Msg "^Republishing /$cim/index.tcf..."
									RunCourseLeafCgi "$tgtDir" "-r /$cim/index.tcf" | Indent | Indent
									cgiCommands+=("./courseleaf.cgi -r /$cim")
									## Should we rebuild the cim history database 
									if [[ $(CompareVersions "$cimVerAfterPatch" 'ge' '3.5.7 rc') == true && \
										$(CompareVersions "$cimVerBeforePatch" 'le' '3.5.7 rc') == true ]]; then
										Msg "^RebuildHistoryDb /$cim/index.tcf..."
										RunCourseLeafCgi "$tgtDir" "rebuildHistoryDb /$cim/index.tcf" | Indent | Indent
										cgiCommands+=("./courseleaf.cgi rebuildHistoryDb /$cim/index.tcf")
									fi
								done
							fi
						else
							RunCourseLeafCgi "$tgtDir" "$specSource $specTarget"
							cgiCommands+=("./courseleaf.cgi $specSource $specTarget")

						fi						
						performedAction=true
					fi
					;;
				command)
					if [[ -z $specOptions ]] || [[ ${specOptions,,[a-z]} == 'always' ]] || \
						[[ ${specOptions,,[a-z]} == 'onchangeonly' && $changesMade == true ]]; then
						msgStr="$msgStr  ${specTarget} ($specOptions)'"; Msg; Msg "$msgStr"; Indent ++
						Pushd "$tgtDir"
						eval "${specSource} ${specTarget}" | Indent
						[[ $? -eq 0 ]] && changeLogRecs+=("Executed unix command: '$specSource'") || \
							Error "Command returned a non-zero condition code"
						Popd
						[[ $buildPatchPackage == true ]] && unixCommands+=("$specSource")
						performedAction=true
					fi
					;;
				compare)
					msgStr="$msgStr  ${specTarget} ($specOptions)'"; Msg; Msg "$msgStr"; Indent ++
					if [[ -f "${tgtDir}${specSource}" ]]; then
						tgtFile="${tgtDir}${specSource##* }"
						tgtFileMd5=$(md5sum $tgtFile)
						[[ $specTarget == 'skeleton' ]] && compareToFile="$skeletonRoot${specSource##* }"
						if [[ -f $compareToFile ]]; then
							cmpFileMd5=$(md5sum $compareToFile)
							if [[ ${tgtFileMd5%% *} != ${cmpFileMd5%% *} ]]; then
								msgLevel='Warning'
								[[  ${specOptions,,[a-z]} == 'error' ]] && msgLevel='Errof'
								$msgLevel "'${specSource##* }' file is different than the skeleton file, you should consult with development if the file should be updated"
								if [[ $(Contains "${specOptions,,[a-z]}" 'only') != true ]]; then
									Indent ++
									Msg "${colorRed}< is ${compareToFile}${colorDefault}"
									Msg "${colorBlue}> is ${tgtFile}${colorDefault}"
									ProtectedCall "colordiff $compareToFile $tgtFile | Indent"
									Msg "$colorDefault"
									Indent --
								fi
							else
								Msg "^File is current"
							fi
						else
							Warning 0 +1 "Source file '$compareToFile', not found.  Cannot compare"
						fi
					fi
					performedAction=true
					;;
				include)
					for ((i2=$ii+1; i2<${#resultSet[@]}; i2++)); do remaining+=("${resultSet[$i2]}"); done
					fields="recordType,sourceSpec,targetSpec,option"
					whereClause="lower(product)=\"$specSource\" and recordType<>\"currentRelease\" and status=\"Y\" order by orderInProduct"
					sqlStmt="select $fields from $patchesTable where $whereClause"
					RunSql $sqlStmt
					if [[ ${#resultSet[@]} -le 0 || -z ${resultSet[0]} ]]; then
						Warning 0 2 "No patch file specs found for '$specSource', skipping"
					else
						for ((i2=0; i2<${#remaining[@]}; i2++)); do resultSet+=("${remaining[$i2]}"); done
					fi
					ii=-1
					;;
				*) Terminate "^^Encountered and invalid processing type '$recordType'\n^$specLine"
					;;
			esac
			Indent --
			[[ $performedAction == true ]] && { ((patchItemNum++)); Indent --; }
		done #Process records
	Msg
	Msg "*** ${product^^[a-z]} updates completed ***"
	Indent --
done ## processSpec (aka products)
Indent --
Msg
Msg "\n*** All requested product updates completed ***"
#=======================================================================================================================

#=======================================================================================================================
## Cross product checks / updates
#=======================================================================================================================
Msg
CPitemCntr=1
Msg "\nCross product checks..."
## Check to see if there are any old formbuilder widgets
	if [[ $client != 'internal' && -n $locallibsDir && -d "$locallibsDir/locallibs" ]]; then
		checkDir="$locallibsDir/locallibs/widgets"
		fileCount=$(ls "$checkDir" 2> /dev/null | grep 'banner_' | wc -l)
		[[ $fileCount -gt 0 ]] && Warning 0 1 "Found 'banner' widgets in '$checkDir', these are probably deprecated, please ask a CIM developer to evaluate."
		fileCount=$(ls "$checkDir" 2> /dev/null | grep 'psoft_' | wc -l)
		[[ $fileCount -gt 0 ]] && Warning 0 1 "Found 'psoft' widgets in '$checkDir', these are probably deprecated, please ask a CIM developer to evaluate."
	fi
## Check /ribbit/getcourse.rjs file
	checkFile="$tgtDir/web/ribbit/getcourse.rjs"
	if [[ -f "$checkFile" ]]; then
		skelDate=$(date +%s -r $skeletonRoot/web/ribbit/getcourse.rjs)
		fileDate=$(date +%s -r $tgtDir/web/ribbit/getcourse.rjs)
		if [[ $skelDate -gt $fileDate ]]; then
			echo
			text="The time date stamp of the file '$tgtDir/web/ribbit/getcourse.rjs' is less "
			text="$text than the time date stamp of the file in the skeleton, you should compare the files and merge"
			text="$text any required changes into '$tgtDir/web/ribbit/getcourse.rjs'."
			Warning 0 1 "$text"
		fi
	fi
## Edit the console page
##	1) change title to 'CourseLeaf Console' (requested by Mike 02/09/17)
## 	2) remove 'System Refresh' (requested by Mike Miller 09/13/17)
## 	3) remove 'localsteps:links|links|links' (requested by Mike Miller 09/13/17)
## 	4) Add 'navlinks:CAT|Rebuild Course Bubbles and Search Results'
	Msg "^Checking /web/$courseleafProgDir/index.tcf..."
	editFile="$tgtDir/web/$courseleafProgDir/index.tcf"
	if [[ -w "$editFile" ]]; then
		fromStr='title:Catalog Console'
		toStr='title:CourseLeaf Console'
		grepStr=$(ProtectedCall "grep '^$fromStr' $editFile")
		if [[ -n $grepStr ]]; then
			backupFile "$editFile" "$backupRootDir"
			sed -i s"!^$fromStr!$toStr!" $editFile
			[[ buildPatchPackage == true ]] && cpToPackageDir "$editFile"
			updateFile="/$courseleafProgDir/index.tcf"
			changeLogRecs+=("$updateFile updated to change title")
			Msg "^Updated '$updateFile' to change 'title:Catalog Console' to 'title:CourseLeaf Console'"
			rebuildConsole=true
		fi

		fromStr='navlinks:CAT|Refresh System|refreshsystem'
		toStr='// navlinks:CAT|Refresh System|refreshsystem'
		grepStr=$(ProtectedCall "grep '^$fromStr' $editFile")
		if [[ -n $grepStr ]]; then
			backupFile "$editFile" "$backupRootDir"
			sed -i s"!^$fromStr!$toStr!" $editFile
			[[ buildPatchPackage == true ]] && cpToPackageDir "$editFile"
			updateFile="/$courseleafProgDir/index.tcf"
			changeLogRecs+=("$updateFile updated to change title")
			Msg "^Updated '$updateFile' to remove 'Refresh System'"
			rebuildConsole=true
		fi

		fromStr='localsteps:links|links|links'
		toStr='// localsteps:links|links|links'
		grepStr=$(ProtectedCall "grep '^$fromStr' $editFile")
		if [[ -n $grepStr ]]; then
			backupFile "$editFile" "$backupRootDir"
			sed -i s"!^$fromStr!$toStr!" $editFile
			[[ buildPatchPackage == true ]] && cpToPackageDir "$editFile"
			updateFile="/$courseleafProgDir/index.tcf"
			changeLogRecs+=("$updateFile updated to change title")
			Msg "^Updated '$updateFile' to remove 'localsteps:links|links|links"
			rebuildConsole=true
		fi

		#navlinks:CAT|Rebuild Course Bubbles and Search Results|mkfscourses^^<h4>Rebuild Course Bubbles and Search Results</h4>Rebuild the course description pop-up bubbles, and also search results.^steptitle=Rebuilding Course Bubbles and Search Results
		fromStr='localsteps:links|links|links'
		toStr='// localsteps:links|links|links'
		grepStr=$(ProtectedCall "grep '^$fromStr' $editFile")
		if [[ -n $grepStr ]]; then
			backupFile "$editFile" "$backupRootDir"
			sed -i s"!^$fromStr!$toStr!" $editFile
			[[ buildPatchPackage == true ]] && cpToPackageDir "$editFile"
			updateFile="/$courseleafProgDir/index.tcf"
			changeLogRecs+=("$updateFile updated to change title")
			Msg "^Updated '$updateFile' to remove 'localsteps:links|links|links"
			rebuildConsole=true
		fi
	else
		Msg
		Warning 0 2 "Could not locate '$editFile', please check the target site"
	fi

## Edit /localsteps/default.tcf
	##	1) Remove uploadurl from the default.tcf file(requested by Ben 04/05/18)
	Msg "^Checking $localstepsDir/default.tcf..."
	if [[ $(CompareVersions "$(GetProductVersion 'cat' "$siteDir")" 'ge' '3.5.10') == true ]]; then
		editFile="$localstepsDir/default.tcf"
		if [[ -f "$editFile" ]]; then
			fromStr='uploadurl:'
			grepStr=$(ProtectedCall "grep '^$fromStr' $editFile")
			if [[ -n $grepStr ]]; then
				backupFile "$editFile" "$backupRootDir"
				sed -i "/^$fromStr/d" $editFile
				[[ buildPatchPackage == true ]] && cpToPackageDir "$editFile"
			fi
			fromStr='cimuploadurl:'
			grepStr=$(ProtectedCall "grep '^$fromStr' $editFile")
			if [[ -n $grepStr ]]; then
				backupFile "$editFile" "$backupRootDir"
				sed -i "/^$fromStr/d" $editFile
				[[ buildPatchPackage == true ]] && cpToPackageDir "$editFile"
			fi
		fi
	fi

## Move / move fsinjector.sqlite to the ribbit folder (requested by Mike 06/03/17)
	checkFile="$tgtDir/web/ribbit/fsinjector.sqlite"
	Msg "^Checking /web/ribbit/fsinjector.sqlite..."
	if [[ ! -f $checkFile ]]; then
		[[ -f "$tgtDir/db/fsinjector.sqlite" ]] && mv -f "$tgtDir/db/fsinjector.sqlite" "$checkFile"
		editFile="$cfgFile"
		fromStr=$(ProtectedCall "grep '^db:fsinjector|sqlite|' $editFile")
		toStr='db:fsinjector|sqlite|/ribbit/fsinjector.sqlite'
		[[ buildPatchPackage == true ]] && cpToPackageDir "$editFile"
		sed -i s"_^${fromStr}_${toStr}_" "$editFile"
		Msg "^Updated '$editFile' to change changed the mapfile record for 'db:fsinjector' to point to the ribbit directory"
	fi

## Rebuild console & approve pages
	if [[ $rebuildConsole == true ]]; then
		Msg "^Republishing CourseLeaf console & approve pages..."
		RunCourseLeafCgi "$tgtDir" "-r /$courseleafProgDir/index.html" | Indent
		RunCourseLeafCgi "$tgtDir" "-r /$courseleafProgDir/approve/index.html" | Indent
	fi

## Check to see if there are any 'special' cgis installed, see if they are still necessary
	tgtVer="$($tgtDir/web/$courseleafProgDir/$courseleafProgDir.cgi -v 2> /dev/null | cut -d" " -f3)"
	for checkDir in tcfdb; do
		if [[ -f $tgtDir/web/$courseleafProgDir/$checkDir/courseleaf.cgi ]]; then
			checkCgiVer="$($tgtDir/web/$courseleafProgDir/$checkDir/$courseleafProgDir.cgi -v 2> /dev/null | cut -d" " -f3)"
			if [[ $(CompareVersions "$checkCgiVer" 'le' "$tgtVer") == true ]]; then
				Msg "^Found a 'special' courseleaf cgi directory ($checkDir) and the version of that cgi ($checkCgiVer) is less than the target version ($tgtVer).  Removing the directory"
				BackupCourseleafFile "$tgtDir/web/$courseleafProgDir/$checkDir" "$backupRootDir"
				backupFile "$tgtDir/web/$courseleafProgDir/$checkDir" "$backupRootDir"
				rm -f $tgtDir/web/$courseleafProgDir/$checkDir
				changeLogRecs+=("Removed '$tgtDir/web/$courseleafProgDir/$checkDir'")
			fi
		fi
	done
#=======================================================================================================================

## If we took the site offline, then put it back online
	if [[ $offline == true ]]; then
		## uncomment the user records, remove the siteadmin: record from the bottoms
		Msg; Msg "Bringing the site back online"
		editFile="$tgtDir/$courseleafProgDir.cfg" 
		sed -e '/user:/ s|^//||' -i "$editFile"
		line=$(tail -1 "$editFile")
		[[ $line == 'sitereadonly:true' ]] && sed -i '$ d' "$editFile"
		offline=false
	fi

## Wait for the curr site to finish publising
	[[ $fullAdvance == true ]] && { Msg; Msg "Waiting for the republish of the new CURR site to complete..."; wait; }

## Write out a changelog entry updates
	if [[ ${#backedupFiles[@]} -gt 0 ]]; then
		changeLogRecs+=("\tFiles edited:")
		for mapCtr in "${!backedupFiles[@]}"; do
			data="$(ParseCourseleafFile "$file")"
			changeLogRecs+=("\t\t${data##* }")
		done;
	fi
	WriteChangelogEntry 'changeLogRecs' "$tgtDir/changelog.txt"

## tar up the backup files
	Msg
	Msg "Generating the backup tar file..."
	backupTarFile="$myName-$(date +"%m-%d-%y@%H-%M-%S").prePatch.tar.gz"
	Pushd "$backupRootDir"
	SetFileExpansion 'off'
	ProtectedCall "tar -czf $backupTarFile * --exclude '*.gz' --remove-files" &> /dev/null
	[[ -f ../$backupTarFile ]] && rm -f "../$backupTarFile"
	$DOIT mv "$backupTarFile" ..
	cd ..
	$DOIT rm -rf "$backupRootDir"
	SetFileExpansion
	Popd

## tar up the remote package files
	if [[ $buildPatchPackage == true ]]; then
		patchTarFile="$myName-$(date +"%m-%d-%y@%H-%M-%S").patch.tar.gz"
		Msg "Generating the remote patch tar file..."
		Msg "" > "$packageRootDir/README"
		Msg "Please follow the following instructions to install this patch, if you have questions please contact your CourseLeaf support rep." >> "$packageRootDir/README" 
		Msg "" >> "$packageRootDir/README" 
		Msg "^1) Download the tar file and copy it to the site root directory" >> "$packageRootDir/README"
		Msg "^^(i.e. just before the 'web' directory)" >> "$packageRootDir/README"
		Msg "" >> "$packageRootDir/README"
		Msg "^2) cd to the above directory " >> "$packageRootDir/README"
		Msg "" >> "$packageRootDir/README"
		Msg "^3) Un-tar the file (e.g. tar -xvf ./$patchTarFile)" >> "$packageRootDir/README"
		Msg "^^(e.g. tar -xvf <tarFileName>)" >> "$packageRootDir/README"
		Msg "" >> "$packageRootDir/README"
		if [[ ${#unixCommands[@]} -ne 0 ]]; then
			Msg "^4) Run the following commands from the command line:" >> "$packageRootDir/README"
			for ((i=0; i<${#unixCommands[@]}; i++)); do
				Msg "^^${unixCommands[$i]}" >> "$packageRootDir/README"
			done
			Msg "" >> "$packageRootDir/README"
		fi
		if [[ ${#cgiCommands[@]} -ne 0 ]]; then
			Msg "^5) cd to the courseleaf directory just under the web directory and run the following courseleaf commands:" >> "$packageRootDir/README"
			Msg "^^(i.e. cd ./web/courseleaf)" >> "$packageRootDir/README"
			for ((i=0; i<${#cgiCommands[@]}; i++)); do
				Msg "^^${cgiCommands[$i]}" >> "$packageRootDir/README"
			done
			Msg "" >> "$packageRootDir/README"
		fi
		Pushd "$packageRootDir"
		SetFileExpansion 'off'
		ProtectedCall "tar -czf $patchTarFile * --exclude '*.gz' --remove-files" &> /dev/null
		[[ -f ../$patchTarFile ]] && rm -f "../$patchTarFile"
		$DOIT mv "$patchTarFile" ..
		cd ..
		$DOIT rm -rf "$packageRootDir"
		SetFileExpansion
		Popd
		Note 0 1 "A remote patch file was created and located at '$patchTarFile'."
		Note 0 1 "Additional install information can be found in the README file in the patch tar."
	fi

## Product messages
	if [[ $(Contains ",$products," ',cat,') == true ]]; then
		Msg
		Msg "$(ColorN *** IMPORTANT ***)"
		Msg "1) The pages database on the target site should be rebuilt please goto ${client^^[a-z]}'s 'CourseLeaf Console' and use the 'Rebuld PageDB' or 'RefreshSystem' action to rebuild the pages database."
		Msg
		Msg "2) The target site needs to be republished, please goto ${client^^[a-z]}'s 'CourseLeaf Console' and use the 'Republish Site' action to rebuild the site."
		Msg	
	fi

## Tell the user what to do if there are problems
	Msg
	Msg "$(ColorN *** IMPORTANT ***)"
	Msg "1) Should you need to restore the target site's files to what they were before the patch was applied simply run this script ($myName) specifying the '-rollback' option, i.e. '$myName -rollback."

#tar -xvf ZendFramework-1.7.2.tar.gz --strip 1

	[[ $backup == true ]] && Msg "2) A backup copy was made of the $(Upper $env) site, once you have verified that the patch results are satisfactory you should delete the backup site '$backupSite'"

# if [[ $nextGitFilesChanged == true || $currGitFilesChanged == true ]]; then
# 	echo
# 	Note "Files where changed that are under git management:"
# 	[[ $nextGitFilesChanged == true ]] && Msg "^NEXT -- $tgtDir/.git"
# 	[[ $currGitFilesChanged == true ]] && Msg "^CURR -- $(dirname $tgtDir)/curr/.git"
#  	Msg "$(ColorN "See above for details, you should commit those changes before proceeding.")"
#  	echo
# fi

#=======================================================================================================================
## Done
#=======================================================================================================================
cd "$cwdStart"
text1='Refresh/Patch of'
text2="$Upper($client/$env)"
[[ $noCheck == true ]] && text2="$tgtDir"
Goodbye 0 "$text1" "$text2"

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
## Tue Jun 21 12:49:50 CDT 2016 - dscudiero - Updated messaging, cgi directory selection, and moved to Msg
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
## 04-17-2017 @ 10.31.31 - 5.0.124 - dscudiero - fixed for selectMenuNew changes
## 04-27-2017 @ 11.10.21 - 5.0.125 - dscudiero - Fixed error reporting rsync errors
## 05-10-2017 @ 07.02.02 - 5.1.22 - dscudiero - Add support for remote patch packages
## 05-10-2017 @ 07.08.45 - 5.1.23 - dscudiero - fix problem setting ownership in the remote pachage
## 05-12-2017 @ 13.46.25 - 5.1.63 - dscudiero - Fix numerious problems with the patch package
## 06-05-2017 @ 07.58.16 - 5.1.88 - dscudiero - Added support for selected refresh of index.cgi in the search directory
## 06-05-2017 @ 11.04.04 - 5.1.95 - dscudiero - Tweaked messaging for product, fixed editing of courseleaf console
## 06-05-2017 @ 14.52.03 - 5.1.101 - dscudiero - Added checing for deprecated formbuilder widgets
## 06-13-2017 @ 12.46.00 - 5.1.105 - dscudiero - g
## 06-19-2017 @ 07.14.10 - 5.2.-1 - dscudiero - Added the include calability back
## 06-19-2017 @ 15.07.53 - 5.2.-1 - dscudiero - Add setting of siteadminmode in the curr site
## 06-19-2017 @ 15.39.16 - 5.2.-1 - dscudiero - Added report as an option to compare directive
## 06-26-2017 @ 10.14.14 - 5.2.0 - dscudiero - Updated for new requirements
## 06-26-2017 @ 15.33.06 - 5.2.1 - dscudiero - Make not having a locallibs directory a warning
## 06-26-2017 @ 15.48.08 - 5.2.2 - dscudiero - General syncing of dev to prod
## 07-17-2017 @ 11.33.20 - 5.2.4 - dscudiero - Updated code checking for locallibs directory
## 07-17-2017 @ 16.25.46 - 5.2.6 - dscudiero - check to see if source file exists for compare actions
## 07-19-2017 @ 14.37.32 - 5.2.10 - dscudiero - Update how the cgi files are sourced
## 07-20-2017 @ 11.08.42 - 5.2.20 - dscudiero - Fix problem where commands were not being run
## 07-20-2017 @ 12.41.43 - 5.2.22 - dscudiero - Move the setting of the permisions for /search/index.cgi into the searchcgi record processing in the script
## 07-24-2017 @ 07.57.41 - 5.2.23 - dscudiero - remove trailing blanks in the log file entries
## 08-02-2017 @ 09.32.38 - 5.3.9 - dscudiero - Updates to cgi selection and add git processing
## 08-02-2017 @ 11.20.43 - 5.3.12 - dscudiero - Change not having a locallibs directory a warning
## 08-02-2017 @ 15.12.51 - 5.3.24 - dscudiero - Fix problem not setting processControl for proucts not in git e.g. cgis
## 08-07-2017 @ 13.51.42 - 5.4.0 - dscudiero - Refreshed how git controlled files are handled
## 08-07-2017 @ 13.58.18 - 5.4.1 - dscudiero - Allow only mzollo and epingel to run the script
## 08-07-2017 @ 14.12.41 - 5.4.0 - dscudiero - Add dscudiero to the allow list
## 08-07-2017 @ 15.52.39 - 5.4.1 - dscudiero - Add checkProdEnv on the Init calls, verify the user can change a production env
## 08-07-2017 @ 17.00.43 - 5.4.2 - dscudiero - remove debug code
## 09-05-2017 @ 08.06.54 - 5.4.4 - dscudiero - Added --ignore-times to the rsync options
## 09-06-2017 @ 13.24.30 - 5.4.5 - dscudiero - Remove ignore-times directive on rsync
## 09-20-2017 @ 15.31.32 - 5.4.17 - dscudiero - Released latest change to edit the console
## 09-21-2017 @ 07.06.18 - 5.4.27 - dscudiero - Comment out the refresh of the auth table
## 09-25-2017 @ 09.48.48 - 5.4.30 - dscudiero - Switch to Msg
## 10-02-2017 @ 17.07.54 - 5.5.0 - dscudiero - Switch to GetExcel
## 10-03-2017 @ 07.14.03 - 5.5.0 - dscudiero - Add Alert to include list
## 10-16-2017 @ 16.40.53 - 5.5.0 - dscudiero - Tweak messaging when reporting the uncommitte git files
## 11-02-2017 @ 06.58.37 - 5.5.0 - dscudiero - Switch to ParseArgsStd
## 11-02-2017 @ 10.27.55 - 5.5.0 - dscudiero - use help2
## 11-02-2017 @ 10.53.32 - 5.5.0 - dscudiero - Add addPvt to the Init call
## 11-30-2017 @ 13.26.33 - 5.5.0 - dscudiero - Switch to use the -all flag on the GetCims call
## 12-01-2017 @ 12.27.36 - 5.5.0 - dscudiero - Remove the hard coded override to always patch from the master release
## 12-20-2017 @ 07.05.24 - 5.5.10 - dscudiero - Add to indentention level before calling Rsync
## 12-20-2017 @ 07.19.54 - 5.5.11 - dscudiero - Cosmetic/minor change
## 12-20-2017 @ 07.21.42 - 5.5.13 - dscudiero - Cosmetic/minor change
## 12-20-2017 @ 14.45.55 - 5.5.22 - dscudiero - Fix problem where ((indentLevel++)) breaks if starting value is 0
## 01-24-2018 @ 10.58.48 - 5.5.44 - dscudiero - Cosmetic/minor change/Sync
## 01-24-2018 @ 13.33.01 - 5.5.45 - dscudiero - Move the backup site to be at the same level as the target directory.
## 03-22-2018 @ 13:25:41 - 5.5.47 - dscudiero - Updated for Msg/Msg, RunSql/RunSql, ParseArgStd/ParseArgStd2
## 03-22-2018 @ 14:06:23 - 5.5.48 - dscudiero - Updated for Msg/Msg, RunSql2/RunSql, ParseArgStd/ParseArgStd2
## 03-23-2018 @ 11:56:10 - 5.5.49 - dscudiero - Updated for GetExcel2/GetExcel
## 03-23-2018 @ 15:33:41 - 5.5.50 - dscudiero - D
## 03-23-2018 @ 16:57:48 - 5.5.51 - dscudiero - Msg3 -> Msg
## 04-02-2018 @ 07:15:41 - 5.5.66 - dscudiero - Move timezone report to weeky
## 04-02-2018 @ 10:12:05 - 5.5.72 - dscudiero - Comment out new code to check versions
## 04-02-2018 @ 13:51:29 - 5.5.104 - dscudiero - Added code to rebuild the history db for cims
## 04-03-2018 @ 10:37:16 - 5.5.105 - dscudiero - Add force check in version compare
## 04-03-2018 @ 10:59:45 - 5.5.110 - dscudiero - Fix problem not prompting for version
## 04-05-2018 @ 10:25:27 - 5.5.111 - dscudiero - Only allow the major products to be selectable for products to patch
## 04-05-2018 @ 11:28:11 - 5.5.113 - dscudiero - Dump out the rsync parameters to the log file
## 04-09-2018 @ 07:40:40 - 5.5.134 - dscudiero - Fix problem with removeing programadmin, add additional items from Melanies email
## 04-09-2018 @ 10:08:02 - 5.6.0 - dscudiero - Fix problem with sed statement syntaz
## 04-12-2018 @ 14:44:53 - 5.6.14 - dscudiero - Fix problem when the target site does not have a clver.txt file
## 04-18-2018 @ 09:36:18 - 5.6.16 - dscudiero - Cleaned up GetDefaultsData call
## 04-26-2018 @ 09:04:02 - 6.0.0 - dscudiero - Cosmetic/minor change/Sync
## 05-04-2018 @ 09:55:43 - 6.0.0 - dscudiero - Rename to DatabaseUtilities.sh
## 05-10-2018 @ 09:24:02 - 6.0.0 - dscudiero - Resynce, many changes
## 05-10-2018 @ 11:49:57 - 6.0.0 - dscudiero - Added removing cimloaderurl
## 05-10-2018 @ 12:13:32 - 6.0.1 - dscudiero - Moved setting of skeletonRoot after parsing args
## 05-10-2018 @ 14:13:35 - 6.0.2 - dscudiero - Only copy the .gitignore file if it is found
## 05-10-2018 @ 15:26:31 - 6.0.3 - dscudiero - Add debug
## 05-11-2018 @ 08:04:55 - 6.0.11 - dscudiero - Fix bug overriding the gitTag
## 05-11-2018 @ 08:37:06 - 6.0.13 - dscudiero - Change messaging from 'compare' operation
## 05-11-2018 @ 08:46:33 - 6.0.14 - dscudiero - Allow specification of the current release to be in any of the columns in the row as long as the recordType is 'currentRelease'
## 05-17-2018 @ 11:23:53 - 6.0.21 - dscudiero - Misc cleanup
