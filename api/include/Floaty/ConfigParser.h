//
// Created by goradef on 11.01.2025.
//

#ifndef CONFIGPARSER_H
#define CONFIGPARSER_H

#include <crow/json.h>
#include <string>
#include <fstream>

class ConfigParser {
public:
    crow::json::rvalue config;

    ConfigParser();

    std::string getPostgresCredentials() const;

    struct jwt_secrets {
        std::string ACCESS_SECRET;
        std::string REFRESH_SECRET;
    };

    struct web {
        bool isMultithreaded;
        bool isRunAsync;
        bool isUseSSL;
    };

    struct postgresql {
        int connection_amount;
    };

    jwt_secrets jwt_secrets{};
    web web{};
    postgresql postgresql;
};

#endif // CONFIGPARSER_H
