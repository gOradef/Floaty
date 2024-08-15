//
// Created by goradef on 15.06.2024.
//

#ifndef FLOATYROOTSERVICE_CONNECTIONPOOL_H
#define FLOATYROOTSERVICE_CONNECTIONPOOL_H

#include "pqxx/pqxx"
#include "mutex"

namespace psqlMethods {
    using str = std::string;

    inline str isDate = "is_date"; //todo move into some other space
    namespace encodingMethods {
        inline str encode = "encode";
        inline str decode = "decode";
    };
    namespace invites {
        inline str getAllInvites = "invites_get";
        inline str isInviteValid = "is_invite_valid";
        inline str createInvite = "invite_create";
        inline str getProperties = "invite_props_get";
        inline str dropInvite = "drop_invite"; // drops row with invite
    }
    namespace userCheckMethods {
        inline str isLoginOccupied = "is_login_occupied";
        inline str isUserExists = "is_user_exists";
        inline str isUserValid = "is_valid_user";
        inline str isUserHasRole = "is_user_has_role";
    };
    namespace userDataGetters {
        inline str getUserName = "user_name_get";
        inline str getUserRoles = "user_roles_get";
        inline str getUserClasses = "user_classes_get";
        inline str getClassStudents = "class_students_get";
        inline str getSchoolId = "school_id_get";
    };

    namespace classHandler {

        namespace checks {
            inline str isClassOwned = "is_class_owned";
            inline str isClassExists = "is_class_exists";
        }

        ///@param school, user, class, [vector of users]
        namespace students {
            inline str addStudents = "class_students_add";
            inline str removeStudents = "class_students_remove";

            inline str addFStudents = "class_fstudents_add";
            inline str removeFStudents = "class_fstudents_remove";
        }
            namespace data {
            inline str getInsertedData = "class_data_insert";
            inline str insertData = "class_data_get";
        }
    }

    namespace schoolManager {
        namespace classes {
            inline str getAllClasses = "school_classes_get"; //school_id
            inline str getClassStudents = "school_class_students_get"; //school_id, class_id

            inline str createClass = "class_create"; //school_id, user_id (can be null), class_name
            inline str renameClass = "class_rename"; //school_id, class_id, new_class_name
            inline str dropClass = "class_drop"; //school_id, class_id
        }
        namespace users {
            inline str getAllUsers= "school_users_get";

            inline str createUser = "user_create"; //school_id, login, password, name
            inline str createUserWithContext = "user_create_with_context"; //school_id, login, password, name, roles, classes
            inline str dropUser = "school_user_drop"; //school_id, user_id


            inline str grantRolesToUser = "school_user_roles_grant";
            inline str degrantRolesToUser = "school_user_roles_degrant";

            inline str grantClassesToUser = "school_user_class_grant";
            inline str degrantClassesToUser = "school_user_class_degrant";
        }
        namespace data
        {
            inline str isSchoolDataExists = "is_school_data_exists";
            inline str getSchoolData = "school_data_get";
            inline str getSchoolSummarizedData = "school_data_summarized_get";
        }

    }

}

class ConnectionPool {
private:
    std::vector<pqxx::connection*> connections;
    std::mutex mtx;

public:
    ConnectionPool(const std::string& connection_string, int pool_size);
    pqxx::connection* getConnection();
    void releaseConnection(pqxx::connection* conn);
    ~ConnectionPool();
};

#endif //FLOATYROOTSERVICE_CONNECTIONPOOL_H
