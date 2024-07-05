#include "json/json.h"
#include "fstream"
#include "Floaty/authentication.h"
#include "Floaty/connectionpool.h"


class User {
protected:
// connection to Postgres
    ConnectionPool* _connectionPool;
    pqxx::connection* _connection;

// attributes of any user
    std::string _org_id;
    std::string _user_id;

public:
    User(ConnectionPool *connectionPool,
         const crow::request &req);
    ~User();

    std::vector<std::string> getRoles() {
        std::vector<std::string> roles;
        pqxx::read_transaction readTransaction(*_connection);
        auto res = readTransaction.exec_prepared("user_roles_get", _org_id, _user_id);
        for (auto role : res) {
            roles.emplace_back(role.front().as<std::string>());
        }
        return roles;
    }
};





class Teacher : User {
    std::string class_id;
public:
    Teacher(ConnectionPool *connectionPool,
            const crow::request &req);
};




//! ARCHIVED
class dataInterface;
//Region general Reqs abstract
class baseReq {

protected:
    dataInterface* interface;
    std::string schoolId;
    std::string action;
    std::string method;
    std::string userBuff;

    virtual crow::response getData() = 0;
    virtual crow::response editData() = 0;

public:

    baseReq();
    baseReq(const crow::request &req);
    virtual ~baseReq();
    crow::response doUserAction();

};

//Region abstractDataHandler
class dataInterface {
protected:
    std::fstream fstream;
    std::ostringstream sbuff;
    Json::Reader jReader;
    Json::StyledWriter jWriter;
    std::string schoolId;
    std::string reqPath;

    std::string genToken();
    Json::Value getCurrentData();

    int genNewData();
public:
    dataInterface() {};
    dataInterface(const std::string& schoolId);
    virtual ~dataInterface() {};
    virtual crow::response getData() = 0;
    virtual crow::response getOptionalData() { return crow::response(); }; //dependency of abstract class interfaceInterface
    virtual crow::response getDTDData(const std::string& userBuff) { return {}; };
    virtual void setDate(const std::string& userDate) {};
    virtual crow::response editData(const std::string& userBuff) = 0;
};




class dataInterfaceForm : public dataInterface{

public:
    dataInterfaceForm() = default;
    dataInterfaceForm(const std::string& schoolId);
    crow::response getData();
    crow::response editData(const std::string& userBuff);
};



class dataInterfaceInterface : public dataInterface{
    std::string userDate;
public:
    dataInterfaceInterface(const std::string& schoolId, const std::string& userDate);
    crow::response getData() override;
    crow::response getOptionalData() override; //data like [yy.mm.dd]
    crow::response getDTDData(const std::string& userBuff) override;
    void setDate(const std::string& userDate) override;
    crow::response editData(const std::string& userBuff) override;

};


class dataInterfaceTemp : public dataInterface {
    Json::Value genLetterRoot();

public:
    dataInterfaceTemp(const std::string& schoolId);
    crow::response getData();
    crow::response editData();

    //! Garbage
    crow::response editData(const std::string& userBuff);
};

//Region Form
class formReq : public baseReq {
private:
    crow::response getData();
    crow::response editData();
public:
    formReq();
    formReq(const crow::request &req);
};

//Region builderOfInterface
class interfaceReq;
class interfaceBuilder {
    std::string schoolId;
    bool isCorrUserKey(const std::string& userKey); //depend of constructor for data
public:
    interfaceBuilder() {};
    interfaceReq* createInterface(const crow::request& req);
};

//Region Interface
class interfaceReq : public baseReq {

    std::string period; //DTD  | usercase | today
    std::string date;
    crow::response getData();
    crow::response editData();
public:
    interfaceReq();
    interfaceReq(const crow::request &req);
};

//Region InterfaceTemplate
class interfaceTempReq : public interfaceReq {
    std::string userKey;
    crow::response getData();
    crow::response editData();
public:
    interfaceTempReq();
    interfaceTempReq(const crow::request &req);
};

Json::Value genTempClassesAsJson( const std::string &reqPath, const std::string& schoolId = "");
