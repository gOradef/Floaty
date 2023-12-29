#include "json/json.h"
#include "fstream"
#include "authentication.h"
//todo non full json
Json::Value genTempClassesAsJson( std::string &reqPath);
crow::response getStaticFileJson(std::string schoolId);
crow::response editClassesData(std::string reqEdit);