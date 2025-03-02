#include "Floaty/api.h"

Request::Request(ConnectionPool *connectionPool, const crow::request &req) {
    this->_connectionPool = connectionPool;
    this->_connection = _connectionPool->getConnection();

    auto app = crow::App<crow::CookieParser> {};
    auto& ctx = app.get_context<crow::CookieParser>(req);
    std::string user_token = ctx.get_cookie("Floaty_access_token");
    // std::string user_token = req.get_header_value("token");
    jwt::decoded_jwt decodedJwt = jwt::decode(user_token);

    this->work = new pqxx::read_transaction(*this->_connection);
    this->_org_id = work->exec(psqlMethods::encoding::decode,decodedJwt.get_payload_claim("aud").as_string()).one_field().as<std::string>();
    this->_user_id = work->exec(psqlMethods::encoding::decode, decodedJwt.get_subject()).one_field().as<std::string>();
}
Request::~Request() {
    delete this->work;
    _connectionPool->releaseConnection(_connection);
}
void Request::isInputIsDateType(const std::string& date) {
    bool isDate = work->exec(psqlMethods::isDate, date).one_field().as<bool>();

    if (!isDate)
        throw api::exceptions::wrongRequest("Input date is not valid format");
};

std::vector<std::string> Request::getRoles() {
    std::vector<std::string> roles;
    auto res = work->exec(psqlMethods::userData::getRoles, {_org_id, _user_id});
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

    auto result = work->exec(psqlMethods::userData::getClasses,{ _org_id, _user_id});

    if (!result.one_field().is_null()) {
        crow::json::wvalue classes = crow::json::load(result.one_field().as<std::string>());
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

    bool isClassOwned = work->exec(psqlMethods::classes::checks::isOwned,{ _org_id, _user_id, classID}).one_field().as<bool>();
    if (!isClassOwned) {
        throw api::exceptions::wrongRequest("Such class doesnt exists");
    }
    this->_class_id = classID;

}

crow::json::wvalue classHandler::getClassProps() {

    auto classProps = work->exec(psqlMethods::userData::getClassProps, {
    _org_id,
    _class_id});

    crow::json::wvalue json = crow::json::load(classProps.one_field().as<std::string>());

    return json;

}

/**
 * @return json: {"students": [], "fstudents": []}
 */
crow::json::wvalue classHandler::getClassStudents() {

    auto studs = work->exec(psqlMethods::userData::getClassStudents, {
        _org_id,
        _user_id,
        _class_id});

    crow::json::wvalue json = crow::json::load(studs.one_field().as<std::string>());

    return json;
}

crow::json::wvalue classHandler::getInsertedDataForToday() {
    auto res = work->exec(psqlMethods::classes::data::getInsertedData, {_org_id, _class_id, nullptr});
    crow::json::wvalue json = crow::json::load(res.one_field().as<std::string>());
    //! std::cout << json.dump();
    return json;
}
crow::json::wvalue classHandler::getInsertedDataForDate(const std::string& date) {

    this->isInputIsDateType(date);

    auto res = work->exec(psqlMethods::classes::data::getInsertedData, {_org_id, _class_id, date});
    crow::json::wvalue json = crow::json::load(res.one_field().as<std::string>());
    return json;
}
/**
 * @brief Sets input students into class list, depending onto params.
 * @param studentsBranch - json.
 * @code
 *  [f]students: {
 *      "add": [],
 *      "remove": []
 *  }
 *  @endcode
 * @throws std::runtime_error exception
 */
    void classHandler::updateClassStudents(const std::string &studentsBranch) {

        this->priviliageWorkerToWrite();

        work->exec(psqlMethods::schoolManager::classes::updateStudentList,{ _org_id, this->_class_id, studentsBranch});
        work->commit();
}

/**
 *
 * @param changes - json
 * @example
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

    const crow::json::rvalue& jsonRoot = crow::json::load(changes);

    if (!jsonRoot.has("absent"))
        throw api::exceptions::MissingRequiredField("absent");

    if (jsonRoot["absent"].t() != crow::json::type::Object)
        throw api::exceptions::InvalidJsonSchema("absent", "Object");

    for (const auto& field : jsonRoot["absent"]) {
        if (field.t() != crow::json::type::List)
            throw api::exceptions::InvalidJsonSchema(field.s(), "list");
    }

    this->priviliageWorkerToWrite();
    auto res = work->exec(psqlMethods::classes::data::insertData,{ _org_id, _class_id, changes});

    work->commit();
}

schoolManager::schoolManager(ConnectionPool *cp, const crow::request &req) : Request(cp, req) {
    auto res = work->exec(psqlMethods::userChecks::hasRole,{ _org_id, _user_id, "admin"}).one_field().as<bool>();

    if (!res)
        throw std::invalid_argument("User doesnt have needed role. Request access from admin");

}


void schoolManager::isLoginOccupied(const std::string &login) {

    bool isLoginOccupied = work->exec(psqlMethods::userChecks::isLoginOccupied, login).one_field().as<bool>();
    if (isLoginOccupied)
        throw api::exceptions::conflict("Login is already occupied. Please, try another");
}
void schoolManager::isClassExists(const std::string &classID) {
    bool isClassExists = work->exec(psqlMethods::classes::checks::isExists,{ _org_id, classID}).one_field().as<bool>();

    if (!isClassExists)
        throw api::exceptions::wrongRequest("No such class: " + classID);
}

void schoolManager::isUserExists(const std::string &userID) {
    bool isUserExists = work->exec(psqlMethods::userChecks::isExists, {_org_id, userID}).one_field().as<bool>();

    if (!isUserExists)
        throw api::exceptions::wrongRequest("No such user: " + userID);
}

void schoolManager::isUserHasntClassesInOwning(const std::string& userID) {
    bool isUserHasClassesInOwning = work->exec(psqlMethods::userChecks::isHasClasses,{ _org_id, userID}).one_field().as<bool>();

    if (isUserHasClassesInOwning)
        throw api::exceptions::conflict("User has classes in owning. Aborting.");
}

void schoolManager::isInviteExists(const std::string& inviteID) {
    bool isInviteExists = work->exec(psqlMethods::invites::isExists,{ _org_id, inviteID}).one_field().as<bool>();

    if (!isInviteExists)
        throw api::exceptions::wrongRequest("No such invite: " + inviteID);
}

void schoolManager::isDataExists(const std::string& date) {
    bool isDataExists = work->exec(psqlMethods::schoolManager::data::isExists, {_org_id, date}).one_field().as<bool>();

    if (!isDataExists)
        throw api::exceptions::wrongRequest("No such data for date: " + date);
}


//Region Data

void schoolManager::genDataForToday() {
    this->priviliageWorkerToWrite();
    work->exec(psqlMethods::schoolManager::data::genNewForToday, _org_id);
    work->commit();
}


/**
     *
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

    auto res = work->exec(psqlMethods::schoolManager::data::getForToday, _org_id);

    // Prepare JSON result
    crow::json::wvalue root;
    if (res.one_field().is_null()) {
        //! std::cout << "IS NULL \n";
        root = nullptr;
        return root;
    }
    root = crow::json::load(res.one_field().as<std::string>());

    return root;
}

crow::json::wvalue schoolManager::getDataForDate(const std::string &date) {

//    Chech if date is date type
    isInputIsDateType(date);

    // Check if school data doesnt exists for the given date
    if (!work->exec(psqlMethods::schoolManager::data::isExists, {_org_id, date}).one_field().as<bool>())
        return nullptr;

    auto res = work->exec(psqlMethods::schoolManager::data::getForDate,{ _org_id, date});

    // Prepare JSON result
    crow::json::wvalue root = crow::json::load(res.one_field().as<std::string>());

    if (res.one_field().is_null()) {
        //! std::cout << "IS NULL \n";
        root = nullptr;
        return root;
    }
    root = crow::json::load(res.one_field().as<std::string>());

    return root;
}



crow::json::wvalue schoolManager::getSummaryFromDateToDate(const std::string &startDate, const std::string& endDate) {
    auto res = work->exec(psqlMethods::schoolManager::data::getSummarized, {_org_id, startDate, endDate});

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

    auto res = work->exec(psqlMethods::schoolManager::classes::getAll, _org_id);
    crow::json::wvalue json;
    if (!res[0][0].is_null())
        json = crow::json::load(res.one_field().as<std::string>());
    else
        json = crow::json::load("[]");
    return json;
}
crow::json::wvalue schoolManager::getClassStudents(const std::string &classID) {

    isClassExists(classID);

    auto res = work->exec(psqlMethods::schoolManager::classes::getStudents, {_org_id, classID});
    pqxx::params p;
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
     *  "owner": "uuid" //optional
     * }
     * @endcode
     */
void schoolManager::classCreate(const crow::json::rvalue &json) {
    const std::string& class_name = json["name"].s();

    //If exists flag isWithOwner -> read value from json
    // std::unique_ptr<std::string> owner_id;
    // if (json["owner"].s() != "")
    // {
    //     owner_id = std::make_unique<std::string>(json["owner"].s());
    //     isUserExists(*owner_id);
    // }
    // else
    //     owner_id = nullptr;

    const std::optional<std::string> owner_id = json["owner"].s();

    this->priviliageWorkerToWrite();

    work->exec(psqlMethods::schoolManager::classes::create, {_org_id, owner_id, class_name});
    work->commit();
}

void schoolManager::classDrop(const std::string& classID) {

    isClassExists(classID);

    this->priviliageWorkerToWrite();
    work->exec(psqlMethods::schoolManager::classes::drop, {_org_id, classID});
    work->commit();
}


/**
     *
     * @param classID - uuid of class
     * @param className - new name of class
     */
void schoolManager::classRename(const std::string& classID, const std::string& className) {
    isClassExists(classID);

    this->priviliageWorkerToWrite();

    work->exec(psqlMethods::schoolManager::classes::rename, {_org_id, classID, className});
    work->commit();
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

    this->priviliageWorkerToWrite();

    work->exec(psqlMethods::schoolManager::classes::updateStudentList, {_org_id, classID, studentsBranch});
    work->commit();
}

void schoolManager::classSetOwners(const std::string& classID, const std::vector<std::string>& newOwners) {
    isClassExists(classID);

    for (const auto& new_owner : newOwners ) {
        isUserExists(new_owner);
    }

    this->priviliageWorkerToWrite();

    work->exec(psqlMethods::schoolManager::classes::setOwners, {_org_id, classID, newOwners});
    work->commit();
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
    auto res = work->exec(psqlMethods::schoolManager::users::getAll, _org_id);
    crow::json::wvalue json;
    if (!res[0][0].is_null())
        json = crow::json::load(res.one_field().as<std::string>());
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

    this->priviliageWorkerToWrite();

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
    work->exec(psqlMethods::schoolManager::users::createWithContext, {_org_id, login, pwd, name, roles, classes});
    work->commit();
}

void schoolManager::userEdit(const std::string& userID, const crow::json::rvalue& userBody) {
    isUserExists(userID);

    auto setRoles = [&]() {
        std::vector<std::string> roles;
        for (auto& role : userBody["roles"]) {
            roles.emplace_back(role.s());
        }
        work->exec(psqlMethods::schoolManager::users::setRoles, {_org_id, userID, roles});
    };
    auto setClasses = [&]() {
        std::vector<std::string> classes;
        for (auto& classt : userBody["classes"]) {
            classes.emplace_back(classt.s());
        }
        work->exec(psqlMethods::schoolManager::users::setClasses, {_org_id, userID, classes});
    };
    auto setName = [&]() {
        const std::string& newUserName = userBody["name"].s();
        work->exec(psqlMethods::schoolManager::users::setName,{ _org_id, userID, newUserName});
    };


    this->priviliageWorkerToWrite();
    //todo Suspiciously maybe move checks to router.cpp
    if (userBody.has("roles") && userBody["roles"].t() == crow::json::type::List) {
        setRoles();
    }
    if (userBody.has("classes") && userBody["classes"].t() == crow::json::type::List) {
        setClasses();
    }
    if (userBody.has("name") && userBody["name"].t() == crow::json::type::String && userBody["name"].s() != "") {
        setName();
    }
    work->commit();
}

void schoolManager::userDrop(const std::string &userID) {

    isUserExists(userID);
    isUserHasntClassesInOwning(userID);

    this->priviliageWorkerToWrite();

    work->exec(psqlMethods::schoolManager::users::drop, {_org_id, userID});
    work->commit();
}
///@param userID - uuid of user
///@param newPassword - already hashed
void schoolManager::userResetPassword(const std::string& userID, const std::string& newPassword) {
    isUserExists(userID);

    this->priviliageWorkerToWrite();
    work->exec(psqlMethods::schoolManager::users::resetPassword, {
        _org_id,
        userID,
        newPassword});

    work->commit();
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
    this->priviliageWorkerToWrite();

    work->exec(psqlMethods::invites::create, {_org_id, invite_body});
    work->commit();
}

crow::json::wvalue schoolManager::getAllInvites() {
    auto res = work->exec(psqlMethods::invites::getAll, _org_id);
    crow::json::wvalue json;
    if (!res[0][0].is_null())
        json = crow::json::load(res.one_field().as<std::string>());
    else
        json = crow::json::load("[]");
    return json;
}
void schoolManager::inviteDrop(const std::string& reqID) {
    isInviteExists(reqID);

    this->priviliageWorkerToWrite();
    work->exec(psqlMethods::invites::drop, {_org_id, reqID});
    work->commit();
}

/**
 * @param classID - id of class
 * @param changes - json with absent
 */
void schoolManager::dataAbsentUpdate(const std::string& classID,const std::string& changes) {
    isClassExists(classID);

    this->priviliageWorkerToWrite();

    work->exec(psqlMethods::classes::data::insertData,{ _org_id, classID, changes});
    work->commit();
}
/**
 * @param classID - id of class
 * @param changes - json with absent
 * @param date - YYYY-MM-DD
*/
void schoolManager::dataAbsentUpdateForDate(const std::string& classID, const std::string& changes, const std::string& date) {
    isClassExists(classID);
    isDataExists(date);

    this->priviliageWorkerToWrite();
    work->exec(psqlMethods::classes::data::insertDataForDate, {_org_id, classID, changes, date});
    work->commit();
}
