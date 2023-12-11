#include "../../includes/Floaty/web_route.h"

//generates pages with navbar & footer if they exists in requestionable file
crow::response genWebPages(std::string file) {
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
}

//NOTE -  Возвращает строку, не полноценный запрос
crow::response sendWebResoursesByRequest(std::string type, std::string file) {
    auto res = crow::mustache::load_text(type +'/' + file);
            if (res== "") {
                res = crow::mustache::load_text("html/error404.html");
                return res;
            }
    return res;
}
//Возвращает 404 страницу
crow::response handle404Page() {
    auto page = crow::mustache::load("html/error404.html");
    return page.render();
}