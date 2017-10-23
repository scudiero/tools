#!/bin/bash
#=========================================================================================================================================================================
module=$1; shift
[[ -z $module ]] && echo "Sorry, you must specify a module name." && exit

## Set the CLASSPATH
	classPathSave="$CLASSPATH"
	unset CLASSPATH
	searchDirs="$TOOLSPATH/src"
	[[ $TOOLSSRCPATH != '' ]] && searchDirs="$( tr ':' ' ' <<< $TOOLSSRCPATH)"
	unset CLASSPATH
	for searchDir in $searchDirs; do
		for jar in $(find $searchDir/java -mindepth 1 -maxdepth 1 -type f -name \*.jar); do
			[[ $CLASSPATH == '' ]] && CLASSPATH="$jar" || CLASSPATH="$CLASSPATH:$jar"
		done
	done
	export CLASSPATH="$CLASSPATH"

## Compile the module
	pushd $HOME/tools/src/java >& /dev/null
	[[ -f $module.class ]] & rm -f $module.class
	javaFile="$module"
	[[ ! -f $javaFile ]] && javaFile="$javaFile.java"
	javac $javaFile; rc=$?
	echo -e "\t$module compiled, rc=$rc"

## Refresh the jar file
	[[ $rc -eq 0 && -r $module.class ]] && jar -uf tools.jar *.class && echo -e "\ttools.jar refreshed " && rm -f $module.class

## Cleanup
	export CLASSPATH="$classPathSave"
	popd >& /dev/null
exit
## 10-23-2017 @ 16.07.08 - dscudiero - misc cleanup
