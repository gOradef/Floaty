import Vue from 'vue'
import VueRouter from 'vue-router'

// Import components
import HelloWorld from '@/components/HelloWorld.vue'
import NotFound from "@/views/NotFound.vue";
import AdminView from "@/views/AdminView.vue";

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
        path: '/about',
        name: 'about',
        component: AboutView
    },
    {
        path: '/org',
        name: 'Управление учреждением',
        component: AdminView,
    },
    {
      path: '/org/:section',
      name: 'Управление учреждением',
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

export default router