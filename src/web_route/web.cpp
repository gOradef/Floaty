#include "../../includes/Floaty/web_route.h"

//generates pages with navbar & footer if they exist in requestionable file
crow::response genWebPages(std::string file) {
    crow::mustache::context ctx;

        auto nav = crow::mustache::load_text("html/templates/navbar.html");
        auto navControl = crow::mustache::load_text("html/templates/navbarControl.html");
        auto footer = crow::mustache::load_text("html/templates/footer.html");
        ctx.content_type = "text/html";

        ctx["navbarFile"] = nav;
        ctx["navbarControlFile"] = navControl;
        ctx["footerFile"] = footer;

        if (file.empty()) file = "home";

        auto page = crow::mustache::load("html/" + file + ".html");
            if (file == "favicon.ico") {
                page = crow::mustache::load("imgs/favicon.ico");
                return page.render();
            }
            if (page.render_string().empty()) {
                return handleErrPage(404);
            }
        return page.render(ctx);
}

//NOTE -  Возвращает строку, не полноценный запрос
crow::response sendWebResoursesByRequest(std::string type, std::string file) {
    if(type == "html") return handleErrPage(404);
    auto page = crow::mustache::load_text(type + '/' + file);
            if (page.empty()) {
                page = handleErrPage(404).body;
                return page;
            }
    return page;
}

crow::response handleErrPage(int ec, std::string ecom) {
    crow::mustache::context ctx;
    switch(ec) {
        default:
            break;
        case 0:
            ctx["ecom"] = "idk what hpnd";
        case 401:
            ctx["ecom"] = "User is not defined";
        case 402:
            ctx["ecom"] = "Authorization failed";
        case 404:
            ctx["ecom"] = "Page is not found";
    }
    ctx["ec"] = ec;
    if (ec == 0) {ctx[ec] = 400;}
    if(ecom != "") {ctx["ecom"] = ecom;}
    auto page = crow::mustache::load("html/error.html");
    return page.render(ctx);
}