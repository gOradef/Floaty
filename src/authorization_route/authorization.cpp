#include "../../includes/Floaty/authorization.h"
bool isValidCookie(const crow::request &req) {


    std::string cookieHeader = req.get_header_value("Cookie");

    std::vector<std::string> tokens;
    size_t start = 0, end = 0;
    while ((end = cookieHeader.find(';', start)) != std::string::npos) {
        tokens.push_back(cookieHeader.substr(start, end - start));
        start = end + 1;
    }
    // Добавляем последний токен
    tokens.push_back(cookieHeader.substr(start));

    // Выбираем последний токен
    std::string userTokenNative;
    if (!tokens.empty()) {
        userTokenNative = tokens.back();
    } else {
        return false;
    }
    //Ломаем статичный префикс токена
    for (int i = 0; i < 7; ++i) {
    userTokenNative.erase(userTokenNative.begin());
    }
    std::string secret;
    if (req.url_params.get("schoolId") != nullptr) {
        const std::string schoolLogin = req.url_params.get("schoolId");
        secret = genToken(schoolLogin);
    }
    else return false;

    try {
        jwt::decoded_jwt decodedToken = jwt::decode(userTokenNative);
        auto verifyApp = jwt::verify()
            .allow_algorithm(jwt::algorithm::hs256("super-mega-giga-kilo-long-secret"))
            .with_issuer("FloatyCook")
            .with_type("JWT")
            .with_id(secret)
            .with_subject("userToken");

        verifyApp.verify(decodedToken);
        return 1;
    }
    catch (jwt::token_verification_exception &e) { std::cout << "exception goted - " << e.what();}
    catch (std::runtime_error &e) {std::cout << "exception goted - " << e.what();}
    catch (std::invalid_argument &e) {std::cout << "exception goted - " << e.what();}

    std::cout << "Skipped exception";
    return false;
}