#include "Floaty/api.h"

Request::Request(ConnectionPool *connectionPool, const crow::request &req) {
    this->_connectionPool = connectionPool;
    this->_connection = _connectionPool->getConnection();

    auto app = crow::App<crow::CookieParser> {};
    auto& ctx = app.get_context<crow::CookieParser>(req);
    std::string user_token = ctx.get_cookie("Floaty_access_token");
    // std::string user_token = req.get_header_value("token");
    jwt::decoded_jwt decodedJwt = jwt::decode(user_token);

    pqxx::read_transaction rtx(*_connection);

    this->_org_id = rtx.exec_prepared1(psqlMethods::encoding::decode,decodedJwt.get_payload_claim("aud").as_string()).front().as<std::string>();
    this->_user_id = rtx.exec_prepared1(psqlMethods::encoding::decode, decodedJwt.get_subject()).front().as<std::string>();
}
Request::~Request() {
    _connectionPool->releaseConnection(_connection);
}

std::vector<std::string> Request::getRoles() {
    std::vector<std::string> roles;
    pqxx::read_transaction readTransaction(*_connection);
    auto res = readTransaction.exec_prepared(psqlMethods::userData::getRoles, _org_id, _user_id);
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
    pqxx::read_transaction work(*_connection);

    auto result = work.exec_prepared(psqlMethods::userData::getClasses, _org_id, _user_id);
    crow::json::wvalue classes;
    if (!result.front().front().is_null()) {
        classes = crow::json::load(result.front().front().as<std::string>());
        return classes;
    }
    return nullptr;
}

/**
 * @throws std::invalid_argument in case wrong constuct
 */
classHandler::classHandler(ConnectionPool *connectionPool,
                           const crow::request &req,
                           const std::string& classID) : Request(connectionPool, req) {

    pqxx::read_transaction rtx(*_connection);
    bool isClassOwned = rtx.exec_prepared1(psqlMethods::classes::checks::isOwned, _org_id, _user_id, classID).front().as<bool>();
    if (!isClassOwned) {
        throw api::exceptions::wrongRequest("Such class doesnt exists");
    }
    this->_class_id = classID;

}

crow::json::wvalue classHandler::getClassProps() {
    pqxx::read_transaction rtx(*_connection);

    auto classProps = rtx.exec_prepared(psqlMethods::userData::getClassProps,
    _org_id,
    _class_id);

    crow::json::wvalue json = crow::json::load(classProps.front().front().as<std::string>());

    return json;

}

/**
 * @return json: {"students": [], "fstudents": []}
 */
crow::json::wvalue classHandler::getClassStudents() {
    pqxx::read_transaction rtx(*_connection);

    auto studs = rtx.exec_prepared(psqlMethods::userData::getClassStudents,
        _org_id,
        _user_id,
        _class_id);

    crow::json::wvalue json = crow::json::load(studs.front().front().as<std::string>());

    return json;
}

crow::json::wvalue classHandler::getInsertedDataForToday() {
    pqxx::read_transaction readTransaction(*_connection);
    auto res = readTransaction.exec_prepared(psqlMethods::classes::data::getInsertedData, _org_id, _class_id, nullptr);
    crow::json::wvalue json = crow::json::load(res.front().front().as<std::string>());
    std::cout << json.dump();
    return json;
}
crow::json::wvalue classHandler::getInsertedDataForDate(const std::string& date) {

    this->isInputIsDateType(date);

    pqxx::read_transaction readTransaction(*_connection);
    auto res = readTransaction.exec_prepared(psqlMethods::classes::data::getInsertedData, _org_id, _class_id, date);
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

        for (const auto& stud_type : _stud_types) {
            for (const auto& action : _actions) {
                if (root.has(stud_type) && root[stud_type].has(action)) {
                    std::vector<std::string> vec;
                    for (const auto& fio : root[stud_type][action]) {
                        vec.emplace_back(fio);
                    }
                    work.exec_prepared("class_" + stud_type + "_" += action, this->_org_id,
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
 *   "absent": {
 *     "global": [],
 *     "ORVI": [],
 *     "fstudents": [],
 *     "respectful": [],
 *     "not_respectful": []
 *   }
 * }
 *@endcode
 */

void classHandler::insertData(const std::string &changes) {
    if (changes.empty())
        throw api::exceptions::wrongRequest("Empty request");

    crow::json::rvalue jsonRoot = crow::json::load(changes);
    if (!jsonRoot)
        throw api::exceptions::parseErr("Can not read body request. Is is json format?");

    if (!jsonRoot.has("absent") || jsonRoot["absent"].t() != crow::json::type::Object)
        throw api::exceptions::wrongRequest("Can not read body request. Is is has absent as object?");

    for (auto type : jsonRoot["absent"]) {
        if (type.t() != crow::json::type::List)
            throw api::exceptions::wrongRequest("Can not parse lists. Is key:" + std::string(type.s()) + " list?");
    }

    pqxx::work work(*_connection);
    auto res = work.exec_prepared(psqlMethods::classes::data::insertData, _org_id, _class_id, changes);

    work.commit();
}

schoolManager::schoolManager(ConnectionPool *cp, const crow::request &req) : Request(cp, req) {
    pqxx::read_transaction readTransaction(*_connection);
    auto res = readTransaction.exec_prepared(psqlMethods::userChecks::hasRole, _org_id, _user_id, "admin").front().front().as<bool>();

    if (!res)
        throw std::invalid_argument("User doesnt have needed role. Request access from admin");

}


void schoolManager::isLoginOccupied(const std::string &login) {
    pqxx::read_transaction readTransaction(*_connection);

    bool isLoginOccupied = readTransaction.exec_prepared(psqlMethods::userChecks::isLoginOccupied, login).front().front().as<bool>();
    if (isLoginOccupied)
        throw api::exceptions::conflict("Login is already occupied. Please, try another");
}
void schoolManager::isClassExists(const std::string &classID) {
    pqxx::read_transaction readTransaction(*_connection);
    bool isClassExists = readTransaction.exec_prepared1(psqlMethods::classes::checks::isExists, _org_id, classID).front().as<bool>();

    if (!isClassExists)
        throw api::exceptions::wrongRequest("No such class: " + classID);
}

void schoolManager::isUserExists(const std::string &userID) {
    pqxx::read_transaction readTransaction(*_connection);
    bool isUserExists = readTransaction.exec_prepared(psqlMethods::userChecks::isExists, _org_id, userID).front().front().as<bool>();

    if (!isUserExists)
        throw api::exceptions::wrongRequest("No such user: " + userID);
}

void schoolManager::isInviteExists(const std::string& inviteID) {
    pqxx::read_transaction readTransaction(*_connection);
    bool isInviteExists = readTransaction.exec_prepared(psqlMethods::invites::isExists, _org_id, inviteID).front().front().as<bool>();

    if (!isInviteExists)
        throw api::exceptions::wrongRequest("No such invite: " + inviteID);
}

void schoolManager::isDataExists(const std::string& date) {
    pqxx::read_transaction readTransaction(*_connection);
    bool isDataExists = readTransaction.exec_prepared(psqlMethods::schoolManager::data::isExists, _org_id, date).front().front().as<bool>();

    if (!isDataExists)
        throw api::exceptions::wrongRequest("No such data for date: " + date);
}


//Region Data

void schoolManager::genDataForToday() {
    // if (!isDataTodayExists()) {
    pqxx::work work(*_connection);
    work.exec_prepared(psqlMethods::schoolManager::data::genNewForToday, _org_id);
    work.commit();
    // }
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

    auto res = readTransaction.exec_prepared(psqlMethods::schoolManager::data::get, _org_id, nullptr);

    // Prepare JSON result
    crow::json::wvalue root;
    if (res.front().front().is_null()) {
        //! std::cout << "IS NULL \n";
        root = nullptr;
        return root;
    }
    root = crow::json::load(res.front().front().as<std::string>());

    return root;
}

crow::json::wvalue schoolManager::getDataForDate(const std::string &date) {

//    Chech if date is date type
    isInputIsDateType(date);

    pqxx::read_transaction readTransaction(*_connection);
    // Check if school data doesnt exists for the given date
    if (!readTransaction.exec_prepared1(psqlMethods::schoolManager::data::isExists, _org_id, date).front().as<bool>())
        return nullptr;

    auto res = readTransaction.exec_prepared(psqlMethods::schoolManager::data::get, _org_id, date);

    // Prepare JSON result
    crow::json::wvalue root = crow::json::load(res.front().front().as<std::string>());

    if (res.front().front().is_null()) {
        //! std::cout << "IS NULL \n";
        root = nullptr;
        return root;
    }
    root = crow::json::load(res.front().front().as<std::string>());

    return root;
}



crow::json::wvalue schoolManager::getSummaryFromDateToDate(const std::string &startDate, const std::string& endDate) {

    pqxx::read_transaction readTransaction(*_connection);
    auto res = readTransaction.exec_prepared(psqlMethods::schoolManager::data::getSummarized, _org_id, startDate, endDate);

    crow::json::wvalue json;
    for (auto row : res) {
        auto class_id = row["class_id"].as<std::string>();
        auto class_body = row["class_body"].as<std::string>();
        json[class_id] = crow::json::load(class_body);
    }
    return json;
}

//Region classes
/**
     *
     * @return
     * @code
     *  {
     *    "class_id": {
     *      "name": "[num]_[letter]",
     *      "amount": 0
     *      "list_students": [],
     *      "list_fstudents": [],
     *      "owner_id": "owner_uuid",
     *      "owner_name": "FI"
     *
     *    }
     *  }
     *  @endcode
     */
crow::json::wvalue schoolManager::getClasses() {
    pqxx::read_transaction readTransaction(*_connection);

    auto res = readTransaction.exec_prepared(psqlMethods::schoolManager::classes::getAll, _org_id);
    crow::json::wvalue json;
    if (!res[0][0].is_null())
        json = crow::json::load(res.front().front().as<std::string>());
    else
        json = crow::json::load("[]");
    return json;
}
crow::json::wvalue schoolManager::getClassStudents(const std::string &classID) {

    isClassExists(classID);

    pqxx::read_transaction readTransaction(*_connection);

    auto res = readTransaction.exec_prepared(psqlMethods::schoolManager::classes::getStudents, _org_id, classID);

    crow::json::wvalue json;
    for (auto row : res) {
        auto class_body = row.front().as<std::string>();
        json = crow::json::load(class_body);
    }
    return json;
};

/**
     * @param json
     * @code
     *
     * {
     *  "name": "1_А",
     *  "amount": 0, //optional
     *  "owner": "uuid" //optional
     * }
     * @endcode
     */
void schoolManager::classCreate(const crow::json::rvalue &json) {
    const std::string& class_name = json["name"].s();

    //If exists flag isWithOwner -> read value from json
    std::unique_ptr<std::string> owner_id;
    if (json.has("owner") &&
        json["owner"].t() == crow::json::type::String &&
        json["owner"].s() != "")
    {
        owner_id = std::make_unique<std::string>(json["owner"].s());
        isUserExists(*owner_id);
    }
    else
        owner_id = nullptr;

    pqxx::work work(*_connection);

    work.exec_prepared(psqlMethods::schoolManager::classes::create, _org_id, owner_id, class_name);
    work.commit();
}

void schoolManager::classDrop(const std::string& classID) {

    isClassExists(classID);

    pqxx::work work(*_connection);
    work.exec_prepared(psqlMethods::schoolManager::classes::drop, _org_id, classID);
    work.commit();
}


/**
     *
     * @param classID - uuid of class
     * @param className - new name of class
     */
void schoolManager::classRename(const std::string& classID, const std::string& className) {
    isClassExists(classID);

    pqxx::work work(*_connection);

    work.exec_prepared(psqlMethods::schoolManager::classes::rename, _org_id, classID, className);
    work.commit();
}

/**
 *
 * @param classID uuid of class
 * @param studentsBranch @code
 * {
 *  list_students: [],
 *  list_fstudents: []
 * }
 * @endcode
 */
void schoolManager::updateClassStudents(const std::string& classID, const std::string& studentsBranch) {
    isClassExists(classID);

    pqxx::work work(*_connection);

    work.exec_prepared(psqlMethods::schoolManager::classes::updateStudentList, _org_id, classID, studentsBranch);
    work.commit();
}

//Region Users
/**
    *
    * @returns json
    * @code
    *  [
    *    {
    *      "name": "FI",
    *      "roles": ["roles"], // or null
    *      "classes": ["classes_id"], // or null
    *      "id": [user_id]
    *    },
    *    {},
    *  ]
    * @encdode
    */
crow::json::wvalue schoolManager::getUsers() {
    pqxx::read_transaction readTransaction(*_connection);
    auto res = readTransaction.exec_prepared(psqlMethods::schoolManager::users::getAll, _org_id);
    crow::json::wvalue json;
    if (!res[0][0].is_null())
        json = crow::json::load(res.front().front().as<std::string>());
    else
        json = crow::json::load("[]");
    return json;
}


/**
     * @param creds
     * @code
     * {
     *  login: smth,
     *  password: smth,
     *  name: {{last_name + first_name}},
     *  roles: [], (optional)
     *  classes: [] (optional)
     * }
     * @endcode
     */
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


    if (creds["roles"].size() != 0)
        roles = std::make_unique<std::vector<std::string>>(creds["roles"].begin(), creds["roles"].end());
    else
        roles = nullptr;

    if (creds["classes"].size() != 0)
        classes = std::make_unique<std::vector<std::string>> (creds["classes"].begin(), creds["classes"].end());
    else
        classes = nullptr;

    // Execute the prepared query
    work.exec_prepared(psqlMethods::schoolManager::users::createWithContext, _org_id, login, pwd, name, roles, classes);
    work.commit();
}

void schoolManager::userEdit(const std::string& userID, const crow::json::rvalue& userBody) {
    isUserExists(userID);

    pqxx::work work(*_connection);
    if (userBody.has("roles") &&
        userBody["roles"].t() == crow::json::type::List) {
        std::vector<std::string> roles;
        for (auto& role : userBody["roles"]) {
            roles.emplace_back(role.s());
        }
        work.exec_prepared(psqlMethods::schoolManager::users::setRoles, _org_id, userID, roles);
    }
    if (userBody.has("classes") &&
        userBody["classes"].t() == crow::json::type::List) {
        std::vector<std::string> classes;
        for (auto& classt : userBody["classes"]) {
            classes.emplace_back(classt.s());
        }
        work.exec_prepared(psqlMethods::schoolManager::users::setClasses, _org_id, userID, classes);
    }
    work.commit();
}

void schoolManager::userDrop(const std::string &userID) {

    isUserExists(userID);

    pqxx::work work(*_connection);

    work.exec_prepared(psqlMethods::schoolManager::users::drop, _org_id, userID);
    work.commit();
}
///@param userID - uuid of user
///@param newPassword - already hashed
void schoolManager::userResetPassword(const std::string& userID, const std::string& newPassword) {
    isUserExists(userID);

    pqxx::work work(*_connection);
    work.exec_prepared(psqlMethods::schoolManager::users::resetPassword, _org_id,
        userID,
        newPassword);

    work.commit();
}



// Region invites
/**
     *
     * @param invite_body should contain:
     * @code
     *  {
     *  "roles": [],
     *  "classes": [],
     *  "name": []
     *  }
     * @endcode
     */
void schoolManager::inviteCreate(const std::string& invite_body) {
    // Check if login is alredy is use
    pqxx::work work(*_connection);

    work.exec_prepared(psqlMethods::invites::create, _org_id, invite_body);
    work.commit();
}

crow::json::wvalue schoolManager::getAllInvites() {
    pqxx::read_transaction rtx(*_connection);
    auto res = rtx.exec_prepared(psqlMethods::invites::getAll, _org_id);
    crow::json::wvalue json;
    if (!res[0][0].is_null())
        json = crow::json::load(res.front().front().as<std::string>());
    else
        json = crow::json::load("[]");
    return json;
}
void schoolManager::inviteDrop(const std::string& reqID) {
    isInviteExists(reqID);

    pqxx::work work(*_connection);
    work.exec_prepared(psqlMethods::invites::drop, _org_id, reqID);
    work.commit();
}
//todo add route to drop invte and drop user password
/*
 * 1. Name psql method
 * 2. Add it to connectionPool
 * 3. create api function
 * 4. create function in interface
 * 5. route it
 *
 */

/**
 * @param classID - id of class
 * @param changes - json with absent
 */
void schoolManager::dataAbsentUpdate(const std::string& classID,const std::string& changes) {
    isClassExists(classID);

    pqxx::work work(*_connection);

    work.exec_prepared(psqlMethods::classes::data::insertData, _org_id, classID, changes);
    work.commit();
}
/**
 * @param classID - id of class
 * @param changes - json with absent
 * @param date - YYYY-MM-DD
*/
void schoolManager::dataAbsentUpdateForDate(const std::string& classID, const std::string& changes, const std::string& date) {
    isClassExists(classID);
    isDataExists(date);

    pqxx::work work(*_connection);
    work.exec_prepared(psqlMethods::classes::data::insertDataForDate, _org_id, classID, changes, date);
    work.commit();
}
