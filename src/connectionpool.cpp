//
// Created by goradef on 15.06.2024.
//
#include "Floaty/connectionpool.h"
ConnectionPool::ConnectionPool(const std::string& connection_string, int pool_size) {
    for (int i = 0; i < pool_size; ++i) {
        pqxx::connection *c = new pqxx::connection(connection_string);
        //login
        c->prepare("is_valid_user", "SELECT * from is_valid_user($1, $2);"); //return bool and user_id
        c->prepare("get_user_roles", "SELECT * from get_user_roles($1::uuid);");
        c->prepare("get_school_id", "select id from schools join lateral jsonb_array_elements(members) as mem on true where mem->>'id' = $1;");

        //data encoding | decoding
        c->prepare("encode", "select encode($1, 'hex');");
        c->prepare("decode", "select decode($1, 'hex');");

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
