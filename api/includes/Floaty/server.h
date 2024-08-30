//
// Created by goradef on 15.08.2024. Contains functios for routing
//
// ReSharper disable CppDeclarationHidesLocal
#pragma once

#include "api.h"
#include "crow/app.h"
#include "crow/middlewares/session.h"
#include "crow/middlewares/cookie_parser.h"
#include "jwt-cpp/jwt.h"

struct appMiddlewareJSON {
    struct context
    {};

    void before_handle(crow::request& req, crow::response& res, context& ctx)
    {}

    void after_handle(crow::request& req, crow::response& res, context& ctx) {
        res.add_header("Content-Type", "application/json");
    }
};

class Server {
    using Session = crow::SessionMiddleware<crow::InMemoryStore>;
    static crow::App<crow::CookieParser, Session, appMiddlewareJSON> app;
    static ConnectionPool* _connectionPool;

    //Init secrets for JWT tokens
    static const std::string& _jwtAccessSecret;
    static const std::string& _jwtRefreshSecret;


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
            catch (jwt::error::token_verification_error) {
                res.code = 401;
                res.body = {};
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
        static void updateStudetsForClass(const crow::request& req, crow::response& res, const std::string& classID);
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
        static void updateDataAbsent(const crow::request& req, crow::response& res, const std::string& classID);

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
