version=1.0.1 # -- dscudiero -- 04/26/2016 @  6:57:49.56
scriptDescription="Patch courseleaf /bin/daily.sh"
TrapSigs 'on'

caller='courseleafPatch'
[[ $(basename $(caller | cut -d' ' -f2) | cut -d'.' -f1) != $caller ]] && Msg2 $T "Sorry this command can only be called by '$caller'"

#==================================================================================================
## Copyright ©2015 David Scudiero -- all rights reserved.
## 09-02-15 -- 	dgs - Initial coding
#==================================================================================================
#==================================================================================================
# local callbacks
#==================================================================================================
	#==============================================================================================
	# parse script specific arguments
	#==============================================================================================
	function parseArgs-addHelpStep  {
		: #argList+=(-all,2,switch,allEnvs,'Patch all envs -- test next curr')
	}
	function testMode-addHelpStep  {
		client="dscudiero-test"
		env=dev
	}

#==================================================================================================
# Declare local variables and constants
#==================================================================================================
eval $trapErrOn
version=1.0
patchDir=/web/courseleaf/steps
patchFile=help.html
srcDir=$skeletonRoot/release/web/courseleaf/steps
srcFile="$srcDir/$patchFile"
allEnvs='test next curr'

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
helpSet='client,script'
ParseArgsStd
Hello
Msg
[[ $allItems == true ]] && env="$allEnvs" || Prompt env 'Which environment do you with to patch?' 'dev test next curr all'
[[ $env == 'all' ]] && env="$allEnvs"
VerifyContinue "Do you wish to apply patch '$myName' ?\n\tFile to patch: '$patchDir/$patchFile'\n\tsrcFile: $srcFile\n\tEnv(s): $env"

#==================================================================================================
# Main
#==================================================================================================
for env in ${env[@]}; do
	Msg "Processing  $(Upper $env)"
	## If client specified then set dirs to the client dir
		if [[ $client != '' ]]; then
			SetSiteDirs 'setDefault'
			eval clientRoot=\$${env}Dir
			dirs=($clientRoot$patchDir)
		else
			Msg "\tGetting directory list (takes a while)..."
			if [[ $env == 'dev' ]]; then
				dirs=$(ls -d /mnt/dev*/web/*/$patchDir)
			else
				dirs=$(ls -d /mnt/*/*/$(Lower $env)$patchDir)
			fi
		fi

	## Loop through the client drectories
		for dir in ${dirs[@]}; do
			dump -1 -t dir
			srcFile="$srcDir/$patchFile"
			tgtFile=$dir/$patchFile
			srcMd5=$(md5sum $srcFile | cut -f1 -d" ")
			tgtMd5=$(md5sum $tgtFile | cut -f1 -d" ")
			if [[ $srcMd5 != $tgtMd5 ]]; then
				$DOIT BackupCourseleafFile "$tgtFile"
				[[ $DOIT == '' ]] && cp -fpv "$srcFile" "$tgtFile" 2>&1 | xargs -0 -I {} printf "\t%s" "{}"
				clientRoot=$(ParseCourseleafFile "$tgtFile" | cut -d ' ' -f2)
				changeLogFile=$clientRoot/changelog.txt
				$DOIT printf "\n$userName\t$(date)\nApplied courseleaf patch: $myName\n" >> $changeLogFile
				$DOIT printf "\tUpdated: '$patchFile' from skeleton\n" >> $changeLogFile
			else
				Msg "\tSkipping $tgtFile, files identical"
			fi	
		done
	Msg
done

##==================================================================================================
## Done
#==================================================================================================
[[ $myPath == $toolsPath ]] && Goodbye 0 'alert' || Goodbye 0
