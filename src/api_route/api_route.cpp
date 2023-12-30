#include "Floaty/api_route.h"
#include "vector"

Json::Value genTempClassesAsJson(const std::string &reqPath){
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
        absentSubRoot["listFreeMeal"] = listFreeMealIs;
        absentSubRoot["listVirusCause"] = listVirusCause;

        letterClass["amount"] = numOfPeople;
        letterClass["absent"] = absentSubRoot;

        for (int j = 0; j < 6; j++) {
        letterClass["name"] = std::to_string(i) +'_' + letters[j];
            classesNum[ letters[j] ] = letterClass;
        }
        root2[std::to_string(i)] = classesNum;
    }
//    root2["10"]["А"]["name"] = "the best!";
    Json::Value root;
    root["classes"] = root2;
    std::ofstream outStream;
    outStream.open(reqPath);

    Json::StyledWriter writer;
    outStream << writer.write(root);
    outStream.close();
    return root;
}

std::map<std::string, Json::Value> genMapOfEditNotes(const std::string &reqEdit) {
    Json::Value reqEditNotesRoot;
    Json::Reader reader;
    try {
        reader.parse(reqEdit, reqEditNotesRoot);
        std::string schoolId = reqEditNotesRoot["schoolId"].asString();
        std::string className = reqEditNotesRoot["className"].asString();
        std::string absentNum = reqEditNotesRoot["absentNum"].asString();
        Json::Value listAbsent = Json::Value(Json::arrayValue);

        std::cout << "All is good here";

        // * schoolId, className, absentNum, absentVir, absentRespCause, absentNonRespCause, absentFreeMeal
        std::map<std::string, Json::Value> absentMap;
        absentMap["schoolId"] = schoolId;
        absentMap["classNum"] = className.substr(0, className.find('_'));
        absentMap["classLetter"] = className.substr(className.find('_')+1, className.back()-1);
        absentMap["absent_amount"] = absentNum;

        listAbsent = reqEditNotesRoot["absentVir"];
        absentMap["absent_listVirusCause"] = listAbsent;
        listAbsent = reqEditNotesRoot["absentRespCause"];
        absentMap["absent_listRespCause"] = listAbsent;
        listAbsent = reqEditNotesRoot["absentNonRespCause"];
        absentMap["absent_listNonRespCause"] = listAbsent;
        listAbsent = reqEditNotesRoot["absentFreeMeal"];
        absentMap["absent_listFreeMeal"] = listAbsent;

        return absentMap;
    }
    catch (Json::Exception &e) {
        std::map<std::string, Json::Value> map;
        map["err"] = Json::Value{e.what()};
        return map;
    }
}

crow::response writeEditNotesOnCurrDate(std::map<std::string, Json::Value> &editNotesMap) {
    std::fstream fstream;
    Json::Value buff_J;
    Json::Reader Jreader;
    std::ostringstream buff_str;

    fstream.open("data/" + editNotesMap["schoolId"].asString() + '/' + genToken(editNotesMap["schoolId"].asString()) + ".json", std::ios::in);
    buff_str << fstream.rdbuf();
    fstream.close();
    Jreader.parse(buff_str.str(), buff_J);
    // * here trys to edit data
    Json::Value neededPart = Json::Value(Json::objectValue);
    neededPart = buff_J["classes"]
    [editNotesMap["classNum"].asString()]
    [editNotesMap["classLetter"].asString()]
    ["absent"];
    for (const auto& [first, second] : editNotesMap) {
            if (!second.empty() && first.substr(0, first.find('_')) == "absent") {
                try {
                    neededPart[first.substr(first.find('_') + 1, first.back() - 1)] = second;
                }
                catch (Json::Exception &e) {
                    try {
                        std::cout << "--- Err: " << e.what() << '\n';
                        neededPart[first.substr(first.find('_') + 1, first.back() - 1)] = second;
                    }
                    catch (Json::Exception &e) {
                        std::cout << "no way to ignore err - " << e.what();
                    }
                }
            }
    }

    buff_J["classes"]
    [editNotesMap["classNum"].asString()]
    [editNotesMap["classLetter"].asString()]
    ["absent"] = neededPart;
    fstream.open("data/" + editNotesMap["schoolId"].asString() + '/' + genToken(editNotesMap["schoolId"].asString()) + ".json", std::ios::out | std::ios::binary);
    fstream << buff_J;
    fstream.close();

    return crow::response(200, "ladna");
}


crow::response editClassesData(std::string reqEdit) {
    std::map<std::string, Json::Value> absentMap = genMapOfEditNotes(reqEdit);

    //error handler
    if (!absentMap["err"].empty()) {
        std::cout << "--- Error:"<< absentMap["err"] << '\n';
        return crow::response(500, "error: " + absentMap["err"].asString());
    }
    //non error
   return writeEditNotesOnCurrDate(absentMap);

}


crow::response getStaticFileJson(const std::string& schoolId) {
    crow::response res;
    std::string currDate = genToken(schoolId);
    auto reqPath = std::string("data/" + schoolId + "/" + genToken(schoolId) + ".json");
    res.set_static_file_info(reqPath);
    if (!res.is_static_type()) { //if file doesn't exist
        Json::FastWriter writer;
        std::string resJ = writer.write(genTempClassesAsJson(reqPath));

        res.body = resJ;
        return res;
    }
    else if (res.is_static_type()) { //if exist
        return res;
    }
    else {
        return crow::response(500, "file exists bun invalid");
    }
}
