#include "../../includes/Floaty/authorization.h"
bool isValidCookie(const crow::request &req) {

    std::string userTokenNative = std::string(req.get_header_value("Cookie"));
    
    const jwt::decoded_jwt userTokenDecoded = jwt::decode(userTokenNative.get("token", "-1"));
    const std::string schoolLogin = std::string(req.url_params.get("schoolId"));

    auto verifier = jwt::verify()
        .allow_algorithm(jwt::algorithm::hs256{ genToken(schoolLogin) })
        .with_id(schoolLogin);


    /* //TODO - рефактить jwt builder, чтобы появился id с датой (может полностью точной?). Далее декодить здесь токен и бранть Id ->
    *  //TODO собирать новый токен с выданным id для сравнения, если соответствие -> пустить в interface 
    */ //TODO - брать из query selector Login школы
   
    // verifier.verify(userTokenDecoded);
    const std::string currentToken = genToken(schoolLogin);
    
    if (userTokenNative == currentToken ) {
        return 1;
    }

    return 0;
}