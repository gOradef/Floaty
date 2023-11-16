#include <crow.h>
#include <string>
#include <mysqlx/common.h>
#include <mysqlx/xapi.h>
#include <mysql/mysql.h>
#include <mysqlx/xdevapi.h>

using ::std::cout;
using ::std::endl;
using namespace ::mysqlx;
// class WebContent
// {
// private:
//     /* data */
// public:
//     WebContent(/* args */);
//     ~WebContent();
// };

// WebContent::WebContent(/* args */) : returnable("text/plain")
// {
//     // crow::mustache::set_global_base("/content");
//     // auto introPage = crow::mustache::load_text("./content/intro.html");
// }

// WebContent::~WebContent()
// {
// }
// class WebContent : crow::returnable {
// public:
//     WebContent() : returnable("text/plain"){};
//     std::string dump() const override
//     {
//         return this.as_string();
//     }

// private:

// };

int main()
{
    
    
    mysql::MySQL_Driver *driver;
    sql::Connection *con;

    driver = sql::mysql::get_mysql_driver_instance();
    con = driver->connect("tcp://127.0.0.1:3306", "user", "password");

    delete con;
    crow::SimpleApp app;

    // crow::mustache::context ctx;
    // // WebContent *webCon = new WebContent;
    // CROW_CATCHALL_ROUTE(app)([](const crow::request &req, crow::response &res){
    //     res.redirect("/intro");
    //     res.end();
    // });
    CROW_ROUTE(app, "/intro")
    ([]{
        // auto pageIntro = crow::mustache::load("/intro.html");
        return "pageIntro"; 
    });
    app.bindaddr("127.0.0.1").port(18080).run_async();
}