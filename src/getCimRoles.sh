#!/bin/bash
#==================================================================================================
version=1.10.20 # -- dscudiero -- 12/14/2016 @ 11:25:46.55
#==================================================================================================
TrapSigs 'on'
imports='GetDefaultsData ParseArgs ParseArgsStd Hello Init Goodbye' #imports="$imports "
Import "$imports"
originalArgStr="$*"
scriptDescription=" Get CIM roles"

#= Description +===================================================================================
# Get a list if CIM roles used in workflows
#===================================================================================================
# 05-28-14 -- 	dgs - Initial coding
# 07-17-15 --	dgs - Migrated to framework 5
#==================================================================================================
#==================================================================================================
# Standard call back functions
#==================================================================================================
function parseArgs-getCimRoles  { # or parseArgs-local
	#argList+=(-optionArg,1,option,scriptVar,,script,'Help text')
	#argList+=(-flagArg,2,switch,scriptVar,,script,'Help text')
	argList+=(-allCims,3,switch,allCims,,script,'Process all the CIM instances present')
	return 0
}
function Goodbye-getCimRoles  { # or Goodbye-local
	rm -rf $tmpRoot > /dev/null 2>&1
	return 0
}
function testMode-getCimRoles  { # or testMode-local
	return 0
}

#==================================================================================================
# local functions
#==================================================================================================

#===================================================================================================
# Declare local variables and constants
#===================================================================================================
step='getCimWorkflowRoles'

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
helpSet='script,client,env,cims'
GetDefaultsData $myName
ParseArgsStd
Hello
Init 'getClient getEnv getDirs checkEnvs getCims noPreview noPublic'

## Set outfile -- look for std locations
outFile=/home/$userName/$client-CIM_Roles.xls
if [[ -d $localClientWorkFolder ]]; then
	if [[ ! -d $localClientWorkFolder/$client ]]; then mkdir -p $localClientWorkFolder/$client; fi
	outFile=$localClientWorkFolder/$client/$client-CimRoles.xls
fi

## Make sure user wants to continue
unset verifyArgs
verifyArgs+=("Client:$client")
verifyArgs+=("Env:$(TitleCase $env) ($srcDir)")
verifyArgs+=("CIMs:$cimStr")
verifyArgs+=("Output File:$outFile")
verifyContinueDefault='Yes'
VerifyContinue "You are asking generate CIM roles for"

if [[ -e $outFile && $verify == true ]]; then
	Msg2 "\nOutput file '$outFile' already exists, file renamed to:\n\t$outFile.$backupSuffix\n"
	mv $outFile $outFile.$backupSuffix
fi

#===================================================================================================
#= Main
#===================================================================================================
cimStr=$(echo $cimStr | tr -d ' ' )
cimStr=\"$(sed 's|,|","|g' <<< $cimStr)\"
#= Run the step
	FindExecutable "$step" 'std' 'steps:html' 'steps' ## Sets variable executeFile
	srcStepFile=$executeFile

	if [[ -f /home/$userName/clientWork/$client/$step.html ]]; then
		srcStepFile=/home/$userName/clientWork/$client/$step.html
	fi
	Msg2 "Using step file: $srcStepFile\n"
	cp -fp $srcStepFile $srcDir/web/courseleaf/localsteps/$step.html
	sed -i s"_var cims=\[\];_var cims=\[${cimStr}\];_" $srcDir/web/courseleaf/localsteps/$step.html
	sed -i s"_var env='';_var env='${env}';_" $srcDir/web/courseleaf/localsteps/$step.html

	Msg2 "Running step $step...\n"
	cd $srcDir/web/courseleaf
	#./courseleaf.cgi $step /roles.tcf > $outFile
	./courseleaf.cgi $step /courseadmin/index.tcf > $outFile
	#rm $srcDir/web/courseleaf/localsteps/$step.html
	Msg2 "\nOutput data generated in '$outFile'\n"
	#rm -f $srcDir/web/courseleaf/localsteps/$step.html

#===================================================================================================
#= Bye-bye
#printf "0: noDbLog = '$noDbLog', myLogRecordIdx = '$myLogRecordIdx'\n" >> ~/stdout.txt
Goodbye 0
## Thu Mar 24 15:03:02 CDT 2016 - dscudiero - Get steps soruce directory from the database
## Thu Mar 24 15:29:16 CDT 2016 - dscudiero - General syncing of dev to prod
## Fri Apr  1 11:49:16 CDT 2016 - dscudiero - Switch to new format VerifyContinue
## Wed Jul 27 09:02:11 CDT 2016 - dscudiero - Delete step file after run
## Wed Jul 27 12:44:31 CDT 2016 - dscudiero - General syncing of dev to prod
## Wed Aug 10 15:33:33 CDT 2016 - dscudiero - General syncing of dev to prod
## Thu Aug 11 15:42:48 CDT 2016 - dscudiero - Add the -allCims flag
## 04-13-2017 @ 14.01.02 - (1.10.20)   - dscudiero - Add a default for VerifyContinue
