import { createRouter, createWebHistory, RouterView } from 'vue-router'
import HomeView from '../views/HomeView.vue'
import LoginView from '@/views/Auth/LoginView.vue'
import { useAuthStore } from '@/stores/auth'
import RegisterView from '@/views/Auth/RegisterView.vue'
import CompamyView from '@/views/Company/CompamyView.vue'
import PortfolioView from '@/views/Portfolio/PortfolioView.vue'
import OrderView from '@/views/Order/OrderView.vue'
import UsersList from '@/components/Admin/UsersList.vue'
import SectorsLists from '@/components/Admin/SectorsLists.vue'
import DataTools from '@/components/Admin/DataTools.vue'
import LogsViewer from '@/components/Admin/LogsViewer.vue'
import CompaniesList from '@/components/Admin/CompaniesList.vue'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    { path: '/', name: 'home', component: HomeView },
    { path: '/login', name: 'login', component: LoginView },
    { path: '/register', name: 'register', component: RegisterView },
    { path: '/company/:id', name: 'company', component: CompamyView },
    { path: '/portfolio', name: 'portfolio', component: PortfolioView , meta:{ requiresAuth:true}},
    { path: '/orders', name: 'orders', component: OrderView , meta:{ requiresAuth:true}},
    {
        path: '/admin',
        component: RouterView,
        meta: { requiresAuth: true, role:'Admin' },
        children: [
            { path: 'users', name: 'admin-users', component: UsersList },
            { path: 'sectors', name: 'admin-sectors', component: SectorsLists },
            { path: 'companies', name: 'admin-companies', component: CompaniesList },
            { path: 'data', name: 'admin-data', component: DataTools },
            { path: 'logs', name: 'admin-logs', component: LogsViewer },
        ]
    }
    // Другие роуты...
  ],
})

router.beforeEach(async (to, from, next) => {
  const auth = useAuthStore()

  if (to.meta.requiresAuth && !auth.isAuthenticated) {
    next('/login')
  } else {
    next()
  }
})

export default router
