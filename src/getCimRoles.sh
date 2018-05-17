#!/bin/bash
#==================================================================================================
version=1.11.7 # -- dscudiero -- Thu 05/17/2018 @ 11:53:20.77
#==================================================================================================
TrapSigs 'on'
myIncludes="WriteChangelogEntry"
Import "$standardInteractiveIncludes $myIncludes"

originalArgStr="$*"
scriptDescription="Build a list of all of the roles that are potentially use in CIM workflows"

#= Description +===================================================================================
# Get a list if CIM roles used in workflows
#===================================================================================================
# 05-28-14 -- 	dgs - Initial coding
# 07-17-15 --	dgs - Migrated to framework 5
#==================================================================================================
#==================================================================================================
# Standard call back functions
#==================================================================================================
function getCimRoles-ParseArgsStd { # or parseArgs-local
	#myArgs+=("shortToken|longToken|type|scriptVariableName|<command to run>|help group|help textHelp")
	myArgs+=("load|load|switch|load||script|Automatically load the roles to the site")
	myArgs+=("noload|noload|switch|load|load=false|script|Automatically load the roles to the site")
	myArgs+=("replace|replace|switch||loadMode='replace'|script|Replace all of the target sites role data")
	myArgs+=("add|add|switch||loadMode='add'|script|Add the role data into the sites existing role data")
	return 0
}
function getCimRoles-Goodbye { # or Goodbye-local
	SetFileExpansion 'on' ; rm -rf $tmpRoot/${myName}* >& /dev/null ; SetFileExpansion
	return 0
}
function getCimRoles-testMode { # or testMode-local
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
Hello
GetDefaultsData $myName
ParseArgsStd $originalArgStr
[[ -n $unknowArgs ]] && cimStr="$unknowArgs"
Init 'getClient getEnv getDirs checkEnvs getCims noPreview noPublic addPvt'
[[ -n $loadMode ]] && load=true
[[ $load == true && -z $loadMode ]] && loadMode='add'

dump 1 env load loadMode verify
## Get load mode
if [[ $env == 'test' && -z $load && $verify == true ]]; then
	unset ans; Prompt 'ans' 'Do you wish to load the data into the roles file?' 'Yes No' 'No'; ans="${ans:0:1}"; ans="${ans,,[a-z]}"
	if [[ $ans == y ]]; then
		load=true
		unset ans; Prompt 'ans' 'Please specify the load mode?' 'Add Replace' 'Add'; ans="${ans:0:1}"; ans=${ans,,[a-z]}
		loadMode='merge'
		[[ $ans == 'a' ]] && loadMode='add'
		[[ $ans == 'r' ]] && loadMode='replace'
	fi
fi
[[ $loadMode == 'merge' ]] && Terminate "Sorry, the '-merge' option is not supported at this time."

## Set outfile -- look for std locations
outFile=/home/$userName/$client-$env-CIM_Roles.txt
if [[ -d $localClientWorkFolder ]]; then
	if [[ ! -d $localClientWorkFolder/$client ]]; then mkdir -p $localClientWorkFolder/$client; fi
	outFile=$localClientWorkFolder/$client/$client-$env-CimRoles.txt
fi

## Make sure user wants to continue
unset verifyArgs
verifyArgs+=("Client:$client")
verifyArgs+=("Env:$(TitleCase $env) ($siteDir)")
verifyArgs+=("CIMs:$cimStr")
[[ $load == true ]] && verifyArgs+=("Load site roles:$loadMode")
verifyContinueDefault='Yes'
VerifyContinue "You are asking generate CIM roles for"

#===================================================================================================
#= Main
#===================================================================================================
cimStr=$(echo $cimStr | tr -d ' ' )

#= Run the step
	srcStepFile="$(FindExecutable -step "$step")"
	[[ -z $srcStepFile ]] && Terminate "Could find the step file ('$step')"

	Msg "Using step file: $srcStepFile\n"
	[[ -f $siteDir/web/courseleaf/localsteps/$step.html ]] && mv -f $siteDir/web/courseleaf/localsteps/$step.html $siteDir/web/courseleaf/localsteps/$step.html.bak
	
	## Make sure we have wffuncs defined and also import each cims workflowFuncs file
	echo > "$siteDir/web/courseleaf/localsteps/$step.html"
	echo '%spidercode%' >> "$siteDir/web/courseleaf/localsteps/$step.html"
	echo 'if(typeof wffuncs == "undefined")' >> "$siteDir/web/courseleaf/localsteps/$step.html"
	echo '	var wffuncs = {};' >> "$siteDir/web/courseleaf/localsteps/$step.html"
	echo '%spidercode%' >> "$siteDir/web/courseleaf/localsteps/$step.html"
	echo >> "$siteDir/web/courseleaf/localsteps/$step.html"
	for cim in ${cimStr//,/ }; do
		echo "%import /$cim/workflowFuncs.atj:atj%" >> "$siteDir/web/courseleaf/localsteps/$step.html"
	done
	cat $srcStepFile >> "$siteDir/web/courseleaf/localsteps/$step.html"

	cimStr=\"$(sed 's|,|","|g' <<< $cimStr)\"
	sed -i s"_var cims=\[\];_var cims=\[${cimStr}\];_" $siteDir/web/courseleaf/localsteps/$step.html
	sed -i s"_var env='';_var env='${env}';_" $siteDir/web/courseleaf/localsteps/$step.html

	Msg "Running step $step...\n"
	cd $siteDir/web/courseleaf
	./courseleaf.cgi $step /courseadmin/index.tcf > $outFile

	## Check for errors
	grepStr=$(ProtectedCall "grep 'ATJ error:' $outFile")
	[[ -n $grepStr ]] && Terminate "Step produced an ATJ error, please review '$outFile' for additional information"

	## If the user requested that the data be loaded the read data and write out to the roles.tcf file
	if [[ $load == true ]]; then
		loadedStr=' '
		Msg "'Load' option is active, $loadMode data..."
		roleFile=$siteDir/web/courseleaf/roles.tcf
		tmpRoleFile=$siteDir/web/courseleaf/roles.tcf.new
		cp -rfp "$roleFile" "${roleFile}.bak"
		Msg "^Existing roles file saved as 'roles.tcf.bak'"
		if  [[ $loadMode == 'replace' ]]; then
			echo "// Loaded ($loadMode) by $userName using $myName ($version) on $(date)" > $tmpRoleFile
			echo "template:custom" >> $tmpRoleFile
			echo "pageflags:autoapprove" >> $tmpRoleFile
			echo "localsteps:Role Management|groups|role|fields=Email;lookuptypes=user;" >> $tmpRoleFile
			echo >> $tmpRoleFile
		else
			cp -fp "$roleFile" "$tmpRoleFile"
		fi

		foundStart=false
		ifs="$IFS"; IFS=$'\r'; while read line; do
			[[ ${line:0:5} == 'Role ' ]] && foundStart=true && continue
			[[ $foundStart != true ]] && continue
			[[ -z $line ]] && break
			# line=$(tr \t '|' <<< "$line")
			roleName="$(cut -f1 -d$'\t' <<< $line)"
			roleMembers="$(cut -f2 -d$'\t' <<< $line)"
			roleEmail="$(cut -f3 -d$'\t' <<< $line)"
			dump -1 -n line -t roleName roleMembers roleEmail
			case $loadMode in
				add) 
					unset grepStr; grepStr=$(ProtectedCall "grep 'role:$roleName' $tmpRoleFile")
					[[ -z $grepStr ]] && echo "role:$roleName|$roleMembers|$roleEmail" >> "$tmpRoleFile"
					;;
				replace)
					echo "role:$roleName|$roleMembers|$roleEmail" >> "$tmpRoleFile"
					;;
			esac
		done < $outFile
		IFS="$ifs"

		mv -f "$tmpRoleFile" "$roleFile"
		Msg "Roles file updated"
		Msg "Writing changelog.txt records..."
		changeLogLines+=("Roles file updated ($loadMode)")
		WriteChangelogEntry 'changeLogLines' "$siteDir/changelog.txt" "$myName"
		Msg "Logging done"
	else
		loadedStr=' not '
	fi

	Msg
	Note "The generated output data can be found at:"
	Msg "^'$(ColorK $outFile)'"
	Msg "This is a tab delimited data file that can be loaded by Microsoft Excel worksheet"
	Msg "if you wish, you can provide a 'prettier' worksheet by copying this data into a .xlsx"
	Msg "format file.  The master workflows template Excel file can be found at:"
	Msg "^'$(ColorK '\\\\saugus\docs\\tools\workbooksCIMWorkflows.xltm')' (Windows)"
	Msg "^'$(ColorK "$TOOLSPATH/workbooks/CIMWorkflows.xltm")' (Linux)"
	Msg "You can use this file as a start if you wish."
	Msg

	if [[ $userName == dscudiero ]]; then
		Msg
		Msg "Workflow roles have been generated for:"
		Msg "^$client / $env / $cimStr"
		Msg "Attached you will find a workbook with the roles data."
		Msg "^$(basename $outFile)"
		Msg "The roles have${loadStr}been loaded into the $env The attached"
		Msg "roles data is provided in raw tab delimited format, if you"
		Msg "wish to provide the client a 'prettier' format, you can copy"
		Msg "this data into a true .xlsx format file."
		Msg "Fyi, the master workflows template Excel file can be found at: "
		Msg '^\\\\saugus\docs\\tools\workbooksCIMWorkflows.xltm (Windows)'
		Msg "You can use this file as a start if you wish."
		Msg
		Msg "If you have questions please see me."
		Msg
	fi

	[[ -x $HOME/bin/logit ]] && $HOME/bin/logit -cl "${client:--}" -e "${env:--}" -ca 'workflow' "$myName - Generated CIM roles worksheet, roles loaded: $load"

	# rm -f "$siteDir/web/courseleaf/localsteps/$step.html"
	[[ -f $siteDir/web/courseleaf/localsteps/$step.html.bak ]] && mv -f $siteDir/web/courseleaf/localsteps/$step.html.bak $siteDir/web/courseleaf/localsteps/$step.html

#===================================================================================================
#= Bye-bye
#printf "0: noDbLog = '$noDbLog', myLogRecordIdx = '$myLogRecordIdx'\n" >> ~/stdout.txt
Goodbye 0

#===================================================================================================
# Check-in Log
#===================================================================================================
## Thu Mar 24 15:03:02 CDT 2016 - dscudiero - Get steps source directory from the database
## Thu Mar 24 15:29:16 CDT 2016 - dscudiero - General syncing of dev to prod
## Fri Apr  1 11:49:16 CDT 2016 - dscudiero - Switch to new format VerifyContinue
## Wed Jul 27 09:02:11 CDT 2016 - dscudiero - Delete step file after run
## Wed Jul 27 12:44:31 CDT 2016 - dscudiero - General syncing of dev to prod
## Wed Aug 10 15:33:33 CDT 2016 - dscudiero - General syncing of dev to prod
## Thu Aug 11 15:42:48 CDT 2016 - dscudiero - Add the -allCims flag
## 04-13-2017 @ 14.01.02 - (1.10.20)   - dscudiero - Add a default for VerifyContinue
## 06-08-2017 @ 10.33.24 - (1.10.21)   - dscudiero - delete step file after run
## 06-08-2017 @ 11.39.13 - (1.10.23)   - dscudiero - General syncing of dev to prod
## 06-08-2017 @ 11.55.25 - (1.10.24)   - dscudiero - General syncing of dev to prod
## 06-26-2017 @ 07.51.04 - (1.10.25)   - dscudiero - change cleanup to not remove the entire tmp directory
## 09-29-2017 @ 10.14.49 - (1.10.28)   - dscudiero - Update FindExcecutable call for new syntax
## 10-03-2017 @ 11.02.00 - (1.10.32)   - dscudiero - General syncing of dev to prod
## 11-01-2017 @ 09.55.10 - (1.10.39)   - dscudiero - Switched to ParseArgsStd
## 11-02-2017 @ 06.58.45 - (1.10.42)   - dscudiero - Switch to ParseArgsStd
## 11-02-2017 @ 11.02.04 - (1.10.43)   - dscudiero - Add addPvt to the init call
## 03-13-2018 @ 08:30:29 - 1.10.92 - dscudiero - Remove the load merge option
## 03-14-2018 @ 13:46:05 - 1.10.93 - dscudiero - Set debug level on debug statements
## 03-16-2018 @ 08:20:27 - 1.10.95 - dscudiero - Added code to make sure wffuncs is defined
## 03-16-2018 @ 08:57:00 - 1.10.100 - dscudiero - Fix problem writing out step header code
## 03-23-2018 @ 15:34:41 - 1.10.101 - dscudiero - D
## 03-23-2018 @ 17:04:45 - 1.10.102 - dscudiero - Msg3 -> Msg
## 04-26-2018 @ 08:34:15 - 1.11.1 - dscudiero - Add longNames to argDefs
## 05-16-2018 @ 15:46:00 - 1.11.1 - dscudiero - Added activityLog logging
## 05-16-2018 @ 15:50:42 - 1.11.2 - dscudiero - Cosmetic/minor change/Sync
## 05-17-2018 @ 11:13:14 - 1.11.6 - dscudiero - Change instructional text
## 05-17-2018 @ 11:53:48 - 1.11.7 - dscudiero - Added loaded to the logit message
