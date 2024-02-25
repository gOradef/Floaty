#include "json/json.h"
#include "fstream"
#include "authentication.h"




//Region general Reqs
class baseReq {

protected:
    std::string schoolId;
    std::string action;
    std::string method;
    std::string userBuff;
    int genNewData();
    virtual std::map<std::string, Json::Value> genMapOfEditNotes() = 0;
    virtual crow::response insertData() = 0;

    virtual crow::response getData() = 0;
    virtual crow::response editData() = 0;

public:

    baseReq();
    baseReq(const crow::request &req);
    crow::response doUserAction();

};

//Region Form
class formReq : public baseReq{
private:
    std::map<std::string, Json::Value> genMapOfEditNotes();
    crow::response insertData();

    crow::response getData();
    crow::response editData();
public:
    formReq();
    formReq(const crow::request &req);

};


//Region Interface
class interfaceReq : public baseReq {

    std::string period; //DTD  | usercase | today
    std::string date;
    crow::response getData();
    crow::response editData();
        std::map<std::string, Json::Value> genMapOfEditNotes();
        crow::response insertData();
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
        std::map<std::string, Json::Value> genMapOfEditNotes();
        crow::response insertData();
public:
    bool isCorrUserKey();
    interfaceTempReq();
    interfaceTempReq(const crow::request &req);

};
class interfaceBuilder {
public:
    interfaceBuilder();
    interfaceReq* createInterface(const crow::request& req);
};
Json::Value genTempClassesAsJson( const std::string &reqPath, const std::string& schoolId = "");
std::map<std::string, Json::Value> handlerGenMapOfEditNotes(const std::string &reqEdit,
                                                            const bool& isForm = true,
                                                            const std::string& schoolIdReq = "",
                                                            const std::string& userCase = "",
                                                            const std::string& userCustomDate = "");

//crow::response writeEditNotesForm(std::map<std::string, Json::Value> &editNotesMap);

//crow::response writeForEditNotesForm(std::string reqEdit);

// * mode: 1-form (names only) 0-interface (fullData);
crow::response getStaticFileJson(const crow::request &reqRoot, bool isShort = true);

crow::response handleCommonReq(const std::string &schoolId, bool isShort = true);
crow::response handleUserReq(const std::string& schoolId, const std::string& userDate, const std::string& period = "");
//gets template as json and send to user res/s
crow::response getTemplateDataInterface(Json::Reader &reader, const Json::Value &reqJ, const std::string &schoolId);

