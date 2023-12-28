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
            case 401:
                res.body = handleErrPage(401, "Undefined query string").body;
                return res.end();
            case 402:
                res.body = handleErrPage(402, "Failed verification").body;
                return res.end();
            case 403:
                res.body = handleErrPage(403,"Invalid token. Visit login page").body;
                return res.end();
            case 404:
                res.body = handleErrPage(404,"Invalid token. Visit login page").body;
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
        if (file == "userForm" || file == "userInterface") return handleErrPage(0, "no access");
        else return genWebPages(file);
     });

    //TODO split jsonFileInto only classes
    CROW_ROUTE(app, "/api/getDataClassesForm")
    .methods(crow::HTTPMethod::POST)
            ([](const crow::request &req, crow::response &res)
    {
        if (!req.get_header_value("Cookie").empty()) {
            if (isValidCookie(req) == 200) {
                res = getStaticFileJson(req.url_params.get("schoolId"));
                return res.end();
            }
            else {
                res = handleErrPage(401, "Verification [user] failed");
                res.end();
            }
        }
        res = handleErrPage(401, "Ur cookie isnt defined. Visit login page");
        return res.end();
    });

    CROW_ROUTE(app, "/api/editDataClassesForm")
            .methods(crow::HTTPMethod::POST)
                    ([](const crow::request &req, crow::response &res)
                     {
                         if (!req.get_header_value("Cookie").empty()) {
                             if (isValidCookie(req) == 200) {
                                std::string editNotes = req.body;
                                crow::response result = editClassesData(editNotes);

                             }
                             else { //login as user non success
                                 res = handleErrPage(401, "Verification [user] failed");
                                 res.end();
                             }
                         } //handler non cookie user
                         res = handleErrPage(401, "Ur cookie isnt defined. Visit login page");
                         return res.end();
                     });

    CROW_ROUTE(app, "/api/getDataClassesInterface")
    .methods(crow::HTTPMethod::POST)
            ([](const crow::request &req, crow::response &res)
    {
        if(!req.get_header_value("Cookie").empty()) {
            if (isValidCookie(req) == 201) {
                res = getStaticFileJson(req.url_params.get("schoolId"));
                return res.end();
            }
        }
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

    CROW_CATCHALL_ROUTE(app)([]
    {
        return handleErrPage(404);
    });
    app .bindaddr("127.0.0.1")
        .port(6010)
        .multithreaded()
        .run_async();
}