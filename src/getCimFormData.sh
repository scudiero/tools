#!/bin/bash
#==================================================================================================
version=1.2.6 # -- dscudiero -- Thu 09/14/2017 @ 15:52:22.51
#==================================================================================================
TrapSigs 'on'
imports='GetDefaultsData ParseArgs ParseArgsStd Hello Init Goodbye' 
imports="$imports BackupCourseleafFile"
Import "$imports"
originalArgStr="$*"
scriptDescription="Report on CIM form data"

#==================================================================================================
# Create a formated report listing the fields on a CIM for with info on each
#==================================================================================================
#==================================================================================================
# Copyright ©2014 David Scudiero -- all rights reserved.
# 06-17-15 -- 	dgs - Initial coding
# 07-17-15 --	dgs - Migrated to framework 5
#==================================================================================================

#==================================================================================================
# Declare local variables and constants
#==================================================================================================
step='getCimFormFieldData'

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
GetDefaultsData $myName
ParseArgsStd
Hello
Init 'getClient getEnv getDirs checkEnvs getCims'

## Set outfile -- look for std locations
if [[ -d $localClientWorkFolder ]]; then
	if [[ ! -d $localClientWorkFolder/$client ]]; then mkdir -p $localClientWorkFolder/$client; fi
	outFile=$localClientWorkFolder/$client/$client-$myName.txt
else
	outFile=/home/$userName/$client-$myName.txt
fi

verifyArgs+=("Client:$client")
verifyArgs+=("Env:$(TitleCase $env)")
verifyArgs+=("CIMs:$cimStr")
verifyArgs+=("Output File:$outFile")
verifyContinueDefault='Yes'
VerifyContinue "You are asking to get CIM fields data for\n\tclient:$client\n\tEnv: $env\n\tCIMs: $cimStr"

#==================================================================================================
## Main
#==================================================================================================
## Find the step file to run
	FindExecutable "$step" 'std' 'steps:html' 'steps' ## Sets variable executeFile
	srcStepFile=$executeFile
	Msg2 "Using step file: $srcStepFile"

## Run the step
	BackupCourseleafFile $srcDir/web/courseleaf/localsteps/$step.html
	cp -fp $srcStepFile $srcDir/web/courseleaf/localsteps/$step.html
	## Edit the CIMS variable in the step file
	cimStr=\'$(echo $cimStr | sed -e "s/, /','/g")\'
	sed -i s"_var cims=\[\];_var cims=\[${cimStr}\];_" $srcDir/web/courseleaf/localsteps/$step.html
	if [[ $quiet = 0 ]]; then Msg "Running step ..."; fi
	cd $srcDir/web/courseleaf
	./courseleaf.cgi $step / > $outFile
	#rm $srcDir/web/courseleaf/localsteps/$step.html
	Msg2 "\nOutput data generated in '$outFile'\n"

#==================================================================================================
## Done
#==================================================================================================
#Alert
Goodbye 0
