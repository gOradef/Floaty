//
// Created by goradef on 15.06.2024.
//
#include "Floaty/connectionpool.h"
ConnectionPool::ConnectionPool(const std::string& connection_string, int pool_size) {
    for (int i = 0; i < pool_size; ++i) {
        pqxx::connection *c = new pqxx::connection(connection_string);
        //login
        c->prepare("is_valid_user", "SELECT * from is_valid_user($1, $2);"); //return bool and user_id in different rows
        c->prepare("user_roles_get", "SELECT * from user_roles_get($1::uuid, $2::uuid);"); //return many rows of roles
        c->prepare("school_id_get", "select school_id_get($1::uuid);");
        c->prepare("is_user_has_role", "select 1 from schools where id = $1::uuid "
                          "and members -> $2::text -> roles ? $3");
        //data encoding | decoding
        c->prepare("encode", "select encode($1, 'hex');");
        c->prepare("decode", "select convert_from(decode($1, 'hex'), 'UTF-8');");

        //get | edit data for teacher

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
