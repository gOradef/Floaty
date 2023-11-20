#include <stdlib.h>
#include <iostream>
#include <string>
#include <jdbc/cppconn/connection.h>
#include <jdbc/cppconn/driver.h>
#include <jdbc/cppconn/exception.h>
#include <jdbc/cppconn/prepared_statement.h>

class WebClient
{
private:
    bool isSuccess{0};
    const std::string server = "tcp://localhost:3306";
    const std::string username = "goradef";
    const std::string password = "Mfdib2233";
    sql::Driver *driver;
    sql::Connection *con;
    sql::Statement *stmt;
    sql::PreparedStatement *pstmt;

public:
    void setupCon();
    void userAction();
    std::string checkIsSuccessCon();
    // WebClient(/* args */);
    // ~WebClient();
};