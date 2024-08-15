
#pragma once

#include "Floaty/connectionpool.h"

#include "vector"

#include "jwt-cpp/jwt.h"

#include "crow/app.h"
#include "crow/middlewares/cookie_parser.h"
#include "crow/json.h"
#include "crow/http_request.h"



//Region api exceptions


    namespace api::exceptions {
        struct wrongRequest : public std::exception {
            wrongRequest(const std::string &message) : msg_(message) {}

            const char *what() const noexcept override {
                return msg_.c_str();
            }

        private:
            std::string msg_;
        };

        struct parseErr : public std::exception {
            parseErr(const std::string &message) : msg_(message) {}

            const char *what() const noexcept override {
                return msg_.c_str();
            }

        private:
            std::string msg_;
        };

        struct classDoesntExists : public std::exception {
            classDoesntExists(const std::string &message) : msg_(message) {}

            const char *what() const noexcept override {
                return msg_.c_str();
            }

        private:
            std::string msg_;
        };

        struct conflict : public std::exception {
            conflict(const std::string &message) : msg_(message) {}

            const char *what() const noexcept override {
                return msg_.c_str();
            }

        private:
            std::string msg_;
        };

        struct userDoesntExists : public std::exception {
            userDoesntExists(const std::string &message) : msg_(message) {}

            const char *what() const noexcept override {
                return msg_.c_str();
            }

        private:
            std::string msg_;
        };

        struct dataDoesntExists : public std::exception {
            dataDoesntExists(const std::string &message) : msg_(message) {}

            const char *what() const noexcept override {
                return msg_.c_str();
            }

        private:
            std::string msg_;
        };

    }


class Request {
protected:
// connection to Postgres
    ConnectionPool* _connectionPool;
    pqxx::connection* _connection;

// attributes of any user
    std::string _org_id;
    std::string _user_id;

    /**
     * @param date date value
     * @throw api::exceptions::wrongRequest("Input date is not valid format");
     */
    void isInputIsDateType(const std::string& date) {
        pqxx::read_transaction readTransaction(*_connection);
        readTransaction.exec_prepared1("is_date", date).front().as<bool>() ?
        nullptr
                                                                           :
        throw api::exceptions::wrongRequest("Input date is not valid format");
    };

public:
    Request(ConnectionPool *connectionPool, const crow::request &req);
    std::vector<std::string> getRoles();
    crow::json::wvalue getAvailibleClasses();

    ~Request();
};





class classHandler : Request {
    std::string _class_id;

    std::vector<std::string> _stud_types{"students", "fstudents"};
    std::vector<std::string> _actions {"add", "remove"}; //? maybe 'set' as well?
    std::vector<std::string> _cause_types {"global",
                                           "ORVI",
                                           "not_respectful",
                                           "respectful",
                                           "fstudents"};

public:
    classHandler(ConnectionPool *connectionPool,
                 const crow::request &req, const std::string& classID);

    /**
     * @return Returns map[id] = name of classes where id is uuid in postgres
     */
    crow::json::wvalue getClassStudents();
    crow::json::wvalue getInsertedDataForToday();
    crow::json::wvalue getInsertedDataForDate(const std::string& date);
    void updateClassStudents(const std::string& changes);
    void insertData(const std::string& changes);
};


class schoolManager : Request {
private:
    void isLoginOccupied(const std::string& login);
    void isUserExists(const std::string& userID);
    void isClassExists(const std::string& classID);
    bool isDataTodayExists();

public:
    schoolManager(ConnectionPool* cp,
                  const crow::request& req);

    struct url_params {
        bool isWithDate;
        bool isWithRoles;
        bool isWithClasses;
        bool isWithOwner;

        url_params() : isWithRoles(false), isWithClasses(false) {};

    };
    url_params urlParams;

    //Region Getters

    crow::json::wvalue getClasses();
    crow::json::wvalue getClassStudents(const std::string& classID);

    crow::json::wvalue getUsers();

    crow::json::wvalue getDataForToday();
    crow::json::wvalue getDataForDate(const std::string& date);

    crow::json::wvalue getSummaryFromDateToDate(const std::string& startDate, const std::string& endDate);

    //Region Events - Classes
    void classRename(const crow::json::rvalue& json);


    void classCreate(const crow::json::rvalue& json);

    void classDrop(const std::string& classID);

    //Region Users
    void userCreate(const crow::json::rvalue& creds);

    void userDrop(const std::string& userID);

    //User grants
    void userGrantClass(const std::string& userID, const std::vector<std::string>& classes);
    void userDegrantClass(const std::string& userID, const std::vector<std::string>& classes);

    //Region Invites
    void inviteCreate(const std::string& invite_body);

    crow::json::wvalue getAllInvites();

    void inviteDrop(const std::string& reqID);

    void userGrantRoles(const std::string& userID, const std::vector<std::string>& roles);
    void userDegrantRoles(const std::string& userID, const std::vector<std::string>& roles);

    void classStudentsEdit(); //update

    void classMoveToNextYear(); //update

    //Data
    void dataUpdate(const std::string& changes);
};
