#!/bin/bash
#DO NOT AUTOVERSION
#==================================================================================================
version=1.1.01 # -- dscudiero -- Fri 05/11/2018 @  9:38:34.16
#==================================================================================================
TrapSigs 'on'
myIncludes="SelectMenuNew CopyFileWithCheck"
Import "$standardInteractiveIncludes $myIncludes"

originalArgStr="$*"
scriptDescription="This script will run automated workflow test cases"

#= Description +===================================================================================
# Run automated test cases for workflow in a CIM insance
# See 'Examle test file' below
#==================================================================================================
#==================================================================================================
# Standard call back functions
#==================================================================================================
function wfTest-ParseArgsStd  {
	myArgs+=('instance|instance|option|instance||script|The name of the CIM instance to be tested')
	#myArgs+=('g|group|option|group||script|The name of the test group to be run')
	myArgs+=('r|runTests|option|runTests||script|The comma seperated list pf test names to run')
	myArgs+=('over|overWrite|switch|overWrite||script|Over write the test proposal folder if present')
	myArgs+=('noS|noStopFirst|switch|noStopFirst||script|Do not stop on the first error detected')
	return 0
}

function wfTest-Goodbye  { # or Goodbye-local
	rm -rf $tmpRoot > /dev/null 2>&1
	for instance in $(tr ',' ' ' <<< $cimStr); do
		proposalDir="$siteDir/web/$instance/$tempProposalId"
		[[ -d "$proposalDir" && -f $proposalDir/.$myName ]] && rm -rf "$proposalDir"
	done
	return 0
}

function wfTest-testMode  { # or testMode-local
	xmlFile="$myPath/workflowTest.xml"
	client='tamu'
	env='pvt'
	cimStr='courseadmin'
	runTests='all'
	overWrite=true
	verify=false
	Msg $N "TestMode:"
	dump -t client env cimStr runTests overWrite verify
	Msg
	return 0
}

#==================================================================================================
# local functions
#==================================================================================================
#==================================================================================================
# Parse the xml file, returns the following hash tables
# setup["$instance.$test.vars"]
# setup["$instance.$test.workflow"]
# expect["$instance.$test.vars"]
# expect["$instance.$test.workflow"]
#
# '.vars' 		contains a string of the form '<varName> varValue|<varName> varValue|<varName> varValue|...'
# '.steps' 		contains a string of the form '<step>|<step>|...'
# '.workflow'	contains a string of the form '<workflowName>'
#
#==================================================================================================
function ParseXmlFile {
	local xmlFile="$1"
	local instance test inSetup inExpect varName varValue tmpStr1 tmpStr2 group

	[[ ! -r "$xmlFile" ]] && Msg $T "Could not locate a '$myName.xml' file in\n^$xmlFile"
	## Parse the XML file
	commentBlock=false
	while read line; do
		line=$(Trim "$(tr -d '\011\012\015' <<< "$line")")
		[[ $line == '' || ${line:0:2} == '//' ]] && continue
		[[ ${line:0:4} == '<!--' && ${line:(-3)} == '-->' ]] && continue
		[[ ${line:0:4} == '<!--' ]] && commentBlock=true && continue
		[[ ${line:0:3} == '-->' || ${line:(-3)} == '-->' ]] && commentBlock=false && continue
		[[ $commentBlock == true ]] && continue
		dump -3 -t line
		xml+=("$line")
		if [[ $(Contains "$line" '<instance name=') == true ]]; then
			instance=$(cut -d'"' -f2 <<< $line) && instances+=($instance)
		elif [[ $(Contains "$line" '</instance>') == true ]]; then
			unset instance
		elif [[ $(Contains "$line" '<group name=') == true ]]; then
			group=$(cut -d'"' -f2- <<< $line)
			group=$(cut -d'"' -f1 <<< $group)
			groups+=("$instance.$group")
		elif [[ $(Contains "$line" '</group>') == true ]]; then
			unset group
		elif [[ $(Contains "$line" '<test name=') == true ]]; then
			test=$(cut -d'"' -f2- <<< $line)
			test=$(cut -d'"' -f1 <<< $test)
			[[ $group != '' ]] && key="$instance.$group.$test" || key="$instance.$test"
			tests+=($key)
		elif [[ $(Contains "$line" '</test>') == true ]]; then
			unset test
		elif [[ $(Contains "$line" '<setup>') == true ]]; then
			inSetup=true
		elif [[ $(Contains "$line" '</setup>') == true ]]; then
			inSetup=false
		elif [[ $(Contains "$line" '<expect>') == true ]]; then
			inExpect=true
		elif [[ $(Contains "$line" '</expect>') == true ]]; then
			inExpect=false
		## <tcfdata>
		elif [[ $inSetup == true &&  $(Contains "$line" '<tcfdata name="') == true ]]; then
			varName=$(cut -d'"' -f2 <<< $line)
			varValue=$(cut -d'"' -f4 <<< $line)
			tmpStr1="$varName $varValue"
			[[ $group != '' ]] && key="$instance.$group.$test" || key="$instance.$test"
			if [[ ${setup["$key.tcfdata"]+abc} ]]; then
				tmpStr2="${setup["$key.tcfdata"]}"
				setup["$key.tcfdata"]="$tmpStr2|$tmpStr1"
			else
				setup["$key.tcfdata"]="$tmpStr1"
			fi
		## <tcadata>
		elif [[ $inSetup == true &&  $(Contains "$line" '<tcadata name="') == true ]]; then
			varName=$(cut -d'"' -f2 <<< $line)
			varValue=$(cut -d'"' -f4 <<< $line)
			tmpStr1="$varName $varValue"
			[[ $group != '' ]] && key="$instance.$group.$test" || key="$instance.$test"
			if [[ ${setup["$key.tcadata"]+abc} ]]; then
				tmpStr2="${setup["$key.tcadata"]}"
				setup["$key.tcadata"]="$tmpStr2|$tmpStr1"
			else
				setup["$key.tcadata"]="$tmpStr1"
			fi
		## <workflow>
		elif [[ $inSetup == true &&  $(Contains "$line" '<workflow name="') == true ]]; then
			workflow=$(cut -d'"' -f2 <<< $line)
			[[ $group != '' ]] && key="$instance.$group.$test" || key="$instance.$test"
			setup["$key.workflow"]="$workflow"

		elif [[ $inSetup == true &&  $(Contains "$line" '<step>') == true ]]; then
			step="$(cut -d'>' -f2 <<< $line | cut -d'<' -f1)"
			[[ $group != '' ]] && key="$instance.$group.$test" || key="$instance.$test"
			if [[ ${setup["$key.steps"]+abc} ]]; then
				tmpStr2="${setup["$key.steps"]}"
				setup["$key.steps"]="$tmpStr2|$step"
			else
				setup["$key.steps"]="$step"
			fi
		elif [[ $inExpect == true &&  $(Contains "$line" '<workflow>') == true ]]; then
			workflow=$(cut -d'>' -f2 <<< $line | cut -d'<' -f1)
			[[ $group != '' ]] && key="$instance.$group.$test" || key="$instance.$test"
			expect["$key.workflow"]="$workflow"
		## <step>
		elif [[ $inExpect == true &&  $(Contains "$line" '<step>') == true ]]; then
			step="$(cut -d'>' -f2 <<< $line | cut -d'<' -f1)"
			[[ $group != '' ]] && key="$instance.$group.$test" || key="$instance.$test"
			if [[ ${expect["$key.steps"]+abc} ]]; then
				tmpStr2="${expect["$keyt.steps"]}"
				expect["$key.steps"]="$tmpStr2|$step"
			else
				expect["$key.steps"]="$step"
			fi
		fi #End of parse checks
	done < "$xmlFile"

	if [[ $verboseLevel -ge 2 ]]; then
		Msg; for instance in "${instances[@]}"; do dump instance; done
		Msg; for group in "${groups[@]}"; do dump group; done
		Msg; for test in "${tests[@]}"; do dump test; done
		Msg; Msg "setup[] ="; for key in "${!setup[@]}"; do echo -e "\t[$key] = >${setup[$key]}<"; done
		Msg; Msg "expect[] ="' '; for key in "${!expect[@]}"; do echo -e "\t[$key] = >${expect[$key]}<"; done
	fi

	return 0
}

#==================================================================================================
# Parse the output of the testworkflow step
#==================================================================================================
function ParseTestworkflowOut {
	local dataFile="$1"
	local line step workflow fyiStr

	local foundStart=false
	while read -r line; do
		## Workflow record
		if [[ $(Contains "$line" 'Workflow:') == true ]]; then
			line=${line##*Workflow:</strong> }
			workflow=${line%%<*}
			actualWorkflow+=("$workflow")
		fi
		## Step record
		if [[ $(Contains "$line" '<li><strong>') == true ]]; then
			line=${line##*<li><strong>}
			step=${line%%<*}
			unset fyiStr
			[[ $(Contains "$line" '<em>FYI</em>') == true ]] && fyiStr=' fyi'
			[[ $(Contains "$line" '<em>FYI All</em>') == true ]] && fyiStr=' fyiall'
			actualWorkflow+=("${step}${fyiStr}")
		fi
	done < $cgiOut
	return 0
}

#==================================================================================================
# Declare local variables and constants
#==================================================================================================
tmpFile=$(mkTmpFile)
trueVars='stopFirst'
for var in $trueVars; do eval $var=true; done
falseVars='errorDetected overWrite'
for var in $falseVars; do eval $var=false; done

unset instances groups tests steps
inSetup=false; inExpect=false;
declare -A setup
declare -A expect
previewStep='testworkflow'
cgiOut=$(mkTmpFile).cgiOut

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
## Initialize
	helpSet='script,client,env'
	scriptHelpDesc="This script can be used to test CIM instances.  Tests are defined in a xml file in the cim instance root directory"

	Hello
	GetDefaultsData -f $myName
	ParseArgsStd $originalArgStr
	[[ -n $file ]] && xmlFile="$file"

	initTokens='getClient getEnv getDirs checkEnvs'
	[[ -n $instance ]] && cimStr="$instance" || initTokens="$initTokens getCim"
	onlyCimsWithTestFile=true
	Init "$initTokens"
	instance="$cimStr"
	[[ $noStopFirst == true ]] && stopFirst=false

	tempProposalId="${scriptData1##*:}"
	[[ -z $tempProposalId ]] && Terminate "Could not resolve tempProposalId from defaults"

## Parse xml file
	[[ -z $xmlFile && -f "$siteDir/web/$cimStr/$myName.xml" ]] && xmlFile="$siteDir/web/$cimStr/wfTest.xml"
	Msg
	Msg "Parsing the XML file: '$xmlFile'"
	ParseXmlFile "$xmlFile"

# ## Get which groups to run
# 	if [[ ${#groups[@]} -gt 0 && $group == '' ]]; then
# 		unset menuList
# 		menuList+=("|Test Name")
# 		for token in ${groups[@]}; do
# 			if [[ ${test:0:${#instance}} == $instance ]]; then
# 				test="$(cut -d'.' -f2 <<< $test)"
# 				menuList+=("|$test")
# 				runTeststring="$runTeststring,$test"
# 			fi
# 		done
# 		menuList+=("|All")
# 		runTeststring=${runTeststring:1}
# 	fi

## Get which tests to run
	unset menuList runTeststring
	menuList+=("|Test Name")
	for test in ${tests[@]}; do
		if [[ ${test:0:${#instance}} == $instance ]]; then
			test="$(cut -d'.' -f2 <<< $test)"
			menuList+=("|$test")
			allTests="$allTests,$test"
		fi
	done
	menuList+=("|All")
	allTests=${allTests:1}
	
	if [[ -z $runTests ]]; then
		[[ $verify != true ]] && Msg $T "No value specified for '-run' and verify is off"
		Msg; Msg "Please select the test(s) that you wish to run, enter the ordinal number:"; Msg
		SelectMenuNew -m -r 'menuList' 'runTests' "\nPlease enter the ordinal(s) of the test(s) to run $(ColorK '(ord)') (or 'x' to quit) > "
		[[ -z $runTests ]] && Goodbye 0
		runTests="${runTests//|/,}"
	fi

## Verify continue with the user
	unset verifyArgs
	verifyArgs+=("Client:$client")
	verifyArgs+=("Env:$(TitleCase $env) ($siteDir)")
	verifyArgs+=("CIM Instance:$instance")
	verifyArgs+=("Test Definition File:$xmlFile")
	verifyArgs+=("Test(s):${runTests//,/, }")
	verifyArgs+=("Stop First:$stopFirst")
	[[ $overWrite == true ]] && verifyArgs+=("Over Write:$overWrite")
	verifyContinueDefault='Yes'
	VerifyContinue "You are asking to run workflow tests for"

## Log Start
	myData="Client: '$client', Env: '$env', Cim: '$instance', Tests: '$allTests'"
	[[ $logInDb != false && $myLogRecordIdx != "" ]] && dbLog 'data' $myLogRecordIdx "$myData"

#===================================================================================================
# Main
#===================================================================================================
## Setup files
	testLogFile=$siteDir/web/$instance/$myName.log
	echo >> $testLogFile
	echo $(date) - $userName: >> $testLogFile
	proposalDir="$siteDir/web/$instance/$tempProposalId"
	proposalTcfFile="$proposalDir/index.tcf"
	proposalTcaFile="$proposalDir/index.tca"
	if [[ -d $proposalDir ]]; then
		if [[ $overWrite == true ]]; then
			ans='y'
		else
			unset ans; Prompt ans "^Found an existing proposal directory with key=$tempProposalId, do you wish to overwrite" "Yes No"; ans=$(Lower ${ans:0:1})
		fi
		[[ $ans == 'y' ]] && rm -rf $proposalDir || Goodbye -1
	fi
	dump 1 proposalDir proposalTcfFile proposalTcaFile
	mkdir -p $proposalDir
	touch "$siteDir/web/$instance/$tempProposalId/.$myName"

## Run the tests
[[ ${runTests,,[a-z]} == 'all' ]] && runTests="$allTests"
for test in ${runTests//,/ }; do
	Msg
	#Msg $V1 "$(PadChar)"
	Msg "Running test: $instance.$test"
	## Build the temp proposal file at location $tempProposalId
		Msg $V1 "^Initializing variables, building temporary proposal..."
		setupTcfdata="${setup["$instance.$test.tcfdata"]}"
		setupTcadata="${setup["$instance.$test.tcadata"]}"
		setupWorkflow="${setup["$instance.$test.workflow"]}"
		setupWorkflowSteps="${setup["$instance.$test.steps"]}"
		dump -2 -t setupTcfdata setupTcadata setupWorkflow setupWorkflowSteps

	## If the test setup specifies a workflow then write that workflow out to the workflow file
		if [[ $setupWorkflow != '' ]]; then
			Msg $V1 "^Build temporary workflow.tcf file..."
			unset wfStepsArray
			workflowFile="$siteDir/web/$cimStr/workflow.tcf"
			unset cpMsg; cpMsg=$(CopyFileWithCheck "$workflowFile" "$workflowFile.bak")
			[[ $cpMsg != true && $cpMsg != 'same' ]] && Msg $T "Could not make a copy of the workflow file:\n\t$cpMsg"
			echo 'workflow:'$setupWorkflow\|$(tr '|' ',' <<< $setupWorkflowSteps) > "$workflowFile"
		fi

	## Initalize the proposal index.tcf file
		dump -2 -t proposalTcfFile proposalTcaFile -n
		echo 'template:cim' > $proposalTcfFile
		echo 'revisionid:2' >> $proposalTcfFile
		echo 'template:cim' > $proposalTcaFile
		echo 'revisionid:1' >> $proposalTcaFile

	## Write data to the proposal index.tcf/tca files
		unset tcfData tcaData tcaDataOut
		IFS='|' read -ra tcfData <<< "$setupTcfdata"
		IFS='|' read -ra tcaData <<< "$setupTcadata"
		for tcfVar in "${tcfData[@]}"; do
			tcfVarName=$(cut -d' ' -f1 <<< "$tcfVar")
			tcfVarVal=$(cut -d' ' -f2- <<< "$tcfVar")
			if [[ $tcfVarVal != '' ]]; then
				tcfLine="$tcfVarName:$tcfVarVal"
			    dump -2 -t tcfVarName tcfVarVal tcfLine
			    echo "$tcfLine" >> $proposalTcfFile
			fi
			## Now check if we have a tcadata override value
			foundTca=false
			for tcaVar in "${tcaData[@]}"; do
				tcaVarName=$(cut -d' ' -f1 <<< "$tcaVar")
				tcaVarVal=$(cut -d' ' -f2- <<< "$tcaVar")
				tcaLine="$tcaVarName:$tcaVarVal"
				[[ $tcaVarName == $tcfVarName ]] && foundTca=true && break
			done
			[[ $foundTca == true ]] && echo "$tcaLine" >> $proposalTcaFile || echo "$tcfLine" >> $proposalTcaFile
		done

	## Run the preview workflow step
		Msg $V1 "^Running step: '$previewStep'..."
		cd $siteDir/web/courseleaf
		./courseleaf.cgi $previewStep /$instance/$tempProposalId > $cgiOut
		cd $cwd

	## Parse the step output
		unset actualWorkflow
		ParseTestworkflowOut "$cgiOut"
		if [[ $verboseLevel -ge 2 ]]; then
			Msg; Msg "actualWorkflow:"
			for line in "${actualWorkflow[@]}"; do Dump -1 -t line; done
			Msg
		fi
		let numStepsActual=${#actualWorkflow[@]}-1

	## Complare actual workflow vs expected
		testStatus='Success'
		## Workflow name
		if [[ ${expect[$instance.$test.workflow]} == ${actualWorkflow[0]} ]]; then
			Msg $V1 "^^Workflow Name: OK (${expect[$instance.$test.workflow]})"
		else
			Msg $ET2 "Workflow is not as expected: \n^^^Expected: '${expect[$instance.$test.workflow]}'\n^^^Actual: '${actualWorkflow[0]}'"
			errorDetected=true
			continue
		fi
		## Check number of steps
			expectedSteps="${expect[$instance.$test.steps]}"
		let numStepsExpected=$(grep -o "|" <<< "$expectedSteps" | wc -l)+1
			[[ $numStepsExpected -ne $numStepsActual ]] && errorDetected=true && Msg $ET2 "Step count error, Number expected: $numStepsExpected, Number actual workflow: $numStepsActual"
		## Workflow steps
		for ((cntr=1; cntr<${#actualWorkflow[@]}; cntr++)); do
			unset aStep eStep
			aStep="${actualWorkflow[$cntr]}"
			eStep="$(cut -d'|' -f$cntr <<< "$expectedSteps")"
			#dump aStep eStep
			if [[ "$aStep" != "$eStep" ]]; then
				Msg $ET2 "Step #$cntr is not as expected. \n^^^Expected: '$eStep'\n^^^Actual: '$aStep'"
				testStatus='Failed'
			else
				Msg  $V1 "^^Step #$cntr is as expected ($eStep)"
			fi
		done
		if [[ $testStatus == 'Success' ]]; then
			Msg $V1 ' ';
			Msg "Test '$instance.$test' completed successfully"
			echo -e "\t$instance.$test completed successfully" >> $testLogFile
		else
			errorDetected=true
			Msg $E "Test '$instance.$test' failed, proposal file (.../$tempProposalId/index.tcf) contents:"
			cat $proposalTcfFile | xargs -I{} echo -e "\t\t{}"
			Msg $E "Test '$instance.$test' failed, workflow file contents:"
			cat $workflowFile | xargs -I{} echo -e "\t\t{}"
			echo -e "\t$instance.$test failed" >> $testLogFile
			Msg $V1 ' ';
		fi

		## Cleanup
		rm -f "$proposalTcfFile" "$proposalTcaFile" > /dev/null 2>&1

		## Restore the backup of the workflow file
		if [[ $setupWorkflow != '' ]]; then
			unset cpMsg; cpMsg=$(CopyFileWithCheck "$workflowFile.bak" "$workflowFile")
			[[ $cpMsg != true && $cpMsg != 'same' ]] && Msg $T "Could not restore the workflow file, backup copy is at:\n^$workflowFile.bak:\n\t$cpMsg"
			rm -rf "$workflowFile.bak"
		fi

		[[ $errorDetected == true && $stopFirst == true ]] && Msg "Stop on First flag was specified, stopping." && break

done # test in tests

#===================================================================================================
## Done
#===================================================================================================
[[ $errorDetected == true ]] && Goodbye -3 'alert' || Goodbye 0


#===================================================================================================
## Example test file, stored as 'wfTests.xml' in the CIM instance root
#===================================================================================================
# <!-- ------------------------------------------------------------------------- -->
# <!-- Automated test patterns for workflow -->
# <!-- Please see xxxx -->
# <!-- DO NOT DELETE/MODIFY THIS FILE WITHOUT CONTACTING David Scudiero -->
# <!-- ------------------------------------------------------------------------- -->
# <?xml version="1.0" encoding="UTF-8"?>
# <wftest>
# 	<instance name="courseadmin">
# 		<test name="IsGraduate">
# 			<setup>
# 				<workflow name="standard">
# 				<step>START</step>
# 				<step>[Is Graduate] isGraduate</step>
# 				<step>END</step>
# 				<var name="acad_level" value="GR">
# 			</setup>
# 			<expect>
# 				<workflow>standard</workflow>
# 				<step>START</step>
# 				<step>[Is GradXuate]</step>
# 				<step>END</step>
# 			</expect>
# 		</test>
# 		<test name="IsUndergraduate">
# 			<setup>
# 				<workflow name="standard">
# 				<step>START</step>
# 				<step>[Is Undergraduate] isUndergraduate</step>
# 				<step>END</step>
# 				<var name="acad_level" value="UG">
# 			</setup>
# 			<expect>
# 				<workflow>standard</workflow>
# 				<step>START</step>
# 				<step>[Is Undergraduate]</step>
# 				<step>END</step>
# 			</expect>
# 		</test>
# 		<test name="Test2">
# 			<setup>
# 				<tcfdata name="college" value="SB">
# 				<tcfdata name="department" value="BIOL">
# 				<tcfdata name="subject" value="BIOL">
# 				<tcfdata name="code" value="BIOL 101">
# 				<tcfdata name="acad_level" value="UG">
# 				<tcfdata name="gened_type" value="*">
# 				<tcfdata name="newrecord" value="true">
# 				//tcfdata that is different from tcadata
# 				<tcadata name="college" value="BL">
# 			</setup>
# 			<expect>
# 				<workflow>LEEPFROG TESTING</workflow>
# 				<step>College: SB</step>
# 				<step>Department: BIOL</step>
# 				<step>Subject: BIOL</step>
# 				<step>Academic Level: UG</step>
# 				<step>[Is Undergraduate]</step>
# 				<step>[Is NOT Writing or Communications]</step>
# 				<step>[New Course]</step>
# 			</expect>
# 		</test>
#
# 	</instance>
#
# <wftest>

#===================================================================================================
## Check-in log
#===================================================================================================
## Wed Jul 20 08:45:46 CDT 2016 - dscudiero - Write out a log file
## Wed Jul 20 08:49:58 CDT 2016 - dscudiero - Write out a log file
## Wed Jul 20 08:58:31 CDT 2016 - dscudiero - Added onlyCimsWithTestFiles
## Thu Jul 21 08:29:07 CDT 2016 - dscudiero - Added tcadata processing
## Wed Aug 10 10:15:21 CDT 2016 - dscudiero - Fixed various problems
## Wed Aug 10 13:21:16 CDT 2016 - dscudiero - Added stop on first
## Tue Aug 23 11:22:35 CDT 2016 - dscudiero - Updated to correctly parse output of selectMenuNew
## Mon Sep 12 14:24:46 CDT 2016 - dscudiero - Fix preview workflow parsing since Mike added Proposal Key
## Mon Sep 12 16:41:04 CDT 2016 - dscudiero - General syncing of dev to prod
## 05-15-2018 @ 08:15:37 - 1.1.01 - dscudiero - Sync
