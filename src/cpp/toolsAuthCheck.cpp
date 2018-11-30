//==================================================================================================
// XO NOT AUTOVERSION
//==================================================================================================
// version="1.0.2" // -- dscudiero -- Fri 11/30/2018 @ 09:46:33
//==================================================================================================
// tools -- Check if the user is authorized to run a particular script
// Usage toolsAuthCheck scriptName <options>
//	scriptName 	- The name of the script to check
//	options		- '-d' -- turn on debug statements
// Returns
//	0 if user is authorized
//	anything else indicates that the user is not authorized
//==================================================================================================
#include <stdlib.h>
#include <string>		// String utility library
#include <iostream>		// IO utility library
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

std::string exec(const char* cmd) {
    std::array<char, 128> buffer;
    std::string result;
    std::unique_ptr<FILE, decltype(&pclose)> pipe(popen(cmd, "r"), pclose);
    if (!pipe) throw std::runtime_error("popen() failed!");
    while (fgets(buffer.data(), buffer.size(), pipe.get()) != NULL) {
        result += buffer.data();
    }
    return result;
}

// //=================================================================================================================
int main(int argc, char *argv[], char **envVarPtr) {

	// Constants
		string dbHost="mdb1-host.inside.leepfrog.com";
		string dbName="courseleafdatawarehouse";
		string dbUser="leepfrogRead";
		string dbPw="v721-!PP9b";

	// Program variables
		bool debug=false;
		string scriptName="";
		string employeeKey="";
		string scriptKey="";
		string sqlStmt="";
		bool foundUserInAuth2user=false;
		bool foundScriptInUser2script=false;
		bool foundScriptInAuth2script=false;

	// Parse arguments
		char* myName = argv[0];
		for(int i=1; i < argc; i++) {
			string arg = argv[i];
			string argl = arg; boost::algorithm::to_lower(argl);
			if (arg.substr(0,1) != "-") {
				scriptName = arg;
				continue;
			} else {
				if (argl == "-d")
		    		debug=true;
			}
		}
		if (debug) std::cout << "\t scriptName = '" + scriptName +"'\n";
		if (scriptName == "") return 0;  // script not registered so allow execution

	// Get the logged in username
		string userName = exec("/usr/bin/logname");
		userName.erase(std::remove(userName.begin(), userName.end(), '\n'), userName.end());
		if (debug) std::cout << "\t userName = '" + userName +"'\n";

		string userNameEnv = getenv("LOGNAME");
		if (debug) std::cout << "\t userNameEnv = '" + userNameEnv +"'\n";
		// Check for spoofing
		if (userName != userNameEnv) {
			std::cout << "*Error* -- LOGNAME environment value not equal to the output of the logname command\n";
			return -1;
		}

	// Connect to the database
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

			// Get scriptKey
				sqlStmt="select keyId from scripts where name=\"" + scriptName + "\"";
				mysqlStatus = mysql_query( MySQLConnection, sqlStmt.c_str());
				if (mysqlStatus)
				    throw FFError( (char*)mysql_error(MySQLConnection) );
				else
				    mysqlResult = mysql_store_result(MySQLConnection); // Get the Result Set

				if (mysqlResult) {
					scriptKey = mysql_fetch_row(mysqlResult)[0];
				} else {
					std::cout << "Could not retrieve auth groups, sql = '\n" + sqlStmt +"'\n";
				   	return -1;
				}
				if (debug) std::cout << "\t scriptKey = '" + scriptKey +"'\n";

			// Get employeeKey
				sqlStmt="select employeekey from employee where userid=\"" + userName + "\"";
				mysqlStatus = mysql_query( MySQLConnection, sqlStmt.c_str());
				if (mysqlStatus)
				    throw FFError( (char*)mysql_error(MySQLConnection) );
				else
				    mysqlResult = mysql_store_result(MySQLConnection); // Get the Result Set

				if (mysqlResult) {
					employeeKey = mysql_fetch_row(mysqlResult)[0];
				} else {
					std::cout << "Could not retrieve auth groups, sql = '\n" + sqlStmt +"'\n";
				   	return -1;
				}
				if (debug) std::cout << "\t employeeKey = '" + employeeKey +"'\n";

			// Get the auth groups this user is in
				list <string> usersAuthGroups;
				sqlStmt="select authKey from auth2user where empKey=" + employeeKey;
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
							if (debug) printf("\t authKey: '%s'\n", mysqlRow[0]);
							usersAuthGroups.push_back(mysqlRow[0]);
						}
						foundUserInAuth2user=true;
					}
				} else {
					std::cout << "Could not retrieve auth groups, sql = '\n" + sqlStmt +"'\n";
				   	return -1;
				}
				if (debug) printf("\t foundUserInAuth2user = %d\n", foundUserInAuth2user);

			// Check to see if the script is in the user2Script table for this user
				sqlStmt="select empkey from user2script where scriptKey=" + scriptKey;
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
							if (debug) printf("\t EmpKey: '%s'\n", mysqlRow[0]);
							if (mysqlRow[0] == employeeKey) {
								if (debug) std::cout << "\t*** Users authorized to the script in user2script\n";
								return 0;
							}
						}
						foundScriptInUser2script=true;
					}
				}
				if (debug) printf("\t foundScriptInUser2script = %d\n", foundScriptInUser2script);

			// Check to see if the script is in the auth2Script table
				sqlStmt="select groupKey from auth2script where scriptKey=" + scriptKey;
				mysqlStatus = mysql_query( MySQLConnection, sqlStmt.c_str());
				if (mysqlStatus)
				    throw FFError( (char*)mysql_error(MySQLConnection) );
				else
				    mysqlResult = mysql_store_result(MySQLConnection); // Get the Result Set
				if (mysqlResult) {
		            // See if the script is in a auth group that the user is in
		            numRows = mysql_num_rows(mysqlResult);
					if (numRows > 0) {
						while(mysqlRow = mysql_fetch_row(mysqlResult)) {
							if (debug) printf("\t GroupKey: '%s'\n", mysqlRow[0]);
							// See if the user is in one of the groups
							if (usersAuthGroups.size() > 0) {
								std::list<string>::iterator it;
								for (it = usersAuthGroups.begin(); it != usersAuthGroups.end(); ++it) {
									string tmpStr = it->c_str();
									if (tmpStr == mysqlRow[0]) {
										if (debug) std::cout << "\t*** Script authorized to one of the users groups\n";
										return 0;
									}
								}
							}
						}
						foundScriptInAuth2script=true;
					}
				}
				if (debug) printf("\t foundScriptInAuth2script = %d\n", foundScriptInAuth2script);

			// If script is not controlled then allow
				if (!foundScriptInAuth2script && !foundScriptInUser2script) {
					if (debug) std::cout << "\t*** Script not controlled\n";
					return 0;
				}
		// database connection failed
		} catch ( FFError e ) {
        	printf("%s\n",e.Label.c_str());
        	return 1;
    	}

	 return 0;
} // main
// 11-30-2018 @ 09:45:36 - 1.0.1 - dscudiero - Testing
// 11-30-2018 @ 09:46:46 - 1.0.2 - dscudiero - Cosmetic/minor change/Sync
