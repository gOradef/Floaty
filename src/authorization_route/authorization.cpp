#include "../../includes/Floaty/authorization.h"

int isValidCookie(const crow::request &req) {


    std::string cookieHeader = req.get_header_value("Cookie");
    std::string userTokenNative;
    std::vector<std::string> tokens;
    size_t start = 0, end = 0;
    while ((end = cookieHeader.find(';', start)) != std::string::npos) {
        tokens.push_back(cookieHeader.substr(start, end - start));
        start = end + 1;
    }
    tokens.push_back(cookieHeader.substr(start));
    if (!tokens.empty()) {
        userTokenNative = tokens.back();
    }
    else {
        return 403; //invalid token
    }

    if (*userTokenNative.begin() == ' ') userTokenNative.erase(userTokenNative.begin());
    for (int i = 0; i < 6; ++i) {
        userTokenNative.erase(userTokenNative.begin());
    }

    std::string secret;
    std::string schoolLogin;
    if (req.body.empty()) {
        if (req.url_params.get("schoolId") != nullptr) {
            schoolLogin = req.url_params.get("schoolId");
            secret = genToken(schoolLogin);
        }
        else {
            return 401;
        }
    }
    else  {
        Json::Reader reader;
        Json::Value reqRootJ;
        reader.parse(req.body, reqRootJ);

        if (reqRootJ["schoolId"].asString() != "1212") {
            schoolLogin = reqRootJ["schoolId"].asString();
            secret = genToken(schoolLogin);
        }
        else {
            return 401;
        }

    }


    try {
        jwt::decoded_jwt decodedToken = jwt::decode(userTokenNative);
        auto verifyApp = jwt::verify()
            .allow_algorithm(jwt::algorithm::hs256("super-mega-giga-kilo-long-secret"))
            .with_issuer("FloatyCook")
            .with_type("JWT")
            .with_id(secret)
            .with_subject("userToken");

        verifyApp.verify(decodedToken);
        return 200; //oke for user
    }
    catch (jwt::token_verification_exception &e) {
        try {
                jwt::decoded_jwt decodedToken = jwt::decode(userTokenNative);
                auto verifyApp = jwt::verify()
                    .allow_algorithm(jwt::algorithm::hs256("super-mega-giga-kilo-long-secret"))
                    .with_issuer("FloatyCook")
                    .with_type("JWT")
                    .with_id(secret)
                    .with_subject("adminToken");
                verifyApp.verify(decodedToken);
                return 201; //oke for admin
        }
        catch(jwt::token_verification_exception &e) {
                std::cout << "exception goted verif- " << e.what();
        }
    }
    catch (std::runtime_error &e) {std::cout << "exception goted runtime - " << e.what();}
    catch (std::invalid_argument &e) {std::cout << "exception goted invalid arg- " << e.what();}

    return 402;
}