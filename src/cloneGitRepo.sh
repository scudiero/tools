#!/bin/bash
#==================================================================================================
version=1.0.35 # -- dscudiero -- Fri 05/19/2017 @ 12:15:15.15
#==================================================================================================
#= Description +===================================================================================
# Clone a Courseleaf git repository
# not meant to be called stand alone
# GitClone "$repo" "$tag" "$gitRepoRoot/${repo}.git" "$relDir"
#==================================================================================================
TrapSigs 'on'
originalArgStr="$*"
scriptDescription="Clone a Courseleaf git repository"

checkParent="syncCourseleafGitRepos.sh"; calledFrom="$(Lower "$(basename "${BASH_SOURCE[2]}")")"
[[ $(Lower $calledFrom) != $(Lower $checkParent) ]] && Terminate "Sorry, this script can only be called from '$checkParent',\nCurrent call parent: '$calledFrom'"

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
	rm -rf /tmp/$userName.$myName* > /dev/null 2>&1
	SetFileExpansion
	return 0
}
#==================================================================================================
# local functions
#==================================================================================================
local tmpFile=$(MkTmpFile $FUNCNAME).$BASHPID

#==================================================================================================
# Declare local variables and constants
#==================================================================================================

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
local repo="$1"
local tag="$2"
local srcDir="$3"
local tgtDir="$4"
parseQuiet=true
ParseArgsStd
dump -2 -t originalArgStr repo tag srcDir tgtDir

ToDo 'remove debug code' ; batchMode=true

#===================================================================================================
# Main
#===================================================================================================
[[ $tag != 'master' ]] && tgtDir=${tgtDir}-new || rm -rf $tgtDir
mkdir -p ${tgtDir}/${repo}
chmod gu+w ${tgtDir}/${repo}
cd $tgtDir

## Initialize the repo
	[[ $batchMode != true ]] && Msg2 "^^Initializing the '$repo' repository (takes a while)..."
	[[ -f $tmpFile.stdout ]] && rm "$tmpFile.stdout"; [[ -f $tmpFile.stderr ]] && rm "$tmpFile.stderr";
	gitCmd="git clone --depth 1 $srcDir"
	ProtectedCall "$gitCmd" 1> $tmpFile.stdout 2> $tmpFile.stderr
	unset grepStr; [[ -f $tmpFile.stderr ]] && grepStr=$(ProtectedCall "grep Fatal: $tmpFile.stderr")
	[[ $grepStr != '' ]] && Terminate 0 1 "git command failed:\n\t\t\tCmd: '$gitCmd'\n$(cat $tmpFile.stderr | xargs -I {} echo -e "\t\t\t{}")"
	[[ -f $tmpFile.stdout && $batchMode != true ]] && cat $tmpFile.stdout | xargs -I {} echo -e  "\t\t\t{}"

## Overlay the specific tagged files
	if [[ $tag  != 'master' ]]; then
		[[ $batchMode != true ]] && Msg2 "^^Extracting tag '$tag' from the '$repo' repository..."
		cd $tgtDir/$repo
		[[ -f $tmpFile.stdout ]] && rm "$tmpFile.stdout"; [[ -f $tmpFile.stderr ]] && rm "$tmpFile.stderr";
		gitCmd="git checkout --force tags/$tag"
		ProtectedCall "$gitCmd" 1> $tmpFile.stdout 2> $tmpFile.stderr
		unset grepStr; [[ -f $tmpFile.stderr ]] && grepStr=$(ProtectedCall "grep Fatal: $tmpFile.stderr")
		[[ $grepStr != '' ]] && Terminate 0 1 "git command failed:\n\t\t\tCmd: '$gitCmd'\n$(cat $tmpFile.stderr | xargs -I {} echo -e "\t\t\t{}")"
		[[ -f $tmpFile.stdout && $batchMode != true ]] && cat $tmpFile.stdout | xargs -I {} echo -e  "\t\t\t{}"
	fi

## git cleanup
	[[ $batchMode != true ]] && Msg2 "^^Cleaning up the repo..."
	cd $tgtDir/$repo
	[[ -f $tmpFile.stdout ]] && rm "$tmpFile.stdout"; [[ -f $tmpFile.stderr ]] && rm "$tmpFile.stderr";
	gitCmd="git clean -fxd"
	ProtectedCall "$gitCmd" 1> $tmpFile.stdout 2> $tmpFile.stderr
	unset grepStr; [[ -f $tmpFile.stderr ]] && grepStr=$(ProtectedCall "grep Fatal: $tmpFile.stderr")
	[[ $grepStr != '' ]] && Terminate 0 1 "git command failed:\n\t\t\tCmd: '$gitCmd'\n$(cat $tmpFile.stderr | xargs -I {} echo -e "\t\t\t{}")"
	[[ -f $tmpFile.stdout && $batchMode != true ]] && cat $tmpFile.stdout | xargs -I {} echo -e  "\t\t\t{}"

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
