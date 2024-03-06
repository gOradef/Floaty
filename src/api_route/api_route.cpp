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
baseReq::~baseReq() {
    delete interface;
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


//Region abstractDataHandler

dataInterface::dataInterface(const std::string &schoolId) {
    this->schoolId = schoolId;
}
std::string dataInterface::genToken() {
    time_t now;
    time(&now);
    struct tm ltm;
    localtime_r(&now, &ltm);
    std::string dynamicDate{std::to_string(1900 + ltm.tm_year) + '.' +  std::to_string(ltm.tm_mon+1) + '.' + std::to_string(ltm.tm_mday)};
    std::string secret = dynamicDate + '.' + schoolId;
    return secret;
}

int dataInterface::genNewData() {
    Json::Value newData;
    try {
        fstream.open(std::string("data/" + schoolId + "/schoolTemplateDate.json"), std::ios::in);
        ostringstream << fstream.rdbuf();
        fstream.close();

        if (!ostringstream.str().empty()) {
            fstream.open(reqPath, std::ios::out);
            fstream << ostringstream.str();
            fstream.close();

            Json::Reader reader;
            reader.parse(ostringstream.str(), newData);
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
            newData["classes"] = root2;
            fstream.open(std::string("data/"+ schoolId + "/schoolTemplateDate.json"), std::ios::out);
            Json::StyledWriter writer;
            fstream << writer.write(newData);
            fstream.close();
            return 201;
        }

    }
    catch (std::exception &e) {
        std::cout << "---ERR: " << e.what() << '\n';
    }
}
Json::Value dataInterface::getCurrentData() {
    reqPath = std::string("data/" + schoolId + '/' + genToken() + ".json");
    fstream.open(reqPath);
    try {
        if (!fstream.good()) { //file exist
            genNewData();
        }
        Json::Value root;
        ostringstream << fstream.rdbuf();
        jReader.parse(ostringstream.str(), root);
        return root["classes"];
    }
    catch (std::exception &e) {
        std::cout << "ERR ON READEING currentDate - " << e.what() << '\n';
    }
    return "-1";
}



dataInterfaceForm::dataInterfaceForm(const std::string &schoolId) : dataInterface(schoolId) {
    reqPath = std::string("data/" + schoolId + '/' + genToken() + ".json");
}


//should return list of classes
crow::response dataInterfaceForm::getData() {
    crow::response res;
    Json::Value root = getCurrentData();
    try {
    Json::Value classNames = Json::Value(Json::arrayValue);

        for (auto num : root) {
            for (auto letter : num) {
                //Debug std::cout << root[std::to_string(num)][].get("name");
                classNames.append(letter["name"].asString());
            }
        }
        res.body = jWriter.write(classNames);
        return res;
    }
    catch (std::exception &e) {
        std::cout << "--- Err: " << e.what();
    }
    return crow::response(500, "Err in form");
}
//schould do changes and return status code
crow::response dataInterfaceForm::editData(const std::string& userBuff) {

    Json::Value reqEditNotesRoot;
    jReader.parse(userBuff, reqEditNotesRoot);
    std::map<std::string, Json::Value> absentMap;
    try {
        std::string className = reqEditNotesRoot["className"].asString();
        std::string globalNum = reqEditNotesRoot["globalNum"].asString();
        std::string absentNum = reqEditNotesRoot["absentNum"].asString();
        Json::Value listAbsent = Json::Value(Json::arrayValue);

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

    }
    catch (Json::Exception &e) {
        std::map<std::string, Json::Value> map;
        map["err"] = Json::Value{ e.what() };
    }

    std::map<std::string, Json::Value> editNotesMap = absentMap;

    std::fstream fstream;
    Json::Value buff_J;

    buff_J["classes"] = getCurrentData();

    /// trys to edit data
    Json::Value neededAbsentPart = Json::Value(Json::objectValue);
    Json::Value globalNum;

    Json::Value rootTemplateDay = Json::Value(Json::objectValue);
    std::stringstream buff_str_T;
    fstream.open("data/" + schoolId + '/' + "schoolTemplateDate.json", std::ios::in);
    buff_str_T << fstream.rdbuf();
    fstream.close();

    jReader.parse(buff_str_T.str(), rootTemplateDay);

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
    fstream.open("data/" + schoolId + '/' + genToken() + ".json", std::ios::out | std::ios::binary);
    fstream << buff_J;
    fstream.close();
    std::system(std::string("./commit_data.sh -d 'form edit for " + schoolId + "'").c_str());
    return crow::response(200, "ladna");
}


dataInterfaceInterface::dataInterfaceInterface(const std::string& schoolId, const std::string& userDate) : dataInterface(schoolId) {
    reqPath = std::string("data/" + schoolId + '/' + genToken() + ".json");
    this->userDate = userDate;
}

crow::response dataInterfaceInterface::getData() {
    crow::response res;
    res.set_static_file_info(reqPath);

    if (!res.is_static_type()) { //if file doesn't exist
        genNewData();
        res.set_static_file_info(reqPath);
        res.add_header("date", "Файл создан только что");
        //! WARN
        res = getData();
        return res;
    }
    else { //if exist
        res.add_header("date", std::string("Сегодня (" + genToken() + ')'));
        return res;
    }
    return crow::response(400, "unknown type of req");
}
crow::response dataInterfaceInterface::getOptionalData() {
    crow::response res;
    reqPath = std::string("data/" + schoolId + "/" + userDate + '.' + schoolId + ".json");
    res.set_static_file_info(reqPath);
    if (!res.is_static_type()) {//if file doesn't exist
        if ((userDate + '.' + schoolId) == genToken()) {  // is same as today's date
            genNewData();
            res.add_header("date", "Файл создан только что");
            //! WARN
            res = getOptionalData();
            return res;
        }
        else {
            return crow::response(400, "Данные за выбранную дату (" + userDate + ") отсутсвутют.");
        }
    }
    else { //if exist
        res.add_header("date", userDate);
        return res;
    }
}

void dataInterfaceInterface::setDate(const std::string &date) {
    this->userDate = date;
}
crow::response dataInterfaceInterface::editData(const std::string& userBuff) {
    Json::Value reqEditNotesRoot;

    jReader.parse(userBuff, reqEditNotesRoot);

    reqEditNotesRoot = reqEditNotesRoot["changesList"];
    crow::response res;
    try {
        Json::Value templateRoot = Json::Value(Json::objectValue);

        std::string path = "data/" + schoolId + '/' + userDate + ".json";

        fstream.open(path, std::ios::in);
        ostringstream << fstream.rdbuf();
        fstream.close();
        jReader.parse(ostringstream.str(), templateRoot);

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
        fstream << jWriter.write(templateRoot);
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

//Region dataInterfaceTemp

dataInterfaceTemp::dataInterfaceTemp(const std::string &schoolId) : dataInterface(schoolId) {
    reqPath = std::string("data/" + schoolId + "/schoolTemplateDate.json");
}

crow::response dataInterfaceTemp::getData() {
    crow::response res;
    res.set_static_file_info(reqPath);
    return res;
}

crow::response dataInterfaceTemp::editData() {

    return crow::response();
}

crow::response dataInterfaceTemp::editData(const std::string& userBuff) {
    crow::response res;
    Json::Value templateRoot;

    Json::Value reqEditNotesRoot;
    jReader.parse(userBuff, reqEditNotesRoot);
    const std::string& templatePath = "data/" + schoolId + "/schoolTemplateDate.json";
    fstream.open(templatePath , std::ios::in);
    ostringstream << fstream.rdbuf();
    fstream.close();
    jReader.parse(ostringstream.str(), templateRoot);
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
    fstream << jWriter.write(templateRoot);
    fstream.close();
    res.code = 200;
    std::system(std::string("./commit_data.sh -d 'template change for " + schoolId + "'").c_str());
    return res;
}

Json::Value dataInterfaceTemp::genLetterRoot() {
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

//Region Form
formReq::formReq(const crow::request& req) : baseReq(req) {
    interface = new dataInterfaceForm(schoolId);
}

crow::response formReq::getData() {
    return interface->getData();
}

crow::response formReq::editData() {
    return interface->editData(userBuff);
}

//Region builderOfInterface

interfaceReq* interfaceBuilder::createInterface(const crow::request &req) {
    if (req.get_header_value("key") != "") {

        schoolId = req.get_header_value("schoolId");
        std::string userKey = req.get_header_value("key");
        interfaceTempReq client(req);
        if (isCorrUserKey(userKey)) {
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
    interface = new dataInterfaceInterface(schoolId, date);
}

crow::response interfaceReq::getData() {
    if (method == "commonCase") { //get data for today
        if (period == "today") {
            crow::response res;
            return interface->getData();
        }
        else {
            return crow::response(400, "unknown type of req");
        }
    }
    else if (method == "customCase") { //get data for userDate
        if (period == "usercase") {
            crow::response res;
            return interface->getOptionalData();
        }
        else if (period == "dateToDate") {
            crow::response res;
            std::string path;
            std::fstream fstream;
            std::stringstream sbuff;

            Json::Reader Jreader;
            Json::Value root;
            std::set<std::string> classesNames;
            std::set<std::string> lastNamesRecpCause;
            Jreader.parse(userBuff, root);
            std::vector<std::string> datesList;
            Json::Value datesListJ = Json::Value(Json::objectValue);
            datesList = root.getMemberNames();

            // * filling dates for js @group.title [start - end]

            datesListJ = root["userDate"];
            for (const auto& el : datesListJ) {
                datesList.push_back(el.asString());
            }

            Json::Value templateJson;
            fstream.open("data/" + schoolId + "/" + "schoolTemplateDate.json", std::ios::in);
            if (fstream.good()) {
                sbuff << fstream.rdbuf();
                fstream.close();
                Jreader.parse(sbuff.str(), templateJson);
                templateJson = templateJson["classes"];

                for (const auto& num : templateJson.getMemberNames()) {
                    for (auto letter : templateJson[num].getMemberNames()) {
                        //TODO брать из шаблона оболочку
                        // * classesNames.insert(templateJson[num][letter]["name"].asString());
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
                if (fstream.good()) {
                    sbuff << fstream.rdbuf();
                    fstream.close();

                    std::cout << el << "----->"<< sbuff.str();
                    //TODO absents
                }
                else {
                    std::cout << "Bad input for " << path << "\n";
                }
            }
            return res;
        }
    }
    else {
        return crow::response(400, "No such method");
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
    interface->setDate(date);
    return interface->editData(userBuff);
}

//Region interfaceTEMPLATEReq



interfaceTempReq::interfaceTempReq(const crow::request& req) : interfaceReq(req) {
    userKey = req.get_header_value("key");
    interface = new dataInterfaceTemp(schoolId);
}

bool interfaceBuilder::isCorrUserKey(const std::string& userKey) {
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
    return interface->getData();
}

crow::response interfaceTempReq::editData() {
    return interface->editData(userBuff);
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