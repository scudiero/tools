#!/bin/bash
#==================================================================================================
version=2.1.13 # -- dscudiero -- 12/14/2016 @ 11:25:36.64
#==================================================================================================
TrapSigs 'on'
imports='GetDefaultsData ParseArgs ParseArgsStd Hello Init Goodbye' 
imports="$imports GetCourseleafPgm"
Import "$imports"
originalArgStr="$*"
scriptDescription="Get catalog page data"

#==================================================================================================
## dump out all of the pages ownership ad workflow data
#==================================================================================================
# Copyright ©2015 David Scudiero -- all rights reserved.
# 11-07-13	--	dgs	-	New
# 07-17-15 --	dgs - Migrated to framework 5
#==================================================================================================

#==================================================================================================
# Declare local variables and constants
#==================================================================================================
step='getCatalogPageData'

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
GetDefaultsData $myName
ParseArgsStd
Hello
Msg2
Init 'getClient getEnv checkEnv getDirs'
VerifyContinue "You are asking to retrieve page data for\n\tclient:$client\n\tEnv: $env"

#==================================================================================================
# Main
#==================================================================================================
## Set outfile -- look for std locations
if [[ -d $localClientWorkFolder ]]; then
	if [[ ! -d $localClientWorkFolder/$client ]]; then mkdir $localClientWorkFolder/$client; fi
	outFile=$localClientWorkFolder/$client/$client-$env-CatalogPageData.xls
else
	outFile=/home/$userName/$client-$env-CatalogPageData.xls
fi

cd $srcDir
## Get the courseleaf pgmname and dir
	courseLeafPgm=$(GetCourseleafPgm | cut -d' ' -f1)
	courseLeafDir=$(GetCourseleafPgm | cut -d' ' -f2)
	if [[ $courseLeafPgm == '' || $courseLeafDir == '' ]]; then Terminate "Could not find courseleaf executable"; fi
	Verbose 3 "$(dump courseLeafPgm courseLeafDir)"

## Does the step file already exists
	stepFile="$courseLeafDir/localsteps/$step.html"
	if [[ -f $stepFile  && $verify == true ]]; then
		Warning "Found file $stepFile"
		unset ans
		Prompt ans "Do you want to overwrite?" 'Yes No'; ans=$(Lower ${ans:0:1})
		if [[ $ans != 'y' ]]; then Goodbye 1; fi
	fi

## Find the step file to run
	FindExecutable "$step" 'std' 'steps:html' 'steps' ## Sets variable executeFile
	srcStepFile=$executeFile
	Msg2 "Using step file: $srcStepFile"

## Copy step file to localsteps
	cp -fP $srcStepFile $stepFile
	chmod ug+w $stepFile

## Run the step
	Msg2 "Running step: $step on every page (usually takes a while)..."
	cd $courseLeafDir
	Msg2 "Page Path\tPage Title\tPage Owner\tPage Workflow" > $outFile
	./$courseLeafPgm.cgi -e $step / >> $outFile
	rm $stepFile

Msg2 "Output can be found in: $outFile\n"

#==================================================================================================
## Bye-bye
#==================================================================================================
Goodbye 0 'alert'
## Tue Oct 18 07:56:54 CDT 2016 - dscudiero - Switch output file type to .xls
## Tue Oct 18 07:58:39 CDT 2016 - dscudiero - Add ENV to the output file name
