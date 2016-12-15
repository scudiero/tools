
#==================================================================================================
version=1.7.2 # -- dscudiero -- 12/14/2016 @  8:57:55.79
#==================================================================================================

#==================================================================================================
# NOTE: This script is sourced by the publish script and cannot be run on its own
#==================================================================================================
## Copyright ©2015 David Scudiero -- all rights reserved.
## 05-12-14 -- 	dgs - Initial coding from origional Publis script.
## 01-21-15 -- 	dgs - Add a step to rebuild the pages database.
## 01-22-15 -- 	dgs - Refactored database file processing.
## 07-30-15 -- 	dgs - Fixed an issue coping the cim instances
#==================================================================================================
#set -x
#==================================================================================================
## Verify execution environment
	if [[ "${myName:0:7}" != 'publish' ]]; then Terminate "This script cannot be run stand alone, please use the 'publish' script"; fi

#===========================================================================
## Check things
	if [[ $cimStr = '' ]]; then Terminate "No CIMs select for copy."; fi

#===========================================================================
## Verify that the user wants to do continue
	VerifyContinue "You asking to publish CIM(s) for client: $client\n\tCIMs: $cimStr\
	\n\tSource Directory: $srcDir\n\tTarget Directory: $tgtDir\n\tBackup Directory: $backupDir\n"

#===========================================================================
## Make sure backup dirs exist
	if [[ -d $backupDir ]]; then rm -rf $backupDir; else mkdir mkdir -p $backupDir; fi
	for mkDirs in /db /web/admin /web/courseleaf/localsteps /web/courseleaf/stylesheets; do
		$DOIT mkdir -p $backupDir/$mkDirs
	done

#===========================================================================
## Make sure we can write to the $target directory, check all directories existance
	$DOIT touch $tgtDir/CIM-publishedOn.$$
	if [[ ! -e $tgtDir/CIM-publishedOn.$$ && $DOIT = '' ]]; then Terminate "You do not have write access to $tgtDir, \nplease contact the system folks to get access"; fi
	$DOIT rm $tgtDir/CIM-publishedOn.$$

#===========================================================================
## Get clversion of target location, set the skeleton directory
	clVer=$(grep '^clver:' $tgtDir/web/courseleaf/default.tcf  | cut -d":" -f2);
	if [[ $clVer != "" ]]; then
		clVer=$(echo $clVer | tr -d '\040\011\012\015\056')
		clVer=${clVer:0:2}
	else
		clVer=$defaultClVer
	fi
	skeleton=$skeletonRoot/$clVer
	if [[ ! -d $skeleton ]]; then Terminate "Could not find a skeletion directory for the clVersion ($clVer) of the site"; fi

#===========================================================================
## compare critical files that need to match before we start files
	Msg2 "Initial file checks ...";
	stop=false
	for compareFile in default.atj courseimportfunctions.html; do
		diff -qw $srcDir/web/courseleaf/localsteps/$compareFile $tgtDir/web/courseleaf/localsteps/$compareFile > /dev/null 2>&1; rc=$?
		[[ $rc -ne 0 ]] && Error ".../localsteps/$compareFile: Source and Target files do not match\n\tFiles must agree before continuing" && stop=true
	done
	[[ $stop == true ]] && Goodbye 3
	Msg2 "^Completed"; Msg2

#===========================================================================
## courseleaf.cgi
	Msg "Checking cgi ...";
	cgiDir=cgirhel${myRhel:0:1}
	eval cgiDir=\$$cgiDir
	CpSwapFiles $LINENO "courseleaf.cgi" "$cgiDir" "$tgtDir/web/courseleaf" "$backupDir/web/courseleaf"
	Msg2 "^Updated courseleaf.cgi from skeleton..."
	$DOIT chmod ug+rx $tgtDir/web/courseleaf/courseleaf.cgi
	Msg2 "^Completed"; Msg2

#===========================================================================
## CIM Core
	Msg "Copying CIM Core ..."
	if [[ -d $tgtDir/web/courseleaf/cim ]]; then
		$DOIT cp -rfp $tgtDir/web/courseleaf/cim $backupDir/web/courseleaf
	fi
	$DOIT rsync -rvqtog --exclude=.git $srcDir/web/courseleaf/cim/ $tgtDir/web/courseleaf/cim/
	Msg2 "^Completed"; Msg2

#===========================================================================
## Copy Database files, remove old dev data
	Msg2 "Copying DBs ..."
	$DOIT cp -fp $srcDir/db/cimcourses.sqlite $tgtDir/db/cimcourses.sqlite.new
	if [[ -f $tgtDir/db/cimcourses.sqlite ]]; then
		unset yesno
		Msg2 "^Found an instance of the cimcourses db in $tgtDir/db"
		Prompt yesno "\t\tDo you wish to copy the database file?" 'Yes No'; yesno=$(Lower ${yesno:0:1})
		if [[ $yesno == "y" ]]; then
			CpSwapFiles $LINENO "cimcourses.sqlite" "$srcDir/db" "$tgtDir/db" "$backupDir/db"
			Msg2 "^File copied"
		else
			Warning 0 1 "Cimcourse.sqlite file, not copied.  you can find the source version of this file in"
			Msg2 "^^the target directory with name: cimcourses.sqlite.new"
		fi
	else
		CpSwapFiles $LINENO "cimcourses.sqlite" "$srcDir/db" "$tgtDir/db"
		Msg2 "\^File copied"; Msg2
	fi

##TODO Need to drop the status table(s) and recreate from DEV.
##TODO Need merge cimcodes.
##TODO Need merge cimlookup.
##TODO Need merge cimballons.
##TODO Need merge user accounts.
#
	Msg2 "Clean instance status tables..."
	for cim in $(echo $cimStr | tr -d ','); do
		cimType=${cim%%admin}
		table="$cimType"'_status'
		Msg2 "^$table"
		$DOIT sqlite3 $tgtDir/db/cimcourses.sqlite "delete from $table"
	done
##TODO Is this correct? will these be rebuilt on cim course import?
	Msg2 "^xreffam"
	$DOIT sqlite3 $tgtDir/db/cimcourses.sqlite 'delete from xreffam'
	Msg2 "^xreffammember"
	$DOIT sqlite3 $tgtDir/db/cimcourses.sqlite 'delete from xreffammember'
	Msg2 "^Completed"; Msg2

#===========================================================================
## CIM Instances
	Msg2 "Copying CIM Instances ...";
	for cim in $(echo $cimStr | tr -d ','); do
		Msg2 "^$cim..."
		if [[ -d $tgtDir/web/$cim ]]; then $DOIT mkdir -p $backupDir/web/$cim; $DOIT cp -rfp $tgtDir/web/$cim $backupDir/web/; fi
		[[ ! -d $tgtDir/web/$cim ]] && mkdir -p $tgtDir/web/$cim
		cd $srcDir/web/$cim
		## Copy only files at the root level
		find . -maxdepth 1 -type f -exec $DOIT cp -fp {} $tgtDir/web/$cim/{} \;
		## Copy non-proposal sub directories
		re='^[0-9]+$'
		for dir in $(find -maxdepth 1 -type d -printf "%f "); do
			[[ $dir == '.' ]] && continue
			[[ $dir =~ $re ]] && continue
			$DOIT cp -rfp $srcDir/web/$cim/$dir $tgtDir/web/$cim
		done
		Msg2 "^^Instance copied"
	done

#===========================================================================
## CIM dbLeafs
	Msg2 "Copying CIM dbLeafs ..."
	cd $srcDir/web/admin
	for dir in $(find -maxdepth 1 -type d -name cim\* -printf "%f "); do
		[[ -d $tgtDir/web/admin/$dir ]] && $DOIT mv $tgtDir/web/admin/$dir $backupDir/web/admin/
		$DOIT cp -rfp $srcDir/web/admin/$dir $tgtDir/web/admin
	done
	if [[ -d $srcDir/web/admin/programs ]]; then
		[[ -d $tgtDir/web/admin/programs ]] && $DOIT mv $tgtDir/web/admin/programs $backupDir/web/admin/
		$DOIT cp -rfp $srcDir/web/admin/programs $tgtDir/web/admin/programs
	fi
	Msg2 "^Copied"; Msg

#===========================================================================
## stylesheets
	Msg2 "Copying stylesheets ..."
	for cssFile in grid.css lfjs-theme.css reset.css; do
		CpSwapFiles $LINENO "$cssFile" "$skeleton/web/courseleaf/stylesheets" \
		"$tgtDir/web/courseleaf/stylesheets" "$backupDir/web/courseleaf/stylesheets"
	done
	Msg2 "^Copied"; Msg

#===========================================================================
## Edit courseleaf/index.tcf
## Turn on CIM actions
	srcFile=$srcDir/web/courseleaf/index.tcf
	tgtFile=$tgtDir/web/courseleaf/index.tcf
	Msg2 "Editing: $tgtFile..."
	if [[ -f $tgtDir/web/courseleaf/index.new ]]; then $DOIT rm $tgtDir/web/courseleaf/index.new; fi
	$DOIT cp $tgtFile $backupDir/web/courseleaf/index.tcf

	# Pull out CIM lines from dev, put in a tmp file
	grep "navlinks:CIM" $srcFile > /tmp/$userName.$myName.srcConsoleData
	# Read in index.tcf file, scan for CIM configs, once we find the CIM configs in the next file then
	# copy the CIM configs from dev into output file, skip over all other existing configs in the next file
	topPart=/tmp/$userName.$myName.topPart
	if [[ -f $topPart ]]; then rm $topPart; fi
	bottomPart=/tmp/$userName.$myName.bottomPart
	if [[ -f $bottomPart ]]; then rm $bottomPart; fi
	found=0
	while read -r line; do
		#echo "line='${line}'" >> ~/stdout.txt
		idx=$(echo ${line} | grep -b -o "navlinks:CIM" | awk 'BEGIN {FS=":"}{print $1}')
		if [[ $idx == "" && $found -eq 0 ]]; then echo "${line}" >> $topPart; fi
		if [[ $idx != "" ]]; then found=1; fi
		if [[ $idx == "" && $found -eq 1 ]]; then echo "${line}" >> $bottomPart; fi
	done < $tgtFile

	# Turn on CIM Section
	fromStr='//sectionlinks:CIM|'
	toStr='sectionlinks:CIM|'
	$DOIT sed -i s"_${fromStr}_${toStr}_" $topPart
	## Paste the file together
		$DOIT cp $topPart $tgtFile.new
		$DOIT cat /tmp/$userName.$myName.srcConsoleData >> $tgtFile.new
		if [[ -f $bottomPart ]]; then $DOIT cat $bottomPart >> $tgtFile.new; fi
		$DOIT mv $tgtFile $tgtFile.bak
		$DOIT mv $tgtFile.new $tgtFile
		$DOIT rm $tgtFile.bak $topPart $bottomPart /tmp/$userName.$myName.srcConsoleData  2>1 /dev/null
	Msg2 "^File edited"; Msg2

	Msg2 "Rebuliding the console, $cimStr pages..."
	# Rebuild the console page
	Courseleaf.cgi $LINENO "$tgtDir" "-r /courseleaf/index.html"

	# Rebuild the CIM Instance pages
	cd $tgtDir/web/courseleaf
	for cim in $(echo $cimStr | tr -d ','); do
		Courseleaf.cgi $LINENO "$tgtDir" "-r /$cim/index.html"
	done
	Msg2 "^Completed"; Msg2

#===========================================================================
## Rebuild the pages database to make sure the reports work (as per NL 01-21-15)
	Msg2 "Rebuilding the pages database, may take a while.";
	cd $tgtDir/web/courseleaf
	Courseleaf.cgi $LINENO "$tgtDir" "-p"
	Msg2 "^Completed"; Msg2

#===========================================================================
## Edit courseleaf/localsteps/default.tcf
## Turn on programs for catalog
	if [[ $(Contains "$cimStr" "programadmin") == true ]]; then
		tgtFile=$tgtDir/web/courseleaf/localsteps/default.tcf
		srcFile=$srcDir/web/courseleaf/localsteps/default.tcf
		cp $tgtFile $backupDir/web/courseleaf/localsteps/default.tcf
		Msg "Editing: $tgtFile (cimprogramextrafields)"
		fromStr='//structuredcontent:programembed|'
		toStr='structuredcontent:programembed|'
		$DOIT sed -i s"_${fromStr}_${toStr}_" $tgtFile

		# Pull out cimprogramextrafields lines from dev, put in a tmp file
		grep 'cimprogramextrafields' $srcFile > /tmp/$userName.$myName.srcConsoleData

		# Parse the target file to put source data in the correct location in target file.
		topPart=/tmp/$userName.$myName.topPart
		if [[ -f $topPart ]]; then rm $topPart; fi
		bottomPart=/tmp/$userName.$myName.bottomPart
		if [[ -f $bottomPart ]]; then rm $bottomPart; fi
		found=0
		while read -r line; do
			#echo "line='${line}'" >> ~/stdout.txt
			idx=$(echo ${line} | grep -b -o "cimprogramextrafields" | awk 'BEGIN {FS=":"}{print $1}')
			if [[ $idx == "" && $found -eq 0 ]]; then echo "${line}" >> $topPart; fi
			if [[ $idx != "" ]]; then found=1; fi
			if [[ $idx == "" && $found -eq 1 ]]; then echo "${line}" >> $bottomPart; fi
		done < $tgtFile
		## Paste the target file together
			$DOIT cp $topPart $tgtFile.new
			$DOIT cat /tmp/$userName.$myName.srcConsoleData >> $tgtFile.new
			if [[ -f $bottomPart ]]; then $DOIT cat $bottomPart >> $tgtFile.new; fi
			$DOIT mv $tgtFile $tgtFile.bak
			$DOIT mv $tgtFile.new $tgtFile
			$DOIT rm $tgtFile.bak $topPart $bottomPart /tmp/$userName.$myName.srcConsoleData 2>1 /dev/null
	Msg2 "^Completed"; Msg2
	fi

#===========================================================================
## Edit courseleaf/localsteps/default.tcf
## edit wfstatqueries to ignore cims
	tgtFile=$tgtDir/web/courseleaf/localsteps/default.tcf
	srcFile=$srcDir/web/courseleaf/localsteps/default.tcf
	cp $tgtFile $backupDir/web/courseleaf/localsteps/default.tcf
	Msg2 "Editing: $tgtFile (wfstatqueries)"
	for cim in $(echo $cimStr | tr -d ','); do
		editLine=$(grep 'wfstatqueries:All Catalog Pages|' $tgtFile)
		#printf "%s" "$editLine"
		if [[ $(Contains "$editLine" "$cim") == true ]]; then
			Msg2 "^Add $cim"
			fromStr='|0'
			toStr=" AND PATH NOT LIKE \'/$cim/%\'|0"
			$DOIT sed -i s"_${fromStr}_${toStr}_" $tgtFile
		fi
	done
	Msg2 "^Completed"; Msg2

#===========================================================================
## Check workflows to make sure SIS step is at the end
	Msg2 "Checking sisname..."
	if [[ $(Contains "$cimStr" "courseadmin") == true ]]; then
		cimSisName=$(grep 'sisname:' $tgtDir/web/courseadmin/cimconfig.cfg)
		if [[ cimSisName = '' ]]; then
			Warning "sisname variable not found in coursadmin/cimconfig.cfg"
		else
			cimSisName=${cimSisName##sisname:}
			if [[ cimSisName = '' ]]; then Warning 0 1 "sisname variable in coursadmin/cimconfig.cfg has no value";
			else
	 			tmpFile=/tmp/$userName.$myName.tmpOut
				grep '^workflow:' $tgtDir/web/courseadmin/workflow.tcf > $tmpFile
				workflows=()
				IFS='';
				while read -r line; do workflows+=("$line"); done < $tmpFile
				rm $tmpFile
				for wfLine in ${workflows[@]}; do
					workflow=${wfLine%%|*}
					lastStep=${wfLine##*,}
					if [[ $lastStep != $cimSisName ]]; then Warning 0 1 "Last step in workflow '$workflow' is not '$cimSisName'"; fi
				done
			fi
		fi
	fi
	Msg2 "^Completed"; Msg2

#===========================================================================
## Turn on edit pencils in courselists
	if [[ $(Contains "$cimStr" "courseadmin") == true ]]; then
		editFile=$tgtDir/web/courseleaf/localsteps/structuredcontentdraw.html
		Msg2 "Turn on edit pencils in courselists..."
		Msg2 "^Editing $editFile"
		fromStr='//html += '\''<img style="cursor: pointer"'
		toStr='html += '\''<img style="cursor: pointer"'
		$DOIT sed -i s"_${fromStr}_${toStr}_" $editFile
		# republish the catalog
##TODO Turn off pdf's
		unset yesno
		Msg2 "The target site needs to be republished."
		Prompt yesno "Do you wish to republish here (Yes) or use the courseleaf console (No)" 'Yes No'; yesno=$(Lower ${yesno:0:1})
		if [[ $yesno == 'y' ]]; then
			Msg2 "Rebuilding the site, may take a while...";
			$DOIT Msg "\n*** $client Site rebuild ***\n" >> /tmp/$userName.$myName.$$
			Courseleaf.cgi $LINENO "$tgtDir" "-r /"
			Msg2 "^Catalog republish completed\n"
			Alert 2
		else
			Msg2 "Please go to the CourseLeaf console for the target site and republish the entire site"
			Pause 'Please press enter after site has been rebuilt'
			Msg2
		fi
		Msg2 "^Completed"; Msg2
	fi

#===========================================================================
## CIM Course Import
	Contains "$cimStr" "courseadmin"; rc=$?
	if [[ $rc -eq 1 ]]; then
		if [[ $(ls $srcDir/clienttransfers/cimcourses/ | wc -l) -ne 0 ]]; then
			Msg2 "Importing CIM Courses, may take a while...";
			[[ ! -d $tgtDir/clienttransfers/cimcourses/ ]] && mkdir -p $tgtDir/clienttransfers/cimcourses/
			cd $tgtDir/clienttransfers/cimcourses/
			# Save any existing data
			if [[ $(ls $tgtDir/clienttransfers/cimcourses/ | wc -l) -ne 0 ]]; then
				Msg2 "^Saving existing course data to ...cimcourses/$backupSuffix.gz"
				tar --remove-files -cvzf $backupSuffix.gz * --exclude '*.gz' > /dev/null
			fi


			$DOIT cp -rfp $srcDir/clienttransfers/cimcourses/* $tgtDir/clienttransfers/cimcourses
			Msg2 "\n*** $client CIM Course Import ***\n" >> /tmp/$userName.$myName.$$
			cd $tgtDir/web/courseleaf
			Courseleaf.cgi $LINENO "$tgtDir" "courseimportcim /courseadmin/index.html"
		else
			Warning "Skipping CIM course import, source directory\n\t$srcDir/clienttransfers/cimcourses/\n\tis empty"
		fi
		Msg2 "^Completed"; Msg2
	fi

#===========================================================================
## End of process messages
	Msg2 $ColorRed
	Msg2 "\n*** Note ***"
	Msg2 "All files have been moved and pages built.  What remains to be done manually:"
	Msg2 "\t1) Merge roles.tcf file from the source environemnt into target environemnt."
	Msg2 "\t2) Merge users from source environemnt into target environemnt."
	Msg2 "\t3) Merge the wfemail data from from source environemnt into target environemnt.\n\tRemember to blank out the test email data if present"
	Msg2 $ColorDefault

#===========================================================================
## All Done CIM
Msg2; Msg2 "Publish of CIMs: $cimStr completed"; Msg2
$DOIT touch $tgtDir/CIM-publishedOn
Goodbye 0
# 10-16-2015 -- dscudiero -- Update for framework 6 (1.7)
