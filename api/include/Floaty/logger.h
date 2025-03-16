//
// Created by goradef on 07.03.2025.
//

#ifndef LOGGER_H
#define LOGGER_H
#include <crow/json.h>

#include "connectionpool.h"


// class loggerData {
      //     void foo() {
      //
      //     }
      //     // update data for date
      // };
      // class loggerClasses {
      //     pqxx::params user_data{_org_id, _user_id};
      //     /*
      //      * create
      //      * edit
      //      *  name
      //      *  students
      //      *  owners
      //      * delete
      //      */
      //     void logCreateClass(const std::string& classconst std::string& className) {
      //         pqxx::params updated {"", ""};
      //         pqxx::params p = {user_data, updated};
      //
      //     }
      // };
      // class loggerUsers {
      //     /*
      //      * create
      //      * edit
      //      *  name
      //      *  roles
      //      *  password
      //      *  classes
      //      * delete
      //      */
      // };
      // class loggerInvites {
      //     /*
      //      * create
      //      * delete
      //      */
      // };

struct baseUserData {
    std::string _org_id;
    std::string _user_id;
    std::optional<std::string> _object_id;

    baseUserData(const std::string& org_id, const std::string& user_id, const std::string& object_id) {
        this->_org_id = org_id;
        this->_user_id = user_id;
        this->_object_id = object_id;
    };
};

class psqlLogger {

protected:
    /// @warning expects to be writeble
    pqxx::transaction_base *work;

    baseUserData *baseUserDataCreds;

public:
    explicit psqlLogger(pqxx::transaction_base *work, const std::string& _org_id, const std::string& _user_id, const std::string& _object_id = "") {
        this->work = work;

        baseUserDataCreds = new baseUserData(_org_id, _user_id, _object_id);
    }
    ~psqlLogger() {
        delete baseUserDataCreds;
    }
};



class loggerClassHandler : psqlLogger {

public:
    explicit loggerClassHandler(pqxx::transaction_base* work, const std::string& _org_id, const std::string& _user_id, const std::string& _object_id) :
        psqlLogger(work, _org_id, _user_id, _object_id) {}


    void logInsertData(const std::string& insertedData) const {
        // const pqxx::params& userData = {
        //     baseUserDataCreds::_org_id,
        //     baseUserDataCreds::_user_id,
        //
        //     categories::data,
        //     operations::edit,
        //     changedProps::none,
        //
        //     baseUserDataCreds::_object_id,
        //     insertedData};

        // Set current date to json
        crow::json::wvalue json;
        json["absent"] = crow::json::load(insertedData)["absent"];
        json["date"] = work->query_value<std::string>("select CURRENT_DATE");

        work->exec(psqlMethods::logger::log, {
                baseUserDataCreds->_org_id,
                baseUserDataCreds->_user_id,

                "data",
                "edit",
                "absent",

                baseUserDataCreds->_object_id,
                json.dump()
            });
    }
    void logUpdateStudentsList(const std::string& studBranch) const {
        work->exec(psqlMethods::logger::log, {
            baseUserDataCreds->_org_id,
            baseUserDataCreds->_user_id,
            "classes",
            "edit",
            "students",
            baseUserDataCreds->_object_id,
            studBranch});
    }

};


class loggerAdmin : psqlLogger {

public:
    explicit loggerAdmin(pqxx::transaction_base* work, const std::string& _org_id, const std::string& _user_id) :
        psqlLogger(work, _org_id, _user_id) {}

    //* data

        void logEditDataForToday(const std::string& classID, const std::string& data) const {

            // Set current date to json
            crow::json::wvalue json;
            json["absent"] = crow::json::load(data)["absent"];
            json["date"] = work->query_value<std::string>("select CURRENT_DATE");

            work->exec(psqlMethods::logger::log, {
                baseUserDataCreds->_org_id,
                baseUserDataCreds->_user_id,
                "data",
                "edit",
                "absent",
                classID,
                json.dump()
            });
        } //classid, data

        void logEditDataForDate(const std::string& classID, const std::string& data, const std::string& date) const {

            // Set current date to json
            crow::json::wvalue json;
            json["absent"] = crow::json::load(data)["absent"];
            json["date"] = date;

            work->exec(psqlMethods::logger::log, {
                baseUserDataCreds->_org_id,
                baseUserDataCreds->_user_id,
                "data",
                "edit",
                "absent",
                classID,
                json.dump()
            });
        } //classid, data

    //* classes


    void logClassCreate(const std::string& className, const std::optional<std::string>& owner_id) const {

        crow::json::wvalue json;
        json["name"] = className;
        if (owner_id.has_value())
            json["owner_id"] = owner_id.value();
        else
            json["owner_id"] = nullptr;

        work->exec(psqlMethods::logger::log, {
            baseUserDataCreds->_org_id,
            baseUserDataCreds->_user_id,
            "classes",
            "create",
            nullptr,
            nullptr,
            json.dump()
        });
    }

    //* Edit class
        void logClassSetNewName(const std::string& classID, const std::string& newName) const {

        crow::json::wvalue json;
        json["name"] = newName;

        work->exec(psqlMethods::logger::log, {
            baseUserDataCreds->_org_id,
            baseUserDataCreds->_user_id,
            "classes",
            "edit",
            "name",
            classID,
            json.dump()
        });

    }
    void logClassSetStudentsList(const std::string& classID, const std::string& studentsBranch) const {
        work->exec(psqlMethods::logger::log, {
            baseUserDataCreds->_org_id,
            baseUserDataCreds->_user_id,
            "classes",
            "edit",
            "students",
            classID,
            studentsBranch
        });
    }
    void logClassSetOwners(const std::string& classID, const std::vector<std::string>& newOwners) const {

        crow::json::wvalue json;
        json["owners"] = newOwners;

        work->exec(psqlMethods::logger::log, {
            baseUserDataCreds->_org_id,
            baseUserDataCreds->_user_id,
            "classes",
            "edit",
            "owners",
            classID,
            json.dump()
        });

    }

    void logClassDelete(const std::string& classID) const {
        const auto& class_body = work->exec(psqlMethods::schoolManager::classes::getClassBody, {baseUserDataCreds->_org_id, classID}).one_field().as<std::string>();

        work->exec(psqlMethods::logger::log, {
            baseUserDataCreds->_org_id,
            baseUserDataCreds->_user_id,
            "classes",
            "delete",
            nullptr,
            classID,
            class_body
        });
    }

    //todo creds in api.cpp is in crow::json::RVALUE fix it to string
    void logUserCreate(const std::string& userData) const {
        work->exec(psqlMethods::logger::log, {
            baseUserDataCreds->_org_id,
            baseUserDataCreds->_user_id,
            "users",
            "create",
            nullptr,
            nullptr,
            userData
        });
    }
    void logUserSetName(const std::string& userID, const std::string& newUserName) const {
        crow::json::wvalue json;
        json["name"] = newUserName;

        work->exec(psqlMethods::logger::log, {
            baseUserDataCreds->_org_id,
            baseUserDataCreds->_user_id,
            "users",
            "edit",
            "name",
            userID,
            json.dump()
        });
    }
    void logUserSetRoles(const std::string& userID, const std::vector<std::string>& roles) const {
        crow::json::wvalue json;
        json["roles"] = roles;

        work->exec(psqlMethods::logger::log, {
            baseUserDataCreds->_org_id,
            baseUserDataCreds->_user_id,
            "users",
            "edit",
            "roles",
            userID,
            json.dump()
        });

    }
    void logUserSetOwnedClasses(const std::string& userID, const std::vector<std::string>& classes) const {
        crow::json::wvalue json;
        json["classes"] = classes;

        work->exec(psqlMethods::logger::log, {
            baseUserDataCreds->_org_id,
            baseUserDataCreds->_user_id,
            "users",
            "edit",
            "classes",
            userID,
            json.dump()
        });
    }
    ///@brief DOES NOT saves  password of user
    void logUserSetPassword(const std::string& userID) const {
        // crow::json::wvalue json;
        // json["password"] = password;

        work->exec(psqlMethods::logger::log, {
            baseUserDataCreds->_org_id,
            baseUserDataCreds->_user_id,
            "users",
            "edit",
            "password",
            userID,
            nullptr
        });
    }
    void logUserDelete(const std::string& userID) const {
        const auto& user_body = work->exec(psqlMethods::schoolManager::users::getUserBody, {baseUserDataCreds->_org_id, userID}).one_field().as<std::string>();

        work->exec(psqlMethods::logger::log, {
            baseUserDataCreds->_org_id,
            baseUserDataCreds->_user_id,
            "users",
            "delete",
            nullptr,
            userID,
            user_body
        });
    }


    void logInviteCreate(const std::string& inviteProps) const { 
        work->exec(psqlMethods::logger::log, {
            baseUserDataCreds->_org_id,
            baseUserDataCreds->_user_id,
            "invites",
            "create",
            nullptr,
            nullptr,
            inviteProps
        });

    }
    ///@warning Invite should be exists in moment of call that foo()
    void logInviteDelete(const std::string& inviteID) const {
        const auto& invite_body = work->exec(psqlMethods::invites::getProperties, {baseUserDataCreds->_org_id, inviteID}).one_field();

        crow::json::wvalue json;
        json["invite_id"] = inviteID;
        json["invite_body"] = crow::json::load(invite_body.as<std::string>());


        work->exec(psqlMethods::logger::log, {
              baseUserDataCreds->_org_id,
              baseUserDataCreds->_user_id,
              "invites",
              "delete",
              nullptr,
              nullptr,
              json.dump()
          });

    }
    // struct invites {
    //     const std::string& category = "invites";
    //
    // };
};

#endif //LOGGER_H
