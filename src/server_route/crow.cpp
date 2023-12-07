#include "../includes/crow.h"

#include "../includes/Floaty.h"
#include <fstream>
#include <string>

#define CROW_STATIC_DIRECTORY "web/"
#define CROW_STATIC_ENDPOINT "web/"

int main()
{
    int i;
    crow::SimpleApp app;
    crow::mustache::context ctx;
    crow::mustache::set_global_base("web");
    CROW_CATCHALL_ROUTE(app)([](const crow::request &req, crow::response &res)
    {
        res.redirect("/home");
        res.end();
    });
    //! Только для html
    CROW_ROUTE(app, "/<string>")
    ([&i](/*const crow::request &req, crow::response &res,*/std::string file)
     {

        crow::mustache::context ctx;
        auto page = crow::mustache::load("html/" + file + ".html");
            if (file == "favicon.ico") {
                page = crow::mustache::load("imgs/favicon.ico");
                return page.render();
            }
            if (page.render_string() == "") {
                page = crow::mustache::load("html/error404.html");
                ctx["id"] = i;
                i++;
                return page.render(ctx);
            }
        return page.render();
     });

    //* Response for resourses of web
    CROW_ROUTE(app, "/<string>/<string>")
    ([](std::string type,std::string file){
        auto res = crow::mustache::load_text(type +'/' + file);
        return res;
    });

    app .bindaddr("127.0.0.1")
        .port(6010)
        .multithreaded()
        // .loglevel(crow::LogLevel::Debug)
        .run_async();
}