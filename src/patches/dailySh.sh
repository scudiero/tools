#==================================================================================================
version=1.2.57 # -- dscudiero -- 12/14/2016 @  9:29:05.42
#==================================================================================================
imports='ParseArgs ParseArgsStd ParseCourseleafFile'
Import "$imports"
scriptDescription="Patch courseleaf /bin/daily.sh"

checkParent='patchcourseleaf.sh'
[[ "${BASH_SOURCE[0]}" != "${0}" ]] && calledFrom="$(Lower "$(basename "${BASH_SOURCE[1]}")")" || calledFrom="$(Lower "$(basename "${BASH_SOURCE[2]}")")"
[[ $calledFrom != $checkParent && $calledFrom != 'call.sh' ]] && Terminate "Sorry, this script can only be called from '$checkParent', \nCurrent call parent: '$calledFrom' \nCall Stack: $(GetCallStack)"

#= Description +===================================================================================
# Patch the daily.sh file for sites that have the new daily.sh installed
# (Has '## Nightly cron job for client')
# Script expects to be called by courseleafPatch.
#==================================================================================================
dump -1 client envs minCgiver minClver patchId
SetIndent '+1'

#==================================================================================================
# Declare local variables and constants
#==================================================================================================
searchFile="/bin/daily.sh"
updateFiles="/bin/daily.sh"
srcDir=/mnt/dev6/web/_skeleton/release

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
client="$1"; shift
envs="$1"; shift
patchId="$1"; shift

[[ $client == '' ]] && Msg2 $T "'Client' variable has not been set, cannot continue"
[[ $envs == '' ]] && Msg2 $T "'Env/envs' variable has not been set, cannot continue"
[[ $patchId == '' ]] && Msg2 $T "'PatchId' variable has not been set, cannot continue"

ParseArgs

#==================================================================================================
# Main
#==================================================================================================
## Find files
	Msg2 "Gathering sites on host $(hostname)..."
	SetIndent '+1'
	unset files
	SetFileExpansion 'on'
	if [[ $testMode != true ]]; then
		## Search for files
		SetFileExpansion 'on'
		processedDev=false
		[[ $envs == 'all' ]] && envs='test,next,curr'
		for env in $(echo $envs | tr ',' ' '); do
			Msg2 "Scanning $(Upper $env) sites..."
			if [[ $env == 'dev' || $env == 'pvt' ]]; then
				[[ $client != '' && $client != 'all' && $client != '*' && $env == 'pvt' ]] && clientNode="$client-*" || clientNode="$client"
				[[ $processedDev == false  ]] && files+=($(ls /mnt/dev*/web/${clientNode}${searchFile} 2>/dev/null | xargs grep '## Nightly cron job for client' 2>/dev/null | cut -d':' -f1))
				processedDev=true
			else
				[[ $client != '' && $client != 'all' && $client != '*' ]] && clientNode="$client" || clientNode='*'
				files+=($(ls /mnt/*/${clientNode}/${env}${searchFile} 2>/dev/null | xargs grep '## Nightly cron job for client' 2>/dev/null | cut -d':' -f1))
			fi
		done
		SetFileExpansion
		[[ ${#files[@]} -eq 0 ]] && unset siteDirs && Msg2 $WT1  "No sites found by search, no changes made" && SetIndent '-2' && return 0
		Msg2 "Found ${#files[@]} sites"
	else
		Msg2 "\t$env (testMode)..."
		files+=("$HOME/testData/$env/$searchFile")
	fi

## Get the max width of a client name
	sqlStmt="select max(length(name)) FROM $clientInfoTable"
	RunSql 'mysql' $sqlStmt
	let maxClientNameLen=${resultSet[0]}+5

## Loop through sites and apply patch
	[[ $informationOnlyMode != true ]] && Msg2 "Applying patch..." || Msg2 "The following sites would be patched..."
	SetIndent '+1'
	unset patchedSiteDirs sitesStr
	for siteDir in ${files[@]}; do
		#[[ $client != '' && $client != 'all' && $client != '*' && $(Contains "$siteDir" "/$client") == false ]] && continue
		chkStr=$(ParseCourseleafFile "$siteDir")
		chkStr="$(cut -d' ' -f1 <<< $chkStr)/$(cut -d' ' -f2 <<< $chkStr)"

		## Is this client on the exclude list?
		removeFromList=false
		for exclude in $(tr ',' ' ' <<< $excludeList); do
			[[ $exclude == $chkStr ]] && removeFromList=true && break
		done
		[[ $removeFromList == true ]] && continue
		## Trim off the search file string from the returned file names
		siteDir="${siteDir%$searchFile}"
		chkStr="$(sed s"/-test//" <<< $chkStr)"
		sitesStr="$sitesStr,$chkStr"
		patchedSiteDirs+=("$chkStr","$siteDir")

		chkStr="${chkStr}$(PadChar ' ' $maxClientNameLen)"
		chkStr="${chkStr:0:$maxClientNameLen}"

		#version=2.8.81 # -- dscudiero -- 07/11/2016 @ 15:52:14.90
		tgtVer=$(ProtectedCall "grep 'version=' ${siteDir}${searchFile}")
		tgtVerPart1=$(cut -d'=' -f2 <<< $tgtVer) ; tgtVerPart1=$(cut -d' ' -f1 <<< $tgtVerPart1)
		tgtVerPart2=$(cut -d' ' -f6 <<< $tgtVer)
		tgtVer="($tgtVerPart1 - $tgtVerPart2)"

		Msg2 "${chkStr} -- ${siteDir} $tgtVer"
		[[ $informationOnlyMode == true ]] && continue
		unset changeLogLines
		for file in $updateFiles; do
			Msg2 'V,1,+1,S' "$file"
			unset cpResult
			if [[ $DOIT == '' ]]; then
				cpResult=$(CopyFileWithCheck "${srcDir}${file}" "${siteDir}${file}" 'courseleaf')
				[[ $cpResult != true ]] && Msg "T Could not copy file: \n\tsrcFile: '$srcDir/$file' \n\ttgtFile: '$siteDir/$file' \n\t$cpResult"
				chmod 744 $siteDir/$file
				changeLogLines+=("Patched ($patchId): $file")
			fi
		done
		## Write out change log record
		WriteChangelogEntry 'changeLogLines' "$siteDir/changelog.txt" 'changeLogEntry'
	done
	sitesStr=${sitesStr:1}
	SetIndent '-1'
	Msg2
	[[ $informationOnlyMode == true ]] && Msg2 "Analysis completed on host $(hostname)" || Msg2 "Patching completed on host $(hostname)"
	Msg2

## Log the patch run
	if [[ $informationOnlyMode != true && ${#patchedSiteDirs[@]} -gt 0 ]]; then
		sqlStmt="insert into $courseleafPatchLogTable values(NULL,\"$patchId\",\"$client\",\"$envs\",\"$userName\",NOW(),\"$sitesStr\")"
		$DOIT RunSql 'mysql' "$sqlStmt"
	fi

##==================================================================================================
## Done
#===================================================================================================
SetIndent '-2'
return 0
