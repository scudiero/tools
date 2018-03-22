#!/bin/bash
#===================================================================================================
version=1.2.31 # -- dscudiero -- Wed 03/21/2018 @ 17:00:21.01
#===================================================================================================
TrapSigs 'on'
myIncludes="ProtectedCall PushPop"
Import "$standardInteractiveIncludes $myIncludes"

originalArgStr="$*"
scriptDescription="Display news"

#===================================================================================================
# Create new tools objects
#===================================================================================================
# 08-05-15 -- dgs - Initial coding
# 02-18-16 -- dgs - refactored to preocess varous object types
#===================================================================================================

#===================================================================================================
# Declare local variables and constants
#===================================================================================================

#===================================================================================================
# Local functions
#===================================================================================================
function NewScript {
	local localToolsDir file
	file=$1

	## Make sure we have a local tools repo
	unset localToolsDir
	[[ -d $HOME/tools ]] && localToolsDir="$HOME/tools"
	[[ -d $HOME/tools.git ]] && localToolsDir="$HOME/tools.git"
	[[ $localToolsDir = '' ]] && Msg $T "Could not find local tools directory\n"
	[[ ! -d $localToolsDir/.git ]] && Msg $T "local tools directory '$localToolsDir' not a git repository"

	## Make sure we have a local bin
	[[ ! -d $HOME/bin ]] && Msg $T "Could not find local bin directory\n"

	## Parse file extension
		fileExt=$(echo $file | cut -d'.' -f2)
		[[ $fileExt == "$file" ]] && fileExt='sh'
		linkFile=$(echo $file | cut -d'.' -f1)
		doCopy=true
	## Check for existing files
		[[ -f $localToolsDir/${linkFile}.${fileExt} ]] && Msg $T "File '$localToolsDir/${linkFile}.${fileExt}' already exists"
		[[ ! -f $localToolsDir/src/test${fileExt}.${fileExt} ]] && Msg $T "Could not locate prototype file '$localToolsDir/src/test${fileExt}.${fileExt}'"
		if [[ -h $TOOLSPATH/bin/$linkFile ]]; then
			unset ans; Prompt ans "Found a pre-esiting file '$TOOLSPATH/bin/$linkFile, do you wish to overwrite" 'Yes No' 'No'; ans=$(Lower ${ans:0:1})
			[[ $ans == 'n' ]] && doCopy=false
			Msg $T "found pre-existing link file '$TOOLSPATH/bin/$linkFile'"
		fi
	## Copy file from prototype
		if [[ $doCopy == true ]]; then
			## Copy file from prototype
			cp -fp $localToolsDir/src/test${fileExt}.${fileExt} $localToolsDir/src/${linkFile}.${fileExt}
			fromStr="test${fileExt}"
			toStr="$(basename ${linkFile})"
			sed -i s"_${fromStr}_${toStr}_g" $localToolsDir/src/${linkFile}.${fileExt}
			Msg "^File '$file' -- copied from '$localToolsDir/src/test${fileExt}.${fileExt}'"
		fi

	## Create link
		if [[ ! -f $linkFile ]]; then
			cwd="$(pwd)";
			cd $HOME/bin ;
			ln -s $TOOLSPATH/src/dispatcher $linkFile; cd "$cwd"
			Msg "^File '$file' -- created '$linkFile' symbolic link in '$HOME/bin' to '$TOOLSPATH/src/dispatcher'"
		fi

	## Create db entry
	unset ans; Prompt ans "Do you want to create a entry in the scripts db for '$linkFile'" 'Yes No' 'Yes'; ans=$(Lower ${ans:0:1})
		if [[ $ans == 'y' ]]; then
			local name execName desc supported restrictToUsers restrictToGroups ignoreList allowList emailAddrs scriptData1 scriptData2 semaphore active
			Prompt name "\tScript Name" "$(echo $file | cut -d'.' -f1),*any*" "$(echo $file | cut -d'.' -f1)"
			name="\"$name\""
			Prompt 'execName' "\tExec Name" '*optional*'
			[[ $execName != '' ]] && execName="\"$exec\"" || execName=NULL
			Prompt 'libs' "\tUses Libs" '*optional*'
			[[ $libs != '' ]] && libs="\"$libs\"" || libs=NULL
			Prompt desc "\tShort Description" '*any*'
			desc="\"$desc\""
			Prompt supported "\tSupported" 'Yes No' 'Yes'
			supported="\"$supported\""
			Prompt restrictToUsers "\tRestrict to Users" '*optional*'
			[[ $restrictToUsers != '' ]] && restrictToUsers="\"$restrictToUsers\"" || restrictToUsers=NULL
			Prompt restrictToGroups "\tRestrict to Groups" '*optional*'
			[[ $restrictToGroups != '' ]] && restrictToGroups="\"$restrictToGroups\"" || restrictToGroups=NULL

			unset ans; Prompt ans "Do you wish to set script data" 'Yes No' 'Yes'; ans=$(Lower ${ans:0:1})
			ignoreList=NULL; allowList=NULL; emailAddrs=NULL; scriptData1=NULL; scriptData2=NULL; scriptData3=NULL; scriptData4=NULL; scriptData5=NULL
			if [[ $ans == 'y' ]]; then
				Prompt ignoreList "\tIgnore List" '*optional*'
				[[ $ignoreList != '' ]] && ignoreList="\"$ignoreList\"
				Prompt allowList "\tAllow List" '*optional*'
				[[ $allowList != '' ]] && allowList="\"$allowList\"
				Prompt emailAddrs "\tEmail addresses" '*optional*'
				[[ $emailAddrs != '' ]] && emailAddrs="\"$emailAddrs\""
				Prompt scriptData1 "\tScript Data 1" '*optional*'
				[[ $scriptData1 != '' ]] && scriptData1="\"$scriptData1\""
				Prompt scriptData2 "\tScript Data 2" '*optional*'
				[[ $scriptData2 != '' ]] && scriptData2="\"$scriptData2\""
				Prompt scriptData3 "\tScript Data 2" '*optional*'
				[[ $scriptData3 != '' ]] && scriptData2="\"$scriptData3\""
				Prompt scriptData4 "\tScript Data 2" '*optional*'
				[[ $scriptData4 != '' ]] && scriptData2="\"$scriptData4\""
				Prompt scriptData5 "\tScript Data 2" '*optional*'
				[[ $scriptData5 != '' ]] && scriptData2="\"$scriptData5\""
			fi
			[[ $ignoreList == '' ]] && ignoreList=NULL
			[[ $allowList == '' ]] && allowList=NULL
			[[ $emailAddrs == '' ]] && emailAddrs=NULL
			[[ $scriptData1 == '' ]] && scriptData1=NULL
			[[ $scriptData2 == '' ]] && scriptData2=NULL
			[[ $scriptData3 == '' ]] && scriptData3=NULL
			[[ $scriptData4 == '' ]] && scriptData4=NULL
			[[ $scriptData5 == '' ]] && scriptData5=NULL

			Prompt semaphore "\tSet Semaphore" 'Yes No' 'No'
			semaphore="\"$semaphore\""
			Prompt active "\tActive" 'Yes No' 'No'
			active="\"$active\""

			values="NULL,$name,$desc,NULL,\"$userName\",$supported,\"$osName\",NULL,$restrictToUsers,$restrictToGroups,$execName,$libs"
			values="${values},NULL,$ignoreList,$allowList,$emailAddrs,$scriptData1,$scriptData2,$scriptData3,$scriptData4,$scriptData5,$semaphore,NULL,$active,\"$(date +%s)\",NULL"
			sqlStmt="insert into $scriptsTable values($values)"
			#echo 'sqlStmt = >'$sqlStmt'<'
			RunSql2 $sqlStmt
		fi
}

#===================================================================================================
function NewPatch {
	local shortDescription longDescription clVersion cgiVersion action actionTarget lineText active
	Prompt shortDescription "\tShort Description" '*any*'
	shortDescription="\"$shortDescription\""
	Prompt longDescription "\tLong Description" '*any*'
	longDescription="\"$longDescription\""
	Prompt clVersion "\tCourseleaf Version" '*optional*'
	[[ $clVersion != '' ]] && clVersion="\"$clVersion\"" || clVersion=NULL
	Prompt cgiVersion "\tCourseleaf CGI Version" '*optional*'
	[[ $cgiVersion != '' ]] && cgiVersion="\"$cgiVersion\"" || cgiVersion=NULL
	Prompt action "\tAction type" 'insertLine deleteLine editLine runScript '
	if [[ $action == 'runScript' ]]; then
		until [[ $actionTarget != '' ]]; do
			Prompt actionTarget "\tScript name" '*any*'
			[[ ! -f $TOOLSPATH/src/$actionTarget ]] && Msg "^^File $actionTarget not found in $TOOLSPATH/src" && unset actionTarget
		done
		actionTarget="\"$actionTarget\""
		lineText=NULL
	else
		Prompt actionTarget "\tFile to act on (relative to site root directory)" '*any*'
		actionTarget="\"$actionTarget\""
		Prompt lineText "\tLine text to ${string%%'Line'}" '*any*'
		lineText="\"$lineText\""
	fi
	action="\"$action\""

	values="NULL,$shortDescription,$longDescription,$clVersion,$cgiVersion,$acton,$actionTarget,$lineText,\"active\",\"$(date +%s)\",\"$userName\",NULL,NULL"
	sqlStmt="insert into $courseleafPatchTable values($values)"
	#echo 'sqlStmt = >'$sqlStmt'<'
	RunSql2 $sqlStmt
}

#===================================================================================================
function NewReport {
	set -f
	local name shortDescription author supported repType header db dbtype sqlStmt script scriptArgs ignoreList allowList active edate
	Prompt name "\tReport Name" "$(echo $file | cut -d'.' -f1),*any*" "$(echo $file | cut -d'.' -f1)"
	name="\"$name\""
	Prompt desc "\tShort Description" '*any*'
	desc="\"$desc\""
	Prompt supported "\tSupported" 'Yes No' 'Yes'
	supported="\"$supported\""
	Prompt repType "\tReport type" 'query script' 'query'
	repType="\"$repType\""
	if [[ $repType == '"query"' ]]; then
		Prompt header "\tReport Column Header" '*any*'
		header="\"$header\""
		Prompt db "\tdb" 'warehouse contacts' 'warehouse'
		db="\"$db\""
		[[ $db == '"warehouse"' ]] && dbtype='"mysql"' || dbtype='"sqlite"'

		Prompt sqlStmt "\tSqlStmt" '*any*'
		sqlStmt="\"$sqlStmt\""
		script='NULL'
		scriptArgs='NULL'
	else
		Prompt script "\tReport script name" '*any*' "$name"
		script="\"$script\""
		Prompt scriptArgs "\tReport Script Args" '*optional*'
		scriptArgs="\"$scriptArgs\""
		header='NULL'
		db='NULL'
		dbtype='NULL'
		sqlStmt='NULL'
	fi
	Prompt ignoreList "\tIgnore List" '*optional*'
	[[ $ignoreList != '' ]] && ignoreList="\"$ignoreList\"" || ignoreList=NULL
	Prompt allowList "\tAllow List" '*optional*'
	[[ $allowList != '' ]] && allowList="\"$allowList\"" || allowList=NULL
	Prompt active "\tActive" 'Yes No' 'Yes'
	active="\"$active\""

	values="NULL,$name,$desc,\"$userName\",$supported,$repType,$header,$db,$dbtype,$sqlStmt,$script,$scriptArgs,$ignoreList,$allowList,$active,\"$(date +%s)\""
	sqlStmt="insert into $reportsTable values($values)"
	#echo 'sqlStmt = >'$sqlStmt'<'
	RunSql2 $sqlStmt
	set +f
}

#===================================================================================================
function NewNewsItem {
	local itemText
	Prompt 'itemText' "Please enter news item for '$objName'\n\t" '*any*'
	[[ ${itemText:${#itemText}-1:1} != '.' ]] && itemText="$itemText."

	sqlStmt="insert into $newsTable values(NULL,\"$objName\",\"$itemText\",NOW(),\"$(date +%s)\",\"$userName\" )"
	RunSql2 $sqlStmt
}

#===================================================================================================
function NewDefault {
	local name value os host mode
	Prompt 'name' "Variable name" '*any*'
	name="\"$name\""
	Prompt 'value' "Value" '*any*'
	value="\"$value\""
	Prompt 'os' "Please enter which OS's the value applies to" 'linux,MSWin32,any' 'any'
	[[ $os == any ]] && os=NULL || os="\"$os\""
	Prompt 'host' "Please enter which Hosts's the value applies to" 'build5,build7,mojave,any' 'any' ; host=$(Lower $host)
	[[ $host == any ]] && host=NULL || host="\"$host\""

	sqlStmt="insert into defaults values(NULL,$name,$value,$os,$host,\"A\",NOW(),\"$userName\",NULL,NULL)"
	RunSql2 $sqlStmt
}

#===================================================================================================
function NewMonitorFile {
	local file userList
	Prompt 'file' "File name" '*file*'
	lastModEtime=$(stat -c %Y $file)
	file="\"$file\""
	sqlStmt="insert into monitorfiles values(NULL,$file,\"$hostName\",$lastModEtime,NULL)"
	RunSql2 $sqlStmt
}

#===================================================================================================
function NewVba {	
	local visualStudioDir projectDirs project newProject editFile editFiles renameFile renameFiles
	visualStudioDir="$HOME/windowsStuff/documents/Visual Studio 2015/Projects"
	[[ ! -d $visualStudioDir ]] && Msg $T "Could not locate the Visual Studio directory"
	cwd=$(pwd)
	cd "$visualStudioDir"
	SetFileExpansion 'on'; projectDirs=($(ls -d -t $objName* 2> /dev/null)); SetFileExpansion
	[[ ${#projectDirs[@]} -eq 0 ]] && Msg $T "Could not locate any matching project directories for '$objType'"
	Msg; Msg "Please specify the ordinal number of the Project you wish to clone\n"
	SelectMenu 'projectDirs' 'project' '\nProject ordinal(or 'x' to quit) > '
	[[ $project == '' ]] && Goodbye 0
	if [[ $(IsNumeric ${project: -1}) == true ]]; then
		newProject=${project: -1}
		(( newProject += 1 ))
		newProject=${project:0:${#project}-1}$newProject
	else
		newProject=${project:0:${#project}-1}2
	fi
	## Create the new project directory and copy source project
		if [[ -d $newProject ]]; then
			unset ans; Prompt ans "The new project directory already exists, do you wish to overwrite it" 'Yes No' 'No'; ans=$(Lower ${ans:0:1})
			[[ $ans != 'y' ]] && Goodbye 0
			rm -rf $newProject
		fi
		Msg "^Creating new project directory: $newProject"
		cp -rfp $project $newProject
		cd $newProject

	## Get the list of files that need to be edited
		ignoreFileTypes='executable|TrueType|directory|MSVC program database|data|CDF V2 Document'
		editFiles=($(find . -name 'packages' -prune -o -print0 | xargs -0r file | grep -E --null -v  "$ignoreFileTypes" | awk -F: '{printf "%s\0", $1}' | xargs -0 grep -l $project))
		for editFile in "${editFiles[@]}"; do
			Msg "^Editing file: $editFile"
			sed -i s"/$project/$newProject/g" $editFile
		done

	## Rename the top directory
		[[ ! -d ./$newProject ]] && mv -f ./$project ./$newProject && Msg "^Renaming file: ./$project"
	## Rename the .vs subdirectory
		[[ ! -d ./.vs/$newProject ]] && mv -f ./.vs/$project ./.vs/$newProject && Msg "^Renaming file: ./.vs/$project"

	## Get the list of files that need to be renamed
		renameFiles=($(find . -name 'packages' -prune -o -print | grep "$project"))
		for renameFile in "${renameFiles[@]}"; do
			Msg "^Renaming file: $renameFile"
			newName=$(sed "s/$project/$newProject/g" <<< "$renameFile")
			mv -f "$renameFile" "$newName"
		done
}

#===================================================================================================
function NewClient {
	local client=$1
	local clientId sqlStmt env siteDir

	## Get the client name, make sure it does not exist
		noCheck=true
		Prompt client "Client Name" "*any*,noCheck" "$client"

	## Insert the clients record
		unset clientId
		sqlStmt="select idx from $clientInfoTable where name=\"$client\""
		RunSql2 $sqlStmt
		if [[ ${#resultSet[@]} -gt 0 ]]; then
			clientId=${resultSet[0]}
			Msg $WT1 "Client record already exist for '$client' in the '$clientInfoTable' table"
		else
			$DOIT insertClientInfoRec $client -noLog -noLogInDb
			sqlStmt="select max(idx) from $clientInfoTable"
			RunSql2 $sqlStmt
			clientId=${resultSet[0]}
			Msg "^Created '$clientInfoTable' record for '$env'"

		fi

	## Insert the sites records
		SetSiteDirs 'set'
		for env in $(tr ',' ' ' <<< "$courseleafDevEnvs $courseleafProdEnvs"); do
			eval siteDir="\$${env}Dir"
			if [[ -d $siteDir ]]; then
				sqlStmt="select siteId from $siteInfoTable where name=\"$client\" and env=\"$env\""
				RunSql2 $sqlStmt
				if [[ ${#resultSet[@]} -gt 0 ]]; then
					Msg $WT1 "Site record already exist for '$env' in the '$siteInfoTable' table "
				else
					$DOIT insertSiteInfoTableRecord "$siteDir" -clientId $clientId -noLog -noLogInDb
					Msg "^Created '$siteInfoTable' record for '$env'"
				fi
			fi
		done
}


#==================================================================================================
# MAIN
#==================================================================================================
validTypes='script patch report newsItem default monitorFile vba client'
GetDefaultsData $myName
ParseArgsStd2 $originalArgStr

Hello
[[ "$1" != "" && ${1:0:1} != '-' ]] && objType="$1" && shift
[[ "$1" != "" && ${1:0:1} != '-' ]] && objName="$1" && shift

Prompt objType "Please specify the object type" "$validTypes"; objType=$(TitleCase $objType)
[[ $(Lower $objType) == 'script' ]] && objType='Script'
[[ $(Lower ${objType:0:4}) == 'news' ]] && objType='NewsItem'
[[ $(Lower ${objType:0:1}) == 'v' ]] && objType='Vba'

[[ $objType == 'Script' || $objType == 'NewsItem' || $objType == 'Vba' ]] && Prompt objName "Please specify the name of the new $objType obj" '*any*'
#[[ $objType == 'vba' ]] && Prompt objName "Please specify the name of the new $objType obj" '*optional*'

## Call functon to build the object
[[ $(type -t New$objType) != 'function' ]] && Msg $T "Invalid object typo specified"
Msg
[[ $objName != '' ]] && Msg "Creating a new $objType object with name '$objName'" || Msg "Creating a new $objType object"
New$objType $objName
Msg; Msg "$objType object created"

#==================================================================================================
## Bye-bye
#==================================================================================================
	Goodbye 0
## Wed Apr 20 11:10:19 CDT 2016 - dscudiero - fix problem if user does not specify any parameters
## Tue Apr 26 06:54:51 CDT 2016 - dscudiero - Updated new patch
## Wed Apr 27 16:01:18 CDT 2016 - dscudiero - Switch to use RunSql
## Thu Apr 28 13:36:09 CDT 2016 - dscudiero - added objType monitorFile
## Thu Apr 28 14:05:40 CDT 2016 - dscudiero - Set userlist to null for new monitorFiles
## Thu Apr 28 16:52:34 CDT 2016 - dscudiero - Added host to the monitoredFile data
## Tue May 24 11:36:43 CDT 2016 - dscudiero - General syncing of dev to prod
## Thu Jun  2 13:24:36 CDT 2016 - dscudiero - General syncing of dev to prod
## Thu Jun  2 13:29:01 CDT 2016 - dscudiero - General syncing of dev to prod
## Thu Jun  2 13:29:43 CDT 2016 - dscudiero - General syncing of dev to prod
## Thu Jun  2 13:30:42 CDT 2016 - dscudiero - General syncing of dev to prod
## Tue Jun 14 15:33:49 CDT 2016 - dscudiero - Updated scripts processing
## Mon Jun 20 10:22:57 CDT 2016 - dscudiero - update creating vba objects
## Fri Jul 15 14:58:00 CDT 2016 - dscudiero - Add the usageCount field on the insert script call
## Mon Jul 18 10:49:45 CDT 2016 - dscudiero - For reports make arguments to report optional
## Mon Jul 18 15:57:54 CDT 2016 - dscudiero - Added client to create new client records in clients and sites tables
## Thu Oct  6 16:40:12 CDT 2016 - dscudiero - Set dbAcc level to Update for db writes
## Thu Oct  6 16:59:31 CDT 2016 - dscudiero - General syncing of dev to prod
## Fri Oct  7 08:00:52 CDT 2016 - dscudiero - Take out the dbAcc switching logic, moved to framework RunSql
## Wed Oct 12 10:00:51 CDT 2016 - dscudiero - Updated to create new script link in the users local bin directory
## Wed Oct 12 12:33:41 CDT 2016 - dscudiero - Re factor new script
## Fri Oct 21 13:43:48 CDT 2016 - dscudiero - Added libs data for scripts
## Thu Dec 29 16:50:57 CST 2016 - dscudiero - Updated creating a default to add the status column
## Wed Jan 11 16:41:31 CST 2017 - dscudiero - fixed import statements
## 09-05-2017 @ 10.09.44 - (1.2.24)    - dscudiero - change location of testsh.sh
## 11-14-2017 @ 07.56.56 - (1.2.30)    - dscudiero - Fix up Vba prompt and switch to Msg
## 03-22-2018 @ 12:36:23 - 1.2.31 - dscudiero - Updated for Msg3/Msg, RunSql2/RunSql, ParseArgStd/ParseArgStd2
