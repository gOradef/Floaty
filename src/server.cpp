#include "Floaty.h"
#include "pqxx/pqxx"

#include "openssl/sha.h"
#define CROW_STATIC_DIRECTORY "web/"
#define CROW_STATIC_ENDPOINT "web/"

class Server {
    static crow::SimpleApp app;
    static ConnectionPool* _connectionPool;
//    crow::mustache::context ctx;

    static bool isValidJWT(const std::string& userjwt) {
        jwt::decoded_jwt decodedJwt = jwt::decode(userjwt);

        std::string user_id_encoded = decodedJwt.get_subject();
        std::string school_id_encoded = decodedJwt.get_payload_claim("aud").as_string();


        pqxx::connection* c = _connectionPool->getConnection();
        pqxx::read_transaction readTransaction(*c);
        try {
            const std::string& user_id_decode = readTransaction.exec_prepared1("decode", user_id_encoded).front().as<std::string>();
            const std::string& school_id_decode = readTransaction.exec_prepared1("decode", school_id_encoded).front().as<std::string>();
        }
        catch (std::exception &e) {
            std::cout << "[ERROR] Cannot decode user's jwt claims. \n" << e.what();
        }

        jwt::verifier verify = jwt::verify();
        verify.with_issuer("Floaty");


        _connectionPool->releaseConnection(c);
    }

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
    static std::string hashSHA256(const std::string& input) {
        unsigned char hash[SHA256_DIGEST_LENGTH];
        SHA256_CTX sha256;
        SHA256_Init(&sha256);
        SHA256_Update(&sha256, input.c_str(), input.length());
        SHA256_Final(hash, &sha256);

        std::stringstream ss;
        for(unsigned char i : hash) {
            ss << std::hex << std::setw(2) << std::setfill('0') << (int)i;
        }

        return ss.str();
    }
public:
    Server(const std::string& address, const int& port, ConnectionPool* cp) {
        Server::_connectionPool = cp;
        app.bindaddr(address)
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
                ([](const std::string& file) {
                    if (file == "userForm" || file == "userInterface") return handleErrPage(0, "no access");
                    else return genWebPages(file);
                });
        //Region API
        CROW_ROUTE(app, "/api/signup")
        .methods(crow::HTTPMethod::POST)
        ([](const crow::request &req){

            crow::response res(500, "under temporary development");
            return "res.end()";
        });


        CROW_ROUTE(app, "/api/login")
        .methods(crow::HTTPMethod::POST)
        ([this](const crow::request &req){

            pqxx::connection* c = _connectionPool->getConnection();

            Json::Reader jReader;
            Json::Value reqBody;

            const std::string &userReqBody_buff = req.body;
            jReader.parse(userReqBody_buff, reqBody);

            const std::string &userLogin = reqBody.get("login", -1).asString();
            const std::string &userPassword = reqBody.get("password", -1).asString();

            if (userLogin == "-1" || userPassword == "-1") {
                return crow::response(400, "Bad creditionals");
            }

            const std::string& hashedLogin = hashSHA256(userLogin);
            const std::string& hashedPassword = hashSHA256(userPassword);

//            std::cout << hashedLogin << '\n' << hashedPassword << '\n'; //!debug

            if (c->is_open()) {
                pqxx::read_transaction readTransacion(*c);


                try {

                    auto result = readTransacion.exec_prepared("is_valid_user", hashedLogin, hashedPassword).front();
                    if (!result[0].as<bool>()) return crow::response(400, "Wrong creds");

                    const std::string& user_id = result[1].as<std::string>();
                    //                std::cout << "[INFO] Tech id: " << user_id << '\n'; //!debug

                    auto roles = readTransacion.exec_prepared("get_user_roles", user_id);
                    picojson::array available_roles;
                    for (auto role : roles) {
                        picojson::value role_v(role.front().as<std::string>());
                        available_roles.push_back(role_v);
                    }
                    if (roles.capacity() == 0) return crow::response(400, "U r doesnt have any available roles. "
                                                                          "Contact with admin for granting privileges");


                    const std::string& school_id = readTransacion.exec_prepared1("get_school_id", user_id).front().as<std::string>();
//                        std::cout << "[INFO] SCHOOL ID iS: " << school_id << '\n'; //!debug

                    const std::string& user_id_encoded = readTransacion.exec_prepared1("encode", user_id).front().as<std::string>();
//                        std::cout << "[INFO] SUB IS: " << user_id << '\n'; //!debug

                    const std::string& school_id_encoded = readTransacion.exec_prepared1("encode", school_id).front().as<std::string>();




                    auto jwt_builder = jwt::create();
                    jwt_builder.set_issuer("Floaty");

                    //id, school_id
                    jwt_builder.set_subject(user_id_encoded);
                    jwt_builder.set_audience(school_id_encoded);

                    //roles
                    jwt_builder.set_payload_claim("roles", jwt::claim(available_roles));

                    //time
                    jwt_builder.set_issued_at(std::chrono::system_clock::now());
                    jwt_builder.set_expires_at(std::chrono::system_clock::now() + std::chrono::seconds(3600)); //1 hour

                    //TODO read key from another place. key.txt?
                    std::string key;
                    auto jwt = jwt_builder.sign(jwt::algorithm::hs256(key));

                    std::cout << jwt << '\n';
                    crow::json::wvalue jsonResponse;
                    jsonResponse["token"] = jwt;

                    _connectionPool->releaseConnection(c);
                    return crow::response(200, jsonResponse);
                }
                catch (std::exception &e) {
                    std::string msg = e.what();
                    std::cerr << "ERR: " <<  e.what() << '\n';
                    return crow::response(500, std::string("ERR: " + msg));
                }

                //TODO: refactor into no 1one else and many if statements
            }
            else {
                std::cout << "c is closed \n";
            }



           return crow::response(200, "all is good");
        });

        CROW_ROUTE(app, "/api/organisation/register")
                .methods(crow::HTTPMethod::POST)([this](const crow::request &req, crow::response &res){

                    const std::string& org_email = "133s5aise@mozmail.com";
                    const std::string& org_password = "testPwd";


                    return res.end();
                });

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
ConnectionPool* Server::_connectionPool;
int main()
{

    //    62.233.46.131
//    Server server("62.233.46.131", 443);
//    Server::useSSL();
//    Server server("192.168.1.126", 80);
    std::string psql_data = "dbname = FloatyDB "
                            "user = floatyapi "
                            "password = FloatyTheBest "
                            "hostaddr = " "127.0.0.1 "
                            "port = " "5432 ";
    ConnectionPool cp(psql_data, 2);
    Server server("127.0.0.1", 80, &cp);
    server.initRoutes();
    Server::run();
    return 0;
}
