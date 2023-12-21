#include "Floaty/api_route.h"

Json::Value getClassesAsJson(std::string schoolId){
    std::ifstream ifstream;
    std::string schoolDate = genToken(schoolId);
    std::stringstream buffSchoolDate;
    try {
//    ifstream.open(std::string("data/" + schoolId + "/" + schoolDate + ".json"));
        ifstream.open(std::string("data/" + schoolId + "/" + "datehere"+ ".json"));

        buffSchoolDate << ifstream.rdbuf();
        ifstream.close();

    }
    catch (std::exception &e) {
        std::cout << "unsuccessful on read data" << e.what()<< '\n';
    }
    Json::Value result;

    Json::Value fileRoot;
    Json::Reader jreader;
    bool isParsedSuccess = jreader.parse(buffSchoolDate, fileRoot);
    if (isParsedSuccess == 1) {
        Json::StyledWriter writer;
        result = writer.write(fileRoot["classes"]);
    }
    else {
        return result;
    }
    return result;
}
void getStaticFileJson(std::string schoolId, crow::response &res) {

    res.set_static_file_info(std::string("data/" + schoolId + "/" + "datehere"+ ".json"));
    return res.end();
}
