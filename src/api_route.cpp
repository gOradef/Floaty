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

/**
 *
 * @return
 * @code
 * {
 *  "class_id": "class_name",
 *  ...
 * }
 * @endcode
 */
crow::json::wvalue Request::getAvailibleClasses() {
    crow::json::wvalue classesMap;
    pqxx::read_transaction work(*_connection);

    auto result = work.exec_prepared("user_classes_get", _org_id, _user_id);
    for (auto row : result) {
        auto id = row["id"].as<std::string>();
        auto name = row["class_name"].as<std::string>();

        classesMap[id] = name;
    }
    return classesMap;
}

/**
 * @throws std::invalid_argument in case wrong constuct
 */
classHandler::classHandler(ConnectionPool *connectionPool,
                           const crow::request &req,
                           const std::string& classID) : Request(connectionPool, req) {

    pqxx::read_transaction rtx(*_connection);
    bool isClassOwned = rtx.exec_prepared1("is_class_owned", _org_id, _user_id, classID).front().as<bool>();
    if (!isClassOwned) {
        throw api::exceptions::wrongRequest("Such class doesnt exists");
    }
    this->_class_id = classID;

}

/**
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

crow::json::wvalue classHandler::getInsertedDataForToday() {
    pqxx::read_transaction readTransaction(*_connection);
    auto res = readTransaction.exec_prepared("class_data_get", _org_id, _class_id, nullptr);
    crow::json::wvalue json;
    json = crow::json::load(res.front().front().as<std::string>());
    return json;
}
crow::json::wvalue classHandler::getInsertedDataForDate(const std::string& date) {

    this->isInputIsDateType(date);

    pqxx::read_transaction readTransaction(*_connection);
    auto res = readTransaction.exec_prepared("class_data_get", _org_id, _class_id, date);
    crow::json::wvalue json;
    json = crow::json::load(res.front().front().as<std::string>());
    return json;
}
/**
 * @brief Sets input students into class list, depending onto params.
 * @param changes - json.
 * @code
 *  [f]students: {
 *      "add": [],
 *      "remove": []
 *  }
 *  @endcode
 * @throws std::runtime_error exception
 */
    void classHandler::updateClassStudents(const std::string &changes) {

        crow::json::rvalue root = crow::json::load(changes);

        if (!root)
            throw api::exceptions::wrongRequest("Cant parse changes of user. Is it valid?");

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
 *   "absent_lists": {
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
        throw api::exceptions::wrongRequest("Empty request");

    crow::json::rvalue jsonRoot = crow::json::load(changes);
    if (!jsonRoot)
        throw api::exceptions::parseErr("Can not read body request. Is is json format?");

    if (!jsonRoot.has("absent_lists") || jsonRoot["absent_lists"].t() != crow::json::type::Object)
        throw api::exceptions::wrongRequest("Can not read body request. Is is has absent_list as object?");

    for (auto type : jsonRoot["absent_lists"]) {
        if (type.t() != crow::json::type::List)
            throw api::exceptions::wrongRequest("Can not parse lists. Is key:" + std::string(type.s()) + " list?");
    }

    pqxx::work work(*_connection);
    auto res = work.exec_prepared("class_data_insert", _org_id, _class_id, changes);

    work.commit();
}

schoolManager::schoolManager(ConnectionPool *cp, const crow::request &req) : Request(cp, req) {
    pqxx::read_transaction readTransaction(*_connection);
    auto res = readTransaction.exec_prepared("is_user_has_role", _org_id, _user_id, "admin").front().front().as<bool>();

    if (!res)
        throw std::invalid_argument("User doesnt have needed role. Request access from admin");

}


void schoolManager::isLoginOccupied(const std::string &login) {
    pqxx::read_transaction readTransaction(*_connection);

    bool isLoginOccupied = readTransaction.exec_prepared("is_login_occupied", login).front().front().as<bool>();
    if (isLoginOccupied)
        throw api::exceptions::conflict("Login is already occupied. Please, try another");
}
void schoolManager::isClassExists(const std::string &classID) {
    pqxx::read_transaction readTransaction(*_connection);
    bool isClassExists = readTransaction.exec_prepared1("is_class_exists", _org_id, classID).front().as<bool>();

    if (!isClassExists)
        throw api::exceptions::wrongRequest("No such class: " + classID);
}

void schoolManager::isUserExists(const std::string &userID) {
    pqxx::read_transaction readTransaction(*_connection);
    bool isUserExists = readTransaction.exec_prepared("is_user_exists", _org_id, userID).front().front().as<bool>();

    if (!isUserExists)
        throw api::exceptions::wrongRequest("No such user: " + userID);
}

//Region Data

crow::json::wvalue schoolManager::getDataForDate(const std::string &date) {

//    Chech if date is date type
    isInputIsDateType(date);

    pqxx::read_transaction readTransaction(*_connection);
    // Check if school data doesnt exists for the given date
    if (!readTransaction.exec_prepared1("is_school_data_exists", _org_id, date).front().as<bool>())
        return crow::json::load(nullptr);

    auto res = readTransaction.exec_prepared("school_data_get", _org_id, date);

    // Prepare JSON result
    crow::json::wvalue root;
    for (auto row : res) {
        std::string class_id = row["class_id"].as<std::string>();
        std::string class_body = row["class_body"].as<std::string>();
        root[class_id] = crow::json::load(class_body);
    }

    return root;
}

/**
     *
     * @param date format YYYY-MM-DD or "" for
     * @return
     * @code
     * {
     *  "class_id": {
     *     "name": "1_А"
     *     "others_props": "some"
     *  }
     * }
     * @endcode
 */
crow::json::wvalue schoolManager::getDataForToday() {
    pqxx::read_transaction readTransaction(*_connection);

    auto res = readTransaction.exec_prepared("school_data_get", _org_id, nullptr);

    // Prepare JSON result
    crow::json::wvalue root;
    for (const auto& row : res) {
        std::string class_id = row["class_id"].as<std::string>();
        std::string class_body = row["class_body"].as<std::string>();
        root[class_id] = crow::json::load(class_body);
    }

    return root;
}


crow::json::wvalue schoolManager::getSummaryFromDateToDate(const std::string &startDate, const std::string& endDate) {
    crow::json::wvalue json;

    pqxx::read_transaction readTransaction(*_connection);
    auto res = readTransaction.exec_prepared("school_data_summarized_get", _org_id, startDate, endDate);

    for (auto row : res) {
        std::string class_id = row["class_id"].as<std::string>();
        std::string class_body = row["class_body"].as<std::string>();
        json[class_id] = crow::json::load(class_body);
    }
    return json;
}

//Region classes
crow::json::wvalue schoolManager::getClasses() {
    pqxx::read_transaction readTransaction(*_connection);

    auto res = readTransaction.exec_prepared("school_classes_get", _org_id);
    crow::json::wvalue json;
    for (auto row : res) {
        std::string class_id = row["class_id"].as<std::string>();
        std::string class_body = row["class_body"].as<std::string>();
        json[class_id] = crow::json::load(class_body);
    }
    return json;
}
crow::json::wvalue schoolManager::getClassStudents(const std::string &classID) {

    isClassExists(classID);

    pqxx::read_transaction readTransaction(*_connection);

    auto res = readTransaction.exec_prepared("school_class_students_get", _org_id, classID);

    crow::json::wvalue json;
    for (auto row : res) {
        std::string class_id = row["class_id"].as<std::string>();
        std::string class_body = row["class_lists"].as<std::string>();
        json[class_id] = crow::json::load(class_body);
    }
    return json;
};
void schoolManager::classCreate(const crow::json::rvalue &json) {
    pqxx::work work(*_connection);
    std::string class_name = json["class_name"].s();

    //If exists flag isWithOwner -> read value from json
    std::unique_ptr<std::string> owner_id;
    this->urlParams.isWithOwner ? owner_id = std::make_unique<std::string>(json["class_owner"].s()) :
            owner_id = nullptr;

    work.exec_prepared("class_create", _org_id, owner_id, class_name);
    work.commit();
}

void schoolManager::classDrop(const std::string& classID) {

    isClassExists(classID);

    pqxx::work work(*_connection);
    work.exec_prepared("class_drop", _org_id, classID);
    work.commit();
}

void schoolManager::classRename(const crow::json::rvalue &json) {
    const std::string& classID = json["class_id"].s();
    const std::string& className = json["class_name"].s();

    isClassExists(classID);

    pqxx::work work(*_connection);

    work.exec_prepared("class_rename", _org_id, classID, className);
    work.commit();
}
//Region Users
crow::json::wvalue schoolManager::getUsers() {
    pqxx::read_transaction readTransaction(*_connection);
    auto res = readTransaction.exec_prepared("school_users_get", _org_id);
    crow::json::wvalue json;
    for (auto row : res) {
        auto userID = row[0].as<std::string>();
        auto userContext = row[1].as<std::string>();
        json[userID] = crow::json::load(userContext);
    }
    return json;
}


void schoolManager::userCreate(const crow::json::rvalue &creds) {

    // Extract credentials
    const std::string login = creds["login"].s();
    const std::string pwd = creds["password"].s();
    const std::string name = creds["name"].s();

    isLoginOccupied(login);

    pqxx::work work(*_connection);

    // Prepare the SQL query based on URL parameters
    std::unique_ptr<std::vector<std::string>> roles;
    std::unique_ptr<std::vector<std::string>> classes;

    this->urlParams.isWithRoles ? roles =
            std::make_unique<std::vector<std::string>>(creds["roles"].begin(), creds["roles"].end())
            : roles = nullptr;
    this->urlParams.isWithClasses ? classes =
            std::make_unique<std::vector<std::string>> (creds["classes"].begin(), creds["classes"].end())
            : classes = nullptr;

    // Execute the prepared query
    work.exec_prepared("user_create_with_context", _org_id, login, pwd, name, roles, classes);
    work.commit();
}

void schoolManager::userDrop(const std::string &userID) {

    isUserExists(userID);

    pqxx::work work(*_connection);

    work.exec_prepared("user_drop", _org_id, userID);
    work.commit();
}