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

dump originalArgStr -q

#= Description +===================================================================================
# Run automated test cases for workflow in a CIM insance
# See 'Examle test file' below
#==================================================================================================
#==================================================================================================
# Standard call back functions
#==================================================================================================
function wfTest-ParseArgsStd  {
	myArgs+=('instance|instance|option|instance||script|The name of the CIM instance to be tested')
	myArgs+=('runtests|runTests|option|runTests||script|The comma seperated list of test names to run')
	myArgs+=('rungroups|runGroups|option|runGroups||script|The comma seperated list of test groups to run')
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

#=======================================================================================================================
# local functions
#=======================================================================================================================

#=======================================================================================================================
# Parse the data file, 
# Usage ParseTestFile $fileName $cimInstance
# 	cimInstance defaults to 'courseadmin'
#
# Returns the following: testHash, instances, groups, tests 
# - testHash has keys as follows: 
#		"${instanceName}.${groupName}.${testName}.setup.['workflow' | 'steps' | 'tcfdata' | 'tcadata' ]
#		"${instanceName}.${groupName}.${testName}.expects.['workflow' | 'steps' ]
# - instances is an array of instance names found
# - groups is an array of group names found
# - tests is an array of test names found
#
# Additionally an 'testKeys' array is returned that lists the hash table keys in the order found
# Steps and tcf/tca data elements are separated with a '^' character
#
# The data file may include 'import:' directives, if specified it is the file name.  The named file is looked for in 
# 1) The current cim instance directory or 2) the tools/src/wfTests directory
#=======================================================================================================================
function ParseTestDataFile {
	local testFile="$1"; shift || true
	local cim="${1:-courseadmin}"

	local line importFile lines recType recData recDataType instance cim
	local workflow steps tcfdatas tcadatas 

	## Read in the data file, processing any imports
	Verbose -2 "^Reading file: $testFile"
	while read line; do
		line="${line:0:${#line}-1}"; line="${line//\011}"
		[[ ${line:0:2} == '//' ]] && continue
		if [[ ${line%%:*} == 'import' ]]; then
			importFile="${line##*:}"; [[ ${importFile:0:1} == ' ' ]] && importFile="${importFile:1}"
			[[ -r $siteDir/web/$cim/${importFile}.wftest ]] && importFile="$siteDir/web/$cim/$importFile" || importFile="$(FindExecutable -wftest $importFile)"
			if [[ -r $importFile ]]; then
				Verbose -2 "^Importing file: $importFile"
				while read importLine; do
					importLine="${importLine:0:${#importLine}-1}"; importLine="${importLine//\011}"
					[[ ${importLine:0:2} == '//' ]] && continue
					lines+=("$importLine")	
				done < "$importFile"
			else
				Terminate "Could not locate importFile '$importFile'"
			fi
		else
			lines+=("$line")
		fi
	done < $testFile

	unset instances groups tests
	unset testName setupWorkflow setupSteps setupTcfDatas setupTcaDatas expectWorkflow expectSteps testKeys
	for line in "${lines[@]}"; do
		[[ -z $line ]] && continue
		recType="${line%%:*}"; recData="${line#*:}"; [[ ${recData:0:1} == ' ' ]] && recData="${recData:1}"
		recDataType="${recData%% *}"; [[ ${recDataType:0:1} == ' ' ]] && recDataType="${recDataType:1}"
		recData="${recData#* }"; [[ ${recData:0:1} == ' ' ]] && recData="${recData:1}"
		dump -2 -n line -t recType recData recDataType

		case ${recType,,[a-z]} in
			'instance')
					instanceName="$recDataType"; [[ ${instanceName:0:1} == ' ' ]] && instanceName="${instanceName:1}"
					## Add to the instances array if not seen before
					found=false
					for instance in "${instances[@]}"; do  [[ $instance == $instanceName ]] && found=true; done
					[[ $found == false ]] && instances+=("$instanceName")
					groupName='none'
				;;
			'group')
					groupName="$recDataType"; [[ ${groupName:0:1} == ' ' ]] && groupName="${groupName:1}"
					## Add to the groups array if not seen before
					found=false
					for group in "${groups[@]}"; do  [[ $group == $groupName ]] && found=true; done
					[[ $found == false ]] && groups+=("$groupName")
				;;
			'test')
					testName="$recDataType"; [[ ${testName:0:1} == ' ' ]] && testName="${testName:1}"
					## Add to the tests array if not seen before
					found=false
					for test in "${tests[@]}"; do  [[ $test == $testName ]] && found=true; done
					[[ $found == false ]] && tests+=("$testName")
				;;
			'testend')
					#keyRoot="${instanceName}.${groupName}.${testName}"
					keyRoot="${groupName}.${testName}"
					[[ ${testHash["$keyRoot"]+abc} ]] && Terminate "Found duplicate test name ($keyRoot)" 
					testHash["$keyRoot"]=true; testKeys+=("$keyRoot")
					testHash["$keyRoot.setup.workflow"]="$setupWorkflow"; testKeys+=("$keyRoot.setup.workflow")
					testHash["$keyRoot.setup.steps"]="$setupSteps"; testKeys+=("$keyRoot.setup.steps")
					testHash["$keyRoot.setup.tcfdata"]="$setupTcfDatas"; testKeys+=("$keyRoot.setup.tcfdata")
					testHash["$keyRoot.setup.tcadata"]="$setupTcaDatas"; testKeys+=("$keyRoot.setup.tcadata")
					testHash["$keyRoot.expect.workflow"]="$expectWorkflow"; testKeys+=("$keyRoot.expect.workflow")
					testHash["$keyRoot.expect.steps"]="$expectSteps"; testKeys+=("$keyRoot.expect.steps")
					[[ ${groupTests["$groupName"]+abc} ]] && groupTests["$groupName"]="${groupTests[$groupName]},$testName" || groupTests["$groupName"]="$testName"
					unset testName setupWorkflow setupSteps setupTcfDatas setupTcaDatas expectWorkflow expectSteps
				;;
			'setup')
				subType="$recDataType"
				#dump -t -t subType
				case ${subType,,[a-z]} in
					'workflow')
						setupWorkflow="${recData#*:}"; [[ ${setupWorkflow:0:1} == ' ' ]] && setupWorkflow="${setupWorkflow:1}"
						;;
					'step')
						[[ -z $setupSteps ]] && setupSteps="${recData}" || setupSteps="${setupSteps},${recData}"
						;;
					'tcfdata')
						[[ -z $setupTcfDatas ]] && setupTcfDatas="${recData}" || setupTcfDatas="${setupTcfDatas}^${recData}"
						;;
					'tcadata')
						[[ -z $setupTcaDatas ]] && setupTcaDatas="${recData}" || setupTcaDatas="${setupTcaDatas}^${recData}"
						;;
					*) 	Terminate "Encountered invalid subType ($subType) for record type ($recDataType) in data source: '$line'"
				esac
				;;
			'expect')
				subType="$recDataType"
				case ${subType,,[a-z]} in
					'workflow')
						expectWorkflow="${recData#*:}"; [[ ${expectWorkflow:0:1} == ' ' ]] && expectWorkflow="${expectWorkflow:1}"
						;;
					'step')
						[[ -z $expectSteps ]] && expectSteps="${recData}" || expectSteps="${expectSteps},${recData}"
						;;
					*) 	Terminate "Encountered invalid subType ($subType) for record type ($recDataType) in data source: '$line'"
				esac
				;;
			*) 	Terminate "Encountered invalid record type in data source: '$line'"
		esac
	done

	return 0
} ## ParseTestDataFile

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
declare -A testHash groupTests
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

dump originalArgStr
	Hello
	GetDefaultsData -f $myName
verboseLevel=3
	ParseArgsStd $originalArgStr
verboseLevel=0
dump file -q

	[[ -n $file ]] && xmlFile="$file"

	initTokens='getClient getEnv getDirs checkEnvs'
	[[ -n $instance ]] && cimStr="$instance" || initTokens="$initTokens getCim"
	onlyCimsWithTestFile=true
	Init "$initTokens"
	instance="$cimStr"
	[[ $noStopFirst == true ]] && stopFirst=false

	tempProposalId="${scriptData1##*:}"
	[[ -z $tempProposalId ]] && Terminate "Could not resolve tempProposalId from defaults"

## Parse data file

	[[ -n $file ]] && dataFile="$file" || dataFile="$siteDir/web/$instance/${myName}s"
	if [[ -r $dataFile ]]; then
		Msg "Parsing the $myName data file: '$dataFile'"
	else
		unset dataFile
		Msg
		Msg "Please specify the name of the test definitions data file, name is relative to '$siteDir/web/$instance'"
		while [[ -z $dataFile ]]; do
			Prompt dataFile "^Data file name" "*any*";
			[[ -r "$siteDir/web/$instance/$dataFile" ]] && dataFile="$siteDir/web/$instance/$dataFile" || unset dataFile
		done
	fi
	ParseTestDataFile "$dataFile" "$instance"

	if [[ $verboseLevel -ge 2 ]]; then
		echo;echo "\${#instances[@]} = '${#instances[@]}'"; for ((xx=0; xx<${#instances[@]}; xx++)); do echo "instances[$xx] = >${instances[$xx]}<"; done
		echo;echo "\${#groups[@]} = '${#groups[@]}'"; for ((xx=0; xx<${#groups[@]}; xx++)); do echo "groups[$xx] = >${groups[$xx]}<"; done
		echo;echo "\${#tests[@]} = '${#tests[@]}'"; for ((xx=0; xx<${#tests[@]}; xx++)); do echo "tests[$xx] = >${tests[$xx]}<"; done
		echo; echo "testHash:"; for mapCtr in "${testKeys[@]}"; do echo -e "\tkey: '$mapCtr', value: '${testHash[$mapCtr]}'"; done
		echo; echo "groupTests:"; for mapCtr in "${!groupTests[@]}"; do echo -e "\tkey: '$mapCtr', value: '${groupTests[$mapCtr]}'"; done
	fi

## Get which groups to run
	if [[ -z $runGroups && -z $runTests && $verify == true && $allItems != true ]]; then
		unset menuList allGroups
		menuList+=('|Group')
		for group in "${groups[@]}"; do
			menuList+=("|$group")
		done
		menuList+=("|All")
		Msg; Msg "Please select the 'groups' that you wish to run, enter the ordinal number(s):"; Msg
		SelectMenuNew -m -r 'menuList' 'runGroups' "\nPlease enter the ordinal(s) of the groups(s) to run $(ColorK '(ord)') (or 'x' to quit) > "
		[[ -z $runGroups ]] && Goodbye 0
		runGroups="${runGroups//|/,}"
	fi
	if [[ ${runGroups,,[a-z]} == 'all' || $allItems == true ]]; then
		runGroups=(${groups[*]})
	else
		tmpStr="${runGroups//,/ }"
		unset runGroups
		for group in $tmpStr; do
			runGroups+=("$group")
		done
	fi

## Get which tests to run
	for group in ${groups[@]}; do
		tmpStr="${groupTests[$group]}"
		for test in ${tmpStr//,/ }; do
			allTests+=("$group.$test")
		done 
	done

	if [[ -z $runTests && $verify == true && $allItems != true ]]; then
		unset menuList allTests
		menuList+=('|Group|Test')
		for menuItem in "${allTests[@]}"; do
			menuList+=("|${menuItem%%.*}|${menuItem##*.}")
		done
		if [[ $allItems != true ]]; then
			menuList+=("|All")
			Msg; Msg "Please select the test(s) that you wish to run, enter the ordinal number(s):"; Msg
			SelectMenuNew -m -r 'menuList' 'runTests' "\nPlease enter the ordinal(s) of the test(s) to run $(ColorK '(ord)') (or 'x' to quit) > "
			[[ -z $runTests ]] && Goodbye 0
		runTests="${runTests//|/,}"; runTests="${runTests// /.}"
		fi
	fi
	if [[ ${runTests,,[a-z]} == 'all.all'  || $allItems == true  ]]; then
		runTests=(${allTests[*]})
	else
		for test in ${runTests//,/ }; do
			runTests+=("$test")
		done
	fi

## Verify continue with the user
	unset verifyArgs
	verifyArgs+=("Client:$client")
	verifyArgs+=("Env:$(TitleCase $env) ($siteDir)")
	verifyArgs+=("CIM Instance:$instance")
	verifyArgs+=("Test Definition File:$dataFile")
	verifyArgs+=("Group(s):runGroups")
	verifyArgs+=("Test(s):runTests")
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
for ((i=0; i<${#runTests[@]}; i++)); do
for keyRoot in "${runTests[@]}"; do
	setupWorkflow="${testHash[$keyRoot.setup.workflow]}"
	setupSteps="${testHash[$keyRoot.setup.steps]}"
	setupTcfdata="${testHash[$keyRoot.setup.tcfdata]}"
	setupTcadata="${testHash[$keyRoot.setup.tcadata]}"
	expectWorkflow="${testHash[$keyRoot.expect.workflow]}"
	expectSteps="${testHash[$keyRoot.expect.steps]}"
	dump 1 -n -t keyRoot -t2 setupWorkflow setupSteps setupTcfData setupTcadata expectWorkflow expectSteps




done
Quit
	test="${runTests[$i]}"
	instance="${test%%.*}" ; test="${test#*.}"
	group="${test%%.*}" ; test="${test#*.}"
	test="${test%%.*}" ; test="${test#*.}"	

	Msg "Running test: $instance.$group.$test"
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
		Pushd "$siteDir/web/courseleaf"
dump instance tempProposalId -p
		./courseleaf.cgi $previewStep /$instance/$tempProposalId > $cgiOut
		Popd

echo "cat $cgiOut"
cat $cgiOut
Pause

	## Parse the step output
		unset actualWorkflow
		ParseTestworkflowOut "$cgiOut"
dump numStepsActual -p

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
## 05-24-2018 @ 08:50:09 - 1.1.01 - dscudiero - Cosmetic/minor change/Sync
