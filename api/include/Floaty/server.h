//
// Created by goradef on 15.08.2024. Contains functios for routing
//
// ReSharper disable CppDeclarationHidesLocal
#pragma once

#define v(function, ...) \
[](const auto& req, auto& res, ##__VA_ARGS__) { \
    verifier(req, res, [&](const auto& req, auto& res) { \
        function; \
    }); \
}

/**
 *
 * @param request crow::request
 */
#define checkRequestBodyForJson(request) \
    if (!crow::json::load(request.body)) \
        throw api::exceptions::parseErr("Is request body is json format?");

#define checkFieldForEmptiness(json, fieldName) \
    if (json[fieldName].s() == "") \
        throw api::exceptions::requiredFieldIsEmpty(fieldName);

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
            catch (api::exceptions::MissingRequiredField& e) {
                crow::json::wvalue json;
                json["type"] = "Json parse error";
                json["context"] = "Json doesnt have needed field: " + std::string(e.what());
                res.body = json.dump();
                res.code = 403;
            }
            catch (api::exceptions::InvalidJsonSchema& e) {
                crow::json::wvalue json;
                json["type"] = "Json Schema error";
                json["context"] = "Json field type is different from expections: " + std::string(e.field()) +
                    " is not: " + std::string(e.getExpectedFieldType());
                res.body = json.dump();
                res.code = 403;
            }
            catch (api::exceptions::requiredFieldIsEmpty& e) {
                crow::json::wvalue json;
                json["type"] = "Request error";
                json["context"] = "Json field type should not be empty: " + std::string(e.field());
                res.body = json.dump();
                res.code = 400;
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

    static void checkFieldForExistingAndType(const crow::json::rvalue& jsonRoot, const std::string& fieldName, const crow::json::type& expectedType) {
        if (!jsonRoot.has(fieldName))
            throw api::exceptions::MissingRequiredField(fieldName);
        if (jsonRoot[fieldName].t() != expectedType)
            throw api::exceptions::InvalidJsonSchema(fieldName, get_type_str(expectedType));
    }
    //* API methods
    struct routes_auth {
        static void login(const crow::request& req, crow::response& res);

        static void refreshToken(const crow::request& req, crow::response& res);

        static void getOrgInformation(const crow::request& req, crow::response& res, const std::string& schoolID);

        static void getInviteProps(const crow::request& req, crow::response& res, const std::string& schoolID,
            const std::string& invite_code);

        static void signupUsingInvite(const crow::request& req, crow::response& res, const std::string& schoolID);
    };

    //* Routing api methods
    static void route_auth();
    static void route_user();
    static void route_classHandler();
    static void route_admin();
public:
    Server(const std::string& address, const int& port, ConnectionPool* cp);

    static void initRoutes();

    static void run();
};
