#!/bin/bash
#==================================================================================================
version=2.6.52 # -- dscudiero -- 01/11/2017 @  8:30:51.13
#==================================================================================================
imports='Hello Goodbye' #imports="$imports "
Import "$imports"
TrapSigs 'on'
originalArgStr="$*"
scriptDescription="Initialize a new production tools repository"

#==================================================================================================
## Copyright �2017 David Scudiero -- all rights reserved.
#==================================================================================================

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
helpSet='script,client,env'
Hello
masterRepo="/mnt/dev6/web/git/tools.git"

#===================================================================================================
#= Main
#===================================================================================================

unset ans
Msg2 "You are asking to $(Lower "$scriptDescription") in $(dirname $TOOLSPATH)"
Prompt ans "Do you wish to continue" "Yes No"; ans=${ans:0:1}; ans=$(Lower $ans)
[[ $ans != 'y' ]] && Goodbye 0

Msg2 "\nBacking up tools directory..."
	cd $TOOLSPATH
	cd ..
	[[ -d " tools.bak" ]] && Terminate "There already is a 'tools.bac' directory in '$(pwd)'"
	mv -v tools tools.bak

Msg2 "\nCloneing repository: $masterRepo..."
	git clone "$masterRepo"
	chgrp -R leepfrog tools
	chmod -R 740 tools
	cd tools
	for dir in lib src workbooks; do
		chmod 750 $dir
	done
	chmod 750 dispatcher.sh

Msg2 "\nMoving over other directories/files..."
	cd ${TOOLSPATH}.bak
	mv -v cygwin64 ../tools
	mv -v courseleafEscrowedSites/ ../tools
	mv -v DBs ../tools
	mv -v Logs ../tools
	mv -v MySQL/ ../tools
	mv -v Python/ ../tools
	mv -v shadows/ ../tools
	cp -v ./src/.pw1 ../tools/src

Msg2 "\nBuilding bin directory..."
	Msg2 "^Symbolic links..."
		cd $TOOLSPATH/src
		files=($(find -maxdepth 1 -type f -name \*.sh -printf "%f "))
		cd ../bin
		for file in ${files[@]}; do
			fileExt=$(echo $file | cut -d '.' -f2)
			fileName=$(echo $file | cut -d '.' -f1)
			[[ ${fileName:0:4} == 'test' || $file == 'tidbits' ]] && continue
			fileNameLower=$(echo $fileName | tr '[:upper:]' '[:lower:]')
			$DOIT ln -s ../dispatcher.sh $fileName
			[[ $fileName != $fileNameLower ]] && $DOIT ln -s ./$fileName ./$fileNameLower
		done
	Msg2 "^Special links for scriptsAndReports..."
		linkTarget=scriptsAndReports
		for token in scripts reports; do
			$DOIT ln -s ./$linkTarget $token
		done
	Msg2 "^.exe files..."
		cd $TOOLSPATH/src
		files=($(find -maxdepth 1 -type f -name \*.exe -printf "%f "))
		cd ../bin
		for file in ${files[@]}; do
			$DOIT ln -s ../src/$file $file
		done
	Msg2 "^.exe files..."
		cd $TOOLSPATH/src
		files=($(find -maxdepth 1 -type f -name \*.exe -printf "%f "))
		cd ../bin
		for file in ${files[@]}; do
			$DOIT ln -s ../src/$file $file
		done
	Msg2 "^.jar files..."
		cd $TOOLSPATH/src/java
		files=($(find -maxdepth 1 -type f -name \*.jar -printf "%f "))
		cd ../bin
		for file in ${files[@]}; do
			$DOIT ln -s ../src/java/$file $file
		done

Msg2 "\nSetting group ownership and permissions"
	cd $TOOLSPATH
	chgrp leepfrog ./src/.pw1
	chmod 740 ./src/.pw1
	for dir in lib src workbooks; do
		chgrp -R leepfrog $dir
		chmod 750 $dir
		dirs=($(find ./$dir -mindepth 1 -maxdepth 1 -type d))
		for subDir in ${dirs[@]}; do
			chmod -R 750 $subDir
		done
	done
	chgrp -R leepfrog bin
	chmod -R 750 bin

	Msg2 "done"




#===================================================================================================
## Bye-bye
#===================================================================================================
Goodbye 0

#===================================================================================================
## Check-in log
#===================================================================================================
## Wed Jan 11 08:31:08 CST 2017 - dscudiero - Added building the bin directory
