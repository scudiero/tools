#!/bin/bash
#=========================================================================================================================================================================
module=$1; shift
[[ -z $module ]] && echo "Sorry, you must specify a module name." && exit

compiler='/usr/bin/g++'
cppSrc="$HOME/tools/src/c++"
cppLibs="$HOME/tools/lib/c++"
libraries=$(ls )

## Set the CLASSPATH
	ldLibPathSave="$LD_LIBRARY_PATH"
	unset LD_LIBRARY_PATH libPath libs
	pushd "$cppLibs" &> /dev/null
	libs=$(find . -maxdepth 1 -type l -printf ",%f"); #len=${#libs}
	#for lib in ${libs:0:len-1}; do
	for lib in ${libs:1}; do
		libPath="$libPath,$(pwd)/$lib/libs"
	done
	libPath="${libPath:1}"
	#echo "libPath = '$libPath"
	export LD_LIBRARY_PATH="$libPath"

## Compile the module
	pushd "$cppSrc" &> /dev/null
	moduleFile="${module}.cpp"
	[[ ! -r $moduleFile ]] && echo -e "Error, could not locate module file '$moduleFile' in '$cppSrc'" && exit -3
	$compiler -o "../../../bin/$module" $moduleFile ; rc=$?
	echo -e "\t$module compiled, rc=$rc"
	popd &> /dev/null

## Cleanup
	export LD_LIBRARY_PATH="$ldLibPathSave"

exit 0
## 09-25-2017 @ 15.49.50 - dscudiero - General syncing of dev to prod
