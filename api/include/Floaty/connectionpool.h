//
// Created by goradef on 15.06.2024.
//

#ifndef FLOATYROOTSERVICE_CONNECTIONPOOL_H
#define FLOATYROOTSERVICE_CONNECTIONPOOL_H

#include "pqxx/pqxx"
#include "mutex"
#include <condition_variable>

namespace psqlMethods {
    using prepped = pqxx::prepped;


    inline prepped isDate{"is_date"}; //todo move into some other space

    namespace org {
      inline prepped getData{"school_org_data_get"}; //org data
    };

    namespace encoding {
        inline prepped encode{"encode"};
        inline prepped decode{"decode"};
    };
    namespace invites {
        inline prepped getAll{"invites_get"};
        inline prepped isValid{"is_invite_valid"};
        inline prepped isExists{"is_invite_exists"};
        inline prepped create{"invite_create"};
        inline prepped getProperties{"invite_props_get"};
        inline prepped drop{"drop_invite"}; // drops row with invite school_id and invite_id
        inline prepped archive{"archive_invite"};
    }
    namespace userChecks {
        inline prepped isLoginOccupied{"is_login_occupied"};
        inline prepped isExists{"is_user_exists"};
        inline prepped isValid{"is_valid_user"};
        inline prepped hasRole{"is_user_has_role"};
        inline prepped isHasClasses{"is_user_has_classes"};
    };
    namespace userData {
        inline prepped getName{"user_name_get"};
        inline prepped getRoles{"user_roles_get"};
        inline prepped getClasses{"user_classes_get"};
        inline prepped getClassProps{"class_props_get"};
        inline prepped getClassStudents{"class_students_get"};
        inline prepped getSchoolId{"school_id_get"};
    };

    namespace classes {
            namespace checks {
                inline prepped isOwned{"is_class_owned"};
                inline prepped isExists{"is_class_exists"};
            }

            namespace data {
            inline prepped getInsertedData{"class_data_get"};
            inline prepped insertData{"class_data_insert"};
            inline prepped insertDataForDate{"class_data_insert_for_date"};
        }
    }

    namespace schoolManager {
        namespace classes {
            inline prepped getAll{"school_classes_get"}; //school_id
            inline prepped getStudents{"school_class_students_get"}; //school_id, class_id

            inline prepped create{"class_create"}; //school_id, user_id (can be null), class_name
            inline prepped rename{"class_rename"}; //school_id, class_id, new_class_name
            inline prepped setOwners{"class_owners_set"};
            inline prepped updateStudentList{"class_students_update"};
            inline prepped drop{"class_drop"}; //school_id, class_id
        }
        namespace users {
            inline prepped getAll{"school_users_get"};

            inline prepped create{"user_create"}; //school_id, login, password, name
            inline prepped createWithContext{"user_create_with_context"}; //school_id, login, password, name, roles, classes
            inline prepped drop{"school_user_drop"}; //school_id, user_id
            inline prepped resetPassword{"school_user_password_reset"}; //school_id, user_id, newPassword

            inline prepped setName{"school_user_name_set"};
            inline prepped setRoles{"school_user_roles_set"};
            inline prepped setClasses{"school_user_classes_set"};
        }
        namespace data
        {
            inline prepped isExists{"is_school_data_exists"};
            inline prepped genNewForToday{"school_data_gen"};
            inline prepped getForToday{"school_data_get_today"};
            inline prepped getForDate{"school_data_get_for_date"};
            inline prepped getSummarized{"school_data_summarized_get"};
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
