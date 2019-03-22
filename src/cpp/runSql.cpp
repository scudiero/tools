//==================================================================================================
// XO NOT AUTOVERSION
//==================================================================================================
// version="1.1.8" // -- dscudiero -- Mon 03/11/2019 @ 08:38:02
//==================================================================================================
#include <iostream>		// IO utility library
#include <string>		// String utility library
#include <fstream>		// Filesystem utility library
#include <cstdlib>		// Standard library
#include <stdlib.h>
#include <list>
#include <vector>
#include <iterator>
#include <mysql.h>
#include <boost/algorithm/string.hpp> 

class FFError {
public:
    std::string Label;
    FFError() { Label = (char *)"Generic Error";}
    FFError(char *message ) {Label = message;}
    ~FFError() { }
    inline const char* GetMessage  (void)   {return Label.c_str();}
};
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

//==================================================================================================
// Utilities
//==================================================================================================
void Here(string where, bool debug) { if (debug) std::cout << "Here: " + where + "\n"; return; }
void Here(int where, bool debug) { if (debug) printf("Here: %d\n", where); return; }
// void Dump(string var, string val, bool debug) { if (debug) printf("%s = '%s'\n", var,val); return; }
// void Dump(string var, int val, bool debug) { if (debug) printf("%s = '%d'\n", var,val); return; }

//==================================================================================================
int main(int argc, char *argv[]) {
	// Constants
		string dbHost="mdb1-host.inside.leepfrog.com";
		string dbName="courseleafdatawarehouse";
		string dbUser="leepfrogRead";
		string dbPw="v721-!PP9b";

	// Program variables
		bool debug=false;
		string sqlStmt="";
		string scriptName="";
		list <ArgDef> argDefs;

	// Parse arguments
		string myName = argv[0];
		for(int i=1; i < argc; i++) {
			string arg = argv[i];
			string argl = arg; boost::algorithm::to_lower(argl);
			if (arg.substr(0,2) != "--") {
				scriptName = arg;
				continue;
			} else {
				if (argl == "--d")
		    		debug=true;
			}
		}
		if (debug) std::cout << "Starting " + myName + "'\n";
		if (debug) std::cout << "\t scriptName = '" + scriptName +"'\n";

    //==============================================================================================
	// Connect to the database to get the standard argDefs
    //==============================================================================================
		MYSQL *MySQLConRet;
		MYSQL *MySQLConnection = NULL;
		MySQLConnection = mysql_init( NULL );
		try {

			MySQLConRet = mysql_real_connect(MySQLConnection, dbHost.c_str(), dbUser.c_str(), dbPw.c_str(), dbName.c_str(), 3306, NULL, 0);
			if ( MySQLConRet == NULL )
            	throw FFError( (char*) mysql_error(MySQLConnection) );
            if (debug) {
	            printf("\t MySQL Connection Info: %s \n", mysql_get_host_info(MySQLConnection));
		        printf("\t MySQL Client Info: %s \n", mysql_get_client_info());
		        printf("\t MySQL Server Info: %s \n", mysql_get_server_info(MySQLConnection));
		   	}

	    	int mysqlStatus = 0;
    		MYSQL_RES *mysqlResult = NULL;
			MYSQL_ROW mysqlRow;
			MYSQL_FIELD *mysqlFields;
            my_ulonglong numRows;
            unsigned int numFields;

			// Get the standard argdefs from the database
				if (debug) std::cout << "Retrieving argDefs ...\n";
				sqlStmt="select shortName, longName, type, scriptVariable, scriptCommand from argdefs where status=\"active\" order by seqOrder";
				mysqlStatus = mysql_query( MySQLConnection, sqlStmt.c_str());
				if (mysqlStatus)
				    throw FFError( (char*)mysql_error(MySQLConnection) );
				else
				    mysqlResult = mysql_store_result(MySQLConnection); // Get the Result Set

				string shortName="", longName="", type="", scriptVar="", scriptCmd="";
				if (mysqlResult) {
		            numRows = mysql_num_rows(mysqlResult);
					if (numRows > 0) {
						while(mysqlRow = mysql_fetch_row(mysqlResult)) {
							shortName="", longName="", type="", scriptVar="", scriptCmd="";
							shortName =  mysqlRow[0];
							longName =  mysqlRow[1];
							type =  mysqlRow[2];
							scriptVar =  mysqlRow[3];
							if (mysqlRow[4] != NULL) scriptCmd =  mysqlRow[4];

							if (debug) printf("\t shortName: '%s', \t longName: '%s', \t type: '%s', \t scriptVar: '%s', \t scriptCmd: '%s'\n", 
												shortName.c_str(),longName.c_str(),type.c_str(),scriptVar.c_str(),scriptCmd.c_str());

							argDefs.push_back(ArgDef(shortName, longName, type, scriptVar, scriptCmd));
						}
					}
				} else {
					std::cout << "Could not retrieve auth groups, sql = '\n" + sqlStmt +"'\n";
				   	return -1;
				}
		// database connection failed
		} catch ( FFError e ) {
        	printf("%s\n",e.Label.c_str());
        	return 1;
    	}

    //==============================================================================================
	// Are there any script specific arguments, if found then add to the argDefs arraylist
	//==============================================================================================
    if (char* myArgsPtr = std::getenv("myArgs")) {
    	if (debug) std::cout << "Retrieving script specific arguments ...\n";
		char str[4096];
		strncpy(str,myArgsPtr,sizeof(str));
		char *line;
		char *token;
		char buf[4096];
		for (line = strtok (str, ";"); line != NULL;
		     line = strtok (line + strlen (line) + 1, ";")) {
			strncpy (buf, line, sizeof (buf));
		   	// printf ("Line: %s\n", buf);
		   	string argDevStr="";
		   	int cntr=1;
		   	string shortName="", longName="", type="", scriptVar="", scriptCmd="";
		  	for (token = strtok (buf, "|"); token != NULL;
		   		token = strtok (token + strlen (token) + 1, "|")) {
		      	// printf ("\tToken: %s\n", token);
		      	if (cntr == 1) {
		      		shortName = token;
		      		boost::algorithm::to_lower(shortName);
		      	} else if (cntr == 2) {
		      		longName = token;
		      	} else if (cntr == 3) {
		      		type = token;
		      	} else if (cntr == 4) {
		      		scriptVar = token;
		      	} else {
		      		scriptCmd = token;
		      	}
		     	cntr++;
		    }
		    argDefs.push_front(ArgDef(shortName, longName, type, scriptVar, scriptCmd));
			if (debug) printf("\t shortName: '%s', \t longName: '%s', \t type: '%s', \t scriptVar: '%s', \t scriptCmd: '%s'\n", 
							shortName.c_str(),longName.c_str(),type.c_str(),scriptVar.c_str(),scriptCmd.c_str());
		}
    }

    //==============================================================================================
	// Loop through the arguments
    //==============================================================================================
    if (debug) std::cout << "Looping through arguments ...\n";
	string unknownArgs="";
	for(int i=1; i < argc; i++) {
		string arg = argv[i];
		if (arg.substr(0,2) == "--") {
			continue;
		}
		if (arg.substr(0,1) != "-") {
			unknownArgs = unknownArgs + " " + argv[i];
			continue;
		}
		arg=arg.substr(1);
		boost::algorithm::to_lower(arg);

		if (debug) cout << "\tProcessing argument: " + arg + "\n";
		// Loop through all of the argument definitions
		bool foundArg=false;
	    std::list<ArgDef>::iterator it;
		for (it = argDefs.begin(); it != argDefs.end(); ++it) {
			// std::cout << "\t" + it->toString() + "\n";
			string shortName = it->shortName;
			if (arg.substr(0,shortName.length()) == shortName) {
				// std::cout << "\t Found match for: " + it->toString() + "\n";
				foundArg=true;
				string longName = it->longName;
				string type = it->type;
				string scriptVar = it->scriptVar;
				string scriptCmd = it->scriptCmd;
				if (type == "switch") {
					if (scriptCmd != "") {
						string scriptCmdL=scriptCmd;
						boost::algorithm::to_lower(scriptCmdL);
						if (scriptCmdL == "appendlongname") {
							// std::cout << scriptVar + "=\"$" + scriptVar + " " + longName + "\"\n";
							std::cout << "[[ -z $" + scriptVar + " ]] && " + scriptVar + "=\"" + longName + "\"" + 
										 " || " + scriptVar + "=\"$" + scriptVar + " " + longName + "\"\n";
						} else if (scriptCmdL == "appendshortname") {
							std::cout << "[[ -z $" + scriptVar + " ]] && " + scriptVar + "=\"" + shortName + "\"" + 
										 " || " + scriptVar + "=\"$" + scriptVar + " " + shortName + "\"\n";
						} else {
							std::cout << scriptCmd + "\n";
						}
					} else {
						std::cout << scriptVar + "=true\n";
					}
				} else if (type == "option") {
					i++;
					arg = argv[i];
					if (scriptCmd != "") {
						string scriptCmdL=scriptCmd;
						boost::algorithm::to_lower(scriptCmdL);
						if (scriptCmdL == "maptoenv") {
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
// 11-16-2018 @ 15:15:20 - 1.0.9 - dscudiero - Add ability to specify script specific arguments
// 12-04-2018 @ 11:40:28 - 1.1.0 - dscudiero - Switch to read the default arguments from the data warehouse
// 02-27-2019 @ 11:05:58 - 1.1.5 - dscudiero - Tweak messaging
// 03-05-2019 @ 16:03:55 - 1.1.6 - dscudiero - Fix problem when emmiting argument that has a script command
