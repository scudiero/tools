#!/bin/bash
#==================================================================================================
version=1.0.45 # -- dscudiero -- Wed 10/18/2017 @ 14:27:23.78
#==================================================================================================
#= Description +===================================================================================
# Clone a Courseleaf git repository
# not meant to be called stand alone
# GitClone "$repo" "$tag" "$gitRepoRoot/${repo}.git" "$relDir"
#==================================================================================================
TrapSigs 'on'
originalArgStr="$*"
scriptDescription="Clone a Courseleaf git repository"

checkParent="syncCourseleafGitRepos"; found=false
for ((i=0; i<${#BASH_SOURCE[@]}; i++)); do 
	echo "\$(basename "${BASH_SOURCE[$i]}").sh = '"$(basename "${BASH_SOURCE[$i]}").sh"'"
	[[ "$(basename "${BASH_SOURCE[$i]}").sh" == $checkParent ]] && found=true; 
done
[[ $found != true ]] && Terminate "Sorry, this script can only be called from '$checkParent',\nCurrent call parent: '$calledFrom'"

#==================================================================================================
# Standard call back functions
#==================================================================================================
#==================================================================================================
# parse script specific argumentstrap
#==================================================================================================
function parseArgs-cloneGitRepo {
	# argList+=(argFlag,minLen,type,scriptVariable,exCmd,helpSet,helpText)  #type in {switch,switch#,option,help}
	noFork=false
	argList+=(-noFork,3,switch,noFork,,script,"Do not for off processes")
}
function Goodbye-cloneGitRepo  { # or Goodbye-$myName
	SetFileExpansion 'on'
	rm -f "$stdOut" "$stdErr" >& /dev/null
	SetFileExpansion
	return 0
}

#==================================================================================================
# local functions
#==================================================================================================

#==================================================================================================
# Declare local variables and constants
#==================================================================================================
tmpFile=$(MkTmpFile $FUNCNAME)
stdOut="$tmpFile.stdout"
stdErr="$tmpFile.stderr"

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
repo="$1"
tag="$2"
srcDir="$3"
tgtDir="$4"
parseQuiet=true
ParseArgsStd
dump -2 -t originalArgStr repo tag srcDir tgtDir

#===================================================================================================
# Main
#===================================================================================================
[[ $tag != 'master' ]] && tgtDir=${tgtDir}-new || rm -rf $tgtDir
mkdir -p ${tgtDir}/${repo}
chmod gu+w ${tgtDir}/${repo}
cd $tgtDir

## Initialize the repo
	[[ $batchMode != true ]] && Msg2 "^^Initializing the '$repo' repository (takes a while)..."
	rm -f "$stdOut" "$stdErr" >& /dev/null
	gitCmd="git clone --depth 1 $srcDir"
	ProtectedCall "$gitCmd" 1> $stdOut 2> $stdErr
	unset grepStr; [[ -f $stdErr ]] && grepStr=$(ProtectedCall "grep Fatal: $stdErr")
	[[ $grepStr != '' ]] && Terminate 0 1 "git command failed:\n\t\t\tCmd: '$gitCmd'\n$(cat $stdErr | xargs -I {} echo -e "\t\t\t{}")"
	[[ -f $stdOut && $batchMode != true ]] && cat $stdOut | xargs -I {} echo -e  "\t\t\t{}"

## Overlay the specific tagged files
	if [[ $tag  != 'master' ]]; then
		[[ $batchMode != true ]] && Msg2 "^^Extracting tag '$tag' from the '$repo' repository..."
		cd $tgtDir/$repo
		rm -f "$stdOut" "$stdErr" >& /dev/null
		gitCmd="git checkout --force tags/$tag"
		ProtectedCall "$gitCmd" 1> $stdOut 2> $stdErr
		unset grepStr; [[ -f $stdErr ]] && grepStr=$(ProtectedCall "grep Fatal: $stdErr")
		[[ $grepStr != '' ]] && Terminate 0 1 "git command failed:\n\t\t\tCmd: '$gitCmd'\n$(cat $stdErr | xargs -I {} echo -e "\t\t\t{}")"
		[[ -f $stdOut && $batchMode != true ]] && cat $stdOut | xargs -I {} echo -e  "\t\t\t{}"
	fi

## git cleanup
	[[ $batchMode != true ]] && Msg2 "^^Cleaning up the repo..."
	cd $tgtDir/$repo
	rm -f "$stdOut" "$stdErr" >& /dev/null
	gitCmd="git clean -fxd"
	ProtectedCall "$gitCmd" 1> $stdOut 2> $stdErr
	unset grepStr; [[ -f $stdErr ]] && grepStr=$(ProtectedCall "grep Fatal: $stdErr")
	[[ $grepStr != '' ]] && Terminate 0 1 "git command failed:\n\t\t\tCmd: '$gitCmd'\n$(cat $stdErr | xargs -I {} echo -e "\t\t\t{}")"
	[[ -f $stdOut && $batchMode != true ]] && cat $stdOut | xargs -I {} echo -e  "\t\t\t{}"

## set the time-date stamp on the extracted files
	if [[ $tag  == 'master' ]]; then
		[[ $batchMode != true ]] && Msg2 "^^Restting file time stamps (again, this will take a while)..."
		cd $tgtDir/$repo
		for file in $(git ls-files | grep -v ' '); do
			time=$(git log --pretty=format:%cd -n 1 --date=iso "$file")
			dateStamp=$(echo $time | cut -d ' ' -f1)
			timeStamp=$(echo $time | cut -d ' ' -f2)
			yy=$(echo $dateStamp | cut -d '-' -f1)
			MM=$(echo $dateStamp | cut -d '-' -f2)
			dd=$(echo $dateStamp | cut -d '-' -f3)
			hh=$(echo $timeStamp | cut -d ':' -f1)
			mm=$(echo $timeStamp | cut -d ':' -f2)
			ss=$(echo $timeStamp | cut -d ':' -f3)
			#dump -n dateStamp timeStamp yy MM dd hh mm ss
			[[ -f $file ]] && touch -t $yy$MM$dd$hh$mm.$ss "$file"
		done
	fi

## set version files
	unset outFile
	outFile=$tgtDir/$repo/clver.txt
	chmod 755 $tgtDir/$repo

	if [[ $tag != 'master' && $outFile != '' ]]; then
		[[ $batchMode != true ]] && Msg2 "^^Updating 'version file', writing out '$outFile'..."
		tagFull=$(echo $tag | cut -d'.' -f 1).$(echo $tag | cut -d'.' -f 2).$(echo $tag'.0' | cut -d'.' -f 3)
		echo "$tagFull" > $outFile
	fi

## remove git files
	cd $tgtDir/$repo
	[[ $batchMode != true ]] && Msg2 "^^Removing git directory and files..."
	rm -rf .git*

## rename the pdfgen folder
	if [[ $repo == 'pdfgen' ]]; then
		cd $tgtDir
		mv -f pdfgen pdf
		[[ $batchMode != true ]] && Msg2 "^^Rename '$repo' folder to 'pdf'..."
	fi

## Create sync file
	touch $tgtDir/.syncDate

## Set ownership
	SetFileExpansion 'on'
	cwd=$(pwd); cd $tgtDir; chgrp -R leepfrog *; chgrp leepfrog .*; cd "$cwd"
	SetFileExpansion 'off'

#==================================================================================================
## Done
#==================================================================================================
SetFileExpansion 'On'
rm -f "$tmpFile.*" &> /dev/null
SetFileExpansion
Goodbye 'Return'
return 0

#==================================================================================================
## Check-in log
#==================================================================================================
## Fri Mar 25 15:38:13 CDT 2016 - dscudiero - subsript for build git repos
## Thu Mar 31 09:05:58 CDT 2016 - dscudiero - Added goodbye callback to cleanup temp files
## Mon Apr 25 07:47:02 CDT 2016 - dscudiero - Added parseQuiet=true to mask messages
## Fri May 13 12:56:16 CDT 2016 - dscudiero - Update the time date stamps in the repo for master also
## Wed Jun 22 07:00:00 CDT 2016 - dscudiero - Force permissions to 755 for the courseleaf directory
## Thu Jul 14 15:08:07 CDT 2016 - fred - Switch LOGNAME for userName
## Tue Sep 27 13:26:24 CDT 2016 - dscudiero - Set file ownership after syncing with masters
## Wed Jan 25 12:58:17 CST 2017 - dscudiero - Fix issue where noglob was set when tryhing to chgrp all files in the new repo
## 04-28-2017 @ 08.18.42 - (1.0.29)    - dscudiero - switch to just return to caller
## 04-28-2017 @ 08.26.15 - (1.0.31)    - dscudiero - use Goodbye 'return'
## 05-02-2017 @ 07.32.32 - (1.0.32)    - dscudiero - cleanup tmp files
## 05-17-2017 @ 16.43.45 - (1.0.33)    - dscudiero - Add process id to the name of the tmpFile to avoid conflicts when running scripts in parallel
## 05-19-2017 @ 12.25.49 - (1.0.35)    - dscudiero - Added debug statements
## 05-31-2017 @ 12.32.11 - (1.0.35)    - dscudiero - Misc cleanup
## 05-31-2017 @ 12.35.33 - (1.0.37)    - dscudiero - General syncing of dev to prod
## 06-13-2017 @ 08.36.22 - (1.0.38)    - dscudiero - Remove debug code
## 10-18-2017 @ 14.16.09 - (1.0.41)    - dscudiero - Make the 'called from' logic more robust
## 10-18-2017 @ 14.20.46 - (1.0.42)    - dscudiero - Cosmetic/minor change
## 10-18-2017 @ 14.22.25 - (1.0.43)    - dscudiero - Cosmetic/minor change
## 10-18-2017 @ 14.23.38 - (1.0.44)    - dscudiero - Cosmetic/minor change
#!/bin/bash
#==================================================================================================
version=1.0.45 # -- dscudiero -- Wed 10/18/2017 @ 14:25:02.15
#==================================================================================================
#= Description +===================================================================================
# Clone a Courseleaf git repository
# not meant to be called stand alone
# GitClone "$repo" "$tag" "$gitRepoRoot/${repo}.git" "$relDir"
#==================================================================================================
TrapSigs 'on'
originalArgStr="$*"
scriptDescription="Clone a Courseleaf git repository"

checkParent="syncCourseleafGitRepos"; found=false
for ((i=0; i<${#BASH_SOURCE[@]}; i++)); do [[ $(basename "${BASH_SOURCE[$i]}").sh == $checkParent ]] && found=true; done
[[ $found != true ]] && Terminate "Sorry, this script can only be called from '$checkParent',\nCurrent call parent: '$calledFrom'"

#==================================================================================================
# Standard call back functions
#==================================================================================================
#==================================================================================================
# parse script specific argumentstrap
#==================================================================================================
function parseArgs-cloneGitRepo {
	# argList+=(argFlag,minLen,type,scriptVariable,exCmd,helpSet,helpText)  #type in {switch,switch#,option,help}
	noFork=false
	argList+=(-noFork,3,switch,noFork,,script,"Do not for off processes")
}
function Goodbye-cloneGitRepo  { # or Goodbye-$myName
	SetFileExpansion 'on'
	rm -f "$stdOut" "$stdErr" >& /dev/null
	SetFileExpansion
	return 0
}

#==================================================================================================
# local functions
#==================================================================================================

#==================================================================================================
# Declare local variables and constants
#==================================================================================================
tmpFile=$(MkTmpFile $FUNCNAME)
stdOut="$tmpFile.stdout"
stdErr="$tmpFile.stderr"

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
repo="$1"
tag="$2"
srcDir="$3"
tgtDir="$4"
parseQuiet=true
ParseArgsStd
dump -2 -t originalArgStr repo tag srcDir tgtDir

#===================================================================================================
# Main
#===================================================================================================
[[ $tag != 'master' ]] && tgtDir=${tgtDir}-new || rm -rf $tgtDir
mkdir -p ${tgtDir}/${repo}
chmod gu+w ${tgtDir}/${repo}
cd $tgtDir

## Initialize the repo
	[[ $batchMode != true ]] && Msg2 "^^Initializing the '$repo' repository (takes a while)..."
	rm -f "$stdOut" "$stdErr" >& /dev/null
	gitCmd="git clone --depth 1 $srcDir"
	ProtectedCall "$gitCmd" 1> $stdOut 2> $stdErr
	unset grepStr; [[ -f $stdErr ]] && grepStr=$(ProtectedCall "grep Fatal: $stdErr")
	[[ $grepStr != '' ]] && Terminate 0 1 "git command failed:\n\t\t\tCmd: '$gitCmd'\n$(cat $stdErr | xargs -I {} echo -e "\t\t\t{}")"
	[[ -f $stdOut && $batchMode != true ]] && cat $stdOut | xargs -I {} echo -e  "\t\t\t{}"

## Overlay the specific tagged files
	if [[ $tag  != 'master' ]]; then
		[[ $batchMode != true ]] && Msg2 "^^Extracting tag '$tag' from the '$repo' repository..."
		cd $tgtDir/$repo
		rm -f "$stdOut" "$stdErr" >& /dev/null
		gitCmd="git checkout --force tags/$tag"
		ProtectedCall "$gitCmd" 1> $stdOut 2> $stdErr
		unset grepStr; [[ -f $stdErr ]] && grepStr=$(ProtectedCall "grep Fatal: $stdErr")
		[[ $grepStr != '' ]] && Terminate 0 1 "git command failed:\n\t\t\tCmd: '$gitCmd'\n$(cat $stdErr | xargs -I {} echo -e "\t\t\t{}")"
		[[ -f $stdOut && $batchMode != true ]] && cat $stdOut | xargs -I {} echo -e  "\t\t\t{}"
	fi

## git cleanup
	[[ $batchMode != true ]] && Msg2 "^^Cleaning up the repo..."
	cd $tgtDir/$repo
	rm -f "$stdOut" "$stdErr" >& /dev/null
	gitCmd="git clean -fxd"
	ProtectedCall "$gitCmd" 1> $stdOut 2> $stdErr
	unset grepStr; [[ -f $stdErr ]] && grepStr=$(ProtectedCall "grep Fatal: $stdErr")
	[[ $grepStr != '' ]] && Terminate 0 1 "git command failed:\n\t\t\tCmd: '$gitCmd'\n$(cat $stdErr | xargs -I {} echo -e "\t\t\t{}")"
	[[ -f $stdOut && $batchMode != true ]] && cat $stdOut | xargs -I {} echo -e  "\t\t\t{}"

## set the time-date stamp on the extracted files
	if [[ $tag  == 'master' ]]; then
		[[ $batchMode != true ]] && Msg2 "^^Restting file time stamps (again, this will take a while)..."
		cd $tgtDir/$repo
		for file in $(git ls-files | grep -v ' '); do
			time=$(git log --pretty=format:%cd -n 1 --date=iso "$file")
			dateStamp=$(echo $time | cut -d ' ' -f1)
			timeStamp=$(echo $time | cut -d ' ' -f2)
			yy=$(echo $dateStamp | cut -d '-' -f1)
			MM=$(echo $dateStamp | cut -d '-' -f2)
			dd=$(echo $dateStamp | cut -d '-' -f3)
			hh=$(echo $timeStamp | cut -d ':' -f1)
			mm=$(echo $timeStamp | cut -d ':' -f2)
			ss=$(echo $timeStamp | cut -d ':' -f3)
			#dump -n dateStamp timeStamp yy MM dd hh mm ss
			[[ -f $file ]] && touch -t $yy$MM$dd$hh$mm.$ss "$file"
		done
	fi

## set version files
	unset outFile
	outFile=$tgtDir/$repo/clver.txt
	chmod 755 $tgtDir/$repo

	if [[ $tag != 'master' && $outFile != '' ]]; then
		[[ $batchMode != true ]] && Msg2 "^^Updating 'version file', writing out '$outFile'..."
		tagFull=$(echo $tag | cut -d'.' -f 1).$(echo $tag | cut -d'.' -f 2).$(echo $tag'.0' | cut -d'.' -f 3)
		echo "$tagFull" > $outFile
	fi

## remove git files
	cd $tgtDir/$repo
	[[ $batchMode != true ]] && Msg2 "^^Removing git directory and files..."
	rm -rf .git*

## rename the pdfgen folder
	if [[ $repo == 'pdfgen' ]]; then
		cd $tgtDir
		mv -f pdfgen pdf
		[[ $batchMode != true ]] && Msg2 "^^Rename '$repo' folder to 'pdf'..."
	fi

## Create sync file
	touch $tgtDir/.syncDate

## Set ownership
	SetFileExpansion 'on'
	cwd=$(pwd); cd $tgtDir; chgrp -R leepfrog *; chgrp leepfrog .*; cd "$cwd"
	SetFileExpansion 'off'

#==================================================================================================
## Done
#==================================================================================================
SetFileExpansion 'On'
rm -f "$tmpFile.*" &> /dev/null
SetFileExpansion
Goodbye 'Return'
return 0

#==================================================================================================
## Check-in log
#==================================================================================================
## Fri Mar 25 15:38:13 CDT 2016 - dscudiero - subsript for build git repos
## Thu Mar 31 09:05:58 CDT 2016 - dscudiero - Added goodbye callback to cleanup temp files
## Mon Apr 25 07:47:02 CDT 2016 - dscudiero - Added parseQuiet=true to mask messages
## Fri May 13 12:56:16 CDT 2016 - dscudiero - Update the time date stamps in the repo for master also
## Wed Jun 22 07:00:00 CDT 2016 - dscudiero - Force permissions to 755 for the courseleaf directory
## Thu Jul 14 15:08:07 CDT 2016 - fred - Switch LOGNAME for userName
## Tue Sep 27 13:26:24 CDT 2016 - dscudiero - Set file ownership after syncing with masters
## Wed Jan 25 12:58:17 CST 2017 - dscudiero - Fix issue where noglob was set when tryhing to chgrp all files in the new repo
## 04-28-2017 @ 08.18.42 - (1.0.29)    - dscudiero - switch to just return to caller
## 04-28-2017 @ 08.26.15 - (1.0.31)    - dscudiero - use Goodbye 'return'
## 05-02-2017 @ 07.32.32 - (1.0.32)    - dscudiero - cleanup tmp files
## 05-17-2017 @ 16.43.45 - (1.0.33)    - dscudiero - Add process id to the name of the tmpFile to avoid conflicts when running scripts in parallel
## 05-19-2017 @ 12.25.49 - (1.0.35)    - dscudiero - Added debug statements
## 05-31-2017 @ 12.32.11 - (1.0.35)    - dscudiero - Misc cleanup
## 05-31-2017 @ 12.35.33 - (1.0.37)    - dscudiero - General syncing of dev to prod
## 06-13-2017 @ 08.36.22 - (1.0.38)    - dscudiero - Remove debug code
## 10-18-2017 @ 14.16.09 - (1.0.41)    - dscudiero - Make the 'called from' logic more robust
## 10-18-2017 @ 14.20.46 - (1.0.42)    - dscudiero - Cosmetic/minor change
## 10-18-2017 @ 14.22.25 - (1.0.43)    - dscudiero - Cosmetic/minor change
## 10-18-2017 @ 14.23.38 - (1.0.44)    - dscudiero - Cosmetic/minor change
## 10-18-2017 @ 14.25.08 - (1.0.45)    - dscudiero - Cosmetic/minor change
## 10-18-2017 @ 14.27.31 - (1.0.45)    - dscudiero - Cosmetic/minor change
