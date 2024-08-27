import Vue from 'vue'
import VueRouter from 'vue-router'

// Import components
import HelloWorld from '@/components/HelloWorld.vue'

import loginPage from '@/views/LoginView.vue'

import UserView from "@/views/Roles/UserView.vue";
import AdminView from "@/views/Roles/AdminView.vue";

import NotFound from "@/views/NotFound.vue";
import axios from "axios";
// Lazy-loaded components
const AboutView = () => import(/* webpackChunkName: "about" */ '../views/AboutView.vue')


Vue.use(VueRouter)

const routes = [
    {
        path: '/',
        name: 'home',
        component: HelloWorld
    },
    {
      path: '/login',
      name: 'login',
      component: loginPage
    },
    {
        path: '/about',
        name: 'О нас',
        component: AboutView
    },
    {
        path: '/user',
        name: 'Кл. рук.',
        component: UserView
    },
    {
        path: '/org',
        name: 'Управление учреждением',
        component: AdminView
    },
    {
      path: '/org/:section',
      name: 'Управление учреждением с разделом',
      component: AdminView
    },
    //! Should be latest
    {
        path: '/:pathMatch(.*)*',
        name: 'NotFound',
        component: NotFound
    }
]

const router = new VueRouter({
    mode: 'history',
    base: process.env.BASE_URL,
    routes
})

axios.defaults.headers.common['accept'] = 'application/json';
axios.defaults.responseType = "json";

export default router;