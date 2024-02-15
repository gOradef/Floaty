#include "json/json.h"
#include "fstream"
#include "authentication.h"


Json::Value genTempClassesAsJson( const std::string &reqPath, const std::string& schoolId = "");
std::map<std::string, Json::Value> handlerGenMapOfEditNotes(const std::string &reqEdit,
                                                            const bool& isForm = true,
                                                            const std::string& schoolIdReq = "",
                                                            const std::string& userCase = "",
                                                            const std::string& userCustomDate = "");

crow::response writeEditNotesForm(std::map<std::string, Json::Value> &editNotesMap);

crow::response writeForEditNotesForm(std::string reqEdit);

// * mode: 1-form (names only) 0-interface (fullData);
crow::response getStaticFileJson(const crow::request &reqRoot, bool isShort = true);
crow::response handleCommonReq(const std::string &schoolId, bool isShort = true);
crow::response handleUserReq(const std::string& schoolId, const std::string& userDate, const std::string& period = "");
//gets template as json and send to user res/s
crow::response getTemplateDataInterface(Json::Reader &reader, const Json::Value &reqJ, const std::string &schoolId);

