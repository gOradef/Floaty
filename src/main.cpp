#include "Floaty.h"


const std::string& Server::_jwtAccessSecret = "dyXJY7wN2fbhxxI6+KZ47IuGfKt0kFXHQQt1gACG7YUB/zwHxA4nRCq0J1pmxthUAi23oHfA8rNMXv0Oi4LuRw==";
const std::string& Server::_jwtRefreshSecret = "gef7v/0djOtra3JvzlnxnInRfQmRUEYR/vSmiCgJSxjTaDrXX6rR+4fMNzbLqcHwyRT3yt+ofr/9F/0IED7vHg==";

int main() {
    const std::string& postgres_creds = "dbname = floatydb "
                            "user = floatyapi "
                            "password = FloatyTheBest "
                            "hostaddr = 127.0.0.1 "
                            "port = 5432 "
                            "options='--client_encoding=UTF8' ";
    ConnectionPool cp(postgres_creds, 20);
    Server("127.0.0.1", 80, &cp);
    Server::initRoutes();
    Server::run();
    return 0;
}
