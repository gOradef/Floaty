#include "Floaty.h"
#include "pqxx/pqxx"

#include "openssl/sha.h"
#define CROW_STATIC_DIRECTORY "web/"
#define CROW_STATIC_ENDPOINT "web/"

class Server {
    static crow::SimpleApp app;
    static ConnectionPool* _connectionPool;
    static const std::string& _jwt_secret;

//    crow::mustache::context ctx;

//Region Check JWT
    static bool isValidJWT(const std::string& userjwt) {

        jwt::verifier verify = jwt::verify();
        verify.allow_algorithm(jwt::algorithm::hs256(_jwt_secret));
        verify.with_issuer("Floaty");

        jwt::decoded_jwt decoded_token = jwt::decode(userjwt);
        try {
            verify.verify(decoded_token);
            // * check exp time
            {
                auto exp = decoded_token.get_payload_claim("exp").as_int();

                auto exp_time_t = std::chrono::system_clock::from_time_t(exp);
                auto now = std::chrono::system_clock::now();

                if (now > exp_time_t) throw jwt::token_verification_exception();
            }

            pqxx::connection* c = _connectionPool->getConnection();
            pqxx::read_transaction rtx(*c);

            auto token_user_id = decoded_token.get_subject();
            auto token_school_id = decoded_token.get_payload_claim("aud").as_string();

            const std::string& token_user_id_decoded = rtx.exec_prepared1("decode", token_user_id).front().as<std::string>();
            const std::string& token_school_id_decoded = rtx.exec_prepared1("decode", token_school_id).front().as<std::string>();
            // * check org_id
            {
                auto school_id = rtx.exec_prepared1("school_id_get", token_user_id_decoded).front().as<std::string>();

                if (token_school_id_decoded != school_id) throw std::runtime_error("Disrespect school id");
            }

            // * check roles
            {
                picojson::array token_roles = decoded_token.get_payload_claim("roles").as_array();

                const std::string& user_id_decoded = rtx.exec_prepared1("decode", token_user_id).front().as<std::string>();
                picojson::array available_roles;
                auto roles = rtx.exec_prepared("user_roles_get", token_school_id_decoded, user_id_decoded);

                if (roles.empty()) {
                    throw std::runtime_error("No roles found for user");
                }
                for (auto role : roles) {
                    available_roles.emplace_back(role.front().as<std::string>());
                }
                if (token_roles != available_roles) throw std::runtime_error("Disrespect roles");
            }
            _connectionPool->releaseConnection(c);
            return true;

        }
        catch (jwt::error::signature_verification_error& e) {
            std::cerr << "Signature verif. err: " << e;
            return false;
        }
        catch(jwt::error::token_verification_exception& e) {
            std::cerr << "Expired time of token: " << e.what() << '\n';
            return false;
        }
        catch (const std::runtime_error& e) {
            std::cerr << "Exception: " << e.what() << '\n';
            return false;
        }
    }
    constexpr static const auto verifier = []
            (const std::string& jwtToken,
                    const crow::request& req,
                    crow::response& res,
                    const std::function<void(const crow::request& req, crow::response& res)>& f)
    {
        if (isValidJWT(jwtToken)) {
            try {
                f(req, res);
            }
            catch (std::invalid_argument &e) {
                res.code = 400;
                res.body = e.what();
                std::cerr << "[ERR]: " << e.what();
            }
            catch (std::runtime_error &e) {
                res.code = 400;
                res.body = e.what();
                std::cerr << "[ERR]: " << e.what();
            }
        }
        else {
            res.code = 401;
            res.body = "Unauthorized";
        }
        return res.end();
    };
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
    void initWeb() {
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
    }

//Region API
    void initAPI() {
        CROW_ROUTE(app, "/api/signup").methods(crow::HTTPMethod::POST)([](const crow::request &req){
            bool isWithSchool;
            if (req.url_params.get("school")) {

            }

            crow::response res(500, "under temporary development");
            return "res.end()";
        });

        CROW_ROUTE(app, "/api/login").methods(crow::HTTPMethod::POST) ([this](const crow::request &req){
            pqxx::connection* c = _connectionPool->getConnection();
            pqxx::read_transaction readTransaction(*c);

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

            try {
                auto result = readTransaction.exec_prepared("is_valid_user", hashedLogin, hashedPassword).front();
                if (!result[0].as<bool>()) return crow::response(400, "Wrong creds");


                // * UUID in postgres
                const std::string& user_id = result[1].as<std::string>();
//                std::cout << "[INFO] Tech id: " << user_id << '\n'; //!debug

                // * UUID in postgres
                const std::string& school_id = readTransaction.exec_prepared1("school_id_get", user_id).front().as<std::string>();
//                std::cout << "[INFO] SCHOOL ID iS: " << school_id << '\n'; //!debug


                auto roles = readTransaction.exec_prepared("user_roles_get", school_id, user_id);
                picojson::array available_roles;
                for (auto role : roles) {
                    picojson::value role_v(role.front().as<std::string>());
                    available_roles.push_back(role_v);
                }
                if (roles.capacity() == 0) return crow::response(400, "U r doesnt have any available roles. "
                                                                      "Contact with admin for granting privileges");




                const std::string& user_id_encoded = readTransaction.exec_prepared1("encode", user_id).front().as<std::string>();
//                std::cout << "[INFO] SUB IS: " << user_id << '\n'; //!debug
                const std::string& school_id_encoded = readTransaction.exec_prepared1("encode", school_id).front().as<std::string>();
//                std::cout << "[INFO] AUD iS: " << school_id_encoded << '\n'; //!debug


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

                auto jwt = jwt_builder.sign(jwt::algorithm::hs256(_jwt_secret));

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
           return crow::response(200, "all is good");
        });
        CROW_ROUTE(app, "/api/jwtcheck").methods(crow::HTTPMethod::POST)
        ([](const crow::request& req){
            Json::Reader reader;
            Json::Value jwt;
//            jwt["token"] = req.get_header_value("Authorization");
            reader.parse(req.body, jwt);
            if (isValidJWT(jwt["token"].asString()))
                return "JWT is good, bruh! U r free to go \n";
            else return "bad. redo token";
        });


        //Region user's api (global)
        CROW_ROUTE(app, "/api/user/roles").methods(crow::HTTPMethod::POST)([this](const crow::request &req, crow::response &res){
            const std::string& token = req.get_header_value("token");

            auto f = [](const crow::request& req, crow::response& res){
                Request user(_connectionPool, req);
                auto roles = user.getRoles();
                crow::json::wvalue json;
                json["roles"] = roles;
                res.body = json.dump();
            };
            return verifier(token, req, res, f);
        });

        CROW_ROUTE(app, "/api/user/classes").methods(crow::HTTPMethod::POST)([](const crow::request &req, crow::response &res){
            const std::string& token = req.get_header_value("token");

            auto f = [](const crow::request& req, crow::response& res){
                Request user(_connectionPool, req);
                std::map<std::string, std::string> classes = user.getClasses();
                crow::json::wvalue json;
                for (auto& [id, name] : classes) {
                    json["classes"][id] = name;
                }
                res.body = json.dump();
            };
            return verifier(token, req, res, f);
        });


    CROW_ROUTE(app, "/api/user/class/students").methods(crow::HTTPMethod::POST)([](const crow::request &req, crow::response &res){
        const std::string& token = req.get_header_value("token");

        auto f = [](const crow::request& req, crow::response& res){
            classHandler user(_connectionPool, req);
            crow::json::wvalue studentsJson = user.getClassStudents();
            res.body = studentsJson.dump();
        };

        return verifier(token, req, res, f);
    });



        /**
         * @brief Needed for updating class_data. Like list of students, amount students
         */
        CROW_ROUTE(app, "/api/user/class/update").methods(crow::HTTPMethod::POST)([](const crow::request &req, crow::response &res) {
            //todo is valid jwt check
            std::string token = req.get_header_value("token");
            auto f = [](const crow::request& req, crow::response& res) {
                classHandler user(_connectionPool, req);
                user.updateClassStudents(req.body);
            };
            return verifier(token, req, res, f);
        });

        CROW_ROUTE(app, "/api/organisation/register")
                .methods(crow::HTTPMethod::POST)([this](const crow::request &req, crow::response &res){

                    const std::string& org_email = "133s5aise@mozmail.com";
                    const std::string& org_password = "testPwd";


                    return res.end();
                });
        CROW_ROUTE(app, "/api/org/invite").methods(crow::HTTPMethod::POST)([](const crow::request& req, crow::response &res){

            return res.end();
        });
    }

    static void initArchivedAPI() {
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
                .methods(crow::HTTPMethod::POST)
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

    void initRoutes() {
        crow::mustache::set_global_base("web");

        initWeb();

        initAPI();

        initArchivedAPI();

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
const std::string& Server::_jwt_secret = "dyXJY7wN2fbhxxI6+KZ47IuGfKt0kFXHQQt1gACG7YUB/zwHxA4nRCq0J1pmxthUAi23oHfA8rNMXv0Oi4LuRw==";
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
    ConnectionPool cp(psql_data, 20);
    Server server("127.0.0.1", 80, &cp);
    server.initRoutes();
    Server::run();
    return 0;
}
