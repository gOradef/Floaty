#include "../../includes/Floaty/authorization.h"
bool isValidCookie(const crow::request &req) {


    std::string userTokenNative = std::string(req.get_header_value("Cookie"));

    //removes here token= prefix
    for(int i{0}; i < 5; i++) {
        userTokenNative.pop_back();
    }

    // const jwt::decoded_jwt userTokenDecoded = jwt::decode(userTokenNative);
    std::string secret;
    if (req.url_params.get("schoolId") != nullptr) {
        const std::string schoolLogin = req.url_params.get("schoolId");
        secret = genToken(schoolLogin);
    }
    else return false;

    /* //TODO - рефактить jwt builder, чтобы появился id с датой (может полностью точной?). Далее декодить здесь токен и бранть Id ->
    *  //TODO собирать новый токен с выданным id для сравнения, если соответствие -> пустить в interface 
    */ //TODO - брать из query selector Login школы
    try {
        jwt::decoded_jwt decodedToken = jwt::decode(userTokenNative);
        auto verifyApp = jwt::verify()
            .allow_algorithm(jwt::algorithm::hs256(secret))
            .with_issuer("FloatyCook")
            .with_type("JWT")
            .with_id(secret)
            .with_subject("userToken");

        verifyApp.verify(decodedToken);
        return 1;
    }
    catch (jwt::token_verification_exception &e) { std::cout << "exception goted - " << e.what();}
    catch (std::runtime_error &e) {std::cout << e.what();}
    catch (std::invalid_argument &e) {std::cout << e.what();}

    std::cout << "Skipped exception";
    return false;
}