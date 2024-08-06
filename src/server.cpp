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
        }
        catch(jwt::error::token_verification_exception& e) {
            std::cerr << "Expired time of token: " << e.what() << '\n';
        }
        catch (const std::runtime_error& e) {
            std::cerr << "Exception: " << e.what() << '\n';
        }
        catch (std::exception &e) {
            std::cerr << "Excp. is: " << e.what();
        }
        return false;
    }
    constexpr static const auto verifier
    = [] (const crow::request& req,
        crow::response& res,
        const std::function<void(const crow::request& req, crow::response& res)>& f)
    {
        if (req.get_header_value("token").empty()) {
            res.code = 401;
            return res.end();
        }
        const std::string& jwtToken = req.get_header_value("token");
        if (isValidJWT(jwtToken)) {
            try {
                f(req, res);
            }
            catch (api::exceptions::wrongRequest &e) {
                res.code = 400;

                crow::json::wvalue json;
                json["type"] = "Wrong request";
                json["context"] = e.what();

                res.body = json.dump();
                std::cerr << "[ERR]: " << e.what() << "\n for: " << req.remote_ip_address;
            }
            catch(api::exceptions::conflict &e) {
                crow::json::wvalue json;
                json["type"] = "Conflict";
                json["context"] = e.what();
                res.body = json.dump();
                res.code = 409;
            }
            catch (api::exceptions::dataDoesntExists &e) {
                crow::json::wvalue json;
                json["type"] = "Data err";
                json["context"] = "Data doesnt exists";
                res.body = json.dump();
                res.code = 204;
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

//Region API
    static void initAPI() {
        CROW_ROUTE(app, "/api/signup").methods(crow::HTTPMethod::POST)([](const crow::request &req){

            if (req.url_params.get("school")) {

            }

            crow::response res(500, "under temporary development");
            return "res.end()";
        });

        CROW_ROUTE(app, "/api/login")
        .methods(crow::HTTPMethod::POST)
        ([](const crow::request &req){
            pqxx::connection* c = _connectionPool->getConnection();
            pqxx::read_transaction readTransaction(*c);

            Json::Reader jReader;
            Json::Value reqBody;

            const std::string &userReqBody_buff = req.body;
            jReader.parse(userReqBody_buff, reqBody);

            const std::string &userLoginRaw = reqBody.get("login", -1).asString();
            const std::string &userPasswordRaw = reqBody.get("password", -1).asString();

            if (userLoginRaw == "-1" || userPasswordRaw == "-1")
                return crow::response(400, "Bad creditionals");


            const std::string& hashedLogin = hashSHA256(userLoginRaw);
            const std::string& hashedPassword = hashSHA256(userPasswordRaw);

            try {
                auto result = readTransaction.exec_prepared("is_valid_user", hashedLogin, hashedPassword).front();
                if (!result[0].as<bool>()) return crow::response(400, "Wrong creds");


                // * UUID in postgres
                const std::string& userUUID = result[1].as<std::string>();
//                std::cout << "[INFO] Tech id: " << user_id << '\n'; //!debug

                // * UUID in postgres
                const std::string& schoolUUID = readTransaction.exec_prepared1("school_id_get", userUUID).front().as<std::string>();
//                std::cout << "[INFO] SCHOOL ID iS: " << school_id << '\n'; //!debug


                auto roles = readTransaction.exec_prepared("user_roles_get", schoolUUID, userUUID);
                picojson::array available_roles;
                for (auto role : roles) {
                    picojson::value role_v(role.front().as<std::string>());
                    available_roles.push_back(role_v);
                }
                if (roles.capacity() == 0) return crow::response(400, "U r doesnt have any available roles. "
                                                                      "Contact with admin for granting privileges");




                const std::string& userIdHex = readTransaction.exec_prepared1("encode", userUUID).front().as<std::string>();
//                std::cout << "[INFO] SUB IS: " << user_id << '\n'; //!debug
                const std::string& schoolIdHex = readTransaction.exec_prepared1("encode", schoolUUID).front().as<std::string>();
//                std::cout << "[INFO] AUD iS: " << school_id_encoded << '\n'; //!debug


                auto jwt_builder = jwt::create();
                jwt_builder.set_issuer("Floaty");

                //id, school_id
                jwt_builder.set_subject(userIdHex);
                jwt_builder.set_audience(schoolIdHex);

                //roles
                jwt_builder.set_payload_claim("roles", jwt::claim(available_roles));

                //time
                jwt_builder.set_issued_at(std::chrono::system_clock::now());
                jwt_builder.set_expires_at(std::chrono::system_clock::now() + std::chrono::seconds(3600)); //1 hour

                auto jwt = jwt_builder.sign(jwt::algorithm::hs256(_jwt_secret));

//!debug                std::cout << jwt << '\n';

                auto userName = readTransaction.exec_prepared1("user_name_get", schoolUUID, userUUID).front().as<std::string>();

                crow::json::wvalue jsonResponse;
                jsonResponse["token"] = jwt;
                jsonResponse["name"] = userName;

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
        CROW_ROUTE(app, "/api/user/roles")
        .methods(crow::HTTPMethod::GET)
        ([](const crow::request &req, crow::response &res){
            auto f = [](const crow::request& req, crow::response& res){
                Request user(_connectionPool, req);
                auto roles = user.getRoles();
                crow::json::wvalue json;
                json["roles"] = roles;
                res.body = json.dump();
            };
            return verifier(req, res, f);
        });

        CROW_ROUTE(app, "/api/user/classes")
        .methods(crow::HTTPMethod::GET)
        ([](const crow::request &req, crow::response &res){
            auto f = [](const crow::request& req, crow::response& res){
                Request user(_connectionPool, req);
                crow::json::wvalue json;
                json["classes"] = user.getAvailibleClasses();

                res.body = json.dump();
            };
            return verifier(req, res, f);
        });

//        CROW_ROUTE(app, "/api/user/classes/<string>")
//        .methods(crow::HTTPMethod::GET)([](const crow::request &req, crow::response &res, const std::string& classID){
//            auto f = [&](const crow::request& req, crow::response& res){
//                classHandler user(_connectionPool, req, classID);
//                crow::json::wvalue studentsJson = user.getClassStudents();
//                res.body = studentsJson.dump();
//            };
//
//            return verifier(req, res, f);
//        });

        CROW_ROUTE(app, "/api/user/classes/<string>/students")
        .methods(crow::HTTPMethod::GET)([](const crow::request &req, crow::response &res, const std::string& classID){
            auto f = [&](const crow::request& req, crow::response& res){
                classHandler user(_connectionPool, req, classID);
                crow::json::wvalue studentsJson = user.getClassStudents();
                res.body = studentsJson.dump();
            };

            return verifier(req, res, f);
        });

        /**
         * @brief Edit list of students
         * @example list_[f]students: []
         */
        CROW_ROUTE(app, "/api/user/classes/<string>/students")
        .methods(crow::HTTPMethod::PUT)
        ([](const crow::request &req, crow::response &res, const std::string& classID) {
            auto f = [&](const crow::request& req, crow::response& res) {
                classHandler user(_connectionPool, req, classID);
                user.updateClassStudents(req.body);
            };
            return verifier(req, res, f);
        });

        CROW_ROUTE(app, "/api/user/classes/<string>/data")
                .methods(crow::HTTPMethod::GET)
                        ([](const crow::request& req, crow::response& res, const std::string& classID){
                            auto f = [&](const crow::request& req, crow::response& res) {
                                classHandler user(_connectionPool, req, classID);
                                crow::json::wvalue json;
                                json["data"] = user.getInsertedDataForToday();
                                res.body = json.dump();
                            };
                            return verifier(req, res, f);
                        });
        CROW_ROUTE(app, "/api/user/classes/<string>/data/<string>")
                .methods(crow::HTTPMethod::GET)
                        ([](const crow::request& req, crow::response& res, const std::string& classID, const std::string& userDate){
                            auto f = [&](const crow::request& req, crow::response& res) {
                                classHandler user(_connectionPool, req, classID);
                                crow::json::wvalue json;
                                json["data"] = user.getInsertedDataForDate(userDate);
                                res.body = json.dump();
                            };
                            return verifier(req, res, f);
                        });

        CROW_ROUTE(app, "/api/user/classes/<string>/data")
        .methods(crow::HTTPMethod::PUT)
        ([](const crow::request& req, crow::response& res, const std::string& classID){
            auto f = [&](const crow::request& req, crow::response& res) {
                classHandler user(_connectionPool, req, classID);
                user.insertData(req.body);
            };
            return verifier(req, res, f);
        });

        //Region HTeacher

        /**
         * @brief Get all classes of organisation
         */
        CROW_ROUTE(app, "/api/org/classes")
        .methods(crow::HTTPMethod::GET)
        ([](const crow::request& req, crow::response& res)
        {
            auto f = [](const crow::request& req, crow::response& res){
                schoolManager schoolManager(_connectionPool, req);
                crow::json::wvalue json = schoolManager.getClasses();
                res.body = json.dump();
            };
            return verifier(req, res, f);
        });

        //Get list of students for class
        CROW_ROUTE(app, "/api/org/classes/<string>/students")
        .methods(crow::HTTPMethod::GET)
        ([](const crow::request& req, crow::response& res, const std::string& classID)
        {
            auto f = [&](const crow::request& req, crow::response& res){
                schoolManager schoolManager(_connectionPool, req);
                crow::json::wvalue json = schoolManager.getClassStudents(classID);
                res.body = json.dump();
            };
            return verifier(req, res, f);
        });

        // Creates class with or without owner depending onto url_param
        CROW_ROUTE(app, "/api/org/classes")
        .methods(crow::HTTPMethod::POST)
        ([](const crow::request& req, crow::response& res){
            auto f = [](const crow::request& req, crow::response& res) {
                schoolManager schoolManager(_connectionPool, req);
                if (crow::json::load(req.body).error()) {
                    throw api::exceptions::parseErr("Is request body json?");
                }

                auto withOwnerParam = req.url_params.get("withOwner");
                bool withOwner = false;
//
                if (withOwnerParam) {
                    std::string withOwnerStr = withOwnerParam;
                    schoolManager.urlParams.isWithOwner = (withOwnerStr == "true");
                }
                schoolManager.classCreate(crow::json::load(req.body));
                res.code = crow::status::CREATED;
            };

            return verifier(req, res, f);
        });

        /**
         * @brief Rename class
         */
        CROW_ROUTE(app, "/api/org/classes/<string>")
                .methods(crow::HTTPMethod::PATCH)
                        ([](const crow::request& req, crow::response& res, const std::string& urlClassID){
                            auto f = [&](const crow::request& req, crow::response& res){
                                schoolManager schoolManager(_connectionPool, req);

                                if (crow::json::load(req.body).error()) {
                                    throw api::exceptions::parseErr("Is request body json?");
                                }

                                //Merging classID and new name from json req.body
                                crow::json::wvalue mergedJson(crow::json::load(req.body));
                                mergedJson["class_id"] = urlClassID;

                                if (!urlClassID.empty()) {
                                    schoolManager.classRename(crow::json::load(mergedJson.dump()));
                                    res.code = 200;
                                }
                                else
                                    throw api::exceptions::wrongRequest("Request doesn't contain class id");

                            };
                            return verifier(req, res, f);
                        });
        /**
         * @brief Deletes class by class id from url
         */
        CROW_ROUTE(app, "/api/org/classes/<string>")
        .methods(crow::HTTPMethod::DELETE)
        ([](const crow::request& req, crow::response& res, const std::string& classID){
            auto f = [&](const crow::request& req, crow::response& res){

                schoolManager schoolManager(_connectionPool, req);
                if (!classID.empty()) {
                    schoolManager.classDrop(classID);
                    res.code = 200;
                }
                else
                    throw api::exceptions::wrongRequest("Request doesn't contain class id");

            };
            return verifier(req, res, f);
        });

        //Region Users
        // Get list of all users
        CROW_ROUTE(app, "/api/org/users")
        .methods(crow::HTTPMethod::GET)
        ([](const crow::request& req, crow::response& res){
        auto f = [](const crow::request& req, crow::response& res){
            schoolManager schoolManager(_connectionPool, req);
            auto json = schoolManager.getUsers();
            res.body = json.dump();
            res.code = 200;
        };
        return verifier(req, res, f);
    });

        /**
         * @param withRoles - if set to true, then reads "roles" under req.body else creates user without any roles
         * @param withClasses - if set to true, then reads "classes"
         */
        // Create new user
        CROW_ROUTE(app, "/api/org/users")
        .methods(crow::HTTPMethod::POST)
        ([&](const crow::request& req, crow::response& res){
            auto f = [&](const crow::request& req, crow::response& res){
                schoolManager schoolManager(_connectionPool, req);

                if (crow::json::load(req.body).error())
                    throw api::exceptions::parseErr("Cant read request body. Is it valid json?");

                crow::json::rvalue body = crow::json::load(req.body);

                if (!body.has("login") ||
                    !body.has("password") ||
                    !body.has("name")
                    )
                    throw api::exceptions::wrongRequest("Request body doesnt have "
                                                        "login / "
                                                        "password / "
                                                        "name");

                //Hashing login / password
                crow::json::wvalue hashedCreds(body);
                hashedCreds["login"] = hashSHA256(body["login"].s());
                hashedCreds["password"] = hashSHA256(body["password"].s());

                auto withRolesParam = req.url_params.get("withRoles");
                auto withClassesParam = req.url_params.get("withClasses");

                //check if withRoles is true
                if (withRolesParam) {
                    std::string withRolesValue = withRolesParam;
                    schoolManager.urlParams.isWithRoles = (withRolesValue == "true");
                }
                //check if withClasses is true
                if (withClassesParam) {
                    std::string withClassesValue = withClassesParam;
                    schoolManager.urlParams.isWithClasses = (withClassesValue == "true");
                }

                if (schoolManager.urlParams.isWithRoles &&
                (!body.has("roles") || body["roles"].t() != crow::json::type::List))
                        throw api::exceptions::wrongRequest("No roles field or roles field is not array");
                if (schoolManager.urlParams.isWithClasses &&
                (!body.has("classes") || body["classes"].t() != crow::json::type::List))
                    throw api::exceptions::wrongRequest("No classes field or classes field is not array");

                schoolManager.userCreate(crow::json::load(req.body));
                res.code = 201;

            };
            return verifier(req, res, f);
        });

        // Deletes user
        CROW_ROUTE(app, "/api/org/users/<string>")
        .methods(crow::HTTPMethod::DELETE)
        ([](const crow::request& req, crow::response& res, const std::string& userID){
            auto f = [&](const crow::request& req, crow::response& res){
                schoolManager schoolManager(_connectionPool, req);
                schoolManager.userDrop(userID);
                res.code = 204;
            };
            return verifier(req, res, f);
        });

        //Region data

        CROW_ROUTE(app, "/api/org/data")
        .methods(crow::HTTPMethod::GET)
        ([](const crow::request& req, crow::response& res){
            auto f = [](const crow::request& req, crow::response& res){
                schoolManager schoolManager(_connectionPool, req);
                auto json = schoolManager.getDataForToday();
                res.body = json.dump();
            };
            return verifier(req, res, f);
        });

        CROW_ROUTE(app, "/api/org/data/<string>")
            .methods(crow::HTTPMethod::GET)
                    ([](const crow::request& req, crow::response& res, const std::string& date) {
                        auto f = [&](const crow::request& req, crow::response& res){
                            schoolManager schoolManager(_connectionPool, req);
                            crow::json::wvalue data;

                            data["data"] = schoolManager.getDataForDate(date);
                            data["date"] = date;

                            res.body = data.dump();
                        };
                        return verifier(req, res, f);
                    });

        CROW_ROUTE(app, "/api/org/data-summary")
        .methods(crow::HTTPMethod::GET)
        ([](const crow::request& req, crow::response& res){
            auto f = [](const crow::request& req, crow::response& res){
                schoolManager schoolManager(_connectionPool, req);

                auto withStartDateParam = req.url_params.get("startDate");
                auto withEndDateParam = req.url_params.get("endDate");

                std::string startDate;
                std::string endDate;

                //check if withRoles is true
                if (withStartDateParam && withEndDateParam) {
                    startDate = withStartDateParam;
                    endDate = withEndDateParam;
                }
                else
                    throw api::exceptions::wrongRequest("No start or end date param in url");

                crow::json::wvalue json;
                json["data"] = schoolManager.getSummaryFromDateToDate(startDate, endDate);
                
                json["start_date"] = startDate;
                json["end_date"] = endDate;

                res.body = json.dump();
            };
            return verifier(req, res, f);
        });

//Region TODO future
        CROW_ROUTE(app, "/api/organisation/register")
                .methods(crow::HTTPMethod::POST)
                ([](const crow::request &req, crow::response &res){

                    const std::string& org_email = "133s5aise@mozmail.com";
                    const std::string& org_password = "testPwd";


                    return res.end();
                });
        CROW_ROUTE(app, "/api/org/invite").methods(crow::HTTPMethod::POST)([](const crow::request& req, crow::response &res){

            return res.end();
        });
    }


    void initRoutes() {
//        crow::mustache::set_global_base("web");

        initAPI();
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
    std::string psql_data = "dbname = floatydb "
                            "user = floatyapi "
                            "password = FloatyTheBest "
                            "hostaddr = 127.0.0.1 "
                            "port = 5432 "
                            "options='--client_encoding=UTF8' ";
    ConnectionPool cp(psql_data, 20);
    Server server("127.0.0.1", 80, &cp);
    server.initRoutes();
    Server::run();
    return 0;
}
