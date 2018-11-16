//==================================================================================================
// XO NOT AUTOVERSION
//==================================================================================================
// version="1.0.9" // -- dscudiero -- Fri 05/25/2018 @ 12:41:06.53
//==================================================================================================
#include <iostream>		// IO utility library
#include <string>		// String utility library
#include <fstream>		// Filesystem utility library
#include <cstdlib>		// Standard library
#include <stdlib.h>
#include <list> 
#include <iterator>
#include <boost/algorithm/string.hpp> 

using namespace std;
using std::cout;
using std::getenv;


//=================================================================================================================
class ArgDef { 
    public: 
    	string shortName, longName, type, scriptVar, scriptCmd;

    public:
    	ArgDef(string, string, string, string, string);
   		string toString () {
		return("shortName: '" + shortName + "', longName: '" + longName + "'; type: '" + type 
			+ "'; scriptVar: '" + scriptVar + "'; scriptCmd: '" + scriptCmd + "'");
		}
};
// constructor
ArgDef::ArgDef (string a, string b, string c, string d, string e) {
	//         (shortName, longName, type,    scriptVar, scriptCmd)
	shortName = a; longName = b; type = c; scriptVar = d; scriptCmd = e;
}

// //=================================================================================================================
int main(int argc, char *argv[]) {
	string myName=argv[0];

	// Get an environment variable
    // if (const char* env_p = std::getenv("PATH"))
    //     std::cout << "Your PATH is: " << env_p << '\n';
	// Set an environment variable
	// setenv("TESTVAR", "12345", true);

	//=================================================================================================================
	// Load the argument definitions array
	//                      (shortName, longName, type, scriptVar, scriptCmd)
	//=================================================================================================================
	list <ArgDef> argDefs;
	argDefs.push_back(ArgDef("hh", "helpextended", "switch", "", "Help2 -extended; Goodbye 0;"));
	argDefs.push_back(ArgDef("h", "help", "switch", "", "Help2; Goodbye 0;"));
	argDefs.push_back(ArgDef("envs", "environments", "option", "", "Help2 -extended; Goodbye 0;"));
	argDefs.push_back(ArgDef("src", "srcenv", "option", "srcEnv", "mapToEnv"));
	argDefs.push_back(ArgDef("tgt", "tgtenv", "option", "tgtEnv", "mapToEnv"));
	argDefs.push_back(ArgDef("prod", "products", "option", "products", ""));
	argDefs.push_back(ArgDef("cimc", "courseadmin", "switch", "cimStr", "appendLong"));
	argDefs.push_back(ArgDef("cimp", "programadmin", "switch", "cimStr", "appendLong"));
	argDefs.push_back(ArgDef("cimm", "miscadmin", "switch", "cimStr", "appendLong"));
	argDefs.push_back(ArgDef("all", "allitems", "switch", "allItems", ""));
	argDefs.push_back(ArgDef("cat", "catalog", "switch", "products", "appendLong"));
	argDefs.push_back(ArgDef("cim", "cim", "switch", "products", "appendLong"));
	argDefs.push_back(ArgDef("clss", "clss", "switch", "products", "appendLong"));
	argDefs.push_back(ArgDef("ignore", "ignorelist", "option", "ignoreList", ""));
	argDefs.push_back(ArgDef("testm", "testmode", "switch", "testMode", ""));
	argDefs.push_back(ArgDef("batch", "batchmode", "switch", "batchMode", ""));
	argDefs.push_back(ArgDef("nob", "nobanners", "switch", "noBanners", ""));
	argDefs.push_back(ArgDef("noe", "noemails", "switch", "noEmails", ""));
	argDefs.push_back(ArgDef("nol", "nolog", "switch", "noLog", ""));
	argDefs.push_back(ArgDef("non", "nonews", "switch", "noNews", ""));
	argDefs.push_back(ArgDef("nop", "noprompt", "switch", "", "verify=false;"));
	argDefs.push_back(ArgDef("now", "nowarn", "switch", "noWarn", ""));
	argDefs.push_back(ArgDef("nocl", "noclear", "switch", "noClear", ""));
	argDefs.push_back(ArgDef("noch", "nocheck", "switch", "noCheck", ""));
	argDefs.push_back(ArgDef("q", "quiet", "switch", "quiet", ""));
	argDefs.push_back(ArgDef("x", "experimentalmode", "switch", "", "DOIT='echo';"));
	argDefs.push_back(ArgDef("force", "force", "switch", "force", ""));
	argDefs.push_back(ArgDef("fork", "fork", "switch", "fork", ""));
	argDefs.push_back(ArgDef("fast", "fastinit", "switch", "fastInit", ""));
	argDefs.push_back(ArgDef("info", "informationonlymode", "informationOnlyMode", "fork", ""));
	argDefs.push_back(ArgDef("for", "foruser", "option", "forUser", ""));
	argDefs.push_back(ArgDef("pub", "public", "switch", "envs", "appendLong"));
	argDefs.push_back(ArgDef("pre", "preview", "switch", "envs", "appendLong"));
	argDefs.push_back(ArgDef("pri", "prior", "switch", "envs", "appendLong"));
	argDefs.push_back(ArgDef("c", "curr", "switch", "envs", "appendLong"));
	argDefs.push_back(ArgDef("n", "next", "switch", "envs", "appendLong"));
	argDefs.push_back(ArgDef("t", "test", "switch", "envs", "appendLong"));
	argDefs.push_back(ArgDef("d", "dev", "switch", "envs", "appendLong"));
	argDefs.push_back(ArgDef("p", "pvt", "switch", "envs", "appendLong"));
	argDefs.push_back(ArgDef("e", "email", "option", "email", ""));
	argDefs.push_back(ArgDef("v", "verbose", "counter", "verboseLevel", ""));
	argDefs.push_back(ArgDef("j", "jalot", "option", "jalot", ""));
	argDefs.push_back(ArgDef("f", "file", "option", "file", ""));
	argDefs.push_back(ArgDef("-uselocal", "useLocal", "switch", "useLocal", ""));

	//=================================================================================================================
	// Loop through the arguments
	string unknownArgs="";
	for(int i=1; i < argc; i++) {
		string arg = argv[i];
		if (arg.substr(0,1) != "-") {
			unknownArgs = unknownArgs + " " + argv[i];
			continue;
		}
		arg=arg.substr(1);
		boost::algorithm::to_lower(arg);

		// cout << "Processing argument: " + arg + "\n";
		// Loop through all of the argument definitions
		bool foundArg=false;
	    std::list<ArgDef>::iterator it;
		for (it = argDefs.begin(); it != argDefs.end(); ++it) {
			string shortName = it->shortName;
			if (arg.substr(0,shortName.length()) == shortName) {
				// std::cout << "\t" + it->toString() + "\n";
				foundArg=true;
				string longName = it->longName;
				string type = it->type;
				string scriptVar = it->scriptVar;
				string scriptCmd = it->scriptCmd;
				if (type == "switch") {
					if (scriptCmd != "") {
						if (scriptCmd == "appendLong") {
							// std::cout << scriptVar + "=\"$" + scriptVar + " " + longName + "\"\n";
							std::cout << "[[ -z $" + scriptVar + " ]] && " + scriptVar + "=\"" + longName + "\"" + 
										 " || " + scriptVar + "=\"$" + scriptVar + " " + longName + "\"\n";
						} else if (scriptCmd == "appendShort") {
							std::cout << "[[ -z $" + scriptVar + " ]] && " + scriptVar + "=\"" + shortName + "\"" + 
										 " || " + scriptVar + "=\"$" + scriptVar + " " + shortName + "\"\n";
						} else {
							std::cout << scriptCmd;
						}
					} else {
						std::cout << scriptVar + "=true\n";
					}
				} else if (type == "option") {
					i++;
					arg = argv[i];
					if (scriptCmd != "") {
						if (scriptCmd == "mapToEnv") {
							if (arg == "c") {
								arg = "curr";
							} else if (arg == "n") {
								arg = "next";
							} else if (arg == "t") {
								arg = "test";
							} else if (arg == "d") {
								arg = "dev";
							} else if (arg == "p") {
								arg = "pvt";
							} else if (arg == "pub") {
								arg = "public";
							} else if (arg == "pri") {
								arg = "prior";
							} else if (arg == "pre") {
								arg = "preview";
							}
						}
					}
					std::cout << scriptVar + "=\"" + arg + "\"\n";
				} else if (type == "counter") {
					std::cout << scriptVar + "=\"" + arg.substr(arg.length()-1) + "\"\n";
				}
				break;
			}
		} //argDefs
		if (!foundArg)
			unknownArgs = unknownArgs + " " + argv[i];
	} // args

	if (unknownArgs != "")
		std::cout << "unknownArgs=\"" + unknownArgs.substr(1) + "\"\n";

	return 0;
} // main
// 11-14-2018 @ 10:42:55 - 1.0.9 - dscudiero - Add expansion of env variable
// 11-16-2018 @ 09:12:00 - 1.0.9 - dscudiero - Added -useLocal
