

// Plugin file (for example, api.js)
import axios from "axios";
import router from "@/router";

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
                                alert('Ключ доступа истёк, пожалуйста, войдите снова');
                                await router.push('/login');
                            }
                        } catch (refreshError) {
                            await router.push('/login'); // Redirect if unable to refresh
                        }
                    } else {
                        console.log('API Error:', error);
                        throw error; // Rethrow error to let the caller handle it
                    }
                }
            };

            Vue.prototype.$refreshAccessToken = async () => {
                try {
                    const res = await axios.post('/api/refresh-token');
                    return res.status === 200; // Return true if the request was successful
                } catch (error) { // Handle API errors
                    console.error('Error refreshing access token:', error?.response?.data || error); // Improved logging with optional chaining
                    throw error; // Rethrow the error to be handled by the caller
                }
            };
            Vue.prototype.$checkAccessRole = async function(requiredRole) {
                const roles = await this.$makeApiRequest("/api/roles");
                if (!roles.roles.includes(requiredRole)) {
                    // Redirect or show an alert if the user does not have access
                    alert('У вас нет разрешения для доступа к данному интерфейсу');
                    await router.push('/'); // Redirect to an unauthorized page
                }
                return true;
            }
            isAPIInitialized = true;
        }
    }
};