#include "json/json.h"
#include "fstream"
#include "authentication.h"




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
    std::ostringstream ostringstream;
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
    virtual crow::response getOptionalData() {};
    virtual crow::response getData() = 0;
    virtual void setDate(const std::string& userDate) {};
    virtual crow::response editData(const std::string& userBuff) = 0;
};




class dataInterfaceForm : public dataInterface{

public:
    dataInterfaceForm() {};
    dataInterfaceForm(const std::string& schoolId);
    crow::response getData();
    crow::response editData(const std::string& userBuff);
};



class dataInterfaceInterface : public dataInterface{
    std::string userDate;
public:
    dataInterfaceInterface(const std::string& schoolId, const std::string& userDate);
    crow::response getData();
    crow::response getOptionalData(); //data like [yy.mm.dd]
    crow::response getDTDDate();
    void setDate(const std::string& userDate);
    crow::response editData(const std::string& userBuff);

};


class dataInterfaceTemp : public dataInterface {

public:
    Json::Value genLetterRoot();
    dataInterfaceTemp(const std::string& schoolId);
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
    Json::Value genLetterRoot();
    std::string userKey;
    crow::response getData();
    crow::response editData();
public:
    bool isCorrUserKey();
    interfaceTempReq();
    interfaceTempReq(const crow::request &req);

};

Json::Value genTempClassesAsJson( const std::string &reqPath, const std::string& schoolId = "");
