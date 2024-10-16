import '@babel/polyfill'
import 'mutationobserver-shim'

import Vue from 'vue'
import './plugins/bootstrap-vue'
//Import api
import api from '@/plugins/api';

import { BootstrapVue, IconsPlugin } from 'bootstrap-vue'

// Import Bootstrap and BootstrapVue CSS files (order is important)
import 'bootstrap/dist/css/bootstrap.css'
import 'bootstrap-vue/dist/bootstrap-vue.css'

// Import your main component and router
import App from './App.vue'
import router from './router'  // Ensure you're importing the router

// Make BootstrapVue available throughout your project
Vue.use(BootstrapVue)
// Optionally install the BootstrapVue icon components plugin
Vue.use(IconsPlugin)
// Set api plugin
Vue.use(api)

Vue.config.productionTip = false

new Vue({
    router,  // Make sure to include the router here
    render: h => h(App)
}).$mount('#app')
