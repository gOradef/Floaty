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
        std::string globalNum = reqEditNotesRoot["globalNum"].asString();
        std::string absentNum = reqEditNotesRoot["absentNum"].asString();
        Json::Value listAbsent = Json::Value(Json::arrayValue);
        // * schoolId, className, absentNum, absentVir, absentRespCause, absentNonRespCause, absentFreeMeal
        std::map<std::string, Json::Value> absentMap;
        absentMap["schoolId"] = schoolId;
        absentMap["classNum"] = className.substr(0, className.find('_'));
        absentMap["classLetter"] = className.substr(className.find('_')+1, className.back()-1);
        absentMap["globalNum"] = globalNum;
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
    std::string currDatePath = "data/" + editNotesMap["schoolId"].asString() + '/' + genToken(editNotesMap["schoolId"].asString()) + ".json";
    fstream.open(currDatePath, std::ios::in);
    buff_str << fstream.rdbuf();
    fstream.close();
    Jreader.parse(buff_str.str(), buff_J);
    // * here trys to edit data
    Json::Value neededAbsentPart = Json::Value(Json::objectValue);

    Json::Value globalNum;

    if (editNotesMap["globalNum"].asString() == "" || editNotesMap["globalNum"].asString() == "!" || editNotesMap["globalNum"].asString() == "-")
    {
        Json::Value rootPrevDay = Json::Value(Json::objectValue);
        std::stringstream buff_str_T;
        fstream.open("data/" + editNotesMap["schoolId"].asString() + '/' + genToken(editNotesMap["schoolId"].asString(), 1) + ".json", std::ios::in);
        buff_str_T << fstream.rdbuf();
        fstream.close();

        Jreader.parse(buff_str_T.str(), rootPrevDay);
        globalNum = rootPrevDay["classes"]
                [editNotesMap["classNum"].asString()]
                [editNotesMap["classLetter"].asString()]
                ["amount"];

        buff_J["classes"]
        [editNotesMap["classNum"].asString()]
        [editNotesMap["classLetter"].asString()]
        ["amount"] =  globalNum.asString();
    }
    else {
        buff_J["classes"]
        [editNotesMap["classNum"].asString()]
        [editNotesMap["classLetter"].asString()]
        ["amount"] = editNotesMap["globalNum"].asString();
    }

    neededAbsentPart = buff_J["classes"]
    [editNotesMap["classNum"].asString()]
    [editNotesMap["classLetter"].asString()]
    ["absent"];


    for (const auto& [first, second] : editNotesMap) {
            if (!second.empty() && first.substr(0, first.find('_')) == "absent") {
                try {
                    neededAbsentPart[first.substr(first.find('_') + 1, first.back() - 1)] = second;
                }
                catch (Json::Exception &e) {
                    try {
                        std::cout << "--- Err: " << e.what() << '\n';
                        neededAbsentPart[first.substr(first.find('_') + 1, first.back() - 1)] = second;
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
    ["absent"] = neededAbsentPart;
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

crow::response getStaticFileJson(const crow::request &reqRoot) {
    // * Parse req into vars
    Json::Reader reader;
    Json::Value reqJ;
    reader.parse(reqRoot.body, reqJ);

    std::string schoolId = reqJ["schoolId"].asString();
    std::string periodReq = reqJ["period"].asString();
    std::string reqPath;
    crow::response res;
    std::string currDate = genToken(schoolId);
    reqPath = std::string("data/" + schoolId + "/" + genToken(schoolId) + ".json");
    res.set_static_file_info(reqPath);
    if (!res.is_static_type()) { //if file doesn't exist
        Json::FastWriter writer;
        std::string resJ = writer.write(genTempClassesAsJson(reqPath));

        res.body = resJ;
        return res;
    }
    else { //if exist
        return res;
    }
}
