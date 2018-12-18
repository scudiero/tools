//==================================================================================================
// XO NOT AUTOVERSION
//==================================================================================================
// version="1.0.14" // -- dscudiero -- Tue 12/18/2018 @ 17:00:03
//==================================================================================================
#include <stdlib.h>
#include <string>		// String utility library
#include <iostream>		// IO utility library
#include <algorithm>    // std::transform
#include <stdexcept>
#include <boost/algorithm/string.hpp> 
#include <mysql.h>
#include <toolsUtils.h>

// class FFError {
// public:
//     std::string Label;
//     FFError() { Label = (char *)"Generic Error";}
//     FFError(char *message ) {Label = message;}
//     ~FFError() { }
//     inline const char* GetMessage  (void)   {return Label.c_str();}
// };

using namespace std;

//==================================================================================================
// Utilities
//==================================================================================================
// void here(string where) { std::cout << "Here: " + where + "\n"; return; }
// void here(int where) { printf("Here: %d\n", where); return;}
// void here(string where, bool debug) { if (debug) std::cout << "Here: " + where + "\n"; return; }
// void here(int where, bool debug) { if (debug) printf("Here: %d\n", where); return; }
// void dump(string var, string val) { printf("%s = '%s'\n", var.c_str(),val.c_str()); return; }
// void dump(string var, string val, bool debug) { if (debug) printf("%s = '%s'\n", var.c_str(),val.c_str()); return; }
// void dump(string var, int val) { printf("%s = '%d'\n", var.c_str(),val); return; }
// void dump(string var, int val, bool debug) { if (debug) printf("%s = '%d'\n", var.c_str(),val); return; }

// std::string env(const char *name) {
// 	const char *ret = getenv(name);
//     if (!ret) return std::string();
//     return std::string(ret);
// }


//=================================================================================================================
// Load tools defaults data from the defaults table in the data warehouse
//
// Usage: toolsSetDefaults [variable]
//	If [variable] is passed then it is taken to be a script name, in that case the scriptData variables will also
//	be set from the scripts table in the data warehouse.  If the value of the script variable has the form 'name:value'
//	then a variable called 'name' will also be created
//
// Sends assignment strings back to the caller (e.g. variableName="variableValue")
//=================================================================================================================
int main(int argc, char *argv[]) {

	// Data warehouse constants
		string dbHost="mdb1-host.inside.leepfrog.com";
		string dbName="courseleafdatawarehouse";
		string dbUser="leepfrogRead";
		string dbPw="v721-!PP9b";

	// Program variables
		bool debug=false;
		string scriptName="";
		int verboseLevel=0;
		if (env("verboseLevel") != "")
			verboseLevel=atoi(env("verboseLevel").c_str());

		std::string hostName = exec("/bin/hostname");
		hostName.erase(std::remove(hostName.begin(), hostName.end(), '\n'), hostName.end());
		std::vector<std::string> splittedStrings=split(hostName, '.');
		hostName=splittedStrings[0];

	// Parse arguments
		string myName = argv[0];
		for(int i=1; i < argc; i++) {
			string arg = argv[i];
			if (arg.substr(0,1) != "-") {
				scriptName=arg;
			} else {
				string argl = arg; 
				transform(argl.begin(), argl.end(), argl.begin(), ::tolower);
				if (argl.substr(1,1) == "v") {
				    verboseLevel=atoi(argl.substr(2,1).c_str());
				    if (verboseLevel > 0) debug=true;
				// } else if (argl.substr(1,1) == "c") {
				// 	i++; client=argv[i];
				}
			}
		}
		
		if (verboseLevel > 0) std::cout << "*** Starting " + myName + "'\n";
		if (verboseLevel > 0) std::cout << "\tscriptName = '" + scriptName + "'\n";
		if (verboseLevel > 0) std::cout << "\thostName = '" + hostName + "'\n";
		if (verboseLevel > 0) printf("\tverboseLevel = %d\n",verboseLevel);
		
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
            if (verboseLevel > 0) {
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
			// Get the tools level defaults
				if (verboseLevel > 0) std::cout << "Retrieving tools defaults data...";
				string sqlStmt="select name,value from defaults where host=\"" + hostName + "\" or host is null and status = \"A\" order by name"; 
				mysqlStatus = mysql_query( MySQLConnection, sqlStmt.c_str());
				if (mysqlStatus)
				    throw FFError( (char*)mysql_error(MySQLConnection) );
				else
				    mysqlResult = mysql_store_result(MySQLConnection); // Get the Result Set
				if (mysqlResult) {
		            // see if this user is authorized in the user2script table
		            numRows = mysql_num_rows(mysqlResult);
					if (numRows > 0) {
						while(mysqlRow = mysql_fetch_row(mysqlResult)) {
							string variable = mysqlRow[0];
							string value = mysqlRow[1];
							if (verboseLevel > 0) printf("\t variable: '%s', \t value: '%s'\n", variable.c_str(),value.c_str());
							std::cout << variable + "=\"" + value + "\"\n";
						}
					}
				}
			// Get the script level defaults
				if (scriptName != "") {
					string fields="scriptData1,scriptData2,scriptData3,scriptData4,scriptData5,ignoreList,allowList,emailAddrs";
					string sqlStmt="select " + fields + " from scripts where name=\"" + scriptName + "\"";
					dump("sqlStmt",sqlStmt,debug);
					mysqlStatus = mysql_query( MySQLConnection, sqlStmt.c_str());
					if (mysqlStatus)
					    throw FFError( (char*)mysql_error(MySQLConnection) );
					else
						mysqlResult = mysql_store_result(MySQLConnection); // Get the Result Set
						if (mysqlResult) {
				            // see if this user is authorized in the user2script table
				            numRows = mysql_num_rows(mysqlResult);
							if (numRows > 0) {
								while(mysqlRow = mysql_fetch_row(mysqlResult)) {
									string scriptData1="", scriptData2="", scriptData3="", scriptData4="", scriptData5="";
									string ignoreList="", allowList="", emailAddrs="";
									int loc=0;

									if (mysqlRow[0] != NULL) scriptData1 = mysqlRow[0];
									dump("scriptData1",scriptData1,debug);
									loc = scriptData1.find(":",0);
									if (loc > 0)
										std::cout << scriptData1.substr(0,loc) + "=\"" + scriptData1.substr(loc+1) + "\"\n";
									std::cout << "scriptData1=\"" + scriptData1 + "\"\n";

									if (mysqlRow[1] != NULL) scriptData2 = mysqlRow[1];
									dump("scriptData2",scriptData2,debug);
									loc = scriptData2.find(":",0);
									if (loc > 0)
										std::cout << scriptData2.substr(0,loc) + "=\"" + scriptData2.substr(loc+1) + "\"\n";
									std::cout << "scriptData2=\"" + scriptData2 + "\"\n";

									if (mysqlRow[2] != NULL) scriptData3 = mysqlRow[2];
									dump("scriptData3",scriptData3,debug);
									loc = scriptData3.find(":",0);
									if (loc > 0)
										std::cout << scriptData3.substr(0,loc) + "=\"" + scriptData3.substr(loc+1) + "\"\n";
									std::cout << "scriptData3=\"" + scriptData3 + "\"\n";

									if (mysqlRow[3] != NULL) scriptData4 = mysqlRow[3];
									dump("scriptData4",scriptData4,debug);
									loc = scriptData4.find(":",0);
									if (loc > 0)
										std::cout << scriptData4.substr(0,loc) + "=\"" + scriptData4.substr(loc+1) + "\"\n";
									std::cout << "scriptData4=\"" + scriptData4 + "\"\n";

									if (mysqlRow[4] != NULL) scriptData5 = mysqlRow[4];
									dump("scriptData5",scriptData5,debug);
									loc = scriptData5.find(":",0);
									if (loc > 0)
										std::cout << scriptData5.substr(0,loc) + "=\"" + scriptData5.substr(loc+1) + "\"\n";
									std::cout << "scriptData5=\"" + scriptData5 + "\"\n";

									if (mysqlRow[5] != NULL) ignoreList = mysqlRow[5];
									dump("ignoreList",ignoreList,debug);
									loc = ignoreList.find(":",0);
									if (loc > 0)
										std::cout << ignoreList.substr(0,loc) + "=\"" + ignoreList.substr(loc+1) + "\"\n";
									std::cout << "ignoreList=\"" + ignoreList + "\"\n";

									if (mysqlRow[6] != NULL) allowList = mysqlRow[6];
									dump("allowList",allowList,debug);
									loc = allowList.find(":",0);
									if (loc > 0)
										std::cout << allowList.substr(0,loc) + "=\"" + allowList.substr(loc+1) + "\"\n";
									std::cout << "allowList=\"" + allowList + "\"\n";

									if (mysqlRow[7] != NULL) allowList = mysqlRow[6];
									dump("emailAddrs",emailAddrs,debug);
									loc = emailAddrs.find(":",0);
									if (loc > 0)
										std::cout << emailAddrs.substr(0,loc) + "=\"" + emailAddrs.substr(loc+1) + "\"\n";
									std::cout << "emailAddrs=\"" + emailAddrs + "\"\n";
								}
							}
						}

				}


		// database connection failed
		} catch ( FFError e ) {
        	printf("%s\n",e.Label.c_str());
        	return 1;
    	}

	return 0;
} // main
// 12-12-2018 @ 12:17:11 - 1.0.2 - dscudiero - Cosmetic/minor change/Sync
// 12-18-2018 @ 15:28:20 - 1.0.3 - dscudiero - Cosmetic/minor change/Sync
// 12-18-2018 @ 16:20:10 - 1.0.4 - dscudiero - Cosmetic/minor change/Sync
// 12-18-2018 @ 17:03:34 - 1.0.14 - dscudiero - Re-factor getting the hostName
