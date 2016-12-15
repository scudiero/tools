#!/bin/bash
#===================================================================================================
version=5.4.3 # -- dscudiero -- 12/14/2016 @ 11:30:08.58
#===================================================================================================
TrapSigs 'on'
imports='GetDefaultsData ParseArgs ParseArgsStd Hello Init Goodbye' #imports="$imports "
Import "$imports"
originalArgStr="$*"
scriptDescription="Publish courseleaf product to NEXT - dispatcher"

#===================================================================================================
# Deployment script to move a site to either public or preview
# Script takes one optional parameter which is the deployment target, if not specified it defaults
# to 'preview'
#===================================================================================================
# Copyright ©2015 David Scudiero -- all rights reserved.
# 04-24-13 -- 	dgs 	- Initial coding
# 05-01-13 -- 	dgs 	- Added code to stop and then resume after an external republish is done
#								Added make bubble step
#								Started undo -- not quite finished
# 05-14-13 -- 	dgs 	- Check for host = host in sendnow.atj. apparent change in skeleton
# 05-23-13 -- 	dgs 	- pulled undo -- major cleanup
# 06-14-13 -- 	dgs 	- fixed sed code for edit of courseleaf.cfg
# 07-30-13 -- 	dgs 	- added CIM
# 08-22-13 -- 	dgs 	- update to handle olympic
# 10-10-13	--	dgs 	- Fixed various issues with the CIM deploy
# 10-10-13	--	dgs 	- Added additional DB deletions for CIM
# 01-14-14	--	dgs		- Updated for new email keywords in localsteps/default.tcf
# 01-15-15	--	dgs		- Updated to intelegently select env list for user to select from .
#===================================================================================================

#==================================================================================================
# local functions
#==================================================================================================
	#==================================================================================================
	# parse script specific arguments
	#==================================================================================================
	function parseArgs-publish {
		# argList+=(argFlag,minLen,type,scriptVariable,extraToken/exCmd,helpSet,helpText)  #type in {switch,switch#,option,help}
		argList+=(-cat,2,switch,cat,cat=y,,"Publish the Catalog")
		argList+=(-cim,2,switch,cim,cim=y,,"Publish the CIMs")
	}

#==================================================================================================
# Declare local variables and constants
#==================================================================================================

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
helpSet='client,env'
GetDefaultsData $myName
ParseArgsStd
Hello
Msg2
# if [[ $cim = '' && $cat = '' ]]; then
# 	Prompt cat 'Do you wish to refresh CAT?' 'Yes No'; cat=$(Upper $cat); cat=$(Lower ${cat:0:1})
# 	if [[ $cat != 'y' ]]; then Msg "Publising CIMs"; cim='y'; fi
# fi
#TODO: Remove when cat publish is done
cim='y'; cat='n';

unset products
if [[ $cat == 'y' ]]; then products="$products cat"; fi
if [[ $cim == 'y' ]]; then products="$products cim"; fi
if [[ $cat == 'y' ]]; then 
	Terminate "Note: Publishing CAT is currently not supported, please see Dave for details.\n"
	initArgs="courseleaf getSrcEnv"
fi

if [[ $cim == 'y' ]]; then initArgs="courseleaf getSrcEnv getTgtEnv getCims"; fi
Init "$initArgs"
#dump -q cat cim products env srcEnv srcDir tgtEnv tgtDir cimStr

#####################################################################################################
# Main loop
#####################################################################################################

#===========================================================================
## set backup dir
	unset backupDir
	if [[ -d  $tgtDir/attic ]]; then backupDir=$tgtDir/attic;
	elif [[ -d  $tgtDir/Attic ]]; then backupDir=$tgtDir/Attic;
	else
		backupDir=$tgtDir/attic
	fi
	backupDir=$backupDir/$myName-$backupSuffix

######################################################################################################
## Source appropriate deployment subscript
######################################################################################################
	if [[ $(Contains "$products" 'cat') == true ]]; then
		tgtDir=$previewDir
		# . $myPath/publishCat $client
	fi
	if [[ $(Contains "$products" 'cim') == true ]]; then
		[[ "$client" == 'jwu' && $srcEnv == 'dev' ]] && srcDir=/mnt/dev9/web/jwucim
		. $(dirname ${BASH_SOURCE[0]})/${myName}Cim.sh
	fi

######################################################################################################
## Done
#####################################################################################################
	Goodbye 0

#==================================================================================================
## Check-in log
#==================================================================================================
# 08-26-2015 -- dscudiero -- Fix issue with setSiteDirs directlry assignments (5.3)
# 10-16-2015 -- dscudiero -- Update for framework 6 (5.4)
