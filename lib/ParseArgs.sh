## XO NOT AUTOVERSION
#===================================================================================================
# version="1.0.1" # -- dscudiero -- Fri 12/14/2018 @ 13:43:59
#===================================================================================================
# Parse script arguments using the C program
#===================================================================================================
# Copyright 2018 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
ParseArgs() {
	source <(CallC parseArgs $*); 
	client="${unknownArgs%% *}"; 
	[[ ${client:0:1} == "-" ]] && unset client || unknownArgs="${unknownArgs##* }"
	[[ -z $env && -n $envs ]] && env="$envs"
	return 0;
}

export -f ParseArgs
#===================================================================================================
# Check-in Log
#===================================================================================================## 12-14-2018 @ 13:45:51 - 1.0.1 - dscudiero - Put