
//==================================================================================================
// Utilities
//==================================================================================================
void Here(std::string where, bool debug) { if (debug) std::cout << "Here: " + where + "\n"; return; }
void here(std::string where, bool debug) { if (debug) std::cout << "Here: " + where + "\n"; return; }
void Here(std::string where) { std::cout << "Here: " + where + "\n"; return; }
void here(std::string where) { std::cout << "Here: " + where + "\n"; return; }
void Here(int where, bool debug) { if (debug) printf("Here: %d\n", where); return; }
void here(int where, bool debug) { if (debug) printf("Here: %d\n", where); return; }
void Here(int where) { printf("Here: %d\n", where); return; }
void here(int where) { printf("Here: %d\n", where); return; }

void Dump(std::string var, std::string val, bool debug) { if (debug) printf("%s = '%s'\n", var.c_str(),val.c_str()); return; }
void dump(std::string var, std::string val, bool debug) { if (debug) printf("%s = '%s'\n", var.c_str(),val.c_str()); return; }
void Dump(std::string var, std::string val) { printf("%s = '%s'\n", var.c_str(),val.c_str()); return; }
void dump(std::string var, std::string val) { printf("%s = '%s'\n", var.c_str(),val.c_str()); return; }
void Dump(std::string var, int val, bool debug) { if (debug) printf("%s = '%d'\n", var.c_str(),val); return; }
void dump(std::string var, int val, bool debug) { if (debug) printf("%s = '%d'\n", var.c_str(),val); return; }
void Dump(std::string var, int val) { printf("%s = '%d'\n", var.c_str(),val); return; }
void dump(std::string var, int val) { printf("%s = '%d'\n", var.c_str(),val); return; }

//==================================================================================================
// Get an environment variable taking into account the variable may not be defined
//==================================================================================================
std::string env(const char *name) {
	const char *ret = getenv(name);
    if (!ret) return std::string();
    return std::string(ret);
};

//==================================================================================================
// Split a string on a delimiter, returns an array (vector)
//==================================================================================================
std::vector<std::string> split(std::string strToSplit, char delimeter) {
    std::stringstream ss(strToSplit);
    std::string item;
    std::vector<std::string> splittedStrings;
    while (std::getline(ss, item, delimeter)) {
       splittedStrings.push_back(item);
    }
    return splittedStrings;
};

//==================================================================================================
// Run a system command and grab stdout into a variable
//==================================================================================================
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

//==================================================================================================
// Error processing for mysql connect errors
//==================================================================================================
class FFError {
    public:
        std::string Label;
        FFError() { Label = (char *)"Generic Error";}
        FFError(char *message ) {Label = message;}
        ~FFError() { }
        inline const char* GetMessage  (void)   {return Label.c_str();}
};


// //==================================================================================================
// // Run sql query
// // Usage <MySQLConnection> <sqlStmt>
// // Returns a list of strings
// //==================================================================================================
// std::list <std::string> runSql(connection* connectStr, std::string sqlStmt) {

//     mysqlStatus = mysql_query(MySQLConnection, sqlStmt.c_str());
//     if (mysqlStatus)
//         throw FFError( (char*)mysql_error(MySQLConnection) );
//     else {
//         mysqlResult = mysql_store_result(MySQLConnection); // Get the Result Set
//         numRows = mysql_num_rows(mysqlResult);
//         if (numRows > 0) {
//             while(mysqlRow = mysql_fetch_row(mysqlResult)) {
//                 validEnvs.push_front(mysqlRow[0]);
//             }
//             std::list<string>::iterator it;
//             for (it = validEnvs.begin(); it != validEnvs.end(); ++it) {
//                 string tmpStr = it->c_str();
//                 if (tmpStr.substr(0,ansl.size()) == ansl) {
//                     ans=tmpStr;
//                     valueOk=true;
//                 }
//             }
//         } else {
//             errorMsg = "*Error* -- Client (" + ans + ") has no site records, please try again";
//             throw std::runtime_error(errorMsg);
//             return -1;                      
//         }
//     }
// }

//==================================================================================================
// Data warehouse constants
//==================================================================================================
std::string dbHost="mdb1-host.inside.leepfrog.com";
std::string dbName="courseleafdatawarehouse";
std::string dbUser="leepfrogRead";
std::string dbPw="v721-!PP9b";

std::string clientInfoTable="clients";
std::string siteInfoTable="sites";
std::string scriptsTable="scripts";

MYSQL *MySQLConRet;
MYSQL *MySQLConnection = NULL;
MYSQL_RES *mysqlResult = NULL;
MYSQL_ROW mysqlRow;
MYSQL_FIELD *mysqlFields;

int mysqlStatus = 0;
my_ulonglong numRows;
unsigned int numFields;