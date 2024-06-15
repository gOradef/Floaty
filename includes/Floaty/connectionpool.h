//
// Created by goradef on 15.06.2024.
//

#ifndef FLOATYROOTSERVICE_CONNECTIONPOOL_H
#define FLOATYROOTSERVICE_CONNECTIONPOOL_H

#include "pqxx/pqxx"
#include "mutex"

class ConnectionPool {
private:
    std::vector<pqxx::connection*> connections;
    std::mutex mtx;

public:
    ConnectionPool(const std::string& connection_string, int pool_size);
    pqxx::connection* getConnection();
    void releaseConnection(pqxx::connection* conn);
    ~ConnectionPool();
};

#endif //FLOATYROOTSERVICE_CONNECTIONPOOL_H
