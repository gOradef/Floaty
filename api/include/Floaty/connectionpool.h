//
// Created by goradef on 15.06.2024.
//

#ifndef FLOATYROOTSERVICE_CONNECTIONPOOL_H
#define FLOATYROOTSERVICE_CONNECTIONPOOL_H

#include "pqxx/pqxx"
#include "mutex"
#include <condition_variable>

namespace psqlMethods {
    using str = std::string;

    inline str isDate = "is_date"; //todo move into some other space

    namespace org {
      inline str getData = "school_org_data_get"; //org data
    };

    namespace encoding {
        inline str encode = "encode";
        inline str decode = "decode";
    };
    namespace invites {
        inline str getAll = "invites_get";
        inline str isValid = "is_invite_valid";
        inline str isExists = "is_invite_exists";
        inline str create = "invite_create";
        inline str getProperties = "invite_props_get";
        inline str drop = "drop_invite"; // drops row with invite school_id and invite_id
        inline str archive = "archive_invite";
    }
    namespace userChecks {
        inline str isLoginOccupied = "is_login_occupied";
        inline str isExists = "is_user_exists";
        inline str isValid = "is_valid_user";
        inline str hasRole = "is_user_has_role";
        inline str isHasClasses = "is_user_has_classes";
    };
    namespace userData {
        inline str getName = "user_name_get";
        inline str getRoles = "user_roles_get";
        inline str getClasses = "user_classes_get";
        inline str getClassProps = "class_props_get";
        inline str getClassStudents = "class_students_get";
        inline str getSchoolId = "school_id_get";
    };

    namespace classes {
            namespace checks {
                inline str isOwned = "is_class_owned";
                inline str isExists = "is_class_exists";
            }

            namespace data {
            inline str getInsertedData = "class_data_get";
            inline str insertData = "class_data_insert";
            inline str insertDataForDate = "class_data_insert_for_date";
        }
    }

    namespace schoolManager {
        namespace classes {
            inline str getAll = "school_classes_get"; //school_id
            inline str getStudents = "school_class_students_get"; //school_id, class_id

            inline str create = "class_create"; //school_id, user_id (can be null), class_name
            inline str updateStudentList = "class_students_update";
            inline str rename = "class_rename"; //school_id, class_id, new_class_name
            inline str drop = "class_drop"; //school_id, class_id
        }
        namespace users {
            inline str getAll= "school_users_get";

            inline str create = "user_create"; //school_id, login, password, name
            inline str createWithContext = "user_create_with_context"; //school_id, login, password, name, roles, classes
            inline str drop = "school_user_drop"; //school_id, user_id
            inline str resetPassword = "school_user_password_reset"; //school_id, user_id, newPassword

            inline str setName = "school_user_name_set";
            inline str setRoles = "school_user_roles_set";
            inline str setClasses = "school_user_classes_set";
        }
        namespace data
        {
            inline str isExists = "is_school_data_exists";
            inline str genNewForToday = "school_data_gen";
            inline str getForToday = "school_data_get_today";
            inline str getForDate = "school_data_get_for_date";
            inline str getSummarized = "school_data_summarized_get";
        }

    }

}

class ConnectionPool {
public:
    ConnectionPool(const std::string& connection_string, int pool_size);
    pqxx::connection* getConnection();
    void releaseConnection(pqxx::connection* conn);
    // ~ConnectionPool();

private:
    std::vector<std::unique_ptr<pqxx::connection>> connections; // Use smart pointers
    std::mutex mtx;
    std::condition_variable cv;
};

#endif //FLOATYROOTSERVICE_CONNECTIONPOOL_H
