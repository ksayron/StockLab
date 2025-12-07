import { defineStore } from 'pinia'
import { ref } from 'vue'
import api from '@/services/api'

// Интерфейс сектора (согласно нашему DTO)
export interface Sector {
  id: number
  name: string
  description?: string
}

export const useSectorStore = defineStore('market', () => {
  const sectors = ref<Sector[]>([])
  const isLoading = ref(false)

  // Загрузка секторов с бэкенда
  async function fetchSectors() {
    // Если уже загружали - не дергаем сервер лишний раз
    if (sectors.value.length > 0) return

    isLoading.value = true
    try {
      // GET /api/Sector
      const response = await api.get('/Sector')
      if (response.data.success) {
        sectors.value = response.data.data
      }
    } catch (e) {
      console.error('Ошибка загрузки секторов', e)
    } finally {
      isLoading.value = false
    }
  }

  return { sectors, isLoading, fetchSectors }
})
