#include "Floaty/api_route.h"
#include "vector"

Json::Value genTempClassesAsJson(std::string &reqPath){
    std::vector <std::string> letters;
    letters.emplace_back("А");
    letters.emplace_back("Б");
    letters.emplace_back("В");
    letters.emplace_back("Г");
    letters.emplace_back("Д");
    letters.emplace_back("Е");

    Json::Value root2;
    Json::Value classesNum(Json::objectValue);
    Json::Value letterClass(Json::objectValue);


    Json::Value nameOfClass;
    Json::Value numOfPeople;

    Json::Value absentSubRoot(Json::objectValue);
    Json::Value numOfPeopleAbsent;
    Json::Value listNonRespCause(Json::arrayValue);
    Json::Value listRespCause(Json::arrayValue);
    Json::Value listVirusCause(Json::arrayValue);
    Json::Value listFreeMealIs(Json::arrayValue);

    for(int i = 1; i < 12; ++i) {

        absentSubRoot["amount"] = numOfPeopleAbsent;
        absentSubRoot["listNonRespCause"] = listNonRespCause;
        absentSubRoot["listRespCause"] = listRespCause;
        absentSubRoot["listFreeIs"] = listFreeMealIs;
        absentSubRoot["listVirusCause"] = listVirusCause;

        letterClass["amount"] = numOfPeople;
        letterClass["absent"] = absentSubRoot;

        for (int j = 0; j < 6; j++) {
        letterClass["name"] = std::to_string(i) + letters[j];
            classesNum[ letters[j] ] = letterClass;
        }
        root2[std::to_string(i)] = classesNum;
    }
    root2["10"]["А"]["name"] = "the best!";
    Json::Value root;
    root["classes"] = root2;
    std::ofstream outStream;
    outStream.open(reqPath);

    Json::StyledWriter writer;
    outStream << writer.write(root);
    outStream.close();
    return root;
}

crow::response getStaticFileJson(std::string schoolId) {
    crow::response res;
    std::string currDate = genToken(schoolId);
    std::string reqPath = std::string("data/" + schoolId + "/" + genToken(schoolId) + ".json");
    res.set_static_file_info(reqPath);
    if (res.body.empty()) { //if file doesn't exist
        Json::FastWriter writer;
        std::string resJ = writer.write(genTempClassesAsJson(reqPath));

        res.body = resJ;
        return res;
    }
    else if (res.is_static_type()) { //if exist
        return crow::response(400);
    }
}
