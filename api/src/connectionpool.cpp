//
// Created by goradef on 15.06.2024.
//
#include "Floaty/connectionpool.h"

#include "Floaty/api.h"


ConnectionPool::ConnectionPool(const std::string& connection_string, int pool_size) {
    for (int i = 0; i < pool_size; ++i) {
        auto c = std::make_unique<pqxx::connection>(connection_string);

        //* Encoding methods
        c->prepare(psqlMethods::encoding::encode, "select encode($1, 'hex')");
        c->prepare(psqlMethods::encoding::decode, "select convert_from(decode($1, 'hex'), 'UTF-8')");

        //* Chechers
        c->prepare(psqlMethods::userChecks::isLoginOccupied, "select EXISTS(select 1 from users where login = $1)");
        c->prepare(psqlMethods::userChecks::isExists, "select exists (select 1 from users where school_id = $1::uuid and id = $2::uuid)");
        c->prepare(psqlMethods::userChecks::isValid, "SELECT * from is_valid_user($1::text, $2::text)"); //return bool and user_id in different rows
        c->prepare(psqlMethods::userChecks::hasRole, "select is_user_has_role($1::uuid, $2::uuid, $3::text)");



        //* Invites
        c->prepare(psqlMethods::invites::isValid, "select is_invite_valid($1::uuid, $2, $3)");
        c->prepare(psqlMethods::invites::isExists, "select is_invite_exists($1::uuid, $2);");
        c->prepare(psqlMethods::invites::getAll, "select school_invite_get($1::uuid)");
        c->prepare(psqlMethods::invites::create, "call school_invite_create($1::uuid, $2::jsonb)");
        c->prepare(psqlMethods::invites::drop, "delete from schools_invites "
                                                  "where school_id = $1::uuid "
                                                  "and req_id = $2 ");
        c->prepare(psqlMethods::invites::archive, "call school_invite_archive($1::uuid, $2::text)");
        c->prepare(psqlMethods::invites::getProperties, "select school_invite_props_get($1::uuid, $2, $3)");

        c->prepare(psqlMethods::userData::getName, "select name from users where school_id = $1::uuid"
                                    " and id = $2::uuid");
        c->prepare(psqlMethods::userData::getRoles, "SELECT * from user_roles_get($1::uuid, $2::uuid)"); //return many rows of roles
        c->prepare(psqlMethods::userData::getSchoolId, "select school_id_get($1::uuid)");
        c->prepare(psqlMethods::userData::getClasses, "select * from user_classes_get($1::uuid, $2::uuid)");
        c->prepare(psqlMethods::userData::getClassProps, "select class_props_get($1::uuid, $2::uuid)");
        c->prepare(psqlMethods::userData::getClassStudents, "select class_students_get($1::uuid, $2::uuid, $3::uuid)");

        // Global
        c->prepare(psqlMethods::isDate, "select is_date($1)");
        c->prepare(psqlMethods::org::getData, "select school_org_data_get($1::text)");

        // * Class Handler
        c->prepare(psqlMethods::classes::checks::isOwned, "select is_class_owned($1::uuid, $2::uuid, uuid_or_null($3))");
        c->prepare(psqlMethods::classes::checks::isExists, "select is_class_exists($1::uuid, uuid_or_null($2))");


        //Includes check on existing data. If data in null -> generates by self
        c->prepare(psqlMethods::classes::data::getInsertedData, "select class_data_get($1::uuid,$2::uuid,$3::date)");
        c->prepare(psqlMethods::classes::data::insertData, "call class_data_insert($1::uuid,$2::uuid,$3::jsonb, current_date)");
        c->prepare(psqlMethods::classes::data::insertDataForDate, "call class_data_insert($1::uuid, $2::uuid, $3::jsonb, $4::date)");


        // Region schoolManager - admin

        //* Classes interface
        c->prepare(psqlMethods::schoolManager::classes::getAll,"select * from school_classes_get($1::uuid)");
        c->prepare(psqlMethods::schoolManager::classes::getStudents, "select * from school_class_students_get($1::uuid, $2::uuid)");
        c->prepare(psqlMethods::schoolManager::classes::create, "call class_create($1::uuid, $2::uuid, $3::text)");
        c->prepare(psqlMethods::schoolManager::classes::updateStudentList, "call class_students_set($1::uuid, $2::uuid, $3)");
        c->prepare(psqlMethods::schoolManager::classes::drop, "call class_drop($1::uuid, $2::uuid)");
        c->prepare(psqlMethods::schoolManager::classes::rename, "call class_rename($1::uuid, $2::uuid, $3::text)");

        //* Users interface
        c->prepare(psqlMethods::schoolManager::users::getAll, "select * from school_users_get($1::uuid)");
        c->prepare(psqlMethods::schoolManager::users::create, "call user_create($1::uuid, $2::text, $3::text, $4::text)");
        c->prepare(psqlMethods::schoolManager::users::createWithContext, "call user_create_with_context("
                                               "$1::uuid, $2::text, $3::text, $4::text, "
                                               "null_to_array($5::text[]), "
                                               "null_to_array($6::text[])"
                                               ")");
        c->prepare(psqlMethods::schoolManager::users::drop ,"call school_user_drop($1::uuid,uuid_or_null($2))");
        c->prepare(psqlMethods::schoolManager::users::resetPassword, "call school_user_password_reset($1::uuid, $2::uuid, $3)");

        //* Grant classes to user
        // c->prepare(psqlMethods::schoolManager::users::grantClasses, "call school_user_classes_grant($1::uuid, $2::uuid, $3::uuid[])");
        // c->prepare(psqlMethods::schoolManager::users::degrantClasses, "call school_user_classes_degrant($1::uuid, $2::uuid, $3::uuid[])");
        c->prepare(psqlMethods::schoolManager::users::setClasses, "call school_user_classes_set($1::uuid, $2::uuid, $3::uuid[])");

        c->prepare(psqlMethods::schoolManager::users::setName, "call school_user_name_set($1::uuid, $2::uuid, $3::text)");
        //* Grant roles to user
        c->prepare(psqlMethods::schoolManager::users::setRoles, "call user_roles_set($1::uuid, $2::uuid, $3::text[])");
        //Region data

        c->prepare(psqlMethods::schoolManager::data::isExists, "select is_school_data_exists($1::uuid, $2::date)");
        c->prepare(psqlMethods::schoolManager::data::genNewForToday, "call school_data_gen($1::uuid)");
        c->prepare(psqlMethods::schoolManager::data::getForToday, "select * from school_data_get($1::uuid, current_date)");
        c->prepare(psqlMethods::schoolManager::data::getForDate, "select * from school_data_get($1::uuid, $2::date)");
        c->prepare(psqlMethods::schoolManager::data::getSummarized, "select * from school_data_summarized_get($1::uuid, jsonb_build_object('start_date', $2::date, 'end_date', $3::date ))");

        connections.push_back(std::move(c)); // Move ownership to the vector
    }
}

pqxx::connection* ConnectionPool::getConnection() {
    std::unique_lock lock(mtx);

    if (connections.empty())
        cv.wait(lock);

    if (connections.empty()) {
        // This should not happen due to the condition variable wait, but let's be defensive
        throw std::runtime_error("Connection pool is empty after wait.");
    }

    // Directly move the unique_ptr to a raw pointer to maintain ownership semantics
    pqxx::connection* conn = connections.back().release();
    connections.pop_back();
    lock.unlock(); // Unlock before returning to minimize lock hold duration
    return conn;
}

void ConnectionPool::releaseConnection(pqxx::connection* conn) {
    mtx.lock();

    connections.emplace_back(conn);

    mtx.unlock();
    cv.notify_one(); // Notify any waiting threads that a connection is now available
}