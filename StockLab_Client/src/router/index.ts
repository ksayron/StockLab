import { createRouter, createWebHistory } from 'vue-router'
import HomeView from '../views/HomeView.vue'
import LoginView from '@/views/Auth/LoginView.vue'
import { useAuthStore } from '@/stores/auth'
import RegisterView from '@/views/Auth/RegisterView.vue'
import CompamyView from '@/views/Company/CompamyView.vue'
import PortfolioView from '@/views/Portfolio/PortfolioView.vue'
import OrderView from '@/views/Order/OrderView.vue'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    { path: '/', name: 'home', component: HomeView },
    { path: '/login', name: 'login', component: LoginView },
    { path: '/register', name: 'register', component: RegisterView },
    { path: '/company/:id', name: 'company', component: CompamyView },
    { path: '/portfolio', name: 'portfolio', component: PortfolioView , meta:{ requiresAuth:true}},
    { path: '/orders', name: 'orders', component: OrderView , meta:{ requiresAuth:true}},
    // Другие роуты...
  ],
})

// Global Guard
router.beforeEach(async (to, from, next) => {
  const auth = useAuthStore()

  // 1. Попытка восстановить сессию при первом заходе
  if (!auth.user && !auth.isLoading) {
    await auth.checkAuth()
  }

  // 2. Если роут требует auth, а юзера нет -> на логин
  // (Добавьте meta: { requiresAuth: true } в роуты типа Портфеля)
  if (to.meta.requiresAuth && !auth.isAuthenticated) {
    next('/login')
  } else {
    next()
  }
})

export default router
