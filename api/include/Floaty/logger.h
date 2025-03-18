//
// Created by goradef on 07.03.2025.
//

#ifndef LOGGER_H
#define LOGGER_H
#include <crow/json.h>

#include "connectionpool.h"


// #define getUserName(id) \
work->exec(psqlMethods::userData::getName, {baseUserDataCreds->_org_id, baseUserDataCreds->_user_id}).one_field().as<std::string>()

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

class baseLogger {

protected:
    /// @warning expects to be writeble
    pqxx::transaction_base *work;

    baseUserData *baseUserDataCreds;

public:
    explicit baseLogger(pqxx::transaction_base *work, const std::string& _org_id, const std::string& _user_id, const std::string& _object_id = "") {
        this->work = work;

        baseUserDataCreds = new baseUserData(_org_id, _user_id, _object_id);
    }
    ~baseLogger() {
        delete baseUserDataCreds;
    }
};



class loggerClassHandler : baseLogger {

public:
    explicit loggerClassHandler(pqxx::transaction_base* work, const std::string& _org_id, const std::string& _user_id, const std::string& _object_id) :
        baseLogger(work, _org_id, _user_id, _object_id) {}


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


class loggerAdmin : baseLogger {

public:
    explicit loggerAdmin(pqxx::transaction_base* work, const std::string& _org_id, const std::string& _user_id) :
        baseLogger(work, _org_id, _user_id) {}

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
        if (owner_id.has_value()) {
            json["owner"]["id"] = owner_id.value();
            json["owner"]["name"] = work->exec(psqlMethods::userData::getName, {baseUserDataCreds->_org_id, owner_id.value()}).one_field().as<std::string>();
        }
        else {
            json["owner"]["id"] = nullptr;
            json["owner"]["name"] = nullptr;
        }

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
        json["old"]["name"] = work->exec(psqlMethods::classes::getters::getClassName, {baseUserDataCreds->_org_id, classID}).one_field().as<std::string>();
        json["new"]["name"] = newName;

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
        crow::json::wvalue json;
        json["old"] = crow::json::load(work->exec(psqlMethods::userData::getClassStudents, {baseUserDataCreds->_org_id, classID}).one_field().as<std::string>());
        json["new"] = crow::json::load(studentsBranch);

        work->exec(psqlMethods::logger::log, {
            baseUserDataCreds->_org_id,
            baseUserDataCreds->_user_id,
            "classes",
            "edit",
            "students",
            classID,
            json.dump()
        });
    }
    ///@param  newOwners - users are exists
    void logClassSetOwners(const std::string& classID, const std::vector<std::string>& newOwners) const {

        crow::json::wvalue json;

        json["old"]["owners"] = crow::json::load(work->exec(psqlMethods::schoolManager::classes::getOwners, {baseUserDataCreds->_org_id, classID}).one_field().as<std::string>());

        // Preparing new owners into vector
        std::vector<crow::json::rvalue> newOwnersArray;
        for (auto& new_ownerID : newOwners) {
            crow::json::wvalue owner_root;
            owner_root["id"] = new_ownerID;
            owner_root["name"] = work->exec(psqlMethods::userData::getName, {baseUserDataCreds->_org_id, new_ownerID}).one_field().as<std::string>();
            newOwnersArray.emplace_back(crow::json::load(owner_root.dump()));
        }

        // Inserting new owners into result by array indexes
        for (size_t i = 0; i < newOwnersArray.size(); ++i) {
            json["new"]["owners"][i] = newOwnersArray[i];
        }


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

    void logUserCreate(const std::string& userData) const {
        crow::json::wvalue json = crow::json::load(userData);
        crow::json::rvalue json_rvalue = crow::json::load(userData);

        json["classes"] = std::vector<std::string>{};
        // Preparing new owners into vector
        std::vector<crow::json::rvalue> newClassesArray;
        for (const auto& new_classID : json_rvalue["classes"]) {
            crow::json::wvalue class_root;
            class_root["id"] = new_classID.s();
            class_root["name"] = work->exec(psqlMethods::classes::getters::getClassName, {baseUserDataCreds->_org_id, std::string(new_classID.s())}).one_field().as<std::string>();
            newClassesArray.emplace_back(crow::json::load(class_root.dump()));
        }

        // Inserting new owners into result by array indexes
        for (size_t i = 0; i < newClassesArray.size(); ++i) {
            json["classes"][i] = newClassesArray[i];
        }

        work->exec(psqlMethods::logger::log, {
            baseUserDataCreds->_org_id,
            baseUserDataCreds->_user_id,
            "users",
            "create",
            nullptr,
            nullptr,
            json.dump()
        });
    }
    void logUserSetName(const std::string& userID, const std::string& newUserName) const {
        crow::json::wvalue json;
        json["old"]["name"] = work->exec(psqlMethods::userData::getName, {baseUserDataCreds->_org_id, userID}).one_field().as<std::string>();
        json["new"]["name"] = newUserName;

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
        json["old"]["roles"] = crow::json::load(work->exec(psqlMethods::userData::getRoles, {baseUserDataCreds->_org_id, userID}).one_field().as<std::string>());
        json["new"]["roles"] = roles;

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
        json["old"]["classes"] = crow::json::load(work->exec(psqlMethods::userData::getClasses, {baseUserDataCreds->_org_id, userID}).one_field().as<std::string>());
        json["new"]["classes"] = std::vector<std::string>{};
        // Preparing new owners into vector
        std::vector<crow::json::rvalue> newClassesArray;
        for (const auto& new_classID : classes) {
            crow::json::wvalue class_root;
            class_root["id"] = new_classID;
            class_root["name"] = work->exec(psqlMethods::classes::getters::getClassName, {baseUserDataCreds->_org_id, new_classID}).one_field().as<std::string>();
            newClassesArray.emplace_back(crow::json::load(class_root.dump()));
        }

        // Inserting new owners into result by array indexes
        for (size_t i = 0; i < newClassesArray.size(); ++i) {
            json["new"]["classes"][i] = newClassesArray[i];
        }


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
        crow::json::wvalue json = crow::json::load(inviteProps);
        crow::json::rvalue json_rvalue = crow::json::load(inviteProps);


        // Preparing new owners into vector
        std::vector<crow::json::rvalue> newClassesArray;
        for (const auto& new_classID : json_rvalue["classes"]) {
            crow::json::wvalue class_root;
            class_root["id"] = new_classID;
            class_root["name"] = work->exec(psqlMethods::classes::getters::getClassName, {baseUserDataCreds->_org_id, std::string(new_classID.s())}).one_field().as<std::string>();
            newClassesArray.emplace_back(crow::json::load(class_root.dump()));
        }

        // Inserting new owners into result by array indexes
        for (size_t i = 0; i < newClassesArray.size(); ++i) {
            json["classes"][i] = newClassesArray[i];
        }


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
        json["invite"]["id"] = inviteID;
        json["invite"]["body"] = crow::json::load(invite_body.as<std::string>());


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
