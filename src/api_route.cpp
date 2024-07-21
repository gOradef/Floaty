#include "Floaty/api_route.h"
#include <cstdlib>

Request::Request(ConnectionPool *connectionPool, const crow::request &req) {
    this->_connectionPool = connectionPool;
    this->_connection = _connectionPool->getConnection();

    std::string user_token = req.get_header_value("token");
    jwt::decoded_jwt decodedJwt = jwt::decode(user_token);

    pqxx::read_transaction rtx(*_connection);

    this->_org_id = rtx.exec_prepared1("decode",decodedJwt.get_payload_claim("aud").as_string()).front().as<std::string>();
    this->_user_id = rtx.exec_prepared1("decode", decodedJwt.get_subject()).front().as<std::string>();
}
Request::~Request() {
    _connectionPool->releaseConnection(_connection);
}

std::vector<std::string> Request::getRoles() {
    std::vector<std::string> roles;
    pqxx::read_transaction readTransaction(*_connection);
    auto res = readTransaction.exec_prepared("user_roles_get", _org_id, _user_id);
    for (auto role : res) {
        roles.emplace_back(role.front().as<std::string>());
    }
    return roles;
}

std::map<std::string, std::string> Request::getClasses() {
    std::map<std::string, std::string> classesMap;
    pqxx::read_transaction work(*_connection);
    auto result = work.exec_prepared("user_classes_get", _org_id, _user_id);
    for (auto row : result) {
        auto id = row["id"].as<std::string>();
        auto name = row["class_name"].as<std::string>();
//        std::cout << id << '\t' << name << '\n'; //!debug

        classesMap[id] = name;
    }
    return classesMap;
}

/**
 * @throws std::invalid_argument in case wrong constuct
 */
classHandler::classHandler(ConnectionPool *connectionPool, const crow::request &req) : Request(connectionPool, req) {
    if (req.url_params.get("class") == nullptr)
        throw std::invalid_argument("No class parameter in URL_params");

    std::string temp_class_id = req.url_params.get("class");

    pqxx::read_transaction rtx(*_connection);
    bool isClassExists = rtx.exec_prepared1("is_class_owned", _org_id, _user_id, temp_class_id).front().as<bool>();
    if (!isClassExists) {
        throw std::invalid_argument("Such class doesnt exists");
    }
    this->_class_id = temp_class_id;

}

/**
 *
 * @return json: {"students": [], "fstudents": []}
 */
crow::json::wvalue classHandler::getClassStudents() {
    crow::json::wvalue json;
    pqxx::read_transaction rtx(*_connection);

    for (auto stud_type : this->_stud_types) {
        std::vector<std::string> vec;
        auto fios = rtx.exec_prepared("class_" + stud_type + "_get",
                                      this->_org_id,
                                      this->_user_id,
                                      this->_class_id
                          );
        for (auto fio : fios) {
            vec.emplace_back(fio.front().as<std::string>());
        }
        json[stud_type] = vec;

    }
    return json;
}
/**
 * @brief Sets input students into class list, depending onto params.
 * @param changes - json. {stud_type["[f]students"]->action[get / remove]->fios[json array]}
 * @throws std::runtime_error exception
 */
    void classHandler::updateClassStudents(const std::string &changes) {

        crow::json::rvalue root = crow::json::load(changes);

        if (!root)
            throw std::runtime_error("Cant parse changes of user. Is it valid?");

        pqxx::work work(*_connection);

        for (auto& stud_type : _stud_types) {
            for (auto& action : _actions) {
                if (root.has(stud_type) && root[stud_type].has(action)) {
                    std::vector<std::string> vec;
                    for (auto fio : root[stud_type][action]) {
                        vec.emplace_back(fio);
                    }
                    work.exec_prepared("class_" + stud_type + "_" + action, this->_org_id,
                                       this->_user_id,
                                       this->_class_id,
                                       vec);
                }
            }
        }

        work.commit();
}

/**
 *
 * @param changes - json
 * @example input:
 * @code
 * {
 *   "absent_fios": {
 *     "global": [],
 *     "ORVI": [],
 *     "fstudents": [],
 *     "respectful": [],
 *     "not_respectful": []
 *   }
 * }
 *@endcode
 *
 * @throws std::runtime_error
 */

void classHandler::insertData(const std::string &changes) {
    if (changes.empty())
        throw std::runtime_error("Empty request");

    crow::json::rvalue jsonRoot = crow::json::load(changes);
    if (!jsonRoot)
        throw std::runtime_error("Can not read body request. Is is json format?");
    if (!jsonRoot.has("absent_lists"))
        throw std::runtime_error("Can not read body request. Is is has head?");

    pqxx::work work(*_connection);
    auto res = work.exec_prepared("class_data_insert", _org_id, _class_id, changes);

    work.commit();
}

schoolManager::schoolManager(ConnectionPool *cp, const crow::request &req) : Request(cp, req) {
    pqxx::read_transaction readTransaction(*_connection);
    auto res = readTransaction.exec_prepared("is_user_has_role", _org_id, _user_id, "dev").front().front().as<bool>();

    if (!res)
        throw std::invalid_argument("User doesnt have needed role. Request access from admin");

    _changes = req.body;
}

crow::json::wvalue schoolManager::getData(const std::string& date) {
    pqxx::read_transaction readTransaction(*_connection);

    if (!date.empty()) {
        // Check if the date is valid
        if (!readTransaction.exec_params1("select is_date($1)", date).front().as<bool>()) {
            throw std::runtime_error("Such date isn't a date");
        }

        // Check if school data exists for the given date
        if (!readTransaction.exec_prepared1("is_school_data_exists", _org_id, date).front().as<bool>()) {
            return crow::json::wvalue(nullptr);
        }
    }

// Execute the query with the appropriate date parameter or nullptr if date is empty
    pqxx::result res;
    if (date.empty()) {
        res = readTransaction.exec_prepared("school_data_get", _org_id, nullptr);
    }
    else {
        res = readTransaction.exec_prepared("school_data_get", _org_id, date);
    }
// Prepare JSON result
    crow::json::wvalue root;
    for (const auto& row : res) {
        root[row["class_id"].as<std::string>()] = row["class_body"].as<std::string>();
    }

    return root;
}

/**
 * @return data for today
 */

//! ARCHIVED
baseReq::baseReq() {};
baseReq::baseReq(const crow::request &req) {
    schoolId = req.get_header_value("schoolId");
    action = req.get_header_value("action");
    method = req.get_header_value("method");
    if (!req.body.empty()) { // for editing req
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
//MARK: DATAHandler

//Region: abstractDataHandler
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
        sbuff << fstream.rdbuf();
        fstream.close();

        if (!sbuff.str().empty()) {
            fstream.open(reqPath, std::ios::out);
            fstream << sbuff.str();
            fstream.close();

            Json::Reader reader;
            reader.parse(sbuff.str(), newData);
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
            Json::Value numOfPeople = 0;

            Json::Value absentSubRoot(Json::objectValue);
            Json::Value numOfPeopleAbsent = 0;
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
//    root2["10"]["А"]["name"] = "the best!"; //devs
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
        sbuff << fstream.rdbuf();
        jReader.parse(sbuff.str(), root);
        return root["classes"];
    }
    catch (std::exception &e) {
        std::cout << "ERR ON READEING currentDate - " << e.what() << '\n';
    }
    return "-1";
}


//MARK: DATA_FORM
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
        Json::Value globalNum = reqEditNotesRoot["globalNum"];
        Json::Value absentNum = reqEditNotesRoot["absentNum"];
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
        ["amount"] = globalNum;
    }
    else {
        try {
            rootTemplateDay["classes"]
            [editNotesMap["classNum"].asString()]
            [editNotesMap["classLetter"].asString()]
            ["amount"] = editNotesMap["globalNum"];

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

//MARK: DATA_INTERFACE
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
        res.add_header("date", std::string("Today (" + genToken() + ')'));
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

crow::response dataInterfaceInterface::getDTDData(const std::string& userBuff) {
    crow::response res;
    std::string path;
    Json::Value root;
//!   std::set<std::string> classesNames;
    std::set<std::string> lastNamesRecpCause;

    jReader.parse(userBuff, root);
    std::vector<std::string> datesList;
    Json::Value datesListJ = Json::Value(Json::arrayValue);

    // * filling dates for js @group.title [start - end]
    datesListJ = root["userDate"];
    for (const auto& el : datesListJ) {
        datesList.push_back(el.asString());
    }
    Json::Value resultJ;
    Json::Value templateJson;
    fstream.open("data/" + schoolId + "/" + "schoolTemplateDate.json", std::ios::in);
    if (fstream.good()) {
        sbuff << fstream.rdbuf();
        fstream.close();
        jReader.parse(sbuff.str(), templateJson);
        templateJson = templateJson["classes"];

        for (const auto& num : templateJson.getMemberNames()) {
            for (auto letter : templateJson[num].getMemberNames()) {
// !                classesNames.insert(templateJson[num][letter]["name"].asString());

                resultJ[num][letter]["amount"] = templateJson[num][letter]["amount"];
                resultJ[num][letter]["name"] = templateJson[num][letter]["name"];
                resultJ[num][letter]["absent"] = Json::Value(Json::objectValue);


                resultJ[num][letter]["absent"]["amount"] = 0;

                //TODO classAdmin
            }
        }
    }
    else {
        return crow::response(500, "--- ERR => no templateFile in root dir \n");
    }
    /*
     Патронажный журнал / 1 янв. - 1 февр.
     1. Класс (t) +
     2. Общее кол-во в классе (t) +
     3. Отсутсвующие в классе (each date +) (+)
     4. Фамилии тех, кто осутвовал, хотя бы раз (each date + set)
     5. Кол-во + фамилии (each date + set)
        5.1. ОРВИ
        5.2. Уваж. прич.
        5.3. Неуваж. прич.
        5.4. Бесплатники
    6. Клас. рук., прикрепленный к классу (ещё нужно собирать как-то - либо самим редактировать шаблон, либо дать самим клас.рук., чтобы они хотя бы раз заполнили)
     `
    */ //TODO sum amounts of skips
    // reading data from given datesList and insert it to sets
    for (auto el : datesList) {
        std::cout << "In loop for: " << el << "\n";
        path = "data/" + schoolId + "/" + el + '.' + schoolId + ".json";
        std::cout << path;
        fstream.open(path, std::ios::in);
        if (fstream.good()) {
            std::ostringstream ss;
            ss << fstream.rdbuf();
            fstream.close();
            Json::Value tmpData;
            jReader.parse(ss.str(), tmpData);
            for (auto const& num : tmpData["classes"].getMemberNames()) {
                for (auto const& letter : tmpData["classes"][num].getMemberNames()) {
                    for (auto const& prop : tmpData["classes"][num][letter]["absent"].getMemberNames()) {
                        Json::Value* ptProp = &tmpData["classes"][num][letter]["absent"][prop];
                        if (ptProp->type() == Json::ValueType::intValue) { //integer
                            std::cout << "INTEGER\n";
                            resultJ[num][letter]["absent"][prop] = resultJ[num][letter]["absent"][prop].asInt() + ptProp->asInt();
                        }
                        else if (tmpData["classes"][num][letter]["absent"][prop].isArray()) {
                            std::cout << "ARRAY\n";

                            //Settind up merged array of data
                            Json::Value mergedArray = Json::ValueType(Json::arrayValue);
                            std::set<Json::Value> uniqVals;
                            for (auto resVal : resultJ[num][letter]["absent"][prop]) {
                                mergedArray.append(resVal);
                                uniqVals.insert(resVal);
                            }
                            for (auto tmpItem : *ptProp) {
                                if (uniqVals.find(tmpItem) == uniqVals.end()) {
                                    mergedArray.append(tmpItem);
                                    uniqVals.insert(tmpItem);
                                }
                            }

                            resultJ[num][letter]["absent"]["amount_" + prop] = mergedArray.size();
                            resultJ[num][letter]["absent"][prop] = mergedArray;
                        }
                        else {
                            std::cout << "WTF - " << prop << '\n';
                            std::cout << ptProp->type() << '\n';
                        }
                    }
                }
            }


            Json::Value jbuff;
            jbuff["classes"] = resultJ;
            res.body = jWriter.write(jbuff);
        }
        else {
            std::cout << "Bad input for " << path << "\n";
        }
    }
    return res;
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
        sbuff << fstream.rdbuf();
        fstream.close();
        jReader.parse(sbuff.str(), templateRoot);

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
//MARK: DATA_TemplateInterface
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
    sbuff << fstream.rdbuf();
    fstream.close();
    jReader.parse(sbuff.str(), templateRoot);
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
//MARK: Form
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
//MARK: Interface
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
            std::cout << userBuff;
            return interface->getDTDData(userBuff);
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


//MARK: TempInterface
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