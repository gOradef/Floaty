// #include "../../includes/crow/http_request.h"
#include "../../includes/Floaty/login.h"
crow::response genToken(const crow::request &req, crow::response &res) {
    Json::Value root;
    Json::Reader reader;
    //* get json object from string req.body
    bool parsingSuccessful = reader.parse(req.body, root);
    if ( !parsingSuccessful )
    {
        return crow::response(501, "Failed to parse user data");
    }

    //* get data from json, if non req key => -1 
    Json::Value loginJ = root.get("login", "-1");
    Json::Value passwordJ = root.get("password", "-1");
    
    //* check IsValid format data
    if (loginJ.asString() == "-1" || passwordJ.asString() == "-1") return crow::response(401, "invalid ClientJson");

    //Todo get login and password from fstream in data_dir/num_dir/shoolData.json
    //* In progress..
    std::ifstream inputFile;
    inputFile.open("data/125/schoolData.json");
    
    std::stringstream buff;
    buff << inputFile.rdbuf();

    inputFile.close();
    
    Json::Value rootSchoolData;
    parsingSuccessful = reader.parse(buff.str(), rootSchoolData);

    if (!parsingSuccessful ) { return crow::response(501, "Failed to parse schooler data"); }
    
    if (root.empty()) { return crow::response(501, "Failed to parse school data"); }

    Json::Value corrLoginJ = rootSchoolData.get("login", "-1");
    Json::Value corrUserPassword = rootSchoolData.get("userPassword", "-1");
    Json::Value corrAdminPassword = rootSchoolData.get("adminPassword", "-1");

    //* check invalid data in schoolData json
    if (corrLoginJ.asString(), corrUserPassword.asString(), corrAdminPassword.asString() == "-1") {
        return crow::response(401, "invalid data in school json");
    }

    if (loginJ.asString() == corrLoginJ.asString() &&
     (passwordJ.asString() == corrUserPassword.asString() || 
        passwordJ.asString() == corrAdminPassword.asString())) {

        // Создание JSON Web Token
        auto token_builder = jwt::create();
        token_builder.set_issuer("my_app");
        token_builder.set_type("JWT");

        token_builder.set_expires_at(std::chrono::system_clock::now() + std::chrono::seconds(3600));
        
        //TODO - add dynamic generator of secret key using current date
        // * auto start = std::chrono::system_clock::now();
        // * std::time_t date = std::chrono::system_clock::to_time_t(start);
        // * return crow::response(200, std::ctime(&date));
        
        
        std::string secret_key = "date";
        token_builder.set_subject("user");
        std::string jwt = token_builder.sign(jwt::algorithm::hs256{std::string(secret_key)});
        
        // Формирование JSON-ответа с токеном
        rapidjson::StringBuffer sb;
        rapidjson::Writer<rapidjson::StringBuffer> writer(sb);
        writer.StartObject();
        writer.Key("token");
        writer.String(jwt.c_str());
        writer.EndObject();

        // auto tokenHere = jwt::decode(token_builder);
        

        // Отправка JSON-ответа с токеном пользователю
        return crow::response(sb.GetString());
    } else {
        // Пользователь не найден
        return crow::response(401);
    }
    }