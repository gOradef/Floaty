// #include "../../includes/crow/http_request.h"
#include "../../includes/Floaty/login.h"
//! TEMP REMOVE AFTER TEST INCLUDE
#include <json/json.h>

crow::response genToken(const crow::request &req, crow::response &res) {
    //* get login and password
    Json::Value root;
    Json::Reader reader;
    bool parsingSuccessful = reader.parse(req.body, root);     //parse process
    if ( !parsingSuccessful )
    {
        std::cout  << "Failed to parse"
               << reader.getFormattedErrorMessages();
        return crow::response(501, "Failed to parse user data");
    }
    
    Json::Value loginJ = root.get("login", "-1");
    Json::Value passwordJ = root.get("password", "-1");
    if (loginJ.asString() == "-1" || passwordJ.asString() == "-1") return crow::response(401, "invalid ClientJson");
    //Todo get login and password from fstream in data_dir/num_dir/shoolData.json
    if (loginJ.asString() == "125" && passwordJ.asString() == "Q125125") {

        // Создание JSON Web Token
        auto token_builder = jwt::create();
        token_builder.set_issuer("my_app");
        token_builder.set_type("JWT");
        //? token_builder.set_payload_claim("user_id", jwt::claim(std::string("login")));
        token_builder.set_expires_at(std::chrono::system_clock::now() + std::chrono::seconds(3600));
        std::string jwt = token_builder.sign(jwt::algorithm::hs256{std::string("secret_server_key")});
        
        // Формирование JSON-ответа с токеном
        rapidjson::StringBuffer sb;
        rapidjson::Writer<rapidjson::StringBuffer> writer(sb);
        writer.StartObject();
        writer.Key("token");
        writer.String(jwt.c_str());
        writer.EndObject();

        // Отправка JSON-ответа с токеном пользователю
        return crow::response(sb.GetString());
    } else {
        // Пользователь не найден
        return crow::response(401);
    }
    }