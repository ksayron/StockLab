import axios from 'axios'

const api = axios.create({
  baseURL: 'http://localhost:5147/api',
  withCredentials: true, // ВАЖНО: Разрешает отправку кук
  headers: {
    'Content-Type': 'application/json',
  },
})

api.interceptors.response.use(
  (response) => response,
  (error) => {
    // Игнорируем 401, если это запрос проверки профиля (checkAuth)
    // URL запроса можно проверить через error.config.url
    const isCheckAuth = error.config.url && error.config.url.includes('/User/profile')

    if (error.response && error.response.status === 401 && !isCheckAuth) {
      // Редиректим ТОЛЬКО если это не фоновая проверка
      // И если мы еще не на странице логина
      if (window.location.pathname !== '/login') {
        window.location.href = '/login'
      }
    }
    return Promise.reject(error)
  },
)

export default api
