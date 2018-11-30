#!/bin/bash
#=======================================================================================================================
module=$1; shift
[[ -z $module ]] && echo "Sorry, you must specify a module name." && exit

compiler='/usr/bin/g++'
cppSrc="$HOME/tools/src/cpp"
cppLibs="$HOME/tools/lib/cpp"
outputDir="$HOME/bin"

## Set the includes string
	includedStr="-I /usr/include/mysql"
	unset libs
	pushd "$cppLibs" &> /dev/null
	libs=$(find . -maxdepth 1 -type l -printf ",%f"); #len=${#libs}
	for lib in ${libs:1}; do
		includedStr="$includedStr -I $(pwd)/$lib"
	done
	# includedStr="${includedStr:1}"
	popd &> /dev/null

## Compile the module
	pushd "$cppSrc" &> /dev/null
	[[ -r ./${module}.cpp ]] && moduleFile="${module}.cpp" || moduleFile="${module}"
	[[ ! -r $moduleFile ]] && echo -e "Error, could not locate module file '$moduleFile' in '$cppSrc'" && exit -3

	compilerArgs="-o $outputDir/$module $includedStr $moduleFile -L /usr/lib64/mysql -l mysqlclient -std=gnu++0x"
	# compilerArgs="-o $outputDir/$module $includedStr $moduleFile -L /usr/lib64/mysql -l mysqlclient"
	echo $compiler $compilerArgs 
	$compiler $compilerArgs
	rc=$?
	[[ $rc -eq 0 ]] && echo -e "\t$module compiled --> ../../../bin/${module%%.*}" || echo -e "\t$module compiled, rc=$rc"
	popd &> /dev/null

## Done
exit $rc


#$compiler -o "../../../bin/$module" $includedStr $moduleFile -L /usr/lib64/mysql -l mysqlclient -std=gnu++0x 
#$compiler -o "../../../bin/${module%%.*}" $includedStr $moduleFile
#/usr/bin/g++ -o ../../../bin/testcpp -I /usr/include/mysql -L /usr/lib64/mysql -l mysqlclient ./tools/src/cpp/testcpp.cpp