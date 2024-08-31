//
// Created by goradef on 15.08.2024.
//

#include "Floaty/server.h"

using Session = crow::SessionMiddleware<crow::InMemoryStore>;

crow::App<crow::CookieParser, Session, appMiddlewareJSON> Server::app {
    Session {
        crow::CookieParser::Cookie("session").max_age(/*one day*/ 24 * 60 * 60).path("/"),
        // set session id length (small value only for demonstration purposes)
        64,
        // init the store
        crow::InMemoryStore{}
}};
ConnectionPool* Server::_connectionPool;

inline void Server::route_auth() {
    CROW_ROUTE(app, "/api/login")
        .methods(crow::HTTPMethod::POST)
        (routes_auth::login);

    CROW_ROUTE(Server::app, "/api/refresh-token")
    .methods(crow::HTTPMethod::POST)
    (routes_auth::refreshToken);

    CROW_ROUTE(app, "/api/signup/invite/<string>")
    .methods(crow::HTTPMethod::GET)
    (routes_auth::getInviteProps);

    CROW_ROUTE(app, "/api/signup/invite/<string>")
    .methods(crow::HTTPMethod::POST)
    (routes_auth::signupUsingInvite);
}
inline void Server::route_user() {
    CROW_ROUTE(app, "/api/roles")
        .methods(crow::HTTPMethod::GET)
        (routes_user::getUserRoles);

    CROW_ROUTE(app, "/api/user/classes")
    .methods(crow::HTTPMethod::GET)
    (routes_user::getUserClasses);

    //Get data of class
    // CROW_ROUTE(app, "/api/user/classes/<string>")
    // .methods(crow::HTTPMethod::GET)([](const crow::request &req, crow::response &res, const std::string& classID){
    //     auto f = [&](const crow::request& req, crow::response& res){
    //         classHandler user(_connectionPool, req, classID);
    //         crow::json::wvalue studentsJson = user.getClassStudents();
    //         res.body = studentsJson.dump();
    //     };
    //
    //     return verifier(req, res, f);
    // });

}
inline void Server::route_classHandler() {
    CROW_ROUTE(app, "/api/user/classes/<string>/students")
    .methods(crow::HTTPMethod::GET)
    (routes_classHandler::getStudents);

    /**
    * @brief Edit list of students
    * @example [f]students: []
    */
    CROW_ROUTE(app, "/api/user/classes/<string>/students")
    .methods(crow::HTTPMethod::PUT)
    (routes_classHandler::insertStudents);

    // Get inserted data for today
    CROW_ROUTE(app, "/api/user/classes/<string>/data")
    .methods(crow::HTTPMethod::GET)
    (routes_classHandler::getDataForToday);

    // Get inserted class data for date
    CROW_ROUTE(app, "/api/user/classes/<string>/data/<string>")
    .methods(crow::HTTPMethod::GET)
    (routes_classHandler::getDataForDate);

    //Insert data for class
    CROW_ROUTE(app, "/api/user/classes/<string>/data")
    .methods(crow::HTTPMethod::PUT)
    (routes_classHandler::insertData);
}
inline void Server::route_admin() {
    // Get all classes
    CROW_ROUTE(app, "/api/org/classes")
    .methods(crow::HTTPMethod::GET)
    (routes_admin::getAllClasses);

    //Get list of students for class
    CROW_ROUTE(app, "/api/org/classes/<string>/students")
    .methods(crow::HTTPMethod::GET)
    (routes_admin::getStudentsForClass);

    // Creates class with or without owner depending onto url_param
    CROW_ROUTE(app, "/api/org/classes")
    .methods(crow::HTTPMethod::POST)
    (routes_admin::createNewClass);

    // Creates class with or without owner depending onto url_param
    CROW_ROUTE(app, "/api/org/classes/<string>/students")
    .methods(crow::HTTPMethod::PUT)
    (routes_admin::updateStudetsForClass);

    // Rename class
    CROW_ROUTE(app, "/api/org/classes/<string>")
    .methods(crow::HTTPMethod::PATCH)
    (routes_admin::renameClass);

    // Delete class
    CROW_ROUTE(app, "/api/org/classes/<string>")
    .methods(crow::HTTPMethod::DELETE)
    (routes_admin::deleteClass);

    //Region Users
    // Get list of all users
    CROW_ROUTE(app, "/api/org/users")
    .methods(crow::HTTPMethod::GET)
    (routes_admin::getAllUsers);

    // Create new user
    CROW_ROUTE(app, "/api/org/users")
    .methods(crow::HTTPMethod::POST)
    (routes_admin::createNewUser);

    // Global edit user (classes, roles)
    CROW_ROUTE(app, "/api/org/users/<string>")
    .methods(crow::HTTPMethod::PUT)
    (routes_admin::editUser);

    // Update password of user
    CROW_ROUTE(app, "/api/org/users/<string>/password")
    .methods(crow::HTTPMethod::PATCH)
    (routes_admin::resetPasswordOfUser);

    // Delete user
    CROW_ROUTE(app, "/api/org/users/<string>")
    .methods(crow::HTTPMethod::DELETE)
    (routes_admin::deleteUser);

    //Region data
    CROW_ROUTE(app, "/api/org/data")
    .methods(crow::HTTPMethod::GET)
    (routes_admin::getDataForToday);

    CROW_ROUTE(app, "/api/org/data/<string>")
    .methods(crow::HTTPMethod::GET)
    (routes_admin::getDataForDate);

    CROW_ROUTE(app, "/api/org/data-summary")
    .methods(crow::HTTPMethod::GET)
    (routes_admin::getDataSummary);

    CROW_ROUTE(app, "/api/org/classes/<string>/data")
    .methods(crow::HTTPMethod::PUT)
    (routes_admin::updateDataAbsent);

    //Region invites
    //Get all invites
    CROW_ROUTE(app, "/api/org/invites")
    .methods(crow::HTTPMethod::GET)
    (routes_admin::getAllInvites);

    //todo get props of one invite

    //todo edit props of invite (set)

    //Create new invite
    CROW_ROUTE(app, "/api/org/invites")
    .methods(crow::HTTPMethod::POST)
    (routes_admin::createInvite);

    //Delete invite
    CROW_ROUTE(app, "/api/org/invites/<string>")
    .methods(crow::HTTPMethod::DELETE)
    (routes_admin::dropInvite);

}


void Server::initRoutes() {
    CROW_ROUTE(app, "/")([]() {
       return crow::response(200, "Hi. I am developed by sofware engineews. So, UwU");
    });


    route_auth();
    route_user();
    route_classHandler();
    route_admin();
}