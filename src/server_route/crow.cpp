#include "../../includes/Floaty.h"


#define CROW_STATIC_DIRECTORY "web/"
#define CROW_STATIC_ENDPOINT "web/"



class Server {
    static crow::SimpleApp app;
//    crow::mustache::context ctx;

    std::string getAdminKey(const std::string& reqPath) {
        std::string key;
        std::stringstream buff;
        Json::Reader jReader;
        Json::Value jKeyVal;
        std::ifstream ifstream;
        ifstream.open(reqPath);
        buff << ifstream.rdbuf();
        ifstream.close();
        jReader.parse(buff.str(), jKeyVal);
        return jKeyVal["superAdminKey"].asString();
    }
    void defineErrCodeOfCookie(const crow::request &req, crow::response &res) {
        if (req.get_header_value("Cookie").empty()) {
            res.moved("/login");
            return res.end();
        }
        else {
            switch(isValidCookie(req.get_header_value("Cookie"), req.url_params.get("schoolId"))) {
                case 200:
                    res.body = genWebPages("userForm").body;
                    return res.end();
                case 201:
                    if (req.url_params.get("key") != nullptr ) {
                        const std::string& reqPath = "data/" + std::string(req.url_params.get("schoolId")) + "/schoolData.json";
                        const std::string& corrKey = getAdminKey(reqPath);
                        if (std::string(corrKey) == std::string(req.url_params.get("key"))) {
                            res.body = genWebPages("userInterfaceConfig").body;
                        }
                        else {
                            res.body = genWebPages("userInterface").body;
                        }
                    }
                    else {
                        res.body = genWebPages("userInterface").body;
                    }
                    return res.end();
                case 401:
                    res.body = handleErrPage(401, "Undefined query string").body;
                    return res.end();
                case 402:
                    res.body = handleErrPage(402, "Failed verification").body;
                    return res.end();
                case 403:
                    res.body = handleErrPage(403,"Invalid token. Visit login page").body;
                    return res.end();
                case 404:
                    res.body = handleErrPage(404,"Invalid token. Visit login page").body;
                    return res.end();

                default:
                    res = handleErrPage(404);
                    return res.end();
            }
        }
    }

public:
    Server(std::string adress, int port) {
        app.bindaddr(adress)
            .port(port);

    }
    void initRoutes() {
        crow::mustache::set_global_base("web");

        CROW_ROUTE(app, "/interface")([this](const crow::request &req, crow::response &res) {
            return defineErrCodeOfCookie(req, res);
        });

        CROW_ROUTE(app, "/")([](const crow::request &req, crow::response &res) {
            res.moved("/home");
            return res.end();
        });

        //! Только для html
        CROW_ROUTE(app, "/<string>")
                ([](std::string file) {
                    if (file == "userForm" || file == "userInterface") return handleErrPage(0, "no access");
                    else return genWebPages(file);
                });

        //Region API
        CROW_ROUTE(app, "/api/form")
                .methods(crow::HTTPMethod::POST)
                        ([](const crow::request &req, crow::response &res) {
                            if (!req.get_header_value("Cookie").empty()) {
                                if (isValidCookie(req.get_header_value("Cookie"), req.get_header_value("schoolId")) == 200) {
                                    formReq client(req);
                                    res = client.doUserAction();
                                    return res.end();
                                } else {
                                    res = handleErrPage(401, "Verification [user] failed");
                                    res.end();
                                }
                            } else res = handleErrPage(401, "Ur cookie isnt defined. Visit login page");
                            return res.end();
                        });

        CROW_ROUTE(app, "/api/interface")
                .methods(crow::HTTPMethod::POST)
                        ([](const crow::request &req, crow::response &res) {
                            if (!req.get_header_value("Cookie").empty() && isValidCookie(req.get_header_value("Cookie"), req.get_header_value("schoolId")) == 201) {
//                                if (req.get_header_value("method") != "templateCase") {
//                                    interfaceReq client(req);
//                                    res = client.doUserAction();
//                                }
//                                else {
//                                    interfaceTempReq tempClient(req);
//                                    res = tempClient.doUserAction();
//                                }
                                interfaceBuilder clientBuilder;
                                auto client = clientBuilder.createInterface(req);
                                res = client->doUserAction();
                                return res.end();
                            }
                        });

        // * Response for login post req
        CROW_ROUTE(app, "/login-process")
                .methods("POST"_method)
                ([](const crow::request &req, crow::response &res) {
                    res = genTokenAndSend(req);
                    return res.end();
                });

        // * Response for resources of web
        CROW_ROUTE (app, "/<string>/<string>").methods(crow::HTTPMethod::GET)
                ([](const std::string &type, const std::string &file) {
                    return sendWebResoursesByRequest(type, file);
                });

        CROW_CATCHALL_ROUTE(app)([] {
            return handleErrPage(404);
        });
    }
    [[maybe_unused]]
    static void useSSL() {
        app
        .ssl_file("fullchain.pem", "privkey.pem");
    }
    static void run() {
        app
        .multithreaded()
        .run_async();
    }

};

crow::SimpleApp Server::app;
int main()
{
//    62.233.46.131
//    Server server("62.233.46.131", 443);
//    server.useSSL();
    Server server("127.0.0.1", 443);
    server.initRoutes();
    Server::run();
    return 0;
}
