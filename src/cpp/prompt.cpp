//==================================================================================================
// XO NOT AUTOVERSION
//==================================================================================================
// version="1.3.86" // -- dscudiero -- Thu 12/13/2018 @ 15:58:48
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
#include <boost/algorithm/string.hpp>
#include <toolsUtils.h>


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
		bool debug=false;
		string varName="";
		string promptText="";
		string validValues="";
		string defaultValue="";
		string sqlStmt="";
		string client="";
		bool prompt=true;
		if (env("verify") != "true") prompt=false;
		bool allowAbbrev=true;
		
	// Parse arguments
		string myName = argv[0];
		for(int i=1; i < argc; i++) {
			string arg = argv[i];
			if (arg.substr(0,1) != "-") {
				varName=arg;
			} else {
				string argl = arg; 
				transform(argl.begin(), argl.end(), argl.begin(), ::tolower);
				if (argl == "-debug") {
				    debug=true;
				} else if(argl == "-noprompt") {
				    prompt=false;
				} else if (argl.substr(1,1) == "p") {
					i++; promptText=argv[i];
				} else if (argl.substr(1,1) == "v") {
					i++; validValues=argv[i];
				} else if (argl.substr(1,1) == "d") {
					i++; defaultValue=argv[i];
				}
			}
		}
		if (debug) std::cout << "Starting " + myName + "'\n";
		if (debug) std::cout << "\tvarName = '" + varName + "'\n\tpromptText = '" + promptText + "'\n";
		if (debug) std::cout << "\tvalidValues = '" + validValues + "'\n\tdefaultValue = '" + defaultValue + "'\n";
		if (debug) std::cout << printf("\tprompt: %s\n",(prompt)?"true":"false");

		// If no varName was passed in the bug out
		if (prompt && varName == "") 
			throw std::invalid_argument("*Error* -- 'Prompt' called with no varName name"); 

		// Is verify off (i.e. prompting not allowed) and no default value was specified then bug out
		if (!prompt && defaultValue == "")
			throw std::invalid_argument("*Error* -- 'Prompt' called for varName '" + varName 
				+ "' but -noPrompt is active and no default value was passed in");

		// Is verify off (i.e. prompting not allowed) and we have a default value, just pass it back
		if (!prompt && defaultValue != "") {
			std::cout << varName + "=\"" + defaultValue + "\"\n";
			//return setenv(varName.c_str(),defaultValue.c_str(),1);
		}

		string ans="";
		string errorMsg="";
		bool valueOk=false;
		ans=env(varName.c_str());
		string varNameL = varName; transform(varNameL.begin(), varNameL.end(), varNameL.begin(), ::tolower);

		//==============================================================================================================
		// If prompting for data base type varName then connect to the warehouse
		//==============================================================================================================
		if (varNameL == "client" || varNameL == "env" || varNameL == "envs" || varNameL == "srcenv" 
			|| varNameL == "tgtenv" || varNameL == "product" || varNameL == "products") 
		{
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
			// database connection failed
			} catch ( FFError e ) {
	        	printf("%s\n",e.Label.c_str());
	        	return 1;
	    	}

	    	// Set validValues from data warehouse
			if (varNameL == "env" || varNameL == "envs" || varNameL == "srcenv" || varNameL == "tgtenv") {
				// Get valid envs from data warehouse
				sqlStmt="select distinct env from " + siteInfoTable 
						+ " where (name=\"" + env("client") + "\" or name like \"" + env("client") + "-test%\")" 
						+ " and env not in (\"" + env("srcEnv") + "\",\"" + env("tgtEnv") + "\")"
						+ "order by env";
				mysqlStatus = mysql_query( MySQLConnection, sqlStmt.c_str());
				if (mysqlStatus)
				    throw FFError( (char*)mysql_error(MySQLConnection) );
				else {
				    mysqlResult = mysql_store_result(MySQLConnection); // Get the Result Set
					numRows = mysql_num_rows(mysqlResult);
					if (numRows > 0) {
						list <string> validEnvs;
						while(mysqlRow = mysql_fetch_row(mysqlResult)) {
							validEnvs.push_front(mysqlRow[0]);
						}
						std::list<string>::iterator it;
						validValues="pvt";
						if (defaultValue == "") defaultValue = "pvt";
						for (it = validEnvs.begin(); it != validEnvs.end(); ++it) {
							string tmpStr = it->c_str();
							validValues += "," + tmpStr;
						}
					} else {
						errorMsg = "*Error* -- Asking for an 'env' type value and client (" + ans + ") has no site records, terminating";
						throw std::runtime_error(errorMsg);
						return -1;						
					}
				}
			} else if (varNameL == "product" || varNameL == "products") {
				allowAbbrev=false;
				// Get valid envs from data warehouse
				sqlStmt="select products from " + clientInfoTable + " where name=\"" + env("client") + "\"";
				mysqlStatus = mysql_query( MySQLConnection, sqlStmt.c_str());
				if (mysqlStatus)
				    throw FFError( (char*)mysql_error(MySQLConnection) );
				else {
				    mysqlResult = mysql_store_result(MySQLConnection); // Get the Result Set
					numRows = mysql_num_rows(mysqlResult);
					if (numRows > 0) {
						mysqlRow = mysql_fetch_row(mysqlResult);
						validValues = mysqlRow[0];
					} else {
						errorMsg = "*Error* -- Asking for an 'product' type value and client (" + ans + ") has no client records, terminating";
						throw std::runtime_error(errorMsg);
						return -1;						
					}
				}
			}
		} // client, env, or prod

		//==============================================================================================================
		// Loop until we get a valid value
		//==============================================================================================================
		while (!valueOk && prompt) {
			if (ans == "") {
				if (validValues == "") {
		    		cout << promptText + " ('x' to quit) > ";
				} else {
					//std::string validValuesStr = boost::replace_all(validValues, ",", ", ");
					std::string tmpStr = boost::replace_all_copy(validValues, ",", ", ");
		    		cout << promptText + " (" + tmpStr + ", or 'x' to quit) > ";
		    	}
				std::getline(std::cin, ans);
					if (ans == "" && defaultValue != "") { 
						ans = defaultValue;
					}
				string ansl = ans; transform(ansl.begin(), ansl.end(), ansl.begin(), ::tolower);
				if ( ansl == "x" || ansl == "exit") {
					string tmpStr="Goodbye x";
					write(3, tmpStr.c_str(), tmpStr.size());
					return 0;
				}
			}
			string ansl = ans; transform(ansl.begin(), ansl.end(), ansl.begin(), ::tolower);

			// Special processing for specific varNames
			// client
			if (varNameL == "client") {
				// Check client value against data warehouse 
				sqlStmt="select idx from " + clientInfoTable + ","+ siteInfoTable 
						+ " where " + clientInfoTable + ".name=" + siteInfoTable + ".name"
						+ " and " + siteInfoTable + ".host=\"" + hostName + "\""
						+ " and " + clientInfoTable + ".name=\"" + ansl + "\"";
				mysqlStatus = mysql_query( MySQLConnection, sqlStmt.c_str());
				if (mysqlStatus)
				    throw FFError( (char*)mysql_error(MySQLConnection) );
				else {
				    mysqlResult = mysql_store_result(MySQLConnection); // Get the Result Set
					numRows = mysql_num_rows(mysqlResult);
					if (numRows > 0) {
						valueOk=true;
					} else {
						errorMsg = "*Error* -- Client value specified (" + ans + ") not valid on this host, please try again";
					}
				}
			} else {
				if (validValues != "") {
					string validValuesl=validValues; transform(validValuesl.begin(), validValuesl.end(), validValuesl.begin(), ::tolower);			
					if (validValuesl == "*any*") {
						valueOk=true;
					} else if (validValuesl == "*dir*") {
						struct stat statbuf; 
						if (stat(ans.c_str(), &statbuf) != -1) {
						   if (S_ISDIR(statbuf.st_mode)) {
						      valueOk=true;
						   } else {
								errorMsg = "*Error* -- Invalid value specified, expecting a fully qualified directory name, please try again";
						   }
						}
					} else if (validValuesl == "*file*") {
						struct stat statbuf; 
						if (stat(ans.c_str(), &statbuf) != -1) {
						   if (S_ISREG(statbuf.st_mode) || S_ISLNK(statbuf.st_mode) ) {
						      valueOk=true;
						   } else {
								errorMsg = "*Error* -- Invalid value specified, expecting a fully qualified file name, please try again";
						   }
						}
					} else if (validValuesl == "*numeric*") {
						if (ans.find_first_not_of("0123456789") == string::npos) {
						      valueOk=true;
						   } else {
								errorMsg = "*Error* -- Invalid value specified, expecting a numeric, please try again";
						   }						
					} else if (validValuesl == "*alpha*") {
						if (ans.find_first_not_of("0123456789") != string::npos) {
						      valueOk=true;
						   } else {
								errorMsg = "*Error* -- Invalid value specified, expecting a alpha numeric, please try again";
						   }
					} else {
						std::vector<std::string> splittedStrings = split(validValuesl, ',');
						for(int i = 0; i < splittedStrings.size() ; i++) {
							string tmpStr=splittedStrings[i];
							if (allowAbbrev) {
								if (tmpStr.substr(0,ansl.size()) == ansl) {
									ans=tmpStr;
									valueOk=true;
									break;
								}								
							} else {
								if (tmpStr == ansl) {
									ans=tmpStr;
									valueOk=true;
									break;
								}
							}
						}
					}
				} else {
					valueOk=true;
				}				
			}
			if (!valueOk) {
				if (errorMsg == "") errorMsg = "*Error* -- Invalid value specified ('" + ans + "'), please try again";
				std::cout << "    " + errorMsg + "\n" << std::endl;
				errorMsg = "";
				ans = "";
			}

		} // while (!valueOk)

		//==============================================================================================================
		// Return the response data via file descriptor #3
		//==============================================================================================================
		if (!prompt && ans == "") {
			std::cout << "    *Warning* -- Requesting value for '" + varName + "' but -noPrompt is active\n" << std::endl;
		} else {
    		string tmpStr=varName + "=\"" + ans + "\"\n";
    		write(3, tmpStr.c_str(), tmpStr.size());
    	}

	return 0;
} // main
