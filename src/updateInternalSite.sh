#!/bin/bash
#==================================================================================================
version=1.0.4 # -- dscudiero -- 12/14/2016 @ 11:31:59.00
#==================================================================================================
TrapSigs 'on'
imports='GetDefaultsData ParseArgs ParseArgsStd Hello Init Goodbye' #imports="$imports "
Import "$imports"
originalArgStr="$*"
scriptDescription="Apply updates to internal site"

#==================================================================================================
# Update the internal site from the staging folders
#==================================================================================================
#==================================================================================================
# local functions
#==================================================================================================
	#==============================================================================================
	# parse script specific arguments
	#==============================================================================================
	function parseArgs-updateInternalSite {
		# argList+=(argFlag,minLen,type,scriptVariable,exCmd,helpSet,helpText)  #type in {switch,switch#,option,help}
		argList+=(-updateMaster,7,switch,updateMaster,,script,'Update the Master stage-internal site')
		:
	}

#==================================================================================================
# Declare local variables and constants
#==================================================================================================
tgtModified=false
exitCode=1

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
GetDefaultsData $myName
ParseArgsStd "$originalArgStr"
Hello

#==================================================================================================
# Main
#==================================================================================================
cgi=pagewiz
srcDir=/home/$userName/tools.dev/$myName.data
tgtDir=/mnt/dev11/web/$userName-internal
[[ $updateMaster == true ]] && tgtDir=/home/dscudiero/internal/stage

Msg2; Msg2 "Source: $srcDir\nTarget: $tgtDir"; Msg2
[[ ! -d $srcDir ]] && Terminate "Could not locate source directory\n\t'$srcDir'"
[[ ! -d $tgtDir ]] && Terminate "Could not locate target directory\n\t'$tgtDir'"
[[ ! -f $srcDir/install ]] && Warning "'$srcDir/install' file not found" && Goodbye $exitCode

## If on build5 see if we want to update the real site
	if [[ $hostName == 'build5' && $verify == true && updateMaster == false ]]; then
		Msg2
		unset ans
		Prompt ans "Do you wish to update the real 'stage-internal" "Yes No"; ans$(Lower ${ans:0:1})
		[[ $ans == 'y' ]] && tgtDir=/home/dscudiero/internal/stage
	fi

## Run sql files if found
	unset files
	cd $srcDir
	files=($(find . -name *.sql))
	for file in ${files[@]}; do
		Msg2 "Running sql" ; Msg2 "^$srcDir/$file..."
		sqlite3 $(dirname $tgtDir)/contactsdb/contacts.sqlite < $file 2>&1 | xargs -I {} printf "\t%s\n" "{}"
		mv $file $file.$(date +"%m-%d-%Y@%H.%M.%S")
		tgtModified=true
	done

## Copy files
	cd $srcDir/web
	unset files
	copyMsg=true
	files=($(find . -type f))
	for file in ${files[@]}; do
		srcFile=$srcDir/web/${file:2}
		tgtFile=$tgtDir/web/${file:2}
		srcMd5=$(md5sum $srcFile | cut -f1 -d" ")
		tgtMd5=$(md5sum $tgtFile | cut -f1 -d" ")
		if [[ $srcMd5 != $tgtMd5 ]]; then
			[[ $copyMsg == true ]] && Msg2 && Msg2 "Copying files..." && copyMsg=false
			Msg2 "^$srcFile --> $tgtFile"
			cp -fpb $srcDir/web $tgtDir
			tgtModified=true
		fi
	done

## rebuild pages
	if [[ $tgtModified == true ]]; then
		Msg2; Msg2 "Rebuilding leepdata..."
		cd $tgtDir/web/$cgi
		./$cgi.cgi -r /leepdata/ | xargs printf "\t%s %s\n"
	fi

## sendemail if anything was changed
	dump -1 emailAddrs tgtModified noEmails
	if [[ $emailAddrs != '' && $tgtModified == true && $noEmails == false ]]; then
		$DOIT mutt -s "Stage-internal updated: $(date +"%m-%d-%Y")" -- $emailAddrs < $logFile
	fi

# update install file
	[[ $tgtModified == true ]] && touch $srcDir/install && exitCode=0
	mv $srcDir/install $srcDir/install.$(date +"%m-%d-%Y@%H.%M.%S")

#==================================================================================================
## Done
#==================================================================================================
#Alert
Goodbye $exitCode
## Thu Jul 14 15:08:40 CDT 2016 - fred - Switch LOGNAME for userName
