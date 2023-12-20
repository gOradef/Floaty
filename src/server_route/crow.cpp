#include "../../includes/Floaty.h"
#define CROW_STATIC_DIRECTORY "web/"
#define CROW_STATIC_ENDPOINT "web/"

int main()
{
    crow::SimpleApp app;
    crow::mustache::context ctx; 
    crow::mustache::set_global_base("web");

    CROW_ROUTE(app, "/interface") ([](const crow::request &req, crow::response &res)
   {
       //handler of non cookie users
    if (req.get_header_value("Cookie") == "") {
        res.moved("/login");
        return res.end();
    }
    if (isValidCookie(req)) {
        res.body = genWebPages("interface").body;
        return res.end();
    }
    res.body = "something went wrong.. UwU";
    return res.end();

   });
    //! Только для html
    CROW_ROUTE(app, "/<string>")
    ([](std::string file)
     {
        return genWebPages(file);
     });
    //*TODO get cookie and compare with current date cookie
    CROW_ROUTE(app, "/api/getData")([](const crow::request &req) 
    {
        if (req.get_header_value("Cookie") != "") {
            if (isValidCookie(req)) {
                //TODO - add Foo() for reading data
                return crow::response(200, "All is good!");
            }
            return crow::response(401);
        }
        return crow::response(300, "get cookie!");
    }
    );

    CROW_CATCHALL_ROUTE(app)([]
    {
        return handle404Page();
    });


    //* Response for login post req
    CROW_ROUTE(app, "/login-process")
    .methods("POST"_method)([](const crow::request &req, crow::response &res){
        res = genTokenAndSend(req);
        return res.end();
    }
    );

    //* Response for resources of web
    CROW_ROUTE (app, "/<string>/<string>")
    ([](std::string type,std::string file)
    {
        return sendWebResoursesByRequest(type, file);
    }
    );
    app .bindaddr("127.0.0.1")
        .port(6010)
        .multithreaded()
        .run_async();
}