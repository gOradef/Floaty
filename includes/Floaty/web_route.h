#include "crow.h"


crow::response genWebPages(std::string jsonLikeResponse);
crow::response sendWebResoursesByRequest(std::string type, std::string file);
crow::response handleErrPage(int ec = 0, std::string comm = "");
