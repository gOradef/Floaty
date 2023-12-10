#include <fstream>
#include <string>
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

        crow::mustache::context ctx;
        auto nav = crow::mustache::load_text("html/templates/navbar.html");
        auto footer = crow::mustache::load_text("html/templates/footer.html");
        ctx.content_type = "text/html";

        ctx["navbarFile"] = nav;
        ctx["footerFile"] = footer;

        auto page = crow::mustache::load("html/" + file + ".html");
            if (file == "favicon.ico") {
                page = crow::mustache::load("imgs/favicon.ico");
                return page.render();
            }
            if (page.render_string() == "") {
                page = crow::mustache::load("html/error404.html");
                return page.render(ctx);
            }
        // page.render_string();
        return page.render(ctx);
     });

    //* Response for resourses of web
    CROW_ROUTE(app, "/<string>/<string>")
    ([](std::string type,std::string file){
        auto res = crow::mustache::load_text(type +'/' + file);
        return res;
    });


    //* Response for login post req
    CROW_ROUTE(app, "/login-process")
    .methods("POST"_method)([](const crow::request &req, crow::response &res){
        // auto temp = &res;
        res = genToken(req, res);
        return res.end();
    }

    );
    app .bindaddr("127.0.0.1")
        .port(6010)
        .multithreaded()
        .run_async();
}