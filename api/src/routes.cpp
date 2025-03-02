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

    CROW_ROUTE(app, "/api/org/<string>/info")
    .methods(crow::HTTPMethod::GET)
    (routes_auth::getOrgInformation);

    CROW_ROUTE(app, "/api/invite/<string>/<string>/<string>")
    .methods(crow::HTTPMethod::GET)
    (routes_auth::getInviteProps);

    CROW_ROUTE(app, "/api/signup/invite/<string>")
    .methods(crow::HTTPMethod::POST)
    (routes_auth::signupUsingInvite);
}
inline void Server::route_user() {
    // Get roles
    CROW_ROUTE(app, "/api/roles")
    .methods(crow::HTTPMethod::GET)
    (v({
      Request user(_connectionPool, req);
      auto roles = user.getRoles();
      crow::json::wvalue json;
      json["roles"] = roles;
      res.body = json.dump();
    }));

    // Get classes
    CROW_ROUTE(app, "/api/user/classes")
    .methods(crow::HTTPMethod::GET)
    (v({
        Request user(_connectionPool, req);
        crow::json::wvalue json;
        json["classes"] = user.getAvailibleClasses();

        res.body = json.dump();
    }));

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

    CROW_ROUTE(app, "/api/user/classes/<string>")
    .methods(crow::HTTPMethod::GET)
    (v({
        classHandler user(_connectionPool, req, classID);
        const crow::json::wvalue& classData = user.getClassProps();
        res.body = classData.dump();
    }, const std::string& classID));

    CROW_ROUTE(app, "/api/user/classes/<string>/students")
    .methods(crow::HTTPMethod::GET)
    (v({
        classHandler user(_connectionPool, req, classID);
        const crow::json::wvalue& studentsJson = user.getClassStudents();
        res.body = studentsJson.dump();
    }, const std::string& classID));

    /**
    * @brief Edit (set) list of students
    * @example [f]students: []
    */
    CROW_ROUTE(app, "/api/user/classes/<string>/students")
    .methods(crow::HTTPMethod::PUT)
    (v({
        classHandler user(_connectionPool, req, classID);

        checkRequestBodyForJson(req);

        user.updateClassStudents(req.body);
        res.code = 204;
    }, const std::string& classID));

    // Get inserted data for today
    CROW_ROUTE(app, "/api/user/classes/<string>/data")
    .methods(crow::HTTPMethod::GET)
    (v({
        classHandler user(_connectionPool, req, classID);
        crow::json::wvalue json;
        json["data"] = crow::json::load(user.getInsertedDataForToday().dump());
        res.body = json.dump();
    }, const std::string& classID));

    // Get inserted class data for date
    CROW_ROUTE(app, "/api/user/classes/<string>/data/<string>")
    .methods(crow::HTTPMethod::GET)
    (v({
        classHandler user(_connectionPool, req, classID);
        crow::json::wvalue json;
        json["data"] = user.getInsertedDataForDate(userDate);
        res.body = json.dump();
    }, const std::string& classID, const std::string& userDate));

    //Insert data for class
    CROW_ROUTE(app, "/api/user/classes/<string>/data")
    .methods(crow::HTTPMethod::PUT)
    (v({
        classHandler user(_connectionPool, req, classID);

        checkRequestBodyForJson(req);

        user.insertData(req.body);
        res.code = 204;
    }, const std::string& classID));
}
inline void Server::route_admin() {
    // Region classes
    // Get all classes
    CROW_ROUTE(app, "/api/org/classes")
    .methods(crow::HTTPMethod::GET)
    (v({
        schoolManager schoolManager(_connectionPool, req);
        const crow::json::wvalue& json = schoolManager.getClasses();
        res.body = json.dump();
    }));

    //Get list of students for class
    CROW_ROUTE(app, "/api/org/classes/<string>/students")
    .methods(crow::HTTPMethod::GET)
    (v({
        schoolManager schoolManager(_connectionPool, req);
        const crow::json::wvalue& json = schoolManager.getClassStudents(classID);
        res.body = json.dump();
    }, const std::string& classID));

    // Update list of students to class
    CROW_ROUTE(app, "/api/org/classes/<string>/students")
    .methods(crow::HTTPMethod::PUT)
    (v({
        schoolManager schoolManager(_connectionPool, req);

        checkRequestBodyForJson(req);

        schoolManager.updateClassStudents(classID, req.body);
        res.code = 204;
    }, const std::string& classID));

    // Creates class with or without owner depending onto url_param
    CROW_ROUTE(app, "/api/org/classes")
    .methods(crow::HTTPMethod::POST)
    (v({
        schoolManager schoolManager(_connectionPool, req);

        checkRequestBodyForJson(req);

        const crow::json::rvalue& json = crow::json::load(req.body);

        checkFieldForExistingAndType(json, "name", crow::json::type::String);
        checkFieldForEmptiness(json, "name");
        checkFieldForExistingAndType(json, "owner", crow::json::type::String);

        schoolManager.classCreate(json);
        res.code = 204;
    }));

    // Rename class
    CROW_ROUTE(app, "/api/org/classes/<string>/name")
    .methods(crow::HTTPMethod::PATCH)
    (v({
        schoolManager schoolManager(_connectionPool, req);

        checkRequestBodyForJson(req);
        const crow::json::rvalue& json = crow::json::load(req.body);

        // Checks for validality of req.body
        checkFieldForExistingAndType(json, "name", crow::json::type::String);

        checkFieldForEmptiness(json, "name");

        schoolManager.classRename(classID, json["name"].s());
        res.code = 204;

    }, const std::string& classID));

    CROW_ROUTE(app, "/api/org/classes/<string>/owners")
        .methods(crow::HTTPMethod::PATCH)
        (v({
            schoolManager schoolManager(_connectionPool, req);

            checkRequestBodyForJson(req);

            const crow::json::rvalue& json = crow::json::load(req.body);

            checkFieldForExistingAndType(json, "owners", crow::json::type::List);

            std::vector<std::string> newOwners;
            for (const auto& el : json["owners"]) {
                newOwners.emplace_back(el.s());
            }

            schoolManager.classSetOwners(classID, newOwners);
            res.code = 204;
        }, const std::string& classID));

    // Delete class
    CROW_ROUTE(app, "/api/org/classes/<string>")
    .methods(crow::HTTPMethod::DELETE)
    (v({
        schoolManager schoolManager(_connectionPool, req);
        schoolManager.classDrop(classID);
        res.code = 204;
    }, const std::string& classID));

    //Region Users
    // Get list of all users
    CROW_ROUTE(app, "/api/org/users")
    .methods(crow::HTTPMethod::GET)
    (v({
        schoolManager schoolManager(_connectionPool, req);
        const crow::json::wvalue& json = schoolManager.getUsers();
        res.body = json.dump();
        res.code = 200;
    }));

    // Create new user
    CROW_ROUTE(app, "/api/org/users")
    .methods(crow::HTTPMethod::POST)
    (v({
        schoolManager schoolManager(_connectionPool, req);

        checkRequestBodyForJson(req);

        const crow::json::rvalue& body = crow::json::load(req.body);

        // Check availbility of all fields
        for (const auto& schema : {"login", "password", "name", "roles", "classes"}) {
            if (!body.has(schema))
                throw api::exceptions::MissingRequiredField(schema);
        }

        for (const auto& schema : {"login", "password", "name"}) {
            if (body[schema].t() != crow::json::type::String)
                throw api::exceptions::InvalidJsonSchema(schema, "String");
        }

        // Check that roles and classes are lists
        for (const auto& schema : {"roles", "classes"}) {
            if (body[schema].t() != crow::json::type::List)
                throw api::exceptions::InvalidJsonSchema(schema, "List");
        }

        //Hashing login / password
        crow::json::wvalue hashedCreds(body);
        hashedCreds["login"] = hashSHA256(body["login"].s());
        hashedCreds["password"] = hashSHA256(body["password"].s());

        schoolManager.userCreate(crow::json::load(hashedCreds.dump()));
        res.code = 204;

    }));

    // Global edit user (classes, roles)
    CROW_ROUTE(app, "/api/org/users/<string>")
    .methods(crow::HTTPMethod::PUT)
    (v({
        schoolManager schoolManager(_connectionPool, req);

        checkRequestBodyForJson(req);

        schoolManager.userEdit(userID, crow::json::load(req.body));
        res.code = 204;
    }, const std::string& userID));

    // Update password of user
    CROW_ROUTE(app, "/api/org/users/<string>/password")
    .methods(crow::HTTPMethod::PATCH)
    (v({
        schoolManager user(_connectionPool, req);
        checkRequestBodyForJson(req);

        const crow::json::rvalue& json = crow::json::load(req.body);

        if (!json.has("password"))
            throw api::exceptions::MissingRequiredField("password");

        if (json["password"].t() != crow::json::type::String)
            throw api::exceptions::InvalidJsonSchema("password", "String");

        const std::string& newPassword = hashSHA256(json["password"].s());
        user.userResetPassword(userID, newPassword);
        res.code = 204;
    }, const std::string& userID));

    // Delete user
    CROW_ROUTE(app, "/api/org/users/<string>")
    .methods(crow::HTTPMethod::DELETE)
    (v({
        schoolManager schoolManager(_connectionPool, req);
        schoolManager.userDrop(userID);
        res.code = 204;
    }, const std::string& userID));

    //Region Data
    // Get today data
    CROW_ROUTE(app, "/api/org/data")
    .methods(crow::HTTPMethod::GET)
    (v({
        schoolManager schoolManager(_connectionPool, req);
        crow::json::wvalue json;
        json["data"] = schoolManager.getDataForToday();

        res.body = json.dump();
    }));

    // Get custom data
    CROW_ROUTE(app, "/api/org/data/<string>")
    .methods(crow::HTTPMethod::GET)
    (v({
        schoolManager schoolManager(_connectionPool, req);
        crow::json::wvalue data;

        data["data"] = crow::json::load(schoolManager.getDataForDate(date).dump());
        data["date"] = date;

        res.body = data.dump();
    }, const std::string& date));

    // Get summary of data
    CROW_ROUTE(app, "/api/org/data-summary")
    .methods(crow::HTTPMethod::GET)
    (v({
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
    }));

    // Create data for today
    CROW_ROUTE(app, "/api/org/data")
    .methods(crow::HTTPMethod::POST)
    (v({
        schoolManager schoolManager(_connectionPool, req);
        schoolManager.genDataForToday();
        res.code = 204;
    }));

    // Set absent_data for class for today
    CROW_ROUTE(app, "/api/org/classes/<string>/data")
    .methods(crow::HTTPMethod::PUT)
    (v({
        schoolManager schoolManager(_connectionPool, req);

        checkRequestBodyForJson(req);
        const crow::json::rvalue& json = crow::json::load(req.body);

        if (!json.has("absent"))
            throw api::exceptions::MissingRequiredField("absent");

        schoolManager.dataAbsentUpdate(classID, req.body);
        res.code = 204;
    }, const std::string& classID));

    // Set absent_data for class for custom date
    CROW_ROUTE(app, "/api/org/classes/<string>/data/<string>")
    .methods(crow::HTTPMethod::PUT)
    (v({
        schoolManager schoolManager(_connectionPool, req);

        checkRequestBodyForJson(req);

        const crow::json::rvalue& json = crow::json::load(req.body);
        if (!json.has("absent"))
            throw api::exceptions::MissingRequiredField("absent");

        schoolManager.dataAbsentUpdateForDate(classID, req.body, date);
        res.code = 204;
    }, const std::string& classID, const std::string& date));

    //Region invites
    //Get all invites
    CROW_ROUTE(app, "/api/org/invites")
    .methods(crow::HTTPMethod::GET)
    (v({
        schoolManager user(_connectionPool, req);
        const auto& invites = user.getAllInvites();
        res.body = invites.dump();
    }));


    //todo get props of one invite

    //todo edit props of invite (set)

    //Create new invite
    CROW_ROUTE(app, "/api/org/invites")
    .methods(crow::HTTPMethod::POST)
    (v({
        schoolManager user(_connectionPool, req);

        checkRequestBodyForJson(req);

        const crow::json::rvalue& json = crow::json::load(req.body);


        for (const auto& field : {"roles", "classes", "name"}) {
            if (!json.has(field))
                throw api::exceptions::MissingRequiredField(field);
        }

        if (json["roles"].t() != crow::json::type::List)
            throw api::exceptions::InvalidJsonSchema("roles", "List");

        if (json["classes"].t() != crow::json::type::List)
            throw api::exceptions::InvalidJsonSchema("classes", "List");

        user.inviteCreate(req.body);
        res.code = 204;
    }));


    //Delete invite
    CROW_ROUTE(app, "/api/org/invites/<string>")
    .methods(crow::HTTPMethod::DELETE)
    (v({
        schoolManager user(_connectionPool, req);

        user.inviteDrop(inviteID);
        res.code = 204;
    }, const std::string& inviteID));


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