#include "../../includes/crow/http_request.h"
#include "../../includes/crow/http_response.h"
#include "../../includes/rapidjson/writer.h"
#include "../../includes/rapidjson/stringbuffer.h"
#include "../../includes/rapidjson/reader.h"
#include "../../includes/jwt-cpp/jwt.h"
#include "../../includes/json/json.h"
#pragma once
std::string genToken(std::string loginStr = "");
crow::response genTokenAndSend(const crow::request &req);
crow::response getResponseAndGenJWT(const Json::Value &loginJ, const Json::Value &passwordJ,
                                    const Json::Value &corrLoginJ,const Json::Value &corrUserPassword,
                                    const Json::Value &corrAdminPassword);