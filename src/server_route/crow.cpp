#include "../../includes/Floaty.h"
#define CROW_STATIC_DIRECTORY "web/"
#define CROW_STATIC_ENDPOINT "web/"


//returns correct key for reqPath
std::string getAdminKey(const std::string& reqPath) {
    std::string key;
    std::stringstream buff;
    Json::Reader jReader;
    Json::Value jKeyVal;
    std::ifstream ifstream;
    ifstream.open(reqPath);
    buff << ifstream.rdbuf();
    ifstream.close();
    jReader.parse(buff.str(), jKeyVal);
    return jKeyVal["superAdminKey"].asString();
}

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
                if (req.url_params.get("key") != nullptr ) {
                    const std::string& reqPath = "data/" + std::string(req.url_params.get("schoolId")) + "/schoolData.json";
                    const std::string& corrKey = getAdminKey(reqPath);
                    if (std::string(corrKey) == std::string(req.url_params.get("key"))) {
                        res.body = genWebPages("userInterfaceConfig").body;
                    }
                    else {
                        res.body = genWebPages("userInterface").body;
                    }
                }
                else {
                    res.body = genWebPages("userInterface").body;
                }
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


    CROW_ROUTE(app, "/")
    ([](crow::response &res)
    {
        res.moved("/home");
        return res.end();
    });
    //! Только для html
    CROW_ROUTE(app, "/<string>")
    ([](const std::string& file)
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
                res = getStaticFileJson(req);
                return res.end();
            }
            else {
                res = handleErrPage(401, "Verification [user] failed");
                res.end();
            }
        } else res = handleErrPage(401, "Ur cookie isnt defined. Visit login page");
        return res.end();
    });
    CROW_ROUTE(app, "/api/editDataClassesForm")
            .methods(crow::HTTPMethod::POST)
                    ([](const crow::request &req, crow::response &res)
                     {
                         if (!req.get_header_value("Cookie").empty()) {
                             if (isValidCookie(req) == 200) {
                                const std::string editNotes = req.body;
                                res = writeForEditNotesForm(editNotes);
                             }
                             else { //login as user non success
                                 res = handleErrPage(401, "Verification [user] failed");
                             }
                         } //handler non cookie user
                         else {
                             res = handleErrPage(401, "Ur cookie isnt defined. Visit login page");
                         }
                         return res.end();
                     });

    CROW_ROUTE(app, "/api/getDataClassesInterface")
    .methods(crow::HTTPMethod::POST)
            ([](const crow::request &req, crow::response &res)
    {
        if (!req.get_header_value("Cookie").empty() && isValidCookie(req) == 201 ) {
                res = getStaticFileJson(req, false);
                return res.end();
        }
    });
    CROW_ROUTE(app, "/api/editDataClassesInterface")
            .methods(crow::HTTPMethod::POST)
                    ([](const crow::request &req, crow::response &res)
                     {
                         if (!req.get_header_value("Cookie").empty()) {
                             if (isValidCookie(req) == 201) {
                                 const std::string editNotes = req.body;
                                 res = getStaticFileJson(req, false);
                             }
                             else { //login as user non success
                                 res = handleErrPage(401, "Verification [user] failed");
                                 res.end();
                             }
                         } //handler: user without cookie
                         else {
                             res = handleErrPage(401, "Ur cookie isnt defined. Visit login page");
                         }
                         return res.end();
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
    ([](const std::string& type,const std::string& file)
    {
        return sendWebResoursesByRequest(type, file);
    });

    CROW_CATCHALL_ROUTE(app)([]
    {
        return handleErrPage(404);
    }); 
    
//    app .bindaddr("127.0.0.1")
    app .bindaddr("62.233.46.131")
        .port(443)
        .multithreaded()
        .ssl_file("fullchain.pem", "privkey.pem")
        .run_async();
}
