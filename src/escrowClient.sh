#!/bin/bash
#==================================================================================================
version=1.0.39 # -- dscudiero -- 12/14/2016 @ 11:26:18.31
#==================================================================================================
TrapSigs 'on'
imports='GetDefaultsData ParseArgs ParseArgsStd Hello Init Goodbye' #imports="$imports "
Import "$imports"
originalArgStr="$*"
scriptDescription="Escrow courseleaf site"

#==================================================================================================
# Create an tared up file of an entire site for escrow purposes
#==================================================================================================
#==================================================================================================
# Copyright ©2014 David Scudiero -- all rights reserved.
# 06-17-15 -- dgs - Initial coding
# 07-17-15 -- dgs - Migrated to framework 5
# 01-23-16 -- dgs - refactored how site directory was found, changed msgs, switched to 'xz' compression
#==================================================================================================

#==================================================================================================
# local functions
#==================================================================================================

#==================================================================================================
# Declare local variables and constants
#==================================================================================================

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
helpSet='script,client'
GetDefaultsData $myName
ParseArgsStd
Hello
Init 'getClient'
SetSiteDirs 'setDefault'

unset verifyArgs
verifyArgs+=("Client:$client")
verifyArgs+=("SiteDir:$prodSiteDir")
VerifyContinue "You are asking create an escrow file"

#==================================================================================================
## Main
#==================================================================================================
cd $prodSiteDir
tarDir=$courseleafEscrowedSitesDir

[[ ! -d $tarDir ]] && mkdir $tarDir
tarFile=$tarDir/$client@$(date +"%m-%d-%Y").tar.xz
[[ -f $tarFile ]] && rm -f $tarFile

Msg2
unset dirsToTar
for env in test next curr public; do
	[[ -d ./$env ]] && dirsToTar="$env $dirsToTar"
done
dirsToTar=$(Trim "$dirsToTar")
Msg2 "Tarring directories: $(echo $dirsToTar | tr ' ' ','), process takes quite a long time..."

set +f
$DOIT tar -cJf $tarFile $dirsToTar; rc=$?
rc=$?; [[ $rc -ne 0 ]] && Msg "T Process returned a non-zero return code ($rc), Please review messages" && Msg
Msg2 "\nEscrow file generated at: $tarFile"

#==================================================================================================
## Done
#==================================================================================================
Goodbye 0 'alert'
