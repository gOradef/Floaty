

// Plugin file (for example, api.js)
import axios from "axios";
// import router from "@/router";

let isAPIInitialized = false;
function isAPIResponding(response) {
    if (response.status === 502) {
        alert('API-сервер не отвечает. Пожалуйста, попробуйте позже. Приносим извинения за доставленные неудобства');
    }
}
export default {
    install(Vue) {
        if (!isAPIInitialized) {
            Vue.prototype.$makeApiRequest = async function(url, method = 'GET', data = null) {
                try {
                    let response;

                    // Determine which method to call and make the request
                    switch (method.toUpperCase()) {
                        case 'POST':
                            response = await axios.post(url, data); // For POST requests
                            isAPIResponding(response);
                            return response.status; // Return only status for POST
                        case 'PATCH':
                            response = await axios.patch(url, data); // For POST requests
                            isAPIResponding(response);
                            return response.status; // Return only status for POST
                        case 'PUT':
                            response = await axios.put(url, data); // For PUT requests
                            isAPIResponding(response);
                            return response.status; // Return only status for PUT

                        case 'DELETE':
                            response = await axios.delete(url); // For DELETE requests
                            isAPIResponding(response);
                            return response.status; // Return only status for DELETE

                        case 'GET': // Fallthrough for GET requests
                        default:
                            response = await axios.get(url); // For GET requests
                            isAPIResponding(response);
                            return response.data; // Return data for GET
                    }

                } catch (error) {
                    if (error.response.status === 409)
                        return 409;
                    if (error.response && error.response.status === 401) {
                        // Handle token expiration
                        try {
                            if (await this.$refreshAccessToken()) {
                                // Retry the request after refreshing the token
                                return this.$makeApiRequest(url, method, data);
                            } else {
                                console.warn('Ключ доступа истёк, пожалуйста, войдите снова');
                                // await router.push('/login');
                            }
                        } catch (refreshError) {
                            console.warn('Unexpected error from api server:', refreshError)
                            // await router.push('/login'); // Redirect if unable to refresh
                        }
                    } else {
                        throw error; // Rethrow error to let the caller handle it
                    }
                }
            };


            Vue.prototype.$refreshAccessToken = async () => { // returns true or false
                try {
                    const res = await axios.post('/api/refresh-token');
                    return res.status === 200; // Return true if the request was successful
                } catch (error) { // Handle API errors
                    console.warn('Error refreshing access token:', error?.response?.data || error); // Improved logging with optional chaining
                }
                return false;
            };
            Vue.prototype.$checkAccessRole = async function(requiredRole) {
                try {
                    const roles = await this.$makeApiRequest("/api/roles");
                    if (!roles.roles.includes(requiredRole)) {
                        return {
                            status: false,
                            reason: 'Вы не владеете необходимой ролью. ' +
                                'Для получения доступа к данному интерфейсу - обратитесь к администратору организации'
                        };
                    }
                }
                catch (err) {
                    return {
                        status: false,
                        reason: 'Ваш ключ доступа истёк. Пожалуйста, войдите в систему заново'
                    };
                    // await router.push('/login'); // Redirect to an unauthorized page
                }

                return {
                    status: true
                };
            }
            isAPIInitialized = true;

            Vue.prototype.$callNotificationEvent = function (isAllGood = false, customMsg = "Что-то пошло не так :(  Чтобы решить проблему как можно быстрее, пожалуйста, свяжитесь с нами:  ") {
                isAllGood ?
                    this.$root.$emit('notification', 'success')
            :
                this.$root.$emit('notification', 'error', customMsg);
            }
        }
    }
};