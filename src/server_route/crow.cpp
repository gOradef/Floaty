#include <crow.h>
#include <string>
#include <stdlib.h>
#include <iostream>
#include "../headerFiles/1.h"
/**
 * Todo add header to web
 * Todo add header to conection for db && login/register

*/
int main()
{
    crow::SimpleApp app;
    crow::mustache::context ctx;

    CROW_CATCHALL_ROUTE(app)([](const crow::request &req, crow::response &res){
        res.redirect("/intro");
        res.end();
    });

    CROW_ROUTE(app, "/intro")
    ([]{
        // auto pageIntro = crow::mustache::load("/intro.html");
        WebClient client;
        client.setupCon();
        // client.userAction();
        return client.checkIsSuccessCon();

    });
    
    app.bindaddr("127.0.0.1").port(18080).run_async();
}