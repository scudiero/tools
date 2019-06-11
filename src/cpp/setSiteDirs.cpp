//==================================================================================================
// XO NOT AUTOVERSION
//==================================================================================================
// version="1.6.22" // -- dscudiero -- Tue 06/11/2019 @ 10:09:54
//==================================================================================================
#include <stdlib.h>
#include <unistd.h>
#include <string>		// String utility library
#include <iostream>		// IO utility library
#include <algorithm>    // std::transform
#include <stdexcept>
#include <regex>
#include <sstream>
#include <sys/stat.h>
#include <mysql.h>
// #include <boost/algorithm/string.hpp>
#include <toolsUtils.h>
#include<bits/stdc++.h>

using namespace std;

//=================================================================================================================
// Prompt varName -p "promptText" -v "validValues" -d "defaultValue"
//
//
//
//
//=================================================================================================================
int main(int argc, char *argv[]) {

	// Program varNames
		bool debug=true;
		string client="";
		int verboseLevel=0;
		if (env("verboseLevel") != "")
			verboseLevel=atoi(env("verboseLevel").c_str());
		
	// Parse arguments
		string myName = argv[0];
		for(int i=1; i < argc; i++) {
			string arg = argv[i];
			if (arg.substr(0,1) != "-") {
				client=arg;
			} else {
				string argl = arg; 
				transform(argl.begin(), argl.end(), argl.begin(), ::tolower);
				if (argl.substr(1,1) == "v") {
				    verboseLevel=atoi(argl.substr(2,1).c_str());
				} else if (argl.substr(1,1) == "c") {
					i++; client=argv[i];
				}
			}
		}
		Debug(1,"\n*** Starting " + myName,verboseLevel);
		Dump(1,"\tclient",client,verboseLevel);
		Dump(1,"\tOS",getOsName(),verboseLevel);

		string sqlStmt="";
		if (getOsName() == "Unix") {
			sqlStmt = "select env,siteDir from " + siteInfoTable + " where (name=\"" + client + "\" or name=\"" + client + "-test\") and siteDir is not null";
		} else {
			sqlStmt = "select env,siteDirWindows from " + siteInfoTable + " where (name=\"" + client + "\" or name=\"" + client + "-test\") and siteDir is not null";
		}

		// Connect to the database
			MYSQL *MySQLConRet;
			MYSQL *MySQLConnection = NULL;
			MySQLConnection = mysql_init( NULL );
			try {
				MySQLConRet = mysql_real_connect(MySQLConnection, dbHost.c_str(), dbUser.c_str(), dbPw.c_str(), dbName.c_str(), 3306, NULL, 0);
				if ( MySQLConRet == NULL )
	            	throw FFError( (char*) mysql_error(MySQLConnection) );

			// database connection failed
			} catch ( FFError e ) {
				Dump(0,"\tMySQL Connection Info", mysql_get_host_info(MySQLConnection), verboseLevel);
				Dump(0,"\tMySQL Client Info", mysql_get_client_info(), verboseLevel);
				Dump(0,"\tMySQL Server Info", mysql_get_server_info(MySQLConnection), verboseLevel);
				Debug(0,"\tMySQL Error: " + e.Label, verboseLevel);
	        	return 1;
	    	}
	    // Run Query
	    	string siteDir="";
	    	Dump(2,"\tsqlStmt 1",sqlStmt,verboseLevel);
			mysqlStatus = mysql_query( MySQLConnection, sqlStmt.c_str());
			if (mysqlStatus)
			    throw FFError( (char*)mysql_error(MySQLConnection) );
			mysqlResult = mysql_store_result(MySQLConnection); // Get the Result Set
			if (mysqlResult) {
		            numRows = mysql_num_rows(mysqlResult);
					if (numRows > 0) {
						while(mysqlRow = mysql_fetch_row(mysqlResult)) {
							// Debug(2,"\t\tmysqlRow.length: " + mysqlRow.length().c_str(), verboseLevel);
				    		string env = mysqlRow[0];
				    		string siteDir = mysqlRow[1];

				    		Debug(2,"\t\tenv: " + env, verboseLevel);
				    		Debug(2,"\t\tsiteDir: " + siteDir, verboseLevel);

	 						string tmpStr = env + "Dir=\"" + siteDir + "\"\n";
	 						Debug(2,"\t\t\ttmpStr: " + tmpStr, verboseLevel);
			     			write(3, tmpStr.c_str(), tmpStr.size());
						}
					}
			} else {
				std::cout << "Could not retrieve siteDirs, sql = '\n" + sqlStmt +"'\n";
			   	return -1;
			}

		// Check to see if we have a pvt site, only on unix
		if (getOsName() == "Unix") {
			Debug(2,"\t\tenv: pvt", verboseLevel);
			// Get the dev servers
				std::string hostName = exec("/bin/hostname");
				hostName.erase(std::remove(hostName.begin(), hostName.end(), '\n'), hostName.end());
				std::vector<std::string> splittedStrings=split(hostName, '.');
				hostName=splittedStrings[0];

				// secondary envs to check created by 'cpclsite'
				std::vector <string> prodEnvsToCheck;
				prodEnvsToCheck.push_back("test");
				prodEnvsToCheck.push_back("next");

				// Can't seem to run second sql query so just set the devServer string based on the host name
				string devServers="";
				if (hostName == "build7") {
					devServers="dev7,dev6";
				} else if (hostName == "mojave") {
					devServers="dev6,dev11";
				}

			if (devServers != "") {
				string userName = exec("/usr/bin/logname");
				userName.erase(std::remove(userName.begin(), userName.end(), '\n'), userName.end());
				std::vector<std::string> splittedStrings=split(devServers, ',');
				for(int i = 0; i < splittedStrings.size() ; i++) {
					string server = splittedStrings[i];
					// Check for tools format pvt site
					string dir="/mnt/" + server + "/web/" + client + "-" + userName;
		    		Dump(2,"\t\tdir",dir,verboseLevel);
					struct stat statbuf; 
					if (stat(dir.c_str(), &statbuf) != -1) {
					   if (S_ISDIR(statbuf.st_mode)) {
	 						string tmpStr = "pvtDir=\"" + dir + "\"\n";
	 						Dump(2,"\t\t\ttmpStr",tmpStr,verboseLevel);
			     			write(3, tmpStr.c_str(), tmpStr.size());
			     			return 0;
					   }
					}					
					// Check for 'cplclsite' pvt site
    				for (int j=0; j<prodEnvsToCheck.size(); j++) {
    					string dir="/mnt/" + server + "/web/" + client + "-" + prodEnvsToCheck[j] + "-" + userName;
		    			Dump(2,"\t\tdir",dir,verboseLevel);
						struct stat statbuf; 
						if (stat(dir.c_str(), &statbuf) != -1) {
						   if (S_ISDIR(statbuf.st_mode)) {
		 						string tmpStr = "pvtDir=\"" + dir + "\"\n";
		 						Dump(2,"\t\t\ttmpStr",tmpStr,verboseLevel);
				     			write(3, tmpStr.c_str(), tmpStr.size());
				     			return 0;
						   }
						}
    				}
				}
			}
		} //(getOsName() == "Unix")

	return 0;
} // main
//=================================================================================================================
// Check-in log
//=================================================================================================================
// 01-29-2019 @ 11:28:24 - 1.5.88 - dscudiero - Remove extra '{'
// 03-06-2019 @ 08:13:18 - 1.5.93 - dscudiero - Add/Remove debug statements
// 03-06-2019 @ 08:28:23 - 1.5.94 - dscudiero - Removed extrea '/' leading the pvtDir setting
// 04-17-2019 @ 10:10:03 - 1.6.14 - dscudiero -  Fix to the code that finds the pvt directory, removed the sql query for devServers, seems like you can only do a single query in a program.
// 06-11-2019 @ 10:15:05 - 1.6.22 - dscudiero -  Update the logic that searches for the pvt site to also look for cpclsite syntax pvt sites
