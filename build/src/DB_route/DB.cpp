#include <mysqlx/xdevapi.h>
#include <iostream>

using ::std::cout;
using ::std::endl;
using namespace ::mysqlx;

int main(int argc, const char *argv[]) {
try
    {

    const char *url = (argc > 1 ? argv[1] : "mysqlx://gOradef@127.0.0.1");

    cout << "Creating session on " << url
         << " ..." << endl;

    Session sess(url);
    }
    catch (std::errc &err) {
        std::cout << "ERR";
    }
}