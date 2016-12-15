#!/bin/bash
#==================================================================================================
version=1.0.4 # -- dscudiero -- 12/14/2016 @ 11:30:50.03
#==================================================================================================
TrapSigs 'on'
imports='GetDefaultsData ParseArgs ParseArgsStd Hello Init Goodbye' #imports="$imports "
Import "$imports"
originalArgStr="$*"
scriptDescription="Sync internal dev site"

#==================================================================================================
# Copyright ©2014 David Scudiero -- all rights reserved.
# 06-17-15 -- 	dgs - Initial coding
# 07-17-15 --	dgs - Migrated to framework 5
#==================================================================================================

#==================================================================================================
# Declare local variables and constants
#==================================================================================================

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
GetDefaultsData $myName
ParseArgsStd
Hello

#==================================================================================================
# Main
#==================================================================================================
share=dev11
srcDir=/home/$userName/internal/stage
tgtDir=/home/$userName/$userName-internal

if [[ $verify == true ]]; then
	unset ans
	printf "You are asking to sychronise the following:\n\tsrcDir: $srcDir\n\ttgtDir: $tgtDir\n"
	Prompt ans "Do you wish continue" "Yes No"; ans=$(Lower ${ans:0:1})
	if [[ $ans != 'y' ]]; then Goodbye -1; fi
fi

## Check enviroment
	if [[ $srcDir == /home/$userName/internal/stage && $hostName != 'build5' ]]; then printf "Sorry, this script can only be run on build5.\n"; Goodbye -1; fi
	if [[ ! -d $srcDir ]]; then printf "Sorry, $srcDir not found.\n"; Goodbye -1; fi

## Scratch copy
	if [[ $scratch = true ]]; then
 		if [[ $quiet == false || $quiet == 0 ]]; then printf "Removeing $tgtDir...\n"; fi
		rm -rf $tgtDir
	fi

 # Copy stage-internal to an location avaiable to windows
 	rsyncFilters=/tmp/$userName.$myName.rsyncFilters.txt
 	if [[ -f $rsyncFilters ]]; then rm $rsyncFilters; fi
 	## ALways Exclued
 		printf "%s\n" '- /attic/' >> $rsyncFilters
 		printf "%s\n" '- /requestlog*' >> $rsyncFilters
 		printf "%s\n" '- *.git*' >> $rsyncFilters
 		printf "%s\n" '- *.gz' >> $rsyncFilters
 		printf "%s\n" '- *.bak' >> $rsyncFilters
 		printf "%s\n" '- *.old' >> $rsyncFilters
 		printf "%s\n" '- *_old' >> $rsyncFilters
  		printf "%s\n" '- *.cgi' >> $rsyncFilters
 		printf "%s\n" '- /web/pagewiz/archive/' >> $rsyncFilters
 		printf "%s\n" '- /web/pagewiz/wizdebug.out' >> $rsyncFilters
 		printf "%s\n" '- /web/pagewiz/wizdebug.log' >> $rsyncFilters
 	rsyncOpts="-a --prune-empty-dirs --include-from $rsyncFilters"
  	if [[ $quiet == false || $quiet == 0 ]]; then rsyncOpts='-v '$rsyncOpts; fi
 	if [[ $quiet == false || $quiet == 0 ]]; then printf "Syncing the folders...\n"; fi
 	$DOIT rsync $rsyncOpts $srcDir/ $tgtDir
 	touch $tgtDir

## copy correct cgis
	cgiDir=$cgisRoot/rhel$(echo $myRhel | cut -d "." -f1)
	myRhel=rhel$(echo $myRhel | cut -d "." -f1)
 	if [[ $quiet == false || $quiet == 0 ]]; then printf "Copying the $myRhel cgi's...\n"; fi
	ls -t $cgiDir > $tmpFile
	cgiVer=$(head -n 1 $tmpFile)

	$DOIT cp $cgiDir/$cgiVer/courseleaf.cgi $tgtDir/web/pagewiz/courseleaf.cgi.$myRhel.$cgiVer
	if [[ -f $tgtDir/web/pagewiz/pagewiz.cgi ]]; then $DOIT rm $tgtDir/web/pagewiz/pagewiz.cgi; fi
	$DOIT ln -s $tgtDir/web/pagewiz/courseleaf.cgi.$myRhel.$cgiVer $tgtDir/web/pagewiz/pagewiz.cgi

	$DOIT cp $cgiDir/$cgiVer/ribbit.cgi $tgtDir/web/ribbit/ribbit.cgi.$myRhel.$cgiVer
	if [[ -f $tgtDir/web/ribbit/ribbit.cgi ]]; then $DOIT rm $tgtDir/web/ribbit/ribbit.cgi; fi
	$DOIT ln -s $tgtDir/web/ribbit/ribbit.cgi.$myRhel.$cgiVer $tgtDir/web/ribbit//ribbit.cgi

## Turn off publishing
	if [[ $quiet == false || $quiet == 0 ]]; then printf "Turn off Publishing...\n"; fi
	$DOIT sed -i s'_^//mapfile:production/|/dev/null_mapfile:production/|/dev/null_' $tgtDir/pagewiz.cfg
	$DOIT sed -i s'_^//mapfile:production|/dev/null_mapfile:production|/dev/null_' $tgtDir/pagewiz.cfg
	$DOIT sed -i s'_^mapfile:production/|../../../public/web_//mapfile:production/|../../../public/web_' $tgtDir/pagewiz.cfg
	$DOIT sed -i s'_^mapfile:production|../../../public/web_//mapfile:production|../../../public/web_' $tgtDir/pagewiz.cfg

## Turn off remote authenticaton
	if [[ $quiet == false || $quiet == 0 ]]; then printf "Turn off Authentication...\n"; fi
	$DOIT sed -i s'_^authuser:true_//authuser:true_' $tgtDir/pagewiz.cfg
	for file in default.tcf localsteps/default.tcf; do
		$DOIT sed -i s'_^authuser:true_//authuser:true_' $tgtDir/web/pagewiz/$file
		$DOIT sed -i s'_^casurl:_//casurl:_' $tgtDir/web/pagewiz/$file
		$DOIT sed -i s'_^loginurl:_//loginurl:_' $tgtDir/web/pagewiz/$file
		$DOIT sed -i s'_^logouturl:_//logouturl:_' $tgtDir/web/pagewiz/$file
	done

## add leepfrog & test user account
	if [[ $quiet == false || $quiet == 0 ]]; then printf "Adding the 'leepfrog' & 'test' userids are in the pagewiz.cfg file...\n"; fi
	$DOIT echo "user:leepfrog|0scys,btdeL||admin" >> $tgtDir/pagewiz.cfg
	$DOIT echo "user:test|test||" >> $tgtDir/pagewiz.cfg

#==================================================================================================
## Done
#==================================================================================================
Goodbye 0
