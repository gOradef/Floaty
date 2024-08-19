//
// Created by goradef on 15.08.2024. Contains functios for routing
//
#pragma once

#include "api.h"
#include "crow/app.h"
#include "crow/middlewares/session.h"
#include "crow/middlewares/cookie_parser.h"
#include "jwt-cpp/jwt.h"

class Server {
    static ConnectionPool* _connectionPool;

    //Init secrets for JWT tokens
    static const std::string& _jwtAccessSecret;
    static const std::string& _jwtRefreshSecret;

    using Session = crow::SessionMiddleware<crow::InMemoryStore>;
    static crow::App<crow::CookieParser, Session> app;

    static bool isValidJWT(const std::string& userjwt, const std::string& _jwtSecret);

    constexpr static auto verifier = [](const crow::request& req, crow::response& res,
                                        const std::function<void(const crow::request&, crow::response&)>& f)
    {
        crow::CookieParser::context& ctx = app.get_context<crow::CookieParser>(req);
        const std::string& jwtAccessToken = ctx.get_cookie("Floaty_access_token");

        if (isValidJWT(jwtAccessToken, _jwtAccessSecret)) {
            try {
                f(req, res);
            }

            catch (jwt::token_verification_exception& e)
            {
                res.code = 401;
            }
            catch (api::exceptions::parseErr& e) {
                res.code = 400;

                crow::json::wvalue json;
                json["type"] = "Parse error";
                json["context"] = e.what();

                res.body = json.dump();
                std::cerr << "[ERR]: " << e.what() << "\n for: " << req.remote_ip_address;
            }
            catch (api::exceptions::wrongRequest& e)
            {
                res.code = 400;

                crow::json::wvalue json;
                json["type"] = "Wrong request";
                json["context"] = e.what();

                res.body = json.dump();
                std::cerr << "[ERR]: " << e.what() << "\n for: " << req.remote_ip_address;
            }
            catch (api::exceptions::requirmentsDoesntMeeted& e) {
                crow::json::wvalue json;
                json["type"] = "Requirments doesnt meeted";
                json["context"] = e.what();
                res.body = json.dump();
                res.code = 403;
            }
            catch (api::exceptions::conflict& e)
            {
                crow::json::wvalue json;
                json["type"] = "Conflict";
                json["context"] = e.what();
                res.body = json.dump();
                res.code = 409;
            }
            catch (api::exceptions::dataDoesntExists& e)
            {
                crow::json::wvalue json;
                json["type"] = "Data err";
                json["context"] = "Data doesnt exists";
                res.body = json.dump();
                res.code = 204;
            }
            catch (std::invalid_argument& e)
            {
                res.code = 400;
                res.body = e.what();
                std::cerr << "[ERR]: " << e.what();
            }
            catch (std::runtime_error& e)
            {
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
    static std::string hashSHA256(const std::string& input);

    //* API methods
    struct routes_auth {
        static void login(const crow::request& req, crow::response& res);

        static void refreshToken(const crow::request& req, crow::response& res);

        static void getInviteProps(const crow::request& req, crow::response& res, const std::string& schoolID);

        static void signupUsingInvite(const crow::request& req, crow::response& res, const std::string& schoolID);
    };
    struct routes_user
    {
        static void getUserRoles(const crow::request& req, crow::response& res);

        static void getUserClasses(const crow::request& req, crow::response& res);;
    };
    struct routes_classHandler
    {
        static void getStudents (const crow::request& req, crow::response& res, const std::string& classID);

        static void insertStudents(const crow::request &req, crow::response &res, const std::string& classID);

        static void getDataForToday(const crow::request& req, crow::response& res, const std::string& classID);

        static void getDataForDate(const crow::request& req, crow::response& res, const std::string& classID, const std::string& userDate);

        static void insertData(const crow::request& req, crow::response& res, const std::string& classID);;
    };
    struct routes_admin
    {
        //* Classes section
        static void getAllClasses(const crow::request& req, crow::response& res);
        static void createNewClass(const crow::request& req, crow::response& res);
        static void getStudentsForClass(const crow::request& req, crow::response& res, const std::string& classID);
        static void renameClass(const crow::request& req, crow::response& res, const std::string& urlClassID);
        static void deleteClass(const crow::request& req, crow::response& res, const std::string& classID);

        //* Users section
        static void getAllUsers(const crow::request& req, crow::response& res);
        static void createNewUser(const crow::request& req, crow::response& res);
        static void deleteUser(const crow::request& req, crow::response& res, const std::string& userID);
        static void resetPasswordOfUser(const crow::request& req, crow::response& res, const std::string& userID);

        //* Data section
        static void getDataForToday(const crow::request& req, crow::response& res);
        static void getDataForDate(const crow::request& req, crow::response& res, const std::string& date);
        static void getDataSummary(const crow::request& req, crow::response& res);

        //* Grant roles
        static void grantRolesToUser(const crow::request& req, crow::response& res, const std::string& userID);
        static void degrantRolesToUser(const crow::request& req, crow::response& res, const std::string& userID);

        //* Grant classes
        static void grantClassesToUser(const crow::request& req, crow::response& res, const std::string& userID);
        static void degrantClassesToUser(const crow::request& req, crow::response& res, const std::string& userID);

        //* Invites
        static void getAllInvites(const crow::request& req, crow::response& res);
        static void createInvite(const crow::request& req, crow::response& res);
        static void dropInvite(const crow::request& req, crow::response& res, const std::string& inviteID);
    };

    //* Routing api methods
    static void route_auth();
    static void route_user();
    static void route_classHandler();
    static void route_admin();
public:
    Server(const std::string& address, const int& port, ConnectionPool* cp);

    static void initRoutes();

    [[maybe_unused]]
    static void useSSL();

    static void run();
};

inline Server::Server(const std::string& address, const int& port, ConnectionPool* cp) {
    Server::_connectionPool = cp;
    app.bindaddr(address)
       .port(port);

}

inline void Server::routes_auth::login(const crow::request& req, crow::response& res) {
    pqxx::connection* c = _connectionPool->getConnection();
    pqxx::read_transaction readTransaction(*c);

    try {
        //Check parsing of req.body
        if (!crow::json::load(req.body)) {
            throw api::exceptions::parseErr("");
        }

        crow::json::rvalue req_json = crow::json::load(req.body);

        //Check existsing and types of creditionals
        if (!req_json.has("login") || !req_json.has("password")
            || req_json["login"].t() != crow::json::type::String
            || req_json["password"].t() != crow::json::type::String)
            {
                throw api::exceptions::wrongRequest("Is login and password exists and it is string?");
            }

        //Hashing creditionals
        const std::string& hashedLogin = hashSHA256(req_json["login"].s());
        const std::string& hashedPassword = hashSHA256(req_json["password"].s());

        //Check if user's creds are valid
        auto result = readTransaction.exec_prepared(psqlMethods::userChecks::isValid, hashedLogin, hashedPassword).front();

        if (!result[0].as<bool>()) {
            throw api::exceptions::wrongRequest("Invalid login or password");
        }

        // * UUID in postgres
        const std::string& userUUID = result[1].as<std::string>();

        // * UUID in postgres
        const std::string& schoolUUID = readTransaction.exec_prepared1(psqlMethods::userData::getSchoolId, userUUID).front().as<std::string>();

        //Get roles from postgres
        auto roles = readTransaction.exec_prepared(psqlMethods::userData::getRoles, schoolUUID, userUUID);
        picojson::array available_roles;
        for (auto role : roles) {
            picojson::value role_v(role.front().as<std::string>());
            available_roles.push_back(role_v);
        }
        if (roles.capacity() == 0) {
            throw api::exceptions::requirmentsDoesntMeeted("U r doesnt have any available roles. "
                "Contact with admin for granting privileges");
        }

        //Get available classes from postgres
        auto classes = readTransaction.exec_prepared(psqlMethods::userData::getClasses, schoolUUID, userUUID);
        picojson::array available_classes;
        for (auto class_v : classes) {
            picojson::value classes_virtual(class_v.front().as<std::string>());
            available_classes.push_back(classes_virtual);
        }


        //Get hexadecimal user's creds
        const std::string& userIdHex = readTransaction.exec_prepared1("encode", userUUID).front().as<std::string>();
        //                std::cout << "[INFO] SUB IS: " << user_id << '\n'; //!debug
        const std::string& schoolIdHex = readTransaction.exec_prepared1("encode", schoolUUID).front().as<std::string>();
        //                std::cout << "[INFO] AUD iS: " << school_id_encoded << '\n'; //!debug


        auto jwt_builder = jwt::create();
        jwt_builder.set_issuer("Floaty");

        //Set id, school_id
        jwt_builder.set_subject(userIdHex);
        jwt_builder.set_audience(schoolIdHex);

        // Set roles
        jwt_builder.set_payload_claim("roles", jwt::claim(available_roles));

        // Set classes
        jwt_builder.set_payload_claim("classes", jwt::claim(available_classes));

        //Set time
        jwt_builder.set_issued_at(std::chrono::system_clock::now());
        jwt_builder.set_expires_at(std::chrono::system_clock::now() + std::chrono::hours(1));

        auto jwtAccess = jwt_builder
                         .set_type("AccessToken")
                         .sign(jwt::algorithm::hs256(_jwtAccessSecret));

        auto jwtRefresh = jwt_builder
                          .set_type("RefreshToken")
                          .sign(jwt::algorithm::hs256(_jwtRefreshSecret));

        auto userName = readTransaction.exec_prepared1("user_name_get", schoolUUID, userUUID).front().as<std::string>();

        // Option 1. User Set-Cookie
        res.set_header("Set-Cookie", "Floaty_access_token=" + jwtAccess + "; path=/;"
                       + "Max-Age=86400;" + "HttpOnly;"+ "Secure;" + "SameSite=Lax;");
        // Set the refresh token in the Set-Cookie header of the response
        res.add_header("Set-Cookie", "Floaty_refresh_token=" + jwtRefresh + "; path=/;"
                       + "Max-Age=432000;" + "HttpOnly;"+ "Secure;" + "SameSite=Lax;");

        crow::json::wvalue root;
        root["user"]["name"] = userName;
        res.body = root.dump();

    }
    catch (api::exceptions::parseErr& e) {
        res.code = 400;
        res.body = "Failed to parse request body. Is it json?";
    }
    catch (api::exceptions::wrongRequest& e) {
        res.code = 400;
        res.body = e.what();
    }
    catch (std::exception &e) {
        std::string msg = e.what();
        std::cerr << "ERR: " <<  e.what() << '\n';
    }

    _connectionPool->releaseConnection(c);
    return res.end();
}

inline void Server::routes_auth::refreshToken(const crow::request& req, crow::response& res) {
    // Get refresh token
    auto& ctx = app.get_context<crow::CookieParser>(req);
    const std::string& refreshToken_buff = ctx.get_cookie("Floaty_refresh_token");

    // Check if token isn't valid
    if (refreshToken_buff.empty() || !isValidJWT(refreshToken_buff, _jwtRefreshSecret)) {
        res.code = 401; // Unauthorized
        return res.end();
    }

    // Decode the JWT and get the payload
    auto decodedJWT = jwt::decode(refreshToken_buff);

    // Create a new token with required claims
    auto builder_jwt = jwt::create();

    // Set claims from the decoded payload – assuming 'sub' is in payload
    for (const auto& e : decodedJWT.get_payload_claims()) {
        // Here we set each claim to the new token
        builder_jwt.set_payload_claim(e.first, e.second);
    }

    // Additional claims that you might want to set
    builder_jwt
        .set_issuer("Floaty") // Set the issuer of your token
        .set_issued_at(std::chrono::system_clock::now()) // Set issuesed time
        .set_expires_at(std::chrono::system_clock::now() + std::chrono::hours(24)) // Set expiration time
        .sign(jwt::algorithm::hs256{_jwtAccessSecret}); // Sign with access token secret

    // Once the new access token has been created
    std::string newAccessToken = builder_jwt
                                 .set_type("AccessToken")
                                 .sign(jwt::algorithm::hs256{_jwtAccessSecret});

    // Send the new access token in response
    res.code = 200; // Success
    res.set_header("Set-Cookie", "Floaty_access_token=" + newAccessToken + "; path=/;"
                   + "Max-Age=86400;" + "HttpOnly;" + "Secure;" + "SameSite=Lax;");
    res.end(); // End the response
}

inline void Server::routes_auth::getInviteProps(const crow::request& req, crow::response& res,
    const std::string& schoolID) {
    const crow::json::rvalue root_body = crow::json::load(req.body);
    const crow::json::rvalue& invite_creds = root_body["invite"];

    if (!invite_creds ||
        !invite_creds.has("code") ||
        !invite_creds.has("secret")
    ) {
        res.code = 400;
        res.write("No \"invite\" field or \"code\" or \"secret\"");
        return res.end();
    }
    const std::string& invite_code = invite_creds["code"].s();
    const std::string& invite_secret = invite_creds["secret"].s();

    auto con = _connectionPool->getConnection();
    pqxx::read_transaction work(*con);
    auto props = work.exec_prepared(psqlMethods::invites::getProperties, schoolID, invite_code, invite_secret).front().front().as<std::string>();
    res.body = props;
    _connectionPool->releaseConnection(con);
    return res.end();
}

inline void Server::routes_auth::signupUsingInvite(const crow::request& req, crow::response& res,
    const std::string& schoolID) {
    const crow::json::rvalue root_body = crow::json::load(req.body);
    const crow::json::rvalue& invite_creds = root_body["invite"];
    const crow::json::rvalue& user_creds = root_body["user"];

    auto c = _connectionPool->getConnection();

    try {
        if (!invite_creds ||
            !invite_creds.has("code") ||
            !invite_creds.has("secret")
        ) {
            throw api::exceptions::wrongRequest("No \"invite\" field or \"code\" or \"secret\"");
        }
        if (!user_creds ||
            !user_creds.has("login") ||
            !user_creds.has("password")
        ) {
            throw api::exceptions::wrongRequest("No \"user\" field or login, password in it");
        }

        const std::string& invite_code = invite_creds["code"].s();
        const std::string& invite_secret = invite_creds["secret"].s();

        const std::string& user_loginHashed = hashSHA256(user_creds["login"].s());
        const std::string& user_passwordHashed = hashSHA256(user_creds["password"].s());

        //* Get con for checking validality of invite
        pqxx::work work(*c);

        //* Check if invite creds are valid
        auto isValidInvite = work.exec_prepared(psqlMethods::invites::isValid, schoolID, invite_code, invite_secret).front().front().as<bool>();
        if (!isValidInvite) {
            throw api::exceptions::wrongRequest("No such invite");
        }
        //* Check if login is alredy is use
        bool isLoginOccupied = work.exec_prepared(psqlMethods::userChecks::isLoginOccupied, user_loginHashed).front().front().as<bool>();
        if (isLoginOccupied)
            throw api::exceptions::conflict("Login is already occupied. Please, try another");

        //* Get invite_props
        auto invite_props = work.exec_prepared(psqlMethods::invites::getProperties, schoolID, invite_code, invite_secret).front().front().as<std::string>();

        crow::json::rvalue json_props = crow::json::load(invite_props);
        if (!json_props) {
            throw api::exceptions::conflict("Wrong format of invite_body created by administrator");
        }
        std::vector<std::string> roles;
        std::vector<std::string> classes;

        for (const auto& el : json_props["roles"]) {
            roles.emplace_back(el.s());
        }
        for (const auto& el : json_props["classes"]) {
            classes.emplace_back(el.s());
        }
        const std::string& name = json_props["name"].s();

        //* Create user
        work.exec_prepared(psqlMethods::schoolManager::users::createWithContext,
                           schoolID,
                           user_loginHashed,
                           user_passwordHashed,
                           name,
                           roles,
                           classes
        );
        work.commit();
        res.code = 201;
    }
    catch (api::exceptions::requirmentsDoesntMeeted& e) {
        res.code = 403;
        res.body = e.what();
    }
    catch (api::exceptions::wrongRequest& e) {
        res.code = 400;
        res.body = e.what();
    }
    catch(api::exceptions::conflict& e) {
        res.code = 409;
        res.body = e.what();
    }
    _connectionPool->releaseConnection(c);
    return res.end();
}

inline void Server::routes_user::getUserRoles(const crow::request& req, crow::response& res) {
    auto f = [&](const crow::request& req, crow::response& res){
        Request user(_connectionPool, req);
        auto roles = user.getRoles();
        crow::json::wvalue json;
        json["roles"] = roles;
        res.body = json.dump();
    };
    return verifier(req, res, f);
}

inline void Server::routes_user::getUserClasses(const crow::request& req, crow::response& res) {
    auto f = [](const crow::request& req, crow::response& res){
        Request user(_connectionPool, req);
        crow::json::wvalue json;
        json["classes"] = user.getAvailibleClasses();

        res.body = json.dump();
    };
    return verifier(req, res, f);
}

inline void Server::routes_classHandler::getStudents(const crow::request& req, crow::response& res,
    const std::string& classID) {
    auto f = [&](const crow::request& req, crow::response& res){
        classHandler user(_connectionPool, req, classID);
        crow::json::wvalue studentsJson = user.getClassStudents();
        res.body = studentsJson.dump();
    };
    return verifier(req, res, f);
}

inline void Server::routes_classHandler::insertStudents(const crow::request& req, crow::response& res,
    const std::string& classID) {
    auto f = [&](const crow::request& req, crow::response& res) {
        classHandler user(_connectionPool, req, classID);
        user.updateClassStudents(req.body);
    };
    return verifier(req, res, f);
}

inline void Server::routes_classHandler::getDataForToday(const crow::request& req, crow::response& res,
    const std::string& classID) {
    auto f = [&](const crow::request& req, crow::response& res) {
        classHandler user(_connectionPool, req, classID);
        crow::json::wvalue json;
        json["data"] = user.getInsertedDataForToday();
        res.body = json.dump();
    };
    return verifier(req, res, f);
}

inline void Server::routes_classHandler::getDataForDate(const crow::request& req, crow::response& res,
    const std::string& classID, const std::string& userDate) {
    auto f = [&](const crow::request& req, crow::response& res) {
        classHandler user(_connectionPool, req, classID);
        crow::json::wvalue json;
        json["data"] = user.getInsertedDataForDate(userDate);
        res.body = json.dump();
    };
    return verifier(req, res, f);

}

inline void Server::routes_classHandler::insertData(const crow::request& req, crow::response& res,
    const std::string& classID) {
    auto f = [&](const crow::request& req, crow::response& res) {
        classHandler user(_connectionPool, req, classID);
        user.insertData(req.body);
    };
    return verifier(req, res, f);
}

inline void Server::routes_admin::getAllClasses(const crow::request& req, crow::response& res) {
    auto f = [](const crow::request& req, crow::response& res){
        schoolManager schoolManager(_connectionPool, req);
        crow::json::wvalue json = schoolManager.getClasses();
        res.body = json.dump();
    };
    return verifier(req, res, f);
}

inline void Server::routes_admin::getStudentsForClass(const crow::request& req, crow::response& res,
    const std::string& classID) {
    auto f = [&](const crow::request& req, crow::response& res){
        schoolManager schoolManager(_connectionPool, req);
        crow::json::wvalue json = schoolManager.getClassStudents(classID);
        res.body = json.dump();
    };
    return verifier(req, res, f);
}

inline void Server::routes_admin::createNewClass(const crow::request& req, crow::response& res) {
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
}

inline void Server::routes_admin::renameClass(const crow::request& req, crow::response& res,
    const std::string& urlClassID) {
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
}

inline void Server::routes_admin::deleteClass(const crow::request& req, crow::response& res, const std::string& classID) {
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
}

inline void Server::routes_admin::getAllUsers(const crow::request& req, crow::response& res) {
    auto f = [](const crow::request& req, crow::response& res){
        schoolManager schoolManager(_connectionPool, req);
        auto json = schoolManager.getUsers();
        res.body = json.dump();
        res.code = 200;
    };
    return verifier(req, res, f);
}

inline void Server::routes_admin::createNewUser(const crow::request& req, crow::response& res) {
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
}

inline void Server::routes_admin::deleteUser(const crow::request& req, crow::response& res, const std::string& userID) {
    auto f = [&](const crow::request& req, crow::response& res){
        schoolManager schoolManager(_connectionPool, req);
        schoolManager.userDrop(userID);
        res.code = 204;
    };
    return verifier(req, res, f);
}
inline void Server::routes_admin::resetPasswordOfUser(const crow::request& req, crow::response& res, const std::string& userID) {
    auto f = [&](const crow::request& req, crow::response& res) {
        schoolManager user(_connectionPool, req);
        if (!crow::json::load(req.body))
            throw api::exceptions::parseErr("Not parseble body. Is it json?");

        crow::json::rvalue json = crow::json::load(req.body);
        if (!json.has("new_password") || json["new_password"].t() != crow::json::type::String)
            throw api::exceptions::wrongRequest("Request doesnt has new_password field "
                                                "or it is in wrong type (expected string)");
        const std::string& newPassword = json["new_password"].s();
        user.userResetPassword(userID, newPassword);
        res.code = 204;
    };
    return verifier(req, res, f);
}


inline void Server::routes_admin::getDataForToday(const crow::request& req, crow::response& res) {
    auto f = [](const crow::request& req, crow::response& res){
        schoolManager schoolManager(_connectionPool, req);
        auto json = schoolManager.getDataForToday();
        res.body = json.dump();
    };
    return verifier(req, res, f);
}

inline void Server::routes_admin::getDataForDate(const crow::request& req, crow::response& res, const std::string& date) {
    auto f = [&](const crow::request& req, crow::response& res){
        schoolManager schoolManager(_connectionPool, req);
        crow::json::wvalue data;

        data["data"] = schoolManager.getDataForDate(date);
        data["date"] = date;

        res.body = data.dump();
    };
    return verifier(req, res, f);
}

inline void Server::routes_admin::getDataSummary(const crow::request& req, crow::response& res) {
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
}

inline void Server::routes_admin::grantRolesToUser(const crow::request& req, crow::response& res,
    const std::string& userID) {
    auto f = [&](const crow::request& req, crow::response& res) {
        schoolManager user(_connectionPool, req);
        std::vector<std::string> roles;

        //Checking request body
        if (!crow::json::load(req.body))
            throw api::exceptions::parseErr("Not parseble request body. Is it json?");

        crow::json::rvalue json = crow::json::load(req.body);
        if (!json.has("roles") || json["roles"].t() != crow::json::type::List)
            throw api::exceptions::wrongRequest("No roles field or it is not a array");

        //Iterating through array
        for (const auto& el : json["roles"])
            roles.emplace_back(el.s());
        user.userGrantRoles(userID, roles);
    };
    return verifier(req, res, f);
}

inline void Server::routes_admin::degrantRolesToUser(const crow::request& req, crow::response& res,
    const std::string& userID) {
    auto f = [&](const crow::request& req, crow::response& res) {
        schoolManager user(_connectionPool, req);
        std::vector<std::string> roles;

        //Checking request body
        if (!crow::json::load(req.body))
            throw api::exceptions::parseErr("Not parseble request body. Is it json?");

        crow::json::rvalue json = crow::json::load(req.body);
        if (!json.has("roles") || json["roles"].t() != crow::json::type::List)
            throw api::exceptions::wrongRequest("No roles field or it is not a array");

        //Iterating through array
        for (const auto& el : json["roles"])
            roles.emplace_back(el.s());
        user.userDegrantRoles(userID, roles);
    };
    return verifier(req, res, f);
}

inline void Server::routes_admin::grantClassesToUser(const crow::request& req, crow::response& res,
    const std::string& userID) {
    auto f = [&](const crow::request& req, crow::response& res) {
        schoolManager user(_connectionPool, req);
        std::vector<std::string> classes;

        //Checking request body
        if (!crow::json::load(req.body))
            throw api::exceptions::parseErr("Not parseble request body. Is it json?");

        crow::json::rvalue json = crow::json::load(req.body);
        if (!json.has("classes") || json["classes"].t() != crow::json::type::List)
            throw api::exceptions::wrongRequest("No classes field or it is not a array");

        //Iterating through array
        for (const auto& el : json["classes"])
            classes.emplace_back(el.s());

        user.userGrantClass(userID, classes);
        res.code = 201;
    };
    return verifier(req, res, f);
}

inline void Server::routes_admin::degrantClassesToUser(const crow::request& req, crow::response& res,
    const std::string& userID) {
    auto f = [&](const crow::request& req, crow::response& res) {
        schoolManager user(_connectionPool, req);
        std::vector<std::string> classes;
        if (!crow::json::load(req.body))
            throw api::exceptions::parseErr("Not parseble request body. Is it json?");

        crow::json::rvalue json = crow::json::load(req.body);
        if (!json.has("classes") || json["classes"].t() != crow::json::type::List)
            throw api::exceptions::wrongRequest("No classes field");

        //Iterating through array
        for (const auto& el : json["classes"])
            classes.emplace_back(el.s());

        user.userDegrantClass(userID, classes);
        res.code = 201;
    };
    return verifier(req, res, f);
}

inline void Server::routes_admin::getAllInvites(const crow::request& req, crow::response& res) {
    auto f = [](const crow::request& req, crow::response& res) {
        schoolManager user(_connectionPool, req);
        auto invites = user.getAllInvites();
        res.body = invites.dump();
        return res.end();
    };
    return verifier(req,res, f);
}

inline void Server::routes_admin::createInvite(const crow::request& req, crow::response& res) {
    auto f = [](const crow::request& req, crow::response& res) {
        schoolManager user(_connectionPool, req);

        if (!crow::json::load(req.body))
            throw api::exceptions::parseErr("Not parseble request body. Is it json?");

        auto json = crow::json::load(req.body);
        if (!json.has("roles") || !json.has("classes") || !json.has("name"))
            throw api::exceptions::wrongRequest("Body doesnt have roles, classes or name field");

        user.inviteCreate(req.body);
        return res.end();
    };
    return verifier(req,res, f);
}
inline void Server::routes_admin::dropInvite(const crow::request& req, crow::response& res, const std::string& inviteID) {
    auto f = [&](const crow::request& req, crow::response& res) {
        schoolManager user(_connectionPool, req);

        user.inviteDrop(inviteID);
        return res.end();
    };
    return verifier(req,res, f);
}


inline bool Server::isValidJWT(const std::string& userjwt, const std::string& _jwtSecret) {

    jwt::verifier verify = jwt::verify();
    verify.allow_algorithm(jwt::algorithm::hs256(_jwtSecret));
    verify.with_issuer("Floaty");

    jwt::decoded_jwt decoded_token = jwt::decode(userjwt);
    pqxx::connection* c = _connectionPool->getConnection();
    try {
        verify.verify(decoded_token);

        // * check exp time
        {
            auto exp = decoded_token.get_payload_claim("exp").as_int();

            auto exp_time_t = std::chrono::system_clock::from_time_t(exp);
            auto now = std::chrono::system_clock::now();

            if (now > exp_time_t)
                throw jwt::token_verification_exception();
        }

        pqxx::read_transaction rtx(*c);

        auto token_user_id = decoded_token.get_subject();
        auto token_school_id = decoded_token.get_payload_claim("aud").as_string();

        const std::string& token_user_id_decoded = rtx.exec_prepared1("decode", token_user_id).front().as<std::string>();
        const std::string& token_school_id_decoded = rtx.exec_prepared1("decode", token_school_id).front().as<std::string>();
        // * check org_id
        {
            auto school_id = rtx.exec_prepared1("school_id_get", token_user_id_decoded).front().as<std::string>();

            if (token_school_id_decoded != school_id)
                throw jwt::token_verification_exception();
        }

        // * check roles
        {
            picojson::array token_roles = decoded_token.get_payload_claim("roles").as_array();

            const std::string& user_id_decoded = rtx.exec_prepared1("decode", token_user_id).front().as<std::string>();
            picojson::array available_roles;
            auto roles = rtx.exec_prepared("user_roles_get", token_school_id_decoded, user_id_decoded);

            if (!roles.empty()) {
                for (auto role : roles) {
                    available_roles.emplace_back(role.front().as<std::string>());
                }
            }
            if (token_roles != available_roles)
                throw jwt::token_verification_exception();
        }
        // Check classes
        {
            picojson::array token_classes = decoded_token.get_payload_claim("classes").as_array();

            const std::string& user_id_decoded = rtx.exec_prepared1("decode", token_user_id).front().as<std::string>();
            picojson::array available_classes;
            auto classes = rtx.exec_prepared("user_classes_get", token_school_id_decoded, user_id_decoded);
            if (!classes.empty()) {
                for (auto class_v : classes) {
                    available_classes.emplace_back(class_v.front().as<std::string>());
                }
            }
            if (token_classes != available_classes)
                throw jwt::token_verification_exception();
        }
        _connectionPool->releaseConnection(c);
        return true;
    }
    catch (jwt::error::signature_verification_error& e) {
        std::cerr << "Signature verif. err: " << e;
    }
    catch (const std::runtime_error& e) {
        std::cerr << "Exception. Data may changed. Err: " << e.what() << '\n';
    }
    catch (std::exception &e) {
        std::cerr << "Excp. is: " << e.what();
    }
    _connectionPool->releaseConnection(c);
    return false;
}

inline std::string Server::hashSHA256(const std::string& input) {
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
//todo set 201 to 204 in grant classes