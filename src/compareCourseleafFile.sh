#!/bin/bash
#==================================================================================================
version=1.0.3 # -- dscudiero -- Fri 03/23/2018 @ 14:28:36.54
#==================================================================================================
TrapSigs 'on'
imports='GetDefaultsData ParseArgs ParseArgsStd Hello Init Goodbye'
imports="$imports GetCims"
Import "$imports"
originalArgStr="$*"
scriptDescription="Compare workflow files"

#==================================================================================================
# Compare courseleaf file
#==================================================================================================
#==================================================================================================
# Copyright ©2017 David Scudiero -- all rights reserved.
#==================================================================================================

#==================================================================================================
# local functions
#==================================================================================================


#==================================================================================================
# Declare local variables and constants
#==================================================================================================
## Get the files to act on from the database
GetDefaultsData

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
helpSet='script,client,env'
GetDefaultsData $myName
ParseArgsStd $originalArgStr

Hello
Init "getClient getSrcEnv getTgtEnv getDirs checkEnvs noWarn"

while [[ -z $file ]]; do
	Prompt file "Please specify the file that you wish to check, relative to the site Dir" "*any*"
	[[ ${file:0:1} == / ]] && file="${file:1}"
	[[ ! -f $siteDir/$file ]] && Error "File not found" && unset file
done
srcFile=$skeletonRoot/release/$file
tgtFile=$tgtDir/$file

## Verify continue
go=true
unset verifyArgs
verifyArgs+=("Client:$client")
verifyArgs+=("Target Env:$(TitleCase $tgtEnv) ($tgtDir")
verifyArgs+=("File:$file")
VerifyContinue "You are comparing CourseLeaf file for:"

myData="Client: '$client', file: '$file', tgtEnv: '$tgtEnv'"
[[ $logInDb != false && $myLogRecordIdx != "" && $testMode != true ]] && dbLog 'data' $myLogRecordIdx "$myData"

#==================================================================================================
## Main
#==================================================================================================
srcMd5=$(md5sum $srcFile | cut -f1 -d" ")
tgtMd5=$(md5sum $tgtFile | cut -f1 -d" ")
[[ $srcMd5 != $tgtMd5 ]] && Warning 0 1 "'${file}', files are different" || Msg "^^'${file}', files match"

#==================================================================================================
## Done
#==================================================================================================
Goodbye 0 #'alert'

#==================================================================================================
## Check-in log
## 04-25-2017 @ 08.39.56 - (1.0.0)     - dscudiero - Update comments
## 03-22-2018 @ 12:35:55 - 1.0.2 - dscudiero - Updated for Msg3/Msg, RunSql2/RunSql, ParseArgStd/ParseArgStd2
## 03-23-2018 @ 15:33:02 - 1.0.3 - dscudiero - D
