#include "json/json.h"
#include "fstream"
#include "authentication.h"
//todo non full json


Json::Value genTempClassesAsJson( const std::string &reqPath);
std::map<std::string, Json::Value> genMapOfEditNotes(const std::string &reqEdit);

crow::response writeEditNotesOnCurrDate(std::map<std::string, Json::Value> &editNotesMap);
crow::response editClassesData(std::string reqEdit);
crow::response getStaticFileJson(const crow::request &reqRoot);
