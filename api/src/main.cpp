#include "Floaty.h"

#include "Floaty/ConfigParser.h"

ConfigParser config_parser;

const std::string& Server::_jwtAccessSecret = config_parser.jwt_secrets.ACCESS_SECRET;
const std::string& Server::_jwtRefreshSecret = config_parser.jwt_secrets.REFRESH_SECRET;


inline void Server::useSSL() {
    app
        .ssl_file("fullchain.pem",
            "privkey.pem");
}

inline void Server::run() {
    if (config_parser.web.isMultithreaded)
        app.multithreaded();

    if(config_parser.web.isRunAsync)
        app.run_async();

    if (config_parser.web.isUseSSL)
        Server::useSSL();

    app.run();
}


int main() {
    // Use std::ostringstream for better string concatenation
    std::ostringstream oss;
    oss << "===== STATUS =====\n"
        << "# CROW #\n"
        << "Multithreaded: " << (config_parser.web.isMultithreaded ? "Enabled" : "Disabled") << "\n"
        << "Async: " << (config_parser.web.isRunAsync ? "Enabled" : "Disabled") << "\n"
        << "SSL: " << (config_parser.web.isUseSSL ? "Enabled" : "Disabled") << "\n"
        << "# Postgresql #\n"
        << "Connections: " << config_parser.postgresql.connection_amount << "\n";

    const std::string status = oss.str();
    std::cout << status;


    const std::string& postgres_creds = config_parser.getPostgresCredentials();

    ConnectionPool cp(postgres_creds, config_parser.postgresql.connection_amount);

    // DataChangesLogger customLogger;
    // crow::logger::setHandler(&customLogger);


    Server("127.0.0.1", 18080, &cp);
    Server::initRoutes();
    Server::run();
    return 0;
}
