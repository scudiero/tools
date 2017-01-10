#!/bin/bash
#==================================================================================================
version=2.6.51 # -- dscudiero -- 12/14/2016 @ 16:37:10.83
#==================================================================================================
imports='Hello Goodbye' #imports="$imports "
Import "$imports"
TrapSigs 'on'
originalArgStr="$*"
scriptDescription="Initialize a new production tools repository"

#==================================================================================================
## Copyright ©2017 David Scudiero -- all rights reserved.
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

Msg2 "\nBacking up tools directory"
	cd $TOOLSPATH
	cd ..
	[[ -d " tools.bak" ]] && Terminate "There already is a 'tools.bac' directory in '$(pwd)'"
	mv -v tools tools.bak

Msg2 "\nCloneing repository: $masterRepo"
	git clone "$masterRepo"
	chgrp -R leepfrog tools
	chmod -R 740 tools
	cd tools
	for dir in lib src workbooks; do
		chmod 750 $dir
	done
	chmod 750 dispatcher.sh

Msg2 "\nMoving over other directories/files"
	cd ${TOOLSPATH}.bak
	mv -v cygwin64 ../tools
	mv -v courseleafEscrowedSites/ ../tools
	mv -v DBs ../tools
	mv -v Logs ../tools
	mv -v MySQL/ ../tools
	mv -v Python/ ../tools
	mv -v shadows/ ../tools
	cp -v ./src/.pw1 ../tools/src

Msg2 "\nSetting group ownership and permissions"
	cd $TOOLSPATH
	chgrp leepfrog ./src/.pw1
	chmod 740 ./src/.pw1
	for dir in lib src workbooks; do
		dirs=($(find ./$dir -mindepth 1 -maxdepth 1 -type d))
		for subDir in ${dirs[@]}; do
			echo chmod -R 750 $subDir
		done
	done
	Msg2 "done"

#===================================================================================================
## Bye-bye
#===================================================================================================
Goodbye 0

#===================================================================================================
## Check-in log
#===================================================================================================
