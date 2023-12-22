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


crow::response generateNewJson(std::string &reqPath) {

    crow::response result;
    std::ostringstream buff;
    std::fstream fileStream("data/asserts/exampleDateData.json", std::fstream::in);

    if (!fileStream.fail()) {
        buff << fileStream.rdbuf();

    }
    else {
        result.code = 410;
        return result;
    }
    Json::Value exampleRoot = buff.str();
    Json::FastWriter styledWriter;

    buff << styledWriter.write(exampleRoot);
    fileStream.close();
    fileStream.open(reqPath, std::fstream::out);
    fileStream << exampleRoot.asString();
    result.body = exampleRoot.asString();
    return result;
}

crow::response getStaticFileJson(std::string schoolId, crow::response &res) {
    crow::response res1;
    std::string currDate = genToken(schoolId);
    std::string reqPath = std::string("data/" + schoolId + "/" + genToken(schoolId) + ".json");
    res.set_static_file_info(reqPath);
    if (res.body.empty()) {
        return generateNewJson(reqPath);
    }
    else if (res.is_static_type()) {
        res1 = res.body;
        return res1;
    }

    else return crow::response(400, "comment");
}
