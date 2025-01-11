//
// Created by goradef on 11.01.2025.
//

// ConfigParser.cpp
#include "Floaty/ConfigParser.h"

ConfigParser::ConfigParser() {
    try {
        std::ifstream reader("config.json");

        std::stringstream raw_config;
        raw_config << reader.rdbuf();
        reader.close();
        config = crow::json::load(raw_config.str());

        // Initialize static members after loading the config
        jwt_secrets.ACCESS_SECRET = config["JWT_SECRETS"]["access"].s();
        jwt_secrets.REFRESH_SECRET = config["JWT_SECRETS"]["refresh"].s();

        web.isMultithreaded = config["CONFIG"]["WEB"]["isMultithreaded"].b();
        web.isRunAsync = config["CONFIG"]["WEB"]["isRunAsync"].b();
        web.isUseSSL = config["CONFIG"]["WEB"]["isUseSSL"].b();

        postgresql.connection_amount = config["CONFIG"]["POSTGRES"]["connections_amount"].i();
    }
    catch (const std::exception &e) {
        std::cerr << "ConfigParser err: " << e.what() << '\n';
        throw e;
    }
}

std::string ConfigParser::getPostgresCredentials() const {
    const auto& db_creds = config["DATABASE_CREDS"];
    std::string result;
    for (const auto& key : db_creds.keys()) {
        result += key + " = " + std::string(db_creds[key].s()) + " ";
    }
    return result;
}