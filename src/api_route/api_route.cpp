#include "Floaty/api_route.h"
#include "vector"


//If  { schoolId exist -> try read template
//else { gen template
// { genForCurrDate
Json::Value genTempClassesAsJson(const std::string &reqPath, const std::string& schoolId){
    std::fstream fstream;
    std::stringstream stringstream;
    Json::Value root;

    try {
        fstream.open(std::string("data/" + schoolId + "/schoolTemplateDate.json"), std::ios::in);
        stringstream << fstream.rdbuf();
        fstream.close();

        if (!stringstream.str().empty()) {
            fstream.open(reqPath, std::ios::out);
            fstream << stringstream.str();
            fstream.close();

            Json::Reader reader;
            reader.parse(stringstream.str(), root);
            root = root["classes"];
            return root;

        }
        else {
            std::cout << "--- ERR: no readable template \n";
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
            root["classes"] = root2;
            fstream.open(std::string("data/"+ schoolId + "/schoolTemplateDate.json"), std::ios::out);
            Json::StyledWriter writer;
            fstream << writer.write(root);
            fstream.close();
            return root;
        }

    }
    catch (std::exception &e) {
        std::cout << "---ERR: " << e.what() << '\n';
    }


}

std::map<std::string, Json::Value> handlerGenMapOfEditNotes(const std::string &reqEdit) {
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
            absentMap["classLetter"] = className.substr(className.find('_') + 1, className.back() - 1);
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
            map["err"] = Json::Value{ e.what() };
            return map;
        }
}

crow::response writeEditNotesForm(std::map<std::string, Json::Value> &editNotesMap) {
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

    if (editNotesMap["globalNum"].asString() == "" || editNotesMap["globalNum"].asString() == "!" || editNotesMap["globalNum"].asString() == "-" || editNotesMap["globalNum"].asString() == " ")
    {
        Json::Value rootTemplateDay = Json::Value(Json::objectValue);
        std::stringstream buff_str_T;
        fstream.open("data/" + editNotesMap["schoolId"].asString() + '/' + "schoolTemplateDate.json", std::ios::in);
        buff_str_T << fstream.rdbuf();
        fstream.close();

        Jreader.parse(buff_str_T.str(), rootTemplateDay);
        globalNum = rootTemplateDay["classes"]
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
//todo for table
crow::response writeEditNotesInterface(std::map<std::string, Json::Value> &editNotesMap) {

};

crow::response writeForEditNotesForm(std::string reqEdit) {
    std::map<std::string, Json::Value> absentMap = handlerGenMapOfEditNotes(reqEdit);

    //error handler
    if (!absentMap["err"].empty()) {
        std::cout << "--- Error:"<< absentMap["err"] << '\n';
        return crow::response(500, "error: " + absentMap["err"].asString());
    }
    //non error
   return writeEditNotesForm(absentMap);

}

crow::response getStaticFileJson(const crow::request &reqRoot, bool isShort) {
    Json::Reader reader;
    Json::Value reqJ;
    reader.parse(reqRoot.body, reqJ);
    std::string schoolId = reqJ["schoolId"].asString();
    if (isShort) {
        return handleCommonReq(schoolId);
    }
    else {
        std::string periodReq = reqJ["period"].asString();
        std::string methodReq = reqJ["method"].asString();

        if (methodReq == "getCommonCase") {
            return handleCommonReq(schoolId, false);
        }

        else if (methodReq == "getCustomCase") {
            std::string dateReq = reqJ["date"].asString();

            if (periodReq == "today") {
                return handleUserReq(schoolId, dateReq);
            }
            else if (periodReq != "") {
                return handleUserReq(schoolId, dateReq, periodReq);
            }
            else {
                return crow::response(500, "out from if chain");
            }
        }
        else if (methodReq == "getTemplateCase") {
            //gets template as json and send to user res/s
            std::fstream fstream;
            std::stringstream buff_str;
            crow::response res;
            const std::string userKey = reqJ["key"].asString();
            std::string corrKey;
            try {
                fstream.open("data/" + schoolId + "/schoolData.json", std::ios::in);
                buff_str << fstream.rdbuf();
                fstream.close();
                if (!buff_str.str().empty()) {
                    Json::Value rootSchoolData;
                    reader.parse(buff_str.str(), rootSchoolData);
                    corrKey = rootSchoolData["superAdminKey"].asString();
                    if (corrKey == userKey) {
                        res.set_static_file_info(std::string("data/" + schoolId + "/schoolTemplateDate.json"));
                        return res;
                    }
                    else {
                        //! wrong adminKeyInReq
                        return crow::response(500, "Wrong key");
                    }
                }
                else {
                    std::cout << "---Err: " <<  "unable reading school date file" << '\n';
                    return crow::response(500, "Req has inturrept schoolId?");
                }
            }
            catch (std::exception &e) {
                std::cout << "---Err: " << e.what() << '\n';
                return crow::response(500, "Req without adminKey?");
            }
        }
        else {
            return crow::response(500, "Unknown method");
        }
    }

}

crow::response handleCommonReq(const std::string &schoolId, bool isShort) {
    crow::response res;
    std::string reqPath;
    std::string currDate = genToken(schoolId);
    reqPath = std::string("data/" + schoolId + "/" + currDate + ".json");
    if (isShort) { //short data (names only)
        Json::Reader jReader;
        Json::Value classNames = Json::Value(Json::arrayValue);
        Json::Value root;
        std::ostringstream ostringstream;
        std::ifstream ifstream;

        try {
            ifstream.open(reqPath);
            ostringstream << ifstream.rdbuf();
            ifstream.close();
            if (ostringstream.str() == "") {
                genTempClassesAsJson(reqPath, schoolId);
            }
            jReader.parse(ostringstream.str(), root);
            root = root["classes"];
            for (auto num : root) {
                for (auto letter : num) {
//                    std::cout << root[std::to_string(num)][].get("name");
                    classNames.append(letter["name"].asString());
                }
            }
            Json::FastWriter jWriter;
            res.body = jWriter.write(classNames);
            return res;
        }
        catch (std::exception &e) {
            std::cout << "--- Err: " << e.what();
        }


    }
    else { //full data
        res.set_static_file_info(reqPath);
        if (!res.is_static_type()) { //if file doesn't exist
            Json::FastWriter writer;
            std::string resJ = writer.write(genTempClassesAsJson(reqPath, schoolId));

            res.body = resJ;
            return res;
        }
        else { //if exist
            res.add_header("date", currDate);
            return res;
        }
    }
    return crow::response(120);
}

crow::response handleUserReq(const std::string& schoolId, const std::string& userDate, const std::string& period) {
    crow::response result;
    //Normal case
    if (period == "usercase") {
        std::string reqPath;
        reqPath = std::string("data/" + schoolId + "/" + userDate + '.' + schoolId + ".json");
        result.set_static_file_info(reqPath);
        if (!result.is_static_type()) { //if file doesn't exist
            Json::FastWriter writer;
            result.body = std::string(writer.write(genTempClassesAsJson(reqPath, schoolId)));

            result.add_header("date", "Файл создан только что");
            return result;
        }
        else { //if exist

            result.add_header("date", userDate);
            return result;
        }
    }
    return result;
}