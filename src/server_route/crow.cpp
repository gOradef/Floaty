#include "../../includes/Floaty.h"
#define CROW_STATIC_DIRECTORY "web/"
#define CROW_STATIC_ENDPOINT "web/"

int main()
{
    int i;
    crow::SimpleApp app;
    crow::mustache::context ctx; 
    crow::mustache::set_global_base("web");

    //! Только для html
    CROW_ROUTE(app, "/<string>")
    ([&i](std::string file)
     {
        return genWebPages(file);
     });

    //*TODO get cookie and compare with current date coockie
    CROW_ROUTE(app, "/admin/report")([](const crow::request &req) {
        std::string userToken = req.get_header_value("Cookie");
        return crow::response(280, "In progress..");

    });
    CROW_CATCHALL_ROUTE(app)([]
    {
        return handle404Page();
    }
    );


    //* Response for login post req
    CROW_ROUTE(app, "/login-process")
    .methods("POST"_method)([](const crow::request &req, crow::response &res){
        // auto temp = &res;
        res = genToken(req, res);
        return res.end();
    }

    );
    //* Response for resourses of web
    CROW_ROUTE(app, "/<string>/<string>")
    ([](std::string type,std::string file){
        return sendWebResoursesByRequest(type, file);
    });
    app .bindaddr("127.0.0.1")
        .port(6010)
        .multithreaded()
        .run_async();
}