

// Plugin file (for example, api.js)
import axios from "axios";
import router from "@/router";

export default {
    install(Vue) {
        Vue.prototype.$makeApiRequest = async function(url, method = 'GET', data = null) {
            try {
                let response;

                // Determine which method to call and make the request
                switch (method.toUpperCase()) {
                    case 'POST':
                        response = await axios.post(url, data); // For POST requests
                        break;
                    case 'PUT':
                        response = await axios.put(url, data); // For PUT requests
                        break;
                    case 'DELETE':
                        response = await axios.delete(url); // For DELETE requests
                        break;
                    case 'GET': // Fallthrough for GET requests
                    default:
                        response = await axios.get(url); // For GET requests
                        break;
                }

                return response.data;
            } catch (error) {
                if (error.response && error.response.status === 401) {
                    // Handle token expiration
                    try {
                        await this.$refreshAccessToken();
                        // Retry the request after refreshing the token
                        return this.$makeApiRequest(url, method, data);
                    } catch (refreshError) {
                        await router.push('/login'); // Redirect if unable to refresh
                    }
                }
                else {
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
    }
};