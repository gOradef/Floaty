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

std::map<std::string, std::string> genMapOfEditNotes(std::string &reqEdit) {
    Json::Value reqEditNotesRoot;
    Json::Reader reader;
    try {
        reader.parse(reqEdit, reqEditNotesRoot);
        std::string schoolId = reqEditNotesRoot["schoolId"].asString();
        std::string className = reqEditNotesRoot["className"].asString();
        std::string absentNum = reqEditNotesRoot["absentNum"].asString();
        std::string absentVir = reqEditNotesRoot["absentVir"].asString();
        std::string absentRespCause = reqEditNotesRoot["absentRespCause"].asString();
        std::string absentNonRespCause= reqEditNotesRoot["absentNonRespCause"].asString();
        std::string absentFreeMeal = reqEditNotesRoot["absentFreeMeal"].asString();

        //schoolId, className, absentNum, absentVir, absentRespCause, absentNonRespCause, absentFreeMeal
        std::map<std::string, std::string> absentMap;
        absentMap["schoolId"] = schoolId;
        absentMap["classNum"] = className.substr(0, className.find('_'));
        absentMap["classLetter"] = className.substr(className.find('_')+1, className.back()-1);
        absentMap["absent_amount"] = absentNum;
        absentMap["absent_listVirusCause"] = absentVir;
        absentMap["absent_listRespCause"] = absentRespCause;
        absentMap["absent_listNonRespCause"] = absentNonRespCause;
        absentMap["absent_listFreeMeal"] = absentFreeMeal;

        return absentMap;
    }
    catch (Json::Exception &e) {
        std::map<std::string, std::string> map;
        map["err"] = e.what();
        return map;
    }
}
    /*
     * 1. Открыть поток на чтение
     * 2. Записать данные в буфер
     * 3. Закрыть поток на чтение
     * 4. Сделать изменения в буфере
     * 5. Открыть поток на запись
     * 6. Записать данные из буфера в текущую дату
    */
crow::response writeEditNotesOnCurrDate(std::map<std::string, std::string> &editNotesMap) {
    std::fstream fstream;
    Json::Value buff_J;
    Json::Reader Jreader;
    std::ostringstream buff_str;

    fstream.open("data/" + editNotesMap["schoolId"] + '/' + genToken(editNotesMap["schoolId"]) + ".json", std::ios::in);
    buff_str << fstream.rdbuf();
    fstream.close();
    Jreader.parse(buff_str.str(), buff_J);
    // * here trys to edit data
    Json::Value neededPart = Json::Value(Json::objectValue);
    neededPart = buff_J["classes"]
            [editNotesMap["classNum"]]
            [editNotesMap["classLetter"]]
            ["absent"];
    for (auto el : editNotesMap) {
        if(el.first.substr(0, el.first.find('_')) == "absent") {
            if (!el.second.empty()){
                try {
                    neededPart[el.first.substr(el.first.find('_') + 1, el.first.back() - 1)].append(
                            el.second);
                }
                catch (Json::Exception &e) {
                    try{
                        neededPart[el.first.substr(el.first.find('_') + 1, el.first.back() - 1)] = el.second;
                    }
                    catch (Json::Exception &e) {
                        std::cout << "no way to ignore err - " << e.what();
                    }
                }
            }
        }
    }

        buff_J["classes"][editNotesMap["classNum"]][editNotesMap["classLetter"]]["absent"] = neededPart;
        fstream.open("data/" + editNotesMap["schoolId"] + '/' + genToken(editNotesMap["schoolId"]) + ".json", std::ios::out | std::ios::binary);
        fstream << buff_J;
        fstream.close();

        return crow::response(200, "ladna");
}


crow::response editClassesData(std::string reqEdit) {
    std::map<std::string, std::string> absentMap = genMapOfEditNotes(reqEdit);

    //error handler
    if (!absentMap["err"].empty()) {
        std::cout << "--- Error:"<< absentMap["err"] << '\n';
        return crow::response(500, "error: " + absentMap["err"]);
    }
    //non error
   return writeEditNotesOnCurrDate(absentMap);

}


crow::response getStaticFileJson(std::string schoolId) {
    crow::response res;
    std::string currDate = genToken(schoolId);
    std::string reqPath = std::string("data/" + schoolId + "/" + genToken(schoolId) + ".json");
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
