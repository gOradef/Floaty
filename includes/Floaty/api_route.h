#include "json/json.h"
#include "fstream"
#include "Floaty/authentication.h"
#include "Floaty/connectionpool.h"

#include "jwt-cpp/jwt.h"
#include "vector"
#include "json/value.h"
#include "crow/json.h"

class Request {
protected:
// connection to Postgres
    ConnectionPool* _connectionPool;
    pqxx::connection* _connection;

// attributes of any user
    std::string _org_id;
    std::string _user_id;

public:
    Request(ConnectionPool *connectionPool,
            const crow::request &req);
    std::vector<std::string> getRoles();
    std::map<std::string, std::string> getClasses();

    ~Request();
};





class classHandler : Request {
    std::string _class_id;

    std::vector<std::string> _stud_types{"students", "fstudents"};
    std::vector<std::string> _actions {"get", "remove"}; //? maybe 'set' as well?
    std::vector<std::string> _cause_types {"global",
                                           "ORVI",
                                           "not_respectful",
                                           "respectful",
                                           "fstudents"};
    /** @brief id - new array */
public:
    classHandler(ConnectionPool *connectionPool,
                 const crow::request &req);

    /**
     * @return Returns map[id] = name of classes where id is uuid in postgres
     */
    crow::json::wvalue getClassStudents();
    void updateClassStudents(const std::string& changes);
    void insertData(const std::string& changes);
};

class schoolManager : Request {
    schoolManager(ConnectionPool* cp,
                  const crow::request& req);

    //Classes
    void classCreate();
    void classRename();
    void classStudentsEdit();
    void classDrop();

    void classMoveToNextYear();


    //Data
    std::string dataGet();
    std::string dataGet(const std::string& date);
    void dataUpdate(const std::string& changes);
    std::string dataSummaryGet();
    std::string dataSummaryGet(const std::string& dateStart,
                               const std::string& dateEnd);

    
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
