#include "../../includes/Floaty.h"
#define CROW_STATIC_DIRECTORY "web/"
#define CROW_STATIC_ENDPOINT "web/"


void defineErrCodeOfCookie(const crow::request &req, crow::response &res) {
    if (req.get_header_value("Cookie").empty()) {
        res.moved("/login");
        return res.end();
    }
    else {
        switch(isValidCookie(req)) {
            case 200:
                res.body = genWebPages("userForm").body;
                return res.end();
            case 201:
                res.body = genWebPages("userInterface").body;
                return res.end();
            case 403:
                res.body = handleErrPage(0,"Invalid cookie. Visit login page").body;
                return res.end();
            case 401:
                res.body = handleErrPage(0, "Undefined query string").body;
                return res.end();
            case 402:
                res.body = handleErrPage(0, "Failed verification").body;
                return res.end();
            default:
                res = handleErrPage(404);
                return res.end();
        }
    }
}
int main()
{
    crow::SimpleApp app;
    crow::mustache::context ctx; 
    crow::mustache::set_global_base("web");

    CROW_ROUTE(app, "/interface") ([](const crow::request &req, crow::response &res)
   {
       //handler of non cookie users
        return defineErrCodeOfCookie(req, res);
    });
    //! Только для html
    CROW_ROUTE(app, "/<string>")
    ([](std::string file)
     {
        return genWebPages(file);
     });

    //*TODO get cookie and compare with current date cookie
    CROW_ROUTE(app, "/api/getData")
//    .methods(crow::HTTPMethod::POST)
            ([](const crow::request &req, crow::response &res)
    {
        if (!req.get_header_value("Cookie").empty()) {
            if (isValidCookie(req) == 200 || isValidCookie(req) == 201) {
//                 res = getClassesAsJson(req.url_params.get("schoolId")).asString();
                return getStaticFileJson(req.url_params.get("schoolId"), res);

            }
            else {
                res = handleErrPage(402);
                res.end();
            }
        }
        res = handleErrPage(402, "Ur cookie is expired or invalid");
        return res.end();
    }
    );

    CROW_CATCHALL_ROUTE(app)([]
    {
        return handleErrPage(404);
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

    });
    app .bindaddr("127.0.0.1")
        .port(6010)
        .multithreaded()
        .run_async();
}