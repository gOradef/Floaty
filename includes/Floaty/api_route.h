#include "json/json.h"
#include "fstream"
#include "authentication.h"


Json::Value genTempClassesAsJson( const std::string &reqPath, const std::string& schoolId = "");
std::map<std::string, Json::Value> handlerGenMapOfEditNotes(const std::string &reqEdit);

crow::response writeEditNotesForm(std::map<std::string, Json::Value> &editNotesMap);
crow::response writeEditNotesInterface(std::map<std::string, Json::Value> &editNotesMap);

crow::response writeForEditNotesForm(std::string reqEdit);

// * mode: 1-form (names only) 0-interface (fullData);
crow::response getStaticFileJson(const crow::request &reqRoot, bool isShort = true);
crow::response handleCommonReq(const std::string &schoolId, bool isShort = true);
crow::response handleUserReq(const std::string& schoolId, const std::string& userDate, const std::string& period = "");
