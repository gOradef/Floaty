//
// Created by goradef on 15.06.2024.
//
#include "Floaty/connectionpool.h"

#include "Floaty/api_route.h"


ConnectionPool::ConnectionPool(const std::string& connection_string, int pool_size) {
    for (int i = 0; i < pool_size; ++i) {
        auto *c = new pqxx::connection(connection_string);

        // ### Encoding methods
        c->prepare(psqlMethods::encodingMethods::encode, "select encode($1, 'hex')");
        c->prepare(psqlMethods::encodingMethods::decode, "select convert_from(decode($1, 'hex'), 'UTF-8')");

        //Chechers
        c->prepare(psqlMethods::userChechMethods::isLoginOccupied, "select EXISTS(select 1 from users where login = $1)");
        c->prepare(psqlMethods::userChechMethods::isUserExists, "select exists (select 1 from users where school_id = $1::uuid and id = $2::uuid)");
        c->prepare(psqlMethods::userChechMethods::isValidUser, "SELECT * from is_valid_user($1::text, $2::text)"); //return bool and user_id in different rows
        c->prepare(psqlMethods::userChechMethods::isUserHasRole, "select is_user_has_role($1::uuid, $2::uuid, $3::text)");


        c->prepare(psqlMethods::userDataGetters::getUserName, "select name from users where school_id = $1::uuid"
                                    " and id = $2::uuid");
        c->prepare(psqlMethods::userDataGetters::getUserRoles, "SELECT * from user_roles_get($1::uuid, $2::uuid)"); //return many rows of roles
        c->prepare(psqlMethods::userDataGetters::getSchoolId, "select school_id_get($1::uuid)");
        c->prepare(psqlMethods::userDataGetters::getUserClasses, "select * from user_classes_get($1::uuid, $2::uuid)");
        c->prepare(psqlMethods::userDataGetters::getClassStudents, "select class_students_get($1::uuid, $2::uuid, $3::uuid)");

        // Global | Requests
        c->prepare(psqlMethods::isDate, "select is_date($1)");


        // * Class Handler
        c->prepare(psqlMethods::classHandler::checks::isClassOwned, "select is_class_owned($1::uuid, $2::uuid, uuid_or_null($3))");
        c->prepare(psqlMethods::classHandler::checks::isClassExists, "select is_class_exists($1::uuid, uuid_or_null($2))");


        //set [add, remove] students
        {
        c->prepare(psqlMethods::classHandler::students::addStudents, "call class_students_add("
                                              "$1::uuid, "
                                              "$2::uuid, "
                                              "$3::uuid, "
                                              "$4::text[]"
                                              ")");
        c->prepare(psqlMethods::classHandler::students::removeStudents, "call class_students_remove("
                                                 "$1::uuid, "
                                                 "$2::uuid, "
                                                 "$3::uuid, "
                                                 "$4::text[]"
                                                 ")");

        }

        //set [add, remove] fstudents
        {
            c->prepare(psqlMethods::classHandler::students::addFStudents, "call class_fstudents_add("
                                              "$1::uuid, $2::uuid, "
                                              "$3::uuid, $4::text[])");
            c->prepare(psqlMethods::classHandler::students::removeFStudents, "call class_fstudents_remove("
                                                     "$1::uuid, $2::uuid, "
                                                     "$3::uuid, $4::text[])");
        }

        //Includes check on existing data. If data in null -> generates by self
        c->prepare(psqlMethods::classHandler::data::insertData, "call class_data_insert($1::uuid,$2::uuid,$3::jsonb)");
        c->prepare(psqlMethods::classHandler::data::getInsertedData, "select class_data_get($1::uuid,$2::uuid,$3::date)");


        // Region schoolManager - admin

        //* Classes interface

        c->prepare(psqlMethods::schoolManager::classes::getAllClasses,"select * from school_classes_get($1::uuid)");
        c->prepare(psqlMethods::schoolManager::classes::getClassStudents, "select * from school_class_students_get($1::uuid, $2::uuid)");
        c->prepare(psqlMethods::schoolManager::classes::createClass, "call class_create($1::uuid, $2::uuid, $3::text)");
        c->prepare(psqlMethods::schoolManager::classes::dropClass, "call class_drop($1::uuid, $2::uuid)");
        c->prepare(psqlMethods::schoolManager::classes::renameClass, "call class_rename($1::uuid, $2::uuid, $3::text)");

        //* Users interface
        c->prepare(psqlMethods::schoolManager::users::getAllUsers, "select * from school_users_get($1::uuid)");
        c->prepare(psqlMethods::schoolManager::users::createUser, "call user_create($1::uuid, $2::text, $3::text, $4::text)");
        c->prepare(psqlMethods::schoolManager::users::createUserWithContext, "call user_create_with_context("
                                               "$1::uuid, $2::text, $3::text, $4::text, "
                                               "null_to_array($5::text[]), "
                                               "null_to_array($6::text[])"
                                               ")");
        c->prepare(psqlMethods::schoolManager::users::grantClassToUser, "call school_user_classes_grant($1::uuid, $2::uuid, $3::uuid[])");
        c->prepare(psqlMethods::schoolManager::users::degrantClassToUser, "call school_user_classes_degrant($1::uuid, $2::uuid, $3::uuid[])");
        c->prepare(psqlMethods::schoolManager::users::dropUser ,"call school_user_drop($1::uuid,uuid_or_null($2))");
        //get | edi data for admin

        //Region data

        c->prepare(psqlMethods::schoolManager::data::isSchoolDataExists, "select is_school_data_exists($1::uuid, $2::date)");
        c->prepare(psqlMethods::schoolManager::data::getSchoolData, "select * from school_data_get($1::uuid, $2::date)");
        c->prepare(psqlMethods::schoolManager::data::getSchoolSummarizedData, "select * from school_data_summarized_get($1::uuid, jsonb_build_object('start_date', $2::date, 'end_date', $3::date ))");

        connections.push_back(c);
    }
}

pqxx::connection *ConnectionPool::getConnection() {
    std::lock_guard<std::mutex> lock(mtx);
    pqxx::connection* conn = connections.back();
    connections.pop_back();
    return conn;
}

void ConnectionPool::releaseConnection(pqxx::connection *conn) {
    std::lock_guard<std::mutex> lock(mtx);
    connections.push_back(conn);

}
ConnectionPool::~ConnectionPool() {
    for (auto conn : connections) {
        delete conn;
    }
}
