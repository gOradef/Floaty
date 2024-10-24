import Vue from 'vue'
import VueRouter from 'vue-router'

// Import components
import HelloWorld from '@/components/HelloWorld.vue'

import loginPage from '@/views/LoginView.vue'
import signupInvite from "@/views/SignupInvite.vue";

import userForm from '@/components/user/form.vue'
import AdminView from "@/views/Roles/AdminView.vue";

import NotFound from "@/views/NotFound.vue";
import axios from "axios";
// import choseClass from "@/components/user/choseClass.vue";
import InterfaceLocker from "@/views/locker.vue";
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
        path: '/home',
        name: 'home2',
        component: HelloWorld,
    },
    {
      path: '/login',
      name: 'login',
      component: loginPage
    },
    {
        path: '/signup/invite',
        name: 'signupInvite',
        component: signupInvite,
        props: () => ({ orgID: '' })
    },
    {
        path: '/signup/invite/:orgID',
        name: 'signupInviteWithOrgId',
        component: signupInvite,
        props: (route) => ({ orgID: route.params.orgID })
    },
    {
        path: '/about',
        name: 'О нас',
        component: AboutView
    },
    {
        path: '/user',
        name: 'Кл. рук.',
        component: InterfaceLocker,
        props: () => ({compType: 'choseClass'})
    },
    {
        path: '/form/:classID',
        name: 'Заполнение данных кл. рук.',
        component: InterfaceLocker,
        props: () => ({compType: 'userForm'})
    },
    {
        path: '/org',
        name: 'Управление учреждением',
        component: InterfaceLocker,
        props: () => ({compType: 'AdminView'})
    },
    {
        path: '/org/:section',
        name: 'Управление учреждением с разделом',
        component: InterfaceLocker,
        props: () => ({compType: 'AdminView'})
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