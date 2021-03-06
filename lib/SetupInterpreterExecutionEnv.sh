## XO NOT AUTOVERSION
#===================================================================================================
# version="1.0.2" # -- dscudiero -- 01/04/2017 @ 13:49:08.24
#===================================================================================================
# Trip all non printable chars from a variable
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

#=========================================================================================================================================================================
# Setup the execution environment for a secondary interpreter
# SetupInterpreterExecutionEnv [interpreter|python] [interpreterVer]
# Interpreters supported are {'python','go'}
# if interpreterVer is not specified then it will look for a env variable called 'Use<Interpreter>Ver' to use, if that is not found it defaults to 'current'
# Sets the interpreter gloal variales, dowes not effect the PATH
#=========================================================================================================================================================================
function SetupInterpreterExecutionEnv {
	local interpreter=${1:-python}; shift
	local interpreterVer=$1
	local interpreterVar
	if [[ $interpreterVer == '' ]]; then
		interpreterVar="Use$(TitleCase "$interpreter")Ver"
		interpreterVer=${!interpreterVar}
	fi
	[[ $interpreterVer == '' ]] && interpreterVer='current'

	local interpreterRoot interpreterBinDir
	cwd=$(pwd)
	dump -3 -t interpreter interpreterVer osName osVer

	## Find the interpreter root, check for local directory, then TOOLSPROD
		local interpreterRoot; unset interpreterRoot
		[[ -d $HOME/$interpreter ]] && interpreterRoot="$HOME/$interpreter"
		[[ $interpreterRoot == '' && -d $HOME/$(TitleCase "$interpreter") ]] && interpreterRoot="$HOME/$(TitleCase $interpreter)"
		[[ $interpreterRoot == '' && -d $TOOLSPATH/$interpreter ]] && interpreterRoot="$TOOLSPATH/$interpreter"
		[[ $interpreterRoot == '' && -d $TOOLSPATH/$(TitleCase $interpreter) ]] && interpreterRoot="$TOOLSPATH/$(TitleCase $interpreter)"

		[[ -d $interpreterRoot/$osName ]] && interpreterRoot="$interpreterRoot/$osName"
		[[ -d $interpreterRoot/$osVer ]] && interpreterRoot="$interpreterRoot/$osVer"
		dump -3 -t interpreterRoot

	## Find the interpreter root directory
		cd "$interpreterRoot"
		[[ ! -d $interpreterRoot/$interpreterVer ]] && interpreterVer="$(find -maxdepth 1 -mindepth 1 -type d -name "$interpreterVer*" -printf '%f\n' | sort -n -r -t / | cut -d$'\n' -f1)"
		interpreterBinDir="$interpreterRoot/$interpreterVer/bin"
		dump -3 -t interpreterVer interpreterBinDir

	## Interpreter specific stuff
		interpreter="$(Lower "$interpreter")"
		if [[ $interpreter == 'python' ]]; then
			PYDIR="$(dirname $interpreterBinDir)"
			cd "$interpreterBinDir"
			local pip="$(find -maxdepth 1 -mindepth 1 -type f -name "pip*" -printf '%f\n' | sort -n -r -t / | cut -d$'\n' -f1)"
			alias pip="$interpreterBinDir/$pip"
			local pypm="$(find -maxdepth 1 -mindepth 1 -type f -name "pypm*" -printf '%f\n' | sort -n -r -t / | cut -d$'\n' -f1)"
			alias pypm="$interpreterBinDir/$pypm"
			cd "$(dirname $interpreterBinDir)/lib/"
			local lib="$(find -maxdepth 1 -mindepth 1 -type d -name "python*" -printf '%f\n' | sort -n -r -t / | cut -d$'\n' -f1)"
			export "PYTHONPATH=$(pwd)/$lib/site-packages"
		elif [[ $interpreter == 'go' ]]; then
			export GOROOT=$interpreterBinDir
			GOPATH="$TOOLSPATH/src/go"
			[[ -d $HOME/tools/go ]] && GOPATH="$HOME/tools/go:$GOPATH"
			#[[ -d $HOME/work ]] && GOPATH="$HOME/work:$GOPATH"
		fi

	cd "$cwd"
	return 0
} #SetupInterpreterExecutionEnv
export -f SetupInterpreterExecutionEnv

#===================================================================================================
# Check-in Log
#===================================================================================================

## Wed Jan  4 13:54:28 CST 2017 - dscudiero - General syncing of dev to prod
