#include "Floaty/authorization.h"

int isValidCookie(const std::string& cookie, const std::string& schoolId) {

    std::string userTokenNative;
    std::vector<std::string> tokens;
    size_t start = 0, end = 0;
    while ((end = cookie.find(';', start)) != std::string::npos) {
        tokens.push_back(cookie.substr(start, end - start));
        start = end + 1;
    }
    tokens.push_back(cookie.substr(start));
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

    secret = genToken(schoolId);


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