//
// Created by goradef on 19.08.2024.
//

// ReSharper disable CppDeclarationHidesLocal
// ReSharper disable CppDeclarationHidesUncapturedLocal
#include "Floaty/server.h"

Server::Server(const std::string& address, const int& port, ConnectionPool* cp) {
    Server::_connectionPool = cp;

    app.bindaddr(address)
       .port(port);

}

void Server::routes_auth::login(const crow::request& req, crow::response& res) {
    pqxx::connection* c = _connectionPool->getConnection();
    pqxx::read_transaction readTransaction(*c);

    try {
        //Check parsing of req.body
        if (!crow::json::load(req.body)) {
            throw api::exceptions::parseErr("");
        }

        crow::json::rvalue req_json = crow::json::load(req.body);

        //Check existsing and types of creditionals
        if (!req_json.has("login") || !req_json.has("password")
            || req_json["login"].t() != crow::json::type::String
            || req_json["password"].t() != crow::json::type::String)
            {
                throw api::exceptions::wrongRequest("Is login and password exists and it is string?");
            }

        //Hashing creditionals
        const std::string& hashedLogin = hashSHA256(req_json["login"].s());
        const std::string& hashedPassword = hashSHA256(req_json["password"].s());

        // std::cout << hashedLogin << '\n' << hashedPassword << '\n';
        //Check if user's creds are valid

        //! DO NOT EDIT .front()
        auto result = readTransaction.exec(psqlMethods::userChecks::isValid,{ hashedLogin, hashedPassword}).front();

        if (!result[0].as<bool>()) {
            throw api::exceptions::wrongRequest("Invalid login or password");
        }

        // * UUID in postgres
        const std::string& userUUID = result[1].as<std::string>();

        // * UUID in postgres
        const std::string& schoolUUID = readTransaction.exec(psqlMethods::userData::getSchoolId, userUUID).one_field().as<std::string>();

        // Get roles from postgres
        auto roles = crow::json::load(readTransaction.exec(psqlMethods::userData::getRoles,{ schoolUUID, userUUID}).one_field().as<std::string>());
        picojson::array available_roles;
        for (const auto& role : roles) {
            picojson::value role_v(std::string(role.s()));
            available_roles.push_back(role_v);
        }
        if (available_roles.capacity() == 0) {
            throw api::exceptions::requirmentsDoesntMeeted("U r doesnt have any available roles. "
                "Contact with admin for granting privileges");
        }

        // Get available classes from postgres
        auto classes = readTransaction.exec(psqlMethods::userData::getClasses, {schoolUUID, userUUID});
        picojson::array available_classes;
        if (!classes.front().front().is_null()) {
            for (auto class_v : classes) {
                picojson::value classes_virtual(class_v.front().as<std::string>());
                available_classes.push_back(classes_virtual);
            }
        }


        //Get hexadecimal user's creds
        const std::string& userIdHex = readTransaction.exec(psqlMethods::encoding::encode, userUUID).one_field().as<std::string>();
        //                std::cout << "[INFO] SUB IS: " << user_id << '\n'; //!debug
        const std::string& schoolIdHex = readTransaction.exec(psqlMethods::encoding::encode, schoolUUID).one_field().as<std::string>();
        //                std::cout << "[INFO] AUD iS: " << school_id_encoded << '\n'; //!debug


        auto jwt_builder = jwt::create();
        jwt_builder.set_issuer("Floaty");

        //Set id, school_id
        jwt_builder.set_subject(userIdHex);
        jwt_builder.set_audience(schoolIdHex);

        // Set roles
        jwt_builder.set_payload_claim("roles", jwt::claim(available_roles));

        // Set classes
        jwt_builder.set_payload_claim("classes", jwt::claim(available_classes));

        //Set time
        jwt_builder.set_issued_at(std::chrono::system_clock::now());
        jwt_builder.set_expires_at(std::chrono::system_clock::now() + std::chrono::hours(24));

        auto jwtAccess = jwt_builder
                         .set_type("AccessToken")
                         .sign(jwt::algorithm::hs256(_jwtAccessSecret));


        jwt_builder.set_expires_at(std::chrono::system_clock::now() + std::chrono::hours(24*7));
        auto jwtRefresh = jwt_builder
                          .set_type("RefreshToken")
                          .sign(jwt::algorithm::hs256(_jwtRefreshSecret));

        auto userName = readTransaction.exec(psqlMethods::userData::getName, {schoolUUID, userUUID}).one_field().as<std::string>();


        //! Set secure
        // User Set-Cookie
        res.set_header("Set-Cookie", "Floaty_access_token=" + jwtAccess +
            "; path=/; Max-Age=86400; HttpOnly; SameSite=Lax;");

        // Set the refresh token in the Set-Cookie header of the response
        if (req_json.has("rememberMe")
            && req_json["rememberMe"].t() == crow::json::type::True)
                res.add_header("Set-Cookie", "Floaty_refresh_token=" + jwtRefresh + "; path=/; Max-Age=604800; HttpOnly; SameSite=Lax;");

        crow::json::wvalue root;
        root["user"]["name"] = userName;
        res.body = root.dump();

    }
    catch (api::exceptions::parseErr& e) {
        res.code = 400;
        crow::json::wvalue json;
        json["type"] = "Parse error";
        json["msg"] = "Failed to parse request body. Is it json?";
    }
    catch (api::exceptions::wrongRequest& e) {
        res.code = 400;
        crow::json::wvalue json;
        json["type"] = "Wrong request";
        json["msg"] = e.what();
        res.body = json.dump();
    }
    catch (std::exception &e) {
        crow::json::wvalue json;
        json["type"] = "Wrong request";
        json["msg"] = e.what();
        res.body = json.dump();
        std::cerr << "ERR: " <<  e.what() << '\n';
    }

    _connectionPool->releaseConnection(c);
    return res.end();
}

void Server::routes_auth::refreshToken(const crow::request& req, crow::response& res) {
    // Get refresh token
    auto& ctx = app.get_context<crow::CookieParser>(req);
    const std::string& refreshToken_buff = ctx.get_cookie("Floaty_refresh_token");

    // Check if token isn't valid
    if (refreshToken_buff.empty() || !isValidJWT(refreshToken_buff, _jwtRefreshSecret)) {
        res.code = 401; // Unauthorized
        return res.end();
    }

    // Decode the JWT and get the payload
    auto decodedJWT = jwt::decode(refreshToken_buff);

    // Create a new token with required claims
    auto builder_jwt = jwt::create();

    // Set claims from the decoded payload – assuming 'sub' is in payload
    for (const auto& e : decodedJWT.get_payload_claims()) {
        // Here we set each claim to the new token
        builder_jwt.set_payload_claim(e.first, e.second);
    }

    // Additional claims that you might want to set
    builder_jwt
        .set_issuer("Floaty") // Set the issuer of your token
        .set_issued_at(std::chrono::system_clock::now()) // Set issuesed time
        .set_expires_at(std::chrono::system_clock::now() + std::chrono::hours(24)) // Set expiration time
        .sign(jwt::algorithm::hs256{_jwtAccessSecret}); // Sign with access token secret

    // Once the new access token has been created
    std::string newAccessToken = builder_jwt
                                 .set_type("AccessToken")
                                 .sign(jwt::algorithm::hs256{_jwtAccessSecret});

    // Send the new access token in response
    res.code = 204; // Success
    res.set_header("Set-Cookie", "Floaty_access_token=" + newAccessToken +
        "; path=/; Max-Age=86400; HttpOnly; Secure; SameSite=Lax;");
    return res.end(); // End the response
}

void Server::routes_auth::getOrgInformation(const crow::request& req, crow::response& res, const std::string& schoolID) {
    auto con = _connectionPool->getConnection();

    pqxx::read_transaction rtx(*con);
    auto pres = rtx.exec(psqlMethods::org::getData, schoolID);
    crow::json::wvalue json;

    if (!pres[0][0].is_null()) {
        json["org"] = crow::json::load(pres[0][0].as<std::string>());
        json["status"] = 200;
    }
    else
        json["status"] = 404;

    _connectionPool->releaseConnection(con);
    res.body = json.dump();
    return res.end();
}


void Server::routes_auth::getInviteProps(const crow::request& req, crow::response& res,
    const std::string& schoolID, const std::string& invite_code) {

    auto con = _connectionPool->getConnection();
    pqxx::read_transaction work(*con);

    auto props = work.exec(psqlMethods::invites::getProperties,{ schoolID, invite_code});
    crow::json::wvalue json;
    //* 50 / 50 maybe refactor todo
    if (!props[0][0].is_null()) {
        json["invite"] = crow::json::load(props[0][0].as<std::string>());
        json["status"] = 200;
    }
    else
        json["status"] = 404;
    res.body = json.dump();
    _connectionPool->releaseConnection(con);
    return res.end();
}

void Server::routes_auth::signupUsingInvite(const crow::request& req, crow::response& res,
    const std::string& schoolID) {
    const crow::json::rvalue root_body = crow::json::load(req.body);
    const crow::json::rvalue& invite_creds = root_body["invite"];
    const crow::json::rvalue& user_creds = root_body["user"];

    auto c = _connectionPool->getConnection();

    try {
        if (!invite_creds ||
            !invite_creds.has("code") ||
            !invite_creds.has("secret")
        ) {
            throw api::exceptions::wrongRequest(R"(No "invite" field or "code" or "secret")");
        }
        if (!user_creds ||
            !user_creds.has("login") ||
            !user_creds.has("password")
        ) {
            throw api::exceptions::wrongRequest("No \"user\" field or login, password in it");
        }

        const std::string& invite_code = invite_creds["code"].s();
        const std::string& invite_secret = invite_creds["secret"].s();

        const std::string& user_loginHashed = hashSHA256(user_creds["login"].s());
        const std::string& user_passwordHashed = hashSHA256(user_creds["password"].s());

        //* Get con for checking validality of invite
        pqxx::work work(*c);

        //* Check if invite creds are valid
        auto isValidInvite = work.exec(psqlMethods::invites::isValid,{ schoolID, invite_code, invite_secret}).one_field().as<bool>();
        if (!isValidInvite) {
            throw api::exceptions::wrongRequest("No such invite");
        }
        //* Check if login is alredy is use
        bool isLoginOccupied = work.exec(psqlMethods::userChecks::isLoginOccupied, user_loginHashed).one_field().as<bool>();
        if (isLoginOccupied)
            throw api::exceptions::conflict("Login is already occupied. Please, try another");

        //* Get invite_props
        auto invite_props = work.exec(psqlMethods::invites::getProperties, {schoolID, invite_code}).one_field().as<std::string>();

        crow::json::rvalue invite_body_json = crow::json::load(invite_props);
        if (!invite_body_json) {
            throw api::exceptions::conflict("Wrong format of invite_body created by administrator");
        }
        std::vector<std::string> roles;
        std::vector<std::string> classes;

        for (const auto& el : invite_body_json["roles"]) {
            roles.emplace_back(el.s());
        }
        for (const auto& el : invite_body_json["classes"]) {
            classes.emplace_back(el["id"].s());
        }
        const std::string& name = invite_body_json["name"].s();

        //* Create user
        work.exec(psqlMethods::schoolManager::users::createWithContext,{
                           schoolID,
                           user_loginHashed,
                           user_passwordHashed,
                           name,
                           roles,
                           classes
        }
        );
        work.exec(psqlMethods::invites::archive, {schoolID, invite_code});
        work.commit();
        res.code = 204;
    }
    catch (api::exceptions::requirmentsDoesntMeeted& e) {
        res.code = 403;
        res.body = e.what();
    }
    catch (api::exceptions::wrongRequest& e) {
        res.code = 400;
        res.body = e.what();
    }
    catch(api::exceptions::conflict& e) {
        res.code = 409;
        res.body = e.what();
    }
    _connectionPool->releaseConnection(c);
    return res.end();
}


bool Server::isValidJWT(const std::string& userjwt, const std::string& _jwtSecret) {

    jwt::verifier verify = jwt::verify();
    verify.allow_algorithm(jwt::algorithm::hs256(_jwtSecret));
    verify.with_issuer("Floaty");

    pqxx::connection* c = _connectionPool->getConnection();
    try {
        jwt::decoded_jwt decoded_token = jwt::decode(userjwt);
        verify.verify(decoded_token);

        // * check exp time
        {
            auto exp = decoded_token.get_payload_claim("exp").as_int();

            auto exp_time_t = std::chrono::system_clock::from_time_t(exp);
            auto now = std::chrono::system_clock::now();

            if (now > exp_time_t)
                throw jwt::token_verification_exception();
        }

        pqxx::read_transaction rtx(*c);

        auto token_user_id = decoded_token.get_subject();
        auto token_school_id = decoded_token.get_payload_claim("aud").as_string();

        const std::string& token_user_id_decoded = rtx.exec(psqlMethods::encoding::decode, token_user_id).one_field().as<std::string>();
        const std::string& token_school_id_decoded = rtx.exec(psqlMethods::encoding::decode, token_school_id).one_field().as<std::string>();
        // * check org_id
        {
            auto school_id = rtx.exec(psqlMethods::userData::getSchoolId, token_user_id_decoded).one_field().as<std::string>();

            if (token_school_id_decoded != school_id)
                throw jwt::token_verification_exception();
        }

        // * check roles
        {
            picojson::array token_roles = decoded_token.get_payload_claim("roles").as_array();

            const std::string& user_id_decoded = rtx.exec(psqlMethods::encoding::decode, token_user_id).one_field().as<std::string>();
            picojson::array available_roles;
            auto roles = crow::json::load(rtx.exec(psqlMethods::userData::getRoles, {token_school_id_decoded, user_id_decoded}).one_field().as<std::string>());

            if (roles.size() != 0) {
                for (const auto& role : roles) {
                    available_roles.emplace_back(std::string(role.s()));
                }
            }
            if (token_roles != available_roles)
                throw jwt::token_verification_exception();
        }
        // * Check classes
        {
            picojson::array token_classes = decoded_token.get_payload_claim("classes").as_array();

            const std::string& user_id_decoded = rtx.exec(psqlMethods::encoding::decode, token_user_id).one_field().as<std::string>();
            picojson::array available_classes;
            auto classes = rtx.exec(psqlMethods::userData::getClasses, {token_school_id_decoded, user_id_decoded});
            if (!classes.front().front().is_null()) {
                for (auto class_v : classes) {
                    available_classes.emplace_back(class_v.front().as<std::string>());
                }
            }
            if (token_classes != available_classes)
                throw jwt::token_verification_exception();
        }
        _connectionPool->releaseConnection(c);
        return true;
    }
    catch (jwt::error::signature_verification_error& e) {
        std::cerr << "Signature verif. err: " << e << '\n';
    }
    catch (jwt::error::token_verification_error& e) {
        std::cerr << "Signature verif. err: " << e << '\n';
    }
    catch (const std::runtime_error& e) {
        std::cerr << "Exception. Data may changed. Err: " << e.what() << '\n';
    }
    catch (std::exception &e) {
        std::cerr << "Excp. is: " << e.what() << '\n';
    }
    _connectionPool->releaseConnection(c);
    return false;
}

std::string Server::hashSHA256(const std::string& input) {
    unsigned char hash[SHA256_DIGEST_LENGTH];
    EVP_MD_CTX* mdCtx;
    const EVP_MD* md;

    // Initialize the message digest context
    mdCtx = EVP_MD_CTX_new();
    if (mdCtx == nullptr) {
        // Handle memory allocation failure
        throw std::runtime_error("Failed to allocate EVP_MD_CTX");
    }

    // Select the SHA256 algorithm
    md = EVP_get_digestbyname("SHA-256");
    if (md == nullptr) {
        EVP_MD_CTX_free(mdCtx);
        throw std::invalid_argument("Failed to get SHA-256 digest");
    }

    // Initialize the digest operation
    if (EVP_DigestInit_ex(mdCtx, md, nullptr)!= 1) {
        EVP_MD_CTX_free(mdCtx);
        throw std::runtime_error("Failed to initialize digest");
    }

    // Update the digest with the input string
    if (EVP_DigestUpdate(mdCtx, input.c_str(), input.length())!= 1) {
        EVP_MD_CTX_free(mdCtx);
        throw std::runtime_error("Failed to update digest");
    }

    // Finalize the digest
    if (EVP_DigestFinal_ex(mdCtx, hash, nullptr)!= 1) {
        EVP_MD_CTX_free(mdCtx);
        throw std::runtime_error("Failed to finalize digest");
    }

    EVP_MD_CTX_free(mdCtx); // Clean up

    std::stringstream ss;
    for (unsigned char byteValue : hash) {
        ss << std::hex << std::setw(2) << std::setfill('0') << (int)byteValue;
    }

    return ss.str();
}