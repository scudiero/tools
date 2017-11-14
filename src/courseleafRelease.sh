#!/bin/bash
# XO NOT AUTOVERSION
#==================================================================================================
version=1.0.14 # -- dscudiero -- Tue 11/14/2017 @  8:02:27.88
#==================================================================================================
TrapSigs 'on'
myIncludes="ProtectedCall SelectMenuNew"
Import "$standardInteractiveIncludes $myIncludes"

originalArgStr="$*"
scriptDescription=""

#= Description +===================================================================================
# Refresh a Courseleaf component from the git repo
#==================================================================================================
#==================================================================================================
# Standard call back functions
#==================================================================================================
function parseArgs-courseleafRelease  { # or parseArgs-local
	#argList+=(-optionArg,1,option,scriptVar,,script,'Help text')
	#argList+=(-flagArg,2,switch,scriptVar,,script,'Help text')
	argList+=(-file,4,option,file,,script,'The file name relative to the root site directory')
	return 0
}
function Goodbye-courseleafRelease  { # or Goodbye-local
	rm -rf $tmpRoot > /dev/null 2>&1
	return 0
}
function testMode-courseleafRelease  { # or testMode-local
	client='tamu'
	env='pvt'
	cimStr='courseadmin'
	runTest='IsGraduate'
	runTest='all'
	overWrite=true
	verify=false
	Msg3 $N "TestMode:"
	dump -t client env cimStr runTest overWrite verify
	Msg3
	return 0
}

#==================================================================================================
# local functions
#==================================================================================================

#==================================================================================================
# Declare local variables and constants
#==================================================================================================
tmpFile=$(mkTmpFile)
trueVars=''
falseVars=''
for var in $trueVars; do eval $var=true; done
for var in $falseVars; do eval $var=false; done

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
helpSet='script'
scriptHelpDesc="This script is used to release a new curseleaf product (CAT, CIM, CLSS) git repository for use by courseleafPatch"
GetDefaultsData $myName
ParseArgsStd
Hello

# Get the list of available releases to release
	[[ -n $client ]] && findRoot="./$client" || findRoot='.'
	cwd=$(pwd)
	cd $gitRepoShadow
	newReleases=($(ProtectedCall "find $findRoot -mindepth 1 -maxdepth 2 -type d -name '*-new'" 2> /dev/null))
	[[ ${#newReleases[@]} -eq 0 ]] && Msg "Found no new releases for '$client'" && Goodbye 0

if [[ ${#newReleases[@]} -gt 1 ]]; then
	unset menuList menuItem
	## Build the menuList
		menuList+=("|Product|Release")
		for release in ${newReleases[@]}; do
			menuItem="|$(cut -d'/' -f2 <<< $release)|$(cut -d'/' -f3 <<< $release)"  #Description
			menuList+=("$menuItem")
		done
	## Display the menu
		Msg3
		Msg3 "Please select the item that you wish to release:"
		Msg3
		SelectMenuNew 'menuList' 'selectItem' "\nRelease ordinal number $(ColorK '(ord)') (or 'x' to quit) > "
		[[ $selectItem == '' ]] && Goodbye 0
		product=$(cut -d'|' -f1 <<< $selectItem)
		release=$(cut -d'|' -f2 <<< $selectItem)
else
	product=$(cut -d'/' -f2 <<< ${newReleases[0]})
	release=$(cut -d'/' -f3 <<< ${newReleases[0]})
fi

unset verifyArgs
verifyArgs+=("Product:$product")
verifyArgs+=("Release:$release")
VerifyContinue "You are asking to release the git repository"

myData="Client: '$client', Env: '$env', Cims: '$cimStr' "
[[ $logInDb != false && $myLogRecordIdx != "" ]] && dbLog 'data' $myLogRecordIdx "$myData"

#===================================================================================================
# Main
#===================================================================================================

mv -f $gitRepoShadow/$product/$release $gitRepoShadow/$product/$(cut -d'-' -f1 <<< $release)
cd "$cwd"

#===================================================================================================
## Done
#===================================================================================================
Goodbye 0 #'alert'

#===================================================================================================
## Check-in log
#===================================================================================================
## Tue Aug 23 10:47:24 CDT 2016 - dscudiero - Release a qualified GIT repo
## Tue Aug 23 10:47:31 CDT 2016 - dscudiero - Release a qualified GIT repo
## Tue Aug 23 12:56:53 CDT 2016 - dscudiero - General syncing of dev to prod
## Fri Oct 14 13:47:39 CDT 2016 - dscudiero - General syncing of dev to prod
## Wed Oct 19 10:42:46 CDT 2016 - dscudiero - fixed another reference to courseleafRefresh
## 04-17-2017 @ 10.31.44 - (1.0.10)    - dscudiero - fixed for selectMenuNew changes
## 11-14-2017 @ 08.02.56 - (1.0.14)    - dscudiero - Switch to Msg3
