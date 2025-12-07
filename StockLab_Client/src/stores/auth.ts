import { defineStore } from 'pinia'
import api from '@/services/api'
import { ref, computed } from 'vue'

// Типы из нашей спецификации
interface UserProfile {
  userId: number
  username: string
  balance: number
  roleName: string
}

export const useAuthStore = defineStore('auth', () => {
  const user = ref<UserProfile | null>(null)
  const isAuthenticated = computed(() => !!user.value)
  const isLoading = ref(false)

  // 1. Проверка авторизации при загрузке (Auto-login)
  async function checkAuth() {
    if (user.value) return // Уже загружен

    isLoading.value = true
    try {
      // GET /api/User/profile - если кука есть, вернет 200 и данные
      const response = await api.get('/User/profile')
      if (response.data.success) {
        user.value = response.data.data
      }
    } catch (e) {
      // 401 - значит мы гость, это нормально
      user.value = null
    } finally {
      isLoading.value = false
    }
  }

  // 2. Логин
  async function login(creds: any) {
    // POST /api/User/login
    const response = await api.post('/User/login', creds)
    // После успешного логина сразу грузим профиль
    if (response.status === 200) {
      await checkAuth()
    }
  }

  // 3. Логаут
  async function logout() {
    try {
      await api.post('/User/logout')
    } finally {
      user.value = null
      // Перенаправление делает компонент или роутер
    }
  }

  return { user, isAuthenticated, isLoading, login, logout, checkAuth }
})
