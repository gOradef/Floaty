#include "Floaty/api_route.h"
#include "jwt-cpp/jwt.h"
#include "vector"
#include "json/value.h"
#include <cstdlib>



baseReq::baseReq() {};
baseReq::baseReq(const crow::request &req) {
    schoolId = req.get_header_value("schoolId");
    action = req.get_header_value("action");
    method = req.get_header_value("method");
    if (!req.body.empty()) {
        userBuff = req.body;
    }
}
crow::response baseReq::doUserAction() {
    if (action == "get") {
        return getData();
    }
    else if (action == "edit") {
        return editData();
    }
    else {
        return crow::response(400, "no such action");
    }
}

int baseReq::genNewData() {
    std::fstream fstream;
    std::stringstream stringstream;
    Json::Value root;

    try {
        fstream.open(std::string("data/" + schoolId + "/schoolTemplateDate.json"), std::ios::in);
        stringstream << fstream.rdbuf();
        fstream.close();

        if (!stringstream.str().empty()) {
            std::string reqPath = "data/" + schoolId + '/' + genToken(schoolId) + ".json";
            fstream.open(reqPath, std::ios::out);
            fstream << stringstream.str();
            fstream.close();

            Json::Reader reader;
            reader.parse(stringstream.str(), root);
            return 200;
        }
        else {
            std::cout << "--- ERR: no readable template -> creating new one \n";
            std::vector <std::string> letters;
            letters.emplace_back("А");
            letters.emplace_back("Б");
            letters.emplace_back("В");
            letters.emplace_back("Г");
            letters.emplace_back("Д");
            letters.emplace_back("Е");

            Json::Value root2;
            Json::Value classesNum(Json::objectValue);
            Json::Value letterClass(Json::objectValue);


            Json::Value nameOfClass;
            Json::Value numOfPeople;

            Json::Value absentSubRoot(Json::objectValue);
            Json::Value numOfPeopleAbsent;
            Json::Value listNonRespCause(Json::arrayValue);
            Json::Value listRespCause(Json::arrayValue);
            Json::Value listVirusCause(Json::arrayValue);
            Json::Value listFreeMealIs(Json::arrayValue);

            for(int i = 1; i < 12; ++i) {

                absentSubRoot["amount"] = numOfPeopleAbsent;
                absentSubRoot["listNonRespCause"] = listNonRespCause;
                absentSubRoot["listRespCause"] = listRespCause;
                absentSubRoot["listFreeMeal"] = listFreeMealIs;
                absentSubRoot["listVirusCause"] = listVirusCause;

                letterClass["amount"] = numOfPeople;
                letterClass["absent"] = absentSubRoot;

                for (int j = 0; j < 6; j++) {
                    letterClass["name"] = std::to_string(i) +'_' + letters[j];
                    classesNum[ letters[j] ] = letterClass;
                }
                root2[std::to_string(i)] = classesNum;
            }
//    root2["10"]["А"]["name"] = "the best!";
            root["classes"] = root2;
            fstream.open(std::string("data/"+ schoolId + "/schoolTemplateDate.json"), std::ios::out);
            Json::StyledWriter writer;
            fstream << writer.write(root);
            fstream.close();
            return 201;
        }

    }
    catch (std::exception &e) {
        std::cout << "---ERR: " << e.what() << '\n';
    }
    return 500;
}

//Region Form
formReq::formReq(const crow::request& req) : baseReq(req) { }

crow::response formReq::getData() {
    crow::response res;
    std::string reqPath;
    std::string currDate = genToken(schoolId);
    reqPath = std::string("data/" + schoolId + "/" + currDate + ".json");

    Json::Value root;
    Json::Reader jReader;

    Json::Value classNames = Json::Value(Json::arrayValue);

    std::ifstream ifstream;
    std::ostringstream ostringstream;

    try {
        ifstream.open(reqPath);
        ostringstream << ifstream.rdbuf();
        ifstream.close();
        if (ostringstream.str() == "") { //if file doesnt exist

        }
        jReader.parse(ostringstream.str(), root);
        root = root["classes"];
        for (auto num : root) {
            for (auto letter : num) {
//                    std::cout << root[std::to_string(num)][].get("name");
                classNames.append(letter["name"].asString());
            }
        }
        Json::FastWriter jWriter;
        res.body = jWriter.write(classNames);
        return res;
    }
    catch (std::exception &e) {
        std::cout << "--- Err: " << e.what();
    }
}

crow::response formReq::editData() {

    return insertData();
}
std::map<std::string, Json::Value> formReq::genMapOfEditNotes() {

    Json::Value reqEditNotesRoot;
    Json::Reader reader;
    reader.parse(userBuff, reqEditNotesRoot);

        try {
            std::string className = reqEditNotesRoot["className"].asString();
            std::string globalNum = reqEditNotesRoot["globalNum"].asString();
            std::string absentNum = reqEditNotesRoot["absentNum"].asString();
            Json::Value listAbsent = Json::Value(Json::arrayValue);

            std::map<std::string, Json::Value> absentMap;
            absentMap["classNum"] = className.substr(0, className.find('_'));
            absentMap["classLetter"] = className.substr(className.find('_') + 1, className.back() - 1);
            absentMap["globalNum"] = globalNum;
            absentMap["absent_amount"] = absentNum;

            listAbsent = reqEditNotesRoot["absentVir"];
            absentMap["absent_listVirusCause"] = listAbsent;

            listAbsent = reqEditNotesRoot["absentRespCause"];
            absentMap["absent_listRespCause"] = listAbsent;

            listAbsent = reqEditNotesRoot["absentNonRespCause"];
            absentMap["absent_listNonRespCause"] = listAbsent;

            listAbsent = reqEditNotesRoot["absentFreeMeal"];
            absentMap["absent_listFreeMeal"] = listAbsent;

            return absentMap;
        }
        catch (Json::Exception &e) {
            std::map<std::string, Json::Value> map;
            map["err"] = Json::Value{ e.what() };
            return map;
        }
}

crow::response formReq::insertData() {
    std::map<std::string, Json::Value> editNotesMap = genMapOfEditNotes();

    std::fstream fstream;
    Json::Value buff_J;
    Json::Reader Jreader;
    std::ostringstream buff_str;
    std::string currDatePath = "data/" + schoolId + '/' + genToken(schoolId) + ".json";
    std::cout << currDatePath;
    fstream.open(currDatePath, std::ios::in);
    buff_str << fstream.rdbuf();
    fstream.close();
    Jreader.parse(buff_str.str(), buff_J);

    /// trys to edit data
    Json::Value neededAbsentPart = Json::Value(Json::objectValue);
    Json::Value globalNum;

    Json::Value rootTemplateDay = Json::Value(Json::objectValue);
    std::stringstream buff_str_T;
    fstream.open("data/" + schoolId + '/' + "schoolTemplateDate.json", std::ios::in);
    buff_str_T << fstream.rdbuf();
    fstream.close();

    Jreader.parse(buff_str_T.str(), rootTemplateDay);

    if (editNotesMap["globalNum"].asString() == "" || editNotesMap["globalNum"].asString() == "!" || editNotesMap["globalNum"].asString() == "-" || editNotesMap["globalNum"].asString() == " ")
    {
        globalNum = rootTemplateDay["classes"]
        [editNotesMap["classNum"].asString()]
        [editNotesMap["classLetter"].asString()]
        ["amount"];

        buff_J["classes"]
        [editNotesMap["classNum"].asString()]
        [editNotesMap["classLetter"].asString()]
        ["amount"] = globalNum.asString();
    }
    else {
        try {
            rootTemplateDay["classes"]
            [editNotesMap["classNum"].asString()]
            [editNotesMap["classLetter"].asString()]
            ["amount"] = editNotesMap["globalNum"].asString();

            Json::StyledWriter writer;
            fstream.open("data/" + schoolId + '/' + "schoolTemplateDate.json", std::ios::out);
            fstream << writer.write(rootTemplateDay);
            fstream.close();
        }
        catch (std::exception &e) {
            return crow::response(500, e.what());
        }
        buff_J["classes"]
        [editNotesMap["classNum"].asString()]
        [editNotesMap["classLetter"].asString()]
        ["amount"] =
                rootTemplateDay["classes"]
                [editNotesMap["classNum"].asString()]
                [editNotesMap["classLetter"].asString()]
                ["amount"];
    }

    neededAbsentPart = buff_J["classes"]
    [editNotesMap["classNum"].asString()]
    [editNotesMap["classLetter"].asString()]
    ["absent"];


    for (const auto& [first, second] : editNotesMap) {
        if (!second.empty() && first.substr(0, first.find('_')) == "absent") {
            try {
                neededAbsentPart[first.substr(first.find('_') + 1, first.back() - 1)] = second;
            }
            catch (Json::Exception &e) {
                try {
                    std::cout << "--- Err: " << e.what() << '\n';
                    neededAbsentPart[first.substr(first.find('_') + 1, first.back() - 1)] = second;
                }
                catch (Json::Exception &e) {
                    std::cout << "no way to ignore err - " << e.what();
                }
            }
        }
    }

    buff_J["classes"]
    [editNotesMap["classNum"].asString()]
    [editNotesMap["classLetter"].asString()]
    ["absent"] = neededAbsentPart;
    fstream.open("data/" + schoolId + '/' + genToken(schoolId) + ".json", std::ios::out | std::ios::binary);
    fstream << buff_J;
    fstream.close();
    std::system(std::string("./commit_data.sh -d 'form edit for " + schoolId + "'").c_str());
    return crow::response(200, "ladna");
}

//Region builderOfInterface

interfaceBuilder::interfaceBuilder() {

}

interfaceReq *interfaceBuilder::createInterface(const crow::request &req) {
    if (req.get_header_value("key") != "") {

        interfaceTempReq client(req);
        if (client.isCorrUserKey()) {
            return new interfaceTempReq(req);
        }
        else return new interfaceReq(req);
    }
    else {
        return new interfaceReq(req);
    }
}

//Region Interface
interfaceReq::interfaceReq(const crow::request& req) : baseReq(req) {
    period = req.get_header_value("period"); // concrete
    date = req.get_header_value("userDate");
}
crow::response interfaceReq::getData() {
    if (method == "commonCase") { //get data for today
        if (period == "today") {
            crow::response res;
            std::string reqPath;
            std::string currDate = genToken(schoolId);
            reqPath = std::string("data/" + schoolId + "/" + currDate + ".json");
            res.set_static_file_info(reqPath);
            if (!res.is_static_type()) { //if file doesn't exist
                Json::FastWriter writer;
                std::string resJ = writer.write(genTempClassesAsJson(reqPath, schoolId));

                res.body = resJ;
                return res;
            }
            else { //if exist
                res.add_header("date", currDate);
                return res;
            }
        }
        else {
            return crow::response(400, "unknown type of req");
        }
    }
    else if (method == "customCase") { //get data for userDate
        if (period == "usercase") {
                crow::response res;
                std::string reqPath;
                reqPath = std::string("data/" + schoolId + "/" + date + '.' + schoolId + ".json");
                res.set_static_file_info(reqPath);
                if (!res.is_static_type()) {//if file doesn't exist
                    if ((date + '.' + schoolId) == genToken(schoolId)) {  // is same as today's date
                        genNewData();
                        res.add_header("date", "Файл создан только что");
                        return res;
                    }
                    else {
                        return crow::response(400, "Данные за выбранную дату (" + date + ") отсутсвутют.");
                    }
                }
                else { //if exist
                    res.add_header("date", date);
                    return res;
                }
        }
        else if (period == "dateToDate") {
            ///TODO handler
        }
    }
}
crow::response interfaceReq::editData() {
    crow::response res;
    if (method == "commonCase") { //today
        date = genToken(schoolId);
    }
    else if (method == "customCase") { //userDate
        date += '.' + schoolId;
    }
    else {
        return crow::response(400, "Unknown method");
    }
    return insertData();
}

std::map<std::string, Json::Value> interfaceReq::genMapOfEditNotes() {}

crow::response interfaceReq::insertData() {
    Json::Value reqEditNotesRoot;
    Json::Reader reader;
    Json::StyledWriter writer;

    reader.parse(userBuff, reqEditNotesRoot);

    reqEditNotesRoot = reqEditNotesRoot["changesList"];
    crow::response res;
    try {
        Json::Value templateRoot = Json::Value(Json::objectValue);

        std::fstream fstream;
        std::stringstream buff;

        std::string path = "data/" + schoolId + '/' + date + ".json";

        fstream.open(path, std::ios::in);
        buff << fstream.rdbuf();
        fstream.close();
        reader.parse(buff.str(), templateRoot);

        std::string numClass;
        std::string letterClass;

        Json::Value listEditClass = Json::Value(Json::objectValue);

        listEditClass = reqEditNotesRoot["editChanges"];
        for (auto letter: listEditClass.getMemberNames()) {
            numClass = letter.substr(0, letter.find('_'));
            letterClass = letter.substr(letter.find('_') + 1, letter.back() - 1);

            for (auto key: listEditClass[letter].getMemberNames()) {
                templateRoot["classes"][numClass][letterClass][key] = listEditClass[letter][key];

                if (key.substr(0, key.find('_')) == "absent") {
                    templateRoot["classes"][numClass][letterClass]["absent"][key.substr(key.find('_') + 1, key.back() -
                                                                                                           1)] = listEditClass[letter][key];
                }
            }
        }
        fstream.open(path, std::ios::out);
        fstream << writer.write(templateRoot);
        fstream.close();
        res.code = 200;
        std::system(std::string("./commit_data.sh -d 'admin change for " + schoolId + "'").c_str());
    }
    catch (Json::Exception &e) {
        res.code = 500;
        res.body += e.what();
    }
    catch (std::exception &e ) {
        res.code = 501;
        res.body += e.what();
    }
    return res;
}

//Region interfaceTEMPLATEReq


interfaceTempReq::interfaceTempReq(const crow::request& req) : interfaceReq(req) {
    userKey = req.get_header_value("key");
}

bool interfaceTempReq::isCorrUserKey() {
    Json::Reader reader;
    std::fstream fstream;
    std::stringstream buff_str;
    std::string corrKey;
    try {
        fstream.open("data/" + schoolId + "/schoolData.json", std::ios::in);
        buff_str << fstream.rdbuf();
        fstream.close();
        if (!buff_str.str().empty()) {
            Json::Value rootSchoolData;
            reader.parse(buff_str.str(), rootSchoolData);
            corrKey = rootSchoolData["superAdminKey"].asString();
            if (corrKey == userKey) {
                return true;
            }
            else {
                //! wrong adminKeyInReq
                return false;
            }
        }
        else {
            std::cout << "---Err: " <<  "unable reading school date file" << '\n';
            return false;
        }
    }
    catch (std::exception &e) {
        std::cout << "---Err: " << e.what() << '\n';
        return false;
    }
}

crow::response interfaceTempReq::getData() {
    std::fstream fstream;
    std::stringstream buff_str;
    crow::response res;
    if (isCorrUserKey()) {
        res.set_static_file_info(std::string("data/" + schoolId + "/schoolTemplateDate.json"));
        return res;
    }
    else {
        return crow::response(400, "Wrong superKey");
    }
}

Json::Value interfaceTempReq::genLetterRoot() {
        Json::Value letterClass(Json::objectValue);

        Json::Value nameOfClass;
        Json::Value numOfPeople;

        Json::Value absentSubRoot(Json::objectValue);
        Json::Value numOfPeopleAbsent;
        Json::Value listNonRespCause(Json::arrayValue);
        Json::Value listRespCause(Json::arrayValue);
        Json::Value listVirusCause(Json::arrayValue);
        Json::Value listFreeMealIs(Json::arrayValue);

        absentSubRoot["amount"] = numOfPeopleAbsent;
        absentSubRoot["listNonRespCause"] = listNonRespCause;
        absentSubRoot["listRespCause"] = listRespCause;
        absentSubRoot["listFreeMeal"] = listFreeMealIs;
        absentSubRoot["listVirusCause"] = listVirusCause;

        letterClass["amount"] = numOfPeople;
        letterClass["absent"] = absentSubRoot;
        letterClass["name"] = Json::Value::null;
        return letterClass;
}
crow::response interfaceTempReq::editData() {
    crow::response res;
    Json::Value templateRoot;
    Json::Reader reader;
    Json::StyledWriter writer;
    std::fstream fstream;
    std::ostringstream buff;

    Json::Value reqEditNotesRoot;
    reader.parse(userBuff, reqEditNotesRoot);
    const std::string& templatePath = "data/" + schoolId + "/schoolTemplateDate.json";
    fstream.open(templatePath , std::ios::in);
    buff << fstream.rdbuf();
    fstream.close();
    reader.parse(buff.str(), templateRoot);
    reqEditNotesRoot = reqEditNotesRoot["changesList"];
    std::string numClass;
    std::string letterClass;

    Json::Value listEditClass = Json::Value(Json::objectValue);
    Json::Value listChangesClass = Json::Value(Json::objectValue);
    Json::Value listAddClass = Json::Value(Json::arrayValue);
    Json::Value listRmClass = Json::Value(Json::arrayValue);

    listEditClass = reqEditNotesRoot["editChanges"];
    for (auto letter : listEditClass.getMemberNames()) {
        numClass = letter.substr(0, letter.find('_'));
        letterClass = letter.substr(letter.find('_')+1, letter.back()-1);
        for (auto key : listEditClass[letter].getMemberNames()) {
            templateRoot["classes"][numClass][letterClass][key] = listEditClass[letter][key];
            if (key.substr(0, key.find('_')) == "absent") {
                templateRoot["classes"][numClass][letterClass]["absent"][key.substr(key.find('_')+1, key.back()-1)] = listEditClass[letter][key];
            }
        }
    }
    std::cout << userBuff;
    listChangesClass = reqEditNotesRoot["listChanges"];
    listAddClass = listChangesClass["add"];
    listRmClass = listChangesClass["rm"];

    for (auto el : listAddClass) {
        numClass = el.asString().substr(0, el.asString().find('_'));
        letterClass = el.asString().substr(el.asString().find('_')+1, el.asString().back()-1);

        templateRoot["classes"][numClass][letterClass] = genLetterRoot();
        templateRoot["classes"][numClass][letterClass]["name"] = numClass + '_' + letterClass;
    }
    for (auto el : listRmClass) {
        numClass = el.asString().substr(0, el.asString().find('_'));
        letterClass = el.asString().substr(el.asString().find('_')+1, el.asString().back()-1);

        templateRoot["classes"][numClass].removeMember(letterClass);
    }
    fstream.open(templatePath,std::ios::out);
    fstream << writer.write(templateRoot);
    fstream.close();
    res.code = 200;
    std::system(std::string("./commit_data.sh -d 'template change for " + schoolId + "'").c_str());
    return res;
}

std::map<std::string, Json::Value> interfaceTempReq::genMapOfEditNotes() {}

crow::response interfaceTempReq::insertData() {}

//Region dataArch

class classData {
private:
    Json::Value classRoot = Json::Value(Json::objectValue);
    Json::Value className;
    Json::Value classAmount; 
    Json::Value absentTree = Json::Value(Json::objectValue);
    Json::Value absentAmount;
    Json::Value absentListFreeMeal = Json::Value(Json::arrayValue);
    Json::Value absentListNonRespCause = Json::Value(Json::arrayValue);
    Json::Value absentListRespCause = Json::Value(Json::arrayValue);
    Json::Value absentListVirusCause = Json::Value(Json::arrayValue);
public:
    classData(std::string name, int amount) {
        className = name;
        classAmount = amount;
    }
    ~classData() {
        
    }
    void setAbsentTree() {
//        absentListFreeMeal =
//        absentListNonRespCause =
//        absentListRespCause =
//        absentListVirusCause =

    }
    Json::Value genRootDirOfClass() {
        classRoot["name"] = className;
        classRoot["amount"] = classAmount;
        classRoot["absent"] = absentTree;
        return classRoot;
    }
};

bool isCorrUserKey( const std::string& userKey, const std::string &schoolId);
crow::response handleDTDReq(const std::string& schoolId, std::vector<std::string> datesList);

Json::Value genLetterRoot() {
    Json::Value letterClass(Json::objectValue);


    Json::Value nameOfClass;
    Json::Value numOfPeople;

    Json::Value absentSubRoot(Json::objectValue);
    Json::Value numOfPeopleAbsent;
    Json::Value listNonRespCause(Json::arrayValue);
    Json::Value listRespCause(Json::arrayValue);
    Json::Value listVirusCause(Json::arrayValue);
    Json::Value listFreeMealIs(Json::arrayValue);

    absentSubRoot["amount"] = numOfPeopleAbsent;
    absentSubRoot["listNonRespCause"] = listNonRespCause;
    absentSubRoot["listRespCause"] = listRespCause;
    absentSubRoot["listFreeMeal"] = listFreeMealIs;
    absentSubRoot["listVirusCause"] = listVirusCause;

    letterClass["amount"] = numOfPeople;
    letterClass["absent"] = absentSubRoot;
    letterClass["name"] = Json::Value::null;
    return letterClass;
}
Json::Value genTempClassesAsJson(const std::string &reqPath, const std::string& schoolId){
    std::fstream fstream;
    std::stringstream stringstream;
    Json::Value root;

    try {
        fstream.open(std::string("data/" + schoolId + "/schoolTemplateDate.json"), std::ios::in);
        stringstream << fstream.rdbuf();
        fstream.close();

        if (!stringstream.str().empty()) {
            fstream.open(reqPath, std::ios::out);
            fstream << stringstream.str();
            fstream.close();

            Json::Reader reader;
            reader.parse(stringstream.str(), root);
            root = root["classes"];
            return root;

        }
        else {
            std::cout << "--- ERR: no readable template -> creating new one \n";
            std::vector <std::string> letters;
            letters.emplace_back("А");
            letters.emplace_back("Б");
            letters.emplace_back("В");
            letters.emplace_back("Г");
            letters.emplace_back("Д");
            letters.emplace_back("Е");

            Json::Value root2;
            Json::Value classesNum(Json::objectValue);
            Json::Value letterClass(Json::objectValue);


            Json::Value nameOfClass;
            Json::Value numOfPeople;

            Json::Value absentSubRoot(Json::objectValue);
            Json::Value numOfPeopleAbsent;
            Json::Value listNonRespCause(Json::arrayValue);
            Json::Value listRespCause(Json::arrayValue);
            Json::Value listVirusCause(Json::arrayValue);
            Json::Value listFreeMealIs(Json::arrayValue);

            for(int i = 1; i < 12; ++i) {

                absentSubRoot["amount"] = numOfPeopleAbsent;
                absentSubRoot["listNonRespCause"] = listNonRespCause;
                absentSubRoot["listRespCause"] = listRespCause;
                absentSubRoot["listFreeMeal"] = listFreeMealIs;
                absentSubRoot["listVirusCause"] = listVirusCause;

                letterClass["amount"] = numOfPeople;
                letterClass["absent"] = absentSubRoot;

                for (int j = 0; j < 6; j++) {
                    letterClass["name"] = std::to_string(i) +'_' + letters[j];
                    classesNum[ letters[j] ] = letterClass;
                }
                root2[std::to_string(i)] = classesNum;
            }
//    root2["10"]["А"]["name"] = "the best!";
            root["classes"] = root2;
            fstream.open(std::string("data/"+ schoolId + "/schoolTemplateDate.json"), std::ios::out);
            Json::StyledWriter writer;
            fstream << writer.write(root);
            fstream.close();
            return root;
        }

    }
    catch (std::exception &e) {
        std::cout << "---ERR: " << e.what() << '\n';
    }


}

std::map<std::string, Json::Value> handlerGenMapOfEditNotes(const std::string &reqEdit, const bool& isForm, const std::string& schoolIdReq,const std::string& userCase, const std::string& userCustomDate) {

    Json::Value reqEditNotesRoot;
    Json::Reader reader;
    reader.parse(reqEdit, reqEditNotesRoot);
    if (isForm) {
        try {
            const std::string& schoolId = reqEditNotesRoot["schoolId"].asString();
            std::string className = reqEditNotesRoot["className"].asString();
            std::string globalNum = reqEditNotesRoot["globalNum"].asString();
            std::string absentNum = reqEditNotesRoot["absentNum"].asString();
            Json::Value listAbsent = Json::Value(Json::arrayValue);

            std::map<std::string, Json::Value> absentMap;
            absentMap["schoolId"] = schoolId;
            absentMap["classNum"] = className.substr(0, className.find('_'));
            absentMap["classLetter"] = className.substr(className.find('_') + 1, className.back() - 1);
            absentMap["globalNum"] = globalNum;
            absentMap["absent_amount"] = absentNum;

            listAbsent = reqEditNotesRoot["absentVir"];
            absentMap["absent_listVirusCause"] = listAbsent;

            listAbsent = reqEditNotesRoot["absentRespCause"];
            absentMap["absent_listRespCause"] = listAbsent;

            listAbsent = reqEditNotesRoot["absentNonRespCause"];
            absentMap["absent_listNonRespCause"] = listAbsent;

            listAbsent = reqEditNotesRoot["absentFreeMeal"];
            absentMap["absent_listFreeMeal"] = listAbsent;

            return absentMap;
        }
        catch (Json::Exception &e) {
            std::map<std::string, Json::Value> map;
            map["err"] = Json::Value{ e.what() };
            return map;
        }
    }
    else { //Interface
        try {
            std::map <std::string, Json::Value> resultMap;
            Json::Value templateRoot = Json::Value(Json::objectValue);

            std::fstream fstream;
            std::stringstream buff;

            if (userCase != "templateCase") { //common admin case
                std::string path;

                if (userCustomDate.empty()) {
                    path = "data/" + schoolIdReq + '/' + genToken(schoolIdReq) + ".json";
                }
                else {
                    path = "data/" + schoolIdReq + '/' + userCustomDate + "." + schoolIdReq + ".json";
                }

                Json::StyledWriter writer;
                fstream.open(path , std::ios::in);
                buff << fstream.rdbuf();
                fstream.close();
                reader.parse(buff.str(), templateRoot);

                std::string numClass;
                std::string letterClass;

                Json::Value listEditClass = Json::Value(Json::objectValue);
                Json::Value listChangesClass = Json::Value(Json::objectValue);
                Json::Value listAddClass = Json::Value(Json::arrayValue);
                Json::Value listRmClass = Json::Value(Json::arrayValue);

                listEditClass = reqEditNotesRoot["editChanges"];
                for (auto letter : listEditClass.getMemberNames()) {
                    numClass = letter.substr(0, letter.find('_'));
                    letterClass = letter.substr(letter.find('_')+1, letter.back()-1);
                    for (auto key : listEditClass[letter].getMemberNames()) {
                        templateRoot["classes"][numClass][letterClass][key] = listEditClass[letter][key];
                        if (key.substr(0, key.find('_')) == "absent") {
                            templateRoot["classes"][numClass][letterClass]["absent"][key.substr(key.find('_')+1, key.back()-1)] = listEditClass[letter][key];
                        }
                    }
                }
                fstream.open(path,std::ios::out);
                fstream << writer.write(templateRoot);
                fstream.close();
                resultMap["status"] = 200;
                std::system(std::string("./commit_data.sh -d 'admin change for " + schoolIdReq + "'").c_str() );
                return resultMap;

            }
            else { //template case
                Json::StyledWriter writer;
                const std::string& templatePath = "data/" + schoolIdReq + "/schoolTemplateDate.json";
                fstream.open(templatePath , std::ios::in);
                buff << fstream.rdbuf();
                fstream.close();
                reader.parse(buff.str(), templateRoot);

                std::string numClass;
                std::string letterClass;

                Json::Value listEditClass = Json::Value(Json::objectValue);
                Json::Value listChangesClass = Json::Value(Json::objectValue);
                Json::Value listAddClass = Json::Value(Json::arrayValue);
                Json::Value listRmClass = Json::Value(Json::arrayValue);

                listEditClass = reqEditNotesRoot["editChanges"];
                for (auto letter : listEditClass.getMemberNames()) {
                    numClass = letter.substr(0, letter.find('_'));
                    letterClass = letter.substr(letter.find('_')+1, letter.back()-1);
                    for (auto key : listEditClass[letter].getMemberNames()) {
                        templateRoot["classes"][numClass][letterClass][key] = listEditClass[letter][key];
                        if (key.substr(0, key.find('_')) == "absent") {
                            templateRoot["classes"][numClass][letterClass]["absent"][key.substr(key.find('_')+1, key.back()-1)] = listEditClass[letter][key];
                        }
                    }
                }

                listChangesClass = reqEditNotesRoot["listChanges"];
                listAddClass = listChangesClass["add"];
                listRmClass = listChangesClass["rm"];

                for (auto el : listAddClass) {
                    numClass = el.asString().substr(0, el.asString().find('_'));
                    letterClass = el.asString().substr(el.asString().find('_')+1, el.asString().back()-1);

                    templateRoot["classes"][numClass][letterClass] = genLetterRoot();
                    templateRoot["classes"][numClass][letterClass]["name"] = numClass + '_' + letterClass;
                }
                for (auto el : listRmClass) {
                    numClass = el.asString().substr(0, el.asString().find('_'));
                    letterClass = el.asString().substr(el.asString().find('_')+1, el.asString().back()-1);

                    templateRoot["classes"][numClass].removeMember(letterClass);
                }
                fstream.open(templatePath,std::ios::out);
                fstream << writer.write(templateRoot);
                fstream.close();
                resultMap["status"] = 200;
                std::system(std::string("./commit_data.sh -d 'template change for " + schoolIdReq + "'").c_str());
                return resultMap;
            }

        }
        catch (Json::Exception &e ) {
            std::map<std::string, Json::Value> map;
            map["err"] = Json::Value{ e.what() };
            return map;
        }
        catch (std::exception &e ) {
            std::map<std::string, Json::Value> map;
            map["err"] = Json::Value{ e.what() };
            return map;
        }
    }
}

//crow::response writeEditNotesForm(std::map<std::string, Json::Value> &editNotesMap) {
//    std::fstream fstream;
//    Json::Value buff_J;
//    Json::Reader Jreader;
//    std::ostringstream buff_str;
//    std::string currDatePath = "data/" + schoolId + '/' + genToken(schoolId) + ".json";
//    fstream.open(currDatePath, std::ios::in);
//    buff_str << fstream.rdbuf();
//    fstream.close();
//    Jreader.parse(buff_str.str(), buff_J);
//
//    /// trys to edit data
//    Json::Value neededAbsentPart = Json::Value(Json::objectValue);
//    Json::Value globalNum;
//
//    Json::Value rootTemplateDay = Json::Value(Json::objectValue);
//    std::stringstream buff_str_T;
//    fstream.open("data/" + schoolId + '/' + "schoolTemplateDate.json", std::ios::in);
//    buff_str_T << fstream.rdbuf();
//    fstream.close();
//
//    Jreader.parse(buff_str_T.str(), rootTemplateDay);
//
//    if (editNotesMap["globalNum"].asString() == "" || editNotesMap["globalNum"].asString() == "!" || editNotesMap["globalNum"].asString() == "-" || editNotesMap["globalNum"].asString() == " ")
//    {
//        globalNum = rootTemplateDay["classes"]
//                [editNotesMap["classNum"].asString()]
//                [editNotesMap["classLetter"].asString()]
//                ["amount"];
//
//        buff_J["classes"]
//        [editNotesMap["classNum"].asString()]
//        [editNotesMap["classLetter"].asString()]
//        ["amount"] = globalNum.asString();
//    }
//    else {
//        try {
//            rootTemplateDay["classes"]
//             [editNotesMap["classNum"].asString()]
//             [editNotesMap["classLetter"].asString()]
//             ["amount"] = editNotesMap["globalNum"].asString();
//
//            Json::StyledWriter writer;
//            fstream.open("data/" + schoolId + '/' + "schoolTemplateDate.json", std::ios::out);
//            fstream << writer.write(rootTemplateDay);
//            fstream.close();
//        }
//        catch (std::exception &e) {
//            return crow::response(500, e.what());
//        }
//            buff_J["classes"]
//        [editNotesMap["classNum"].asString()]
//        [editNotesMap["classLetter"].asString()]
//        ["amount"] =
//                rootTemplateDay["classes"]
//        [editNotesMap["classNum"].asString()]
//        [editNotesMap["classLetter"].asString()]
//        ["amount"];
//    }
//
//    neededAbsentPart = buff_J["classes"]
//    [editNotesMap["classNum"].asString()]
//    [editNotesMap["classLetter"].asString()]
//    ["absent"];
//
//
//    for (const auto& [first, second] : editNotesMap) {
//            if (!second.empty() && first.substr(0, first.find('_')) == "absent") {
//                try {
//                    neededAbsentPart[first.substr(first.find('_') + 1, first.back() - 1)] = second;
//                }
//                catch (Json::Exception &e) {
//                    try {
//                        std::cout << "--- Err: " << e.what() << '\n';
//                        neededAbsentPart[first.substr(first.find('_') + 1, first.back() - 1)] = second;
//                    }
//                    catch (Json::Exception &e) {
//                        std::cout << "no way to ignore err - " << e.what();
//                    }
//                }
//            }
//    }
//
//    buff_J["classes"]
//    [editNotesMap["classNum"].asString()]
//    [editNotesMap["classLetter"].asString()]
//    ["absent"] = neededAbsentPart;
//    fstream.open("data/" + schoolId + '/' + genToken(schoolId) + ".json", std::ios::out | std::ios::binary);
//    fstream << buff_J;
//    fstream.close();
//    std::system(std::string("./commit_data.sh -d 'form edit for " + schoolId + "'").c_str());
//    return crow::response(200, "ladna");
//}

//crow::response writeForEditNotesForm(std::string reqEdit) {
//    std::map<std::string, Json::Value> absentMap = handlerGenMapOfEditNotes(reqEdit);
//
//    //error handler
//    if (!absentMap["err"].empty()) {
//        std::cout << "--- Error:"<< absentMap["err"] << '\n';
//        return crow::response(500, "error: " + absentMap["err"].asString());
//    }
//    //non error
//   return writeEditNotesForm(absentMap);
//}

crow::response getStaticFileJson(const crow::request &reqRoot, bool isShort) {
    Json::Reader reader;
    Json::Value reqJ;
    reader.parse(reqRoot.body, reqJ);

    std::string schoolId = reqJ["schoolId"].asString();


    if (isShort) {
        return handleCommonReq(schoolId);
    }
    else {
        std::string methodReq = reqJ["method"].asString();
        std::string actionReq = reqJ["action"].asString();
        std::string periodReq = reqJ["period"].asString();
        if (methodReq == "commonCase") {
            if (actionReq  == "get") {
                return handleCommonReq(schoolId, false);
            }
            else if (actionReq == "edit") {
                crow::response res;
                std::map<std::string, Json::Value> map = handlerGenMapOfEditNotes(reqJ["changesList"].toStyledString(), false, reqJ["schoolId"].asString());
                if (map["err"].empty()) {
                    res.code= 200;
                }
                else {
                    res.body = map["err"].asString();
                }
                return res;
            }
            else {
                return crow::response(400, "undenfined action");
            }
        }
        else if (methodReq == "customCase") {
            if (actionReq == "get") {
                //TODO refactor to one if check and one foo()
                if (periodReq == "dateToDate") {
                    Json::Value root = reqJ["date"];
                    std::vector<std::string> datesList;
                    for (auto el : root) {
                        datesList.push_back(el.asString());
                    }
                    return handleDTDReq(schoolId, datesList);
                }
                else if (periodReq != "") {
                    std::string dateReq = reqJ["date"].asString();
                    return handleUserReq(schoolId, dateReq, periodReq);
                }
                else {
                    return crow::response(500, "out from if chain");
                }
            }
            else if (actionReq == "edit") {
                crow::response res;
                std::map<std::string, Json::Value> map = handlerGenMapOfEditNotes(reqJ["changesList"].toStyledString(), false, reqJ["schoolId"].asString(), "customCase",reqJ["date"].asString());
                if (map["err"].empty()) {
                    res.code= 200;
                }
                else {
                    res.body = map["err"].asString();
                }
                return res;
            }
            else return crow::response(400, "undenfined action");

        }

        else if (methodReq == "templateCase") {
            std::string action = reqJ["action"].asString();

            if (action == "get") {
                return getTemplateDataInterface(reader, reqJ, schoolId);
            }
            else if (action == "edit") {
                const std::string& userKey = reqJ["key"].asString();
                if (isCorrUserKey(userKey, schoolId)) {
                    crow::response res;
                    Json::StyledWriter writer;
                    // * get userChanges
                    Json::Value rootJ = reqJ["changesList"];

                    std::map<std::string, Json::Value> map = handlerGenMapOfEditNotes(rootJ.toStyledString(), false, schoolId,"templateCase");
                    if (map["err"].empty()) {
                        res.code = 200;
                    }
                    else {
                        res.body = map["err"].asString();
                    }
                    return res;
                }
                else {
                    return crow::response(400, "Wrong superKey");
                }
            }
            else return crow::response(410, "Undenfined action");
        }
        else {
            return crow::response(500, "Unknown method");
        }
    }

}

crow::response getTemplateDataInterface(Json::Reader &reader, const Json::Value &reqJ, const std::string &schoolId) {
    std::fstream fstream;
    std::stringstream buff_str;
    crow::response res;
    const std::string userKey = reqJ["key"].asString();
    if (isCorrUserKey(userKey, schoolId)) {
        res.set_static_file_info(std::string("data/" + schoolId + "/schoolTemplateDate.json"));
        return res;
    }
    else {
        return crow::response(400, "Wrong superKey");
    }
}

bool isCorrUserKey(const std::string& userKey, const std::string &schoolId) {
    Json::Reader reader;
    std::fstream fstream;
    std::stringstream buff_str;
    std::string corrKey;
    try {
        fstream.open("data/" + schoolId + "/schoolData.json", std::ios::in);
        buff_str << fstream.rdbuf();
        fstream.close();
        if (!buff_str.str().empty()) {
            Json::Value rootSchoolData;
            reader.parse(buff_str.str(), rootSchoolData);
            corrKey = rootSchoolData["superAdminKey"].asString();
            if (corrKey == userKey) {
                return true;
            }
            else {
                //! wrong adminKeyInReq
                return false;
            }
        }
        else {
            std::cout << "---Err: " <<  "unable reading school date file" << '\n';
            return false;
        }
    }
    catch (std::exception &e) {
        std::cout << "---Err: " << e.what() << '\n';
        return false;
    }
}

//Note uses for today's data
crow::response handleCommonReq(const std::string &schoolId, bool isShort) {
    crow::response res;
    std::string reqPath;
    std::string currDate = genToken(schoolId);
    reqPath = std::string("data/" + schoolId + "/" + currDate + ".json");
    if (isShort) { //short data (names only)
        Json::Reader jReader;
        Json::Value classNames = Json::Value(Json::arrayValue);
        Json::Value root;
        std::ostringstream ostringstream;
        std::ifstream ifstream;

        try {
            ifstream.open(reqPath);
            ostringstream << ifstream.rdbuf();
            ifstream.close();
            if (ostringstream.str() == "") { //if file doesnt exist
                genTempClassesAsJson(reqPath, schoolId);
            }
            jReader.parse(ostringstream.str(), root);
            root = root["classes"];
            for (auto num : root) {
                for (auto letter : num) {
//                    std::cout << root[std::to_string(num)][].get("name");
                    classNames.append(letter["name"].asString());
                }
            }
            Json::FastWriter jWriter;
            res.body = jWriter.write(classNames);
            return res;
        }
        catch (std::exception &e) {
            std::cout << "--- Err: " << e.what();
        }


    }
    else { //full data (for interface)
        res.set_static_file_info(reqPath);
        if (!res.is_static_type()) { //if file doesn't exist
            Json::FastWriter writer;
            std::string resJ = writer.write(genTempClassesAsJson(reqPath, schoolId));

            res.body = resJ;
            return res;
        }
        else { //if exist
            res.add_header("date", currDate);
            return res;
        }
    }
    return crow::response(120);
}

// * Interface one date
crow::response handleUserReq(const std::string& schoolId, const std::string& userDate, const std::string& period) {
    crow::response result;

    if (period == "usercase") { //Normal case
        std::string reqPath;
        reqPath = std::string("data/" + schoolId + "/" + userDate + '.' + schoolId + ".json");
        result.set_static_file_info(reqPath);
        if (!result.is_static_type()) { //if file doesn't exist
            Json::FastWriter writer;
            result.body = std::string(writer.write(genTempClassesAsJson(reqPath, schoolId)));

            result.add_header("date", "Файл создан только что");
            return result;
        }
        else { //if exist
            result.add_header("date", userDate);
            return result;
        }
    }
    return result;
}

// * Interface list of dates
crow::response handleDTDReq(const std::string& schoolId, std::vector<std::string> datesList) {
    crow::response res;
    std::string path;
    std::fstream fstream;
    std::stringstream sbuff;

    Json::Reader Jreader;
    Json::Value root;
    std::set<std::string> classesNames;
    std::set<std::string> lastNamesRecpCause;
    Json::Value datesListJ = Json::Value(Json::arrayValue);



    // * filling dates for js @group.title [start - end]
    datesListJ.append(datesList[0]);
    datesListJ.append(datesList.at(datesList.size()-1));

    root["datesList"] = datesListJ;




    std::cout << root;

    Json::Value templateJson;
    fstream.open("data/" + schoolId + "/" + "schoolTemplateData.json", std::ios::in);
    if (fstream.good()) {
        sbuff << fstream.rdbuf();
        fstream.close();
        Jreader.parse(sbuff.str(), templateJson);
        templateJson = templateJson["classes"];
        for (auto num : templateJson.getMemberNames()) {
            for (auto letter : templateJson[num].getMemberNames()) {
//                classesNames.insert(templateJson[num][letter]["name"].asString());
                //TODO add class object of class
                //TODO add class admin

            }
        }
    }
    else {
        return crow::response(500, "--- ERR => no templateFile in root dir \n");
    }
    /*
     Патронажный журнал / 1 янв. - 1 февр.
     1. Класс (t)
     2. Общее кол-во в классе (t)
     3. Отсутсвующие в классе (each date +)
     4. Фамилии тех, кто осутвовал, хотя бы раз (each date + set)
     5. Кол-во + фамилии (each date + set)
        5.1. ОРВИ
        5.2. Уваж. прич.
        5.3. Неуваж. прич.
        5.4. Бесплатники
    6. Клас. рук., прикрепленный к классу (ещё нужно собирать как-то - либо самим редактировать шаблон, либо дать самим клас.рук., чтобы они хотя бы раз заполнили)
     `
    */
    // reading data from given datesList and insert it to sets
    for (auto el : datesList) {
        path = "data/" + schoolId + "/" + el + '.' + schoolId + ".json";
        fstream.open(path, std::ios::in);
        if (!fstream.good()) {
            std::cout << "Bad input for " << path << "\n";
        }
        else {
            sbuff << fstream.rdbuf();
            fstream.close();
            std::cout << el << "----->"<< sbuff.str();
            //TODO absents


        }
    }

    return res;
}