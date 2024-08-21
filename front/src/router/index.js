import Vue from 'vue'
import VueRouter from 'vue-router'

// Import components
import HelloWorld from '@/components/HelloWorld.vue'

// Lazy-loaded components
const AboutView = () => import(/* webpackChunkName: "about" */ '../views/AboutView.vue')

Vue.use(VueRouter)

const routes = [
    {
        path: '/',
        name: 'home',
        component: HelloWorld,
        msg: "Darova"
    },
    {
        path: '/about',
        name: 'about',
        component: AboutView
    }
]

const router = new VueRouter({
    mode: 'history',
    base: process.env.BASE_URL,
    routes
})

export default router