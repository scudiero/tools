#!/bin/bash
#==================================================================================================
version=2.1.17 # -- dscudiero -- Fri 09/29/2017 @ 10:06:48.02
#==================================================================================================
TrapSigs 'on'
includes='Msg2 Dump GetDefaultsData ParseArgsStd Hello DbLog Init Goodbye VerifyContinue MkTmpFile'
includes="$includes GetCourseleafPgm"
Import "$includes"

originalArgStr="$*"
scriptDescription="Get catalog page owner and workflow data in a format suitable to paste into a MS Excel workbook"

#==================================================================================================
## dump out all of the pages ownership ad workflow data
#==================================================================================================
# Copyright �2015 David Scudiero -- all rights reserved.
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

## Set outfile -- look for std locations
if [[ -d $localClientWorkFolder ]]; then
	if [[ ! -d $localClientWorkFolder/$client ]]; then mkdir $localClientWorkFolder/$client; fi
	outFile=$localClientWorkFolder/$client/$client-$env-CatalogPageData.xls
else
	outFile=/home/$userName/$client-$env-CatalogPageData.xls
fi

unset verifyArgs
verifyArgs+=("Client:$client")
verifyArgs+=("Env:$(TitleCase $env)")
verifyArgs+=("Output File:$outFile")
verifyContinueDefault='Yes'
verifyContinueDefault='Yes'
VerifyContinue "You are asking to retrieve page data for"

#==================================================================================================
# Main
#==================================================================================================
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
	srcStepFile="$(FindExecutable -step "$step")"
	[[ -z $srcStepFile ]] && Terminate "Could find the step file ('$step')"
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
## 04-13-2017 @ 14.01.07 - (2.1.13)    - dscudiero - Add a default for VerifyContinue
## 09-29-2017 @ 10.14.57 - (2.1.17)    - dscudiero - Update FindExcecutable call for new syntax
