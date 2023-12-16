#include "../../includes/crow/http_request.h"
#include "../../includes/crow/http_response.h"
#include "../../includes/rapidjson/writer.h"
#include "../../includes/rapidjson/stringbuffer.h"
#include "../../includes/rapidjson/reader.h"
#include "../../includes/jwt-cpp/jwt.h"
#include "../../includes/json/json.h"
// #include "../../includes/jwt-cpp/base.h"
// #include <jdbc/cppconn/connection.h>
// #include <jdbc/cppconn/driver.h>
// #include <jdbc/cppconn/exception.h>
// #include <jdbc/cppconn/prepared_statement.h>
#pragma once
std::string genToken(const std::string userLogin = "");
crow::response genTokenAndSend(const crow::request &req, crow::response &res);