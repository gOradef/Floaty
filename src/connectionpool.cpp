//
// Created by goradef on 15.06.2024.
//
#include "Floaty/connectionpool.h"
ConnectionPool::ConnectionPool(const std::string& connection_string, int pool_size) {
    for (int i = 0; i < pool_size; ++i) {
        auto *c = new pqxx::connection(connection_string);

        //data encoding | decoding
        c->prepare("encode", "select encode($1, 'hex')");
        c->prepare("decode", "select convert_from(decode($1, 'hex'), 'UTF-8')");

        //login
        c->prepare("is_valid_user", "SELECT * from is_valid_user($1::text, $2::text)"); //return bool and user_id in different rows
        c->prepare("user_roles_get", "SELECT * from user_roles_get($1::uuid, $2::uuid)"); //return many rows of roles
        c->prepare("school_id_get", "select school_id_get($1::uuid)");
        c->prepare("is_user_has_role", "select 1 from schools "
                                       "where id = $1::uuid "
                                       "and members -> $2::text -> 'roles' ? $3::text");
        c->prepare("user_classes_get", "select * from user_classes_get($1::uuid, $2::uuid)");

        //get | edit data for classes
        c->prepare("is_class_valid", "select is_class_owned($1::uuid, $2::uuid, uuid_or_null($3))");

        //get list of students in class
        {
            c->prepare("class_students_get", "select class_students_get($1::uuid, $2::uuid, $3::uuid)");
            c->prepare("class_fstudents_get", "select class_fstudents_get($1::uuid, $2::uuid, $3::uuid)");
        }

        //set [add, remove] students
        {
            c->prepare("class_students_add", "call class_students_add("
                                                  "$1::uuid, "
                                                  "$2::uuid, "
                                                  "$3::uuid, "
                                                  "$4::text[]"
                                                  ")");
            c->prepare("class_students_remove", "call class_students_remove("
                                                     "$1::uuid, "
                                                     "$2::uuid, "
                                                     "$3::uuid, "
                                                     "$4::text[]"
                                                     ")");
        }

        //set [add, remove] fstudents
        {
            c->prepare("class_fstudents_add", "call class_fstudents_add("
                                                   "$1::uuid, "
                                                   "$2::uuid, "
                                                   "$3::uuid, "
                                                   "$4::text[]"
                                                   ")");
            c->prepare("class_fstudents_remove", "call class_fstudents_remove("
                                                      "$1::uuid, "
                                                      "$2::uuid, "
                                                      "$3::uuid, "
                                                      "$4::text[]"
                                                      ")");

            c->prepare("class_amount_set", "call class_amount_set("
                                                "$1::uuid, "
                                                "$2::uuid, "
                                                "$3::uuid, "
                                                "$4::int"
                                                ")");
            c->prepare("class_amount_drop", "call class_amount_drop("
                                                 "$1::uuid, "
                                                 "$2::uuid, "
                                                 "$3::uuid "
                                                 ")");
        }


        //get | edit data for Headteacher

        //get | edi data for admin


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
