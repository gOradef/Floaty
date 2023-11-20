#include <stdlib.h>
#include <iostream>
#include "../headerFiles/1.h"
#include <jdbc/cppconn/connection.h>
#include <jdbc/cppconn/driver.h>
#include <jdbc/cppconn/exception.h>
#include <jdbc/cppconn/prepared_statement.h>
using namespace std;

// for demonstration only. never save your password in the code!

void WebClient::setupCon() {
        try {
            driver = get_driver_instance();
            con = driver->connect(server, username, password);

        }
        catch (sql::SQLException e) {
            cout << "Could not connect to server. Error message: " << e.what() << endl;
            system("pause");
            exit(1);
        }
    }
    //!Attention Deletes con
    void WebClient::userAction() {
        con->setSchema("test");

        stmt = con->createStatement();
        stmt->execute("DROP TABLE IF EXISTS inventory");
        cout << "Finished dropping table (if existed)" << endl;
        stmt->execute("CREATE TABLE inventory (id serial PRIMARY KEY, name VARCHAR(50), quantity INTEGER);");
        cout << "Finished creating table" << endl;
        delete stmt;

        pstmt = con->prepareStatement("INSERT INTO inventory(name, quantity) VALUES(?,?)");
        pstmt->setString(1, "banana");
        pstmt->setInt(2, 150);
        pstmt->execute();
        cout << "One row inserted." << endl;

        pstmt->setString(1, "orange");
        pstmt->setInt(2, 154);
        pstmt->execute();
        cout << "One row inserted." << endl;

        pstmt->setString(1, "apple");
        pstmt->setInt(2, 100);
        pstmt->execute();
        cout << "One row inserted." << endl;

        delete pstmt;
        delete con;
        system("pause");
    }
    std::string WebClient::checkIsSuccessCon()
    {

        if (con->isValid())
        {
            return "1";
        }
        else return "nope";
    }
