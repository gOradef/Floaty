#include <ctime>
#include "../../includes/Floaty/authentication.h"



// * returns secret for jwt <y.m.d.>.<loginStr>ls

std::string genToken(const std::string& loginStr) {
        time_t now;
        time(&now);
        struct tm ltm;
        localtime_r(&now, &ltm);
        std::string dynamicDate{std::to_string(1900 + ltm.tm_year) + '.' +  std::to_string(ltm.tm_mon+1) + '.' + std::to_string(ltm.tm_mday)};
        std::string secret = dynamicDate + '.' + loginStr;
        return secret;
}
crow::response getResponseAndGenJWT(const Json::Value &loginJ, const Json::Value &passwordJ, const Json::Value &corrLoginJ,
                                    const Json::Value &corrUserPassword, const Json::Value &corrAdminPassword) {
    bool state;
    if (passwordJ.asString() == corrUserPassword.asString()) {state = false;}
    if (passwordJ.asString() == corrAdminPassword.asString()) {state = true;}

    // Создание JSON Web Token
    if(state == 0) {
        auto token_builder = jwt::create();
        token_builder.set_issuer("FloatyCook");
        token_builder.set_type("JWT");
        token_builder.set_expires_at(std::chrono::system_clock::now() + std::chrono::seconds(3600));
        token_builder.set_id(genToken(corrLoginJ.asString()));
        token_builder.set_subject("userToken");

        std::string secret_key = "super-mega-giga-kilo-long-secret";
        std::string jwt = token_builder.sign(jwt::algorithm::hs256{std::string(secret_key)});

        // Формирование JSON-ответа с токеном
        rapidjson::StringBuffer sb;
        rapidjson::Writer<rapidjson::StringBuffer> writer(sb);
        writer.StartObject();
        writer.Key("token");
        writer.String(jwt.c_str());
        writer.Key("schoolId");
        writer.String(loginJ.asCString());
        writer.EndObject();
        return crow::response(sb.GetString());
    }
    else if (state == 1) {
        auto token_builder = jwt::create();
        token_builder.set_issuer("FloatyCook");
        token_builder.set_type("JWT");
        token_builder.set_expires_at(std::chrono::system_clock::now() + std::chrono::seconds(3600));
        token_builder.set_id(genToken(corrLoginJ.asString()));
        token_builder.set_subject("adminToken");

        std::string secret_key = "super-mega-giga-kilo-long-secret";
        std::string jwt = token_builder.sign(jwt::algorithm::hs256{ std::string(secret_key) });

        // Формирование JSON-ответа с токеном
        rapidjson::StringBuffer sb;
        rapidjson::Writer<rapidjson::StringBuffer> writer(sb);
        writer.StartObject();
        writer.Key("token");
        writer.String(jwt.c_str());
        writer.Key("schoolId");
        writer.String(loginJ.asCString());
        writer.EndObject();
        return crow::response(sb.GetString());
    }
        // Отправка JSON-ответа с токеном пользователю
    else return crow::response(599, "impossible");
}
crow::response genTokenAndSend(const crow::request &req) {
    Json::Value userReq;
    Json::Reader reader;
    //* get json object from string req.body
    bool parsingSuccessful = reader.parse(req.body, userReq);
    if ( !parsingSuccessful )
    {
        return crow::response(501, "Failed to parse user data");
    }

    //* get data from json, if non => req key = -1
    Json::Value loginJ = userReq.get("login", "-1");
    Json::Value passwordJ = userReq.get("password", "-1");

    //* check IsValid format data
    if (loginJ.asString() == "-1" || passwordJ.asString() == "-1") return crow::response(401, "invalid ClientJson");

    std::ifstream inputFile;

    try {
        inputFile.open("data/" + loginJ.asString() +"/schoolData.json");
    }
    catch(std::exception &e) {
        return crow::response(500, e.what());
    }
    std::stringstream buff;
    buff << inputFile.rdbuf();

    inputFile.close();

    Json::Value rootSchoolData;
    parsingSuccessful = reader.parse(buff.str(), rootSchoolData);

    if (!parsingSuccessful) return crow::response(401, "Failed to parse schooler data");
    if (rootSchoolData.empty()) return crow::response(501, "Failed to parse school data");

    Json::Value corrLoginJ = rootSchoolData.get("login", "-1");
    Json::Value corrUserPassword = rootSchoolData.get("userPassword", "-1");
    Json::Value corrAdminPassword = rootSchoolData.get("adminPassword", "-1");

    //* check invalid data in schoolData json
    if (corrLoginJ.asString(), corrUserPassword.asString(), corrAdminPassword.asString() == "-1") {
        return crow::response(401, "invalid data in school json");
    }

    if (loginJ.asString() == corrLoginJ.asString() && (
            passwordJ.asString() == corrUserPassword.asString() ||
            passwordJ.asString() == corrAdminPassword.asString()
            )
            ) {
        return getResponseAndGenJWT(loginJ, passwordJ, corrLoginJ, corrUserPassword, corrAdminPassword);
    }
    else {
        // Пользователь не найден
        return crow::response(401);
    }
}


