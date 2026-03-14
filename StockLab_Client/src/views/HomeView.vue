<script setup lang="ts">
import { ref, onMounted, reactive, computed } from 'vue'
import api from '@/services/api'
import { useSectorStore } from '@/stores/sectorStore'
import { useAuthStore } from '@/stores/auth' // Импортируем стор авторизации

import DataTable from 'primevue/datatable'
import Column from 'primevue/column'
import InputText from 'primevue/inputtext'
import Button from 'primevue/button'
import Popover from 'primevue/popover'
import Select from 'primevue/select' // Или Dropdown для PrimeVue 3
import Tag from 'primevue/tag' // Для красивого отображения изменения (опционально)

// Данные
const companies = ref([])
const topCompanies = ref<any[]>([]) // Данные для Топ-5
const totalRecords = ref(0)
const loading = ref(false)
const op = ref() 
const sectorStore = useSectorStore()
const authStore = useAuthStore() // Инициализируем стор

// Проверка прав администратора
const isAdmin = computed(() => authStore.isAdmin)

// Параметры запроса
const queryParams = reactive({
  search: '',
  sectorId: null as number | null,
  sortBy: 'NAME',
  sortDir: 'ASC',
})

// Загрузка основных данных (список)
const loadCompanies = async () => {
  loading.value = true
  try {
    const res = await api.get('/Company', { params: queryParams })
    if (res.data.success) {
      companies.value = res.data.data
      totalRecords.value = res.data.data.length
    }
  } finally {
    loading.value = false
  }
}

// Загрузка ТОП-5 (Только для Админа)
const loadTopActive = async () => {
    // Если не админ или если уже загружали и пусто - можно не грузить, но проверим роль
    if (!isAdmin.value) return;
    try {
        const res = await api.get('/Analytics/top5');
        if (res.data.success) {
            topCompanies.value = res.data.data;
            console.log(topCompanies.value)
        }
    } catch (e) {
        console.error("Failed to load top 5 analytics", e);
    }
}

// Обработчик сортировки
const onSort = (event: any) => {
  const fieldMap: Record<string, string> = {
    name: 'NAME',
    currentPrice: 'PRICE',
    volatility: 'VOLATILITY',
  }
  queryParams.sortBy = fieldMap[event.sortField] || 'NAME'
  queryParams.sortDir = event.sortOrder === 1 ? 'ASC' : 'DESC'
  loadCompanies()
}

const onSearch = () => { loadCompanies() }
const toggleFilter = (event: any) => { op.value.toggle(event) }

onMounted(() => {
  loadCompanies()
  sectorStore.fetchSectors()
  // Пробуем загрузить аналитику, если админ
  if (isAdmin.value) {
      loadTopActive();
  }
})
</script>

<template>
  <div class="flex flex-col gap-10">
    <div class="flex flex-col items-center justify-center gap-6 py-10">
      <h1 class="text-3xl font-bold text-brand-primary">Рынок Акций</h1>

      <div 
        v-if="isAdmin && topCompanies.length > 0" 
        class="w-full max-w-6xl mb-6 p-6 bg-surface-50 dark:bg-surface-900 rounded-xl border border-surface-200 dark:border-surface-700 shadow-sm"
      >
          <div class="flex items-center gap-2 mb-4">
              <i class="pi pi-chart-line text-xl text-blue-600"></i>
              <h2 class="text-xl font-bold text-gray-800 dark:text-gray-100">ТОП-5 Активных Компаний</h2>
              <Tag value="Admin Only" severity="info" class="ml-auto" />
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-4">
              <div 
                v-for="comp in topCompanies" 
                :key="comp.tickerSymbol"
                class="flex flex-col p-4 bg-white dark:bg-surface-800 rounded-lg shadow-sm border border-gray-100 hover:shadow-md transition-shadow cursor-pointer"
                @click="$router.push(`/company/${comp.companyName}`)" 
              >
                  <div class="flex justify-between items-start mb-2">
                      <span class="font-bold text-lg text-gray-900">{{ comp.tickerSymbol }}</span>
                      </div>
                  
                  <div class="text-sm text-gray-500 truncate mb-3" :title="comp.companyName">
                      {{ comp.companyName }}
                  </div>

                  <div class="mt-auto pt-2 border-t border-gray-100 flex flex-col gap-1">
                      <div class="flex justify-between text-sm">
                          <span class="text-gray-500">Объем:</span>
                          <span class="font-mono font-bold">{{ comp.totalShares }}</span>
                      </div>
                      <div class="flex justify-between text-sm">
                          <span class="text-gray-500">Сделок:</span>
                          <span class="font-mono font-bold">{{ comp.tradeCount }}</span>
                      </div>
                  </div>
              </div>
          </div>
      </div>

      <div class="w-full flex justify-center gap-10 max-w-2xl">
        <div class="flex gap-2 w-full">
          <InputText
              v-model="queryParams.search"
              placeholder="Поиск по тикеру или названию..."
              size="large"
              class="w-full max-w-2xl p-2"
              @keydown.enter="onSearch"
            />
          <Button icon="pi pi-search" @click="onSearch" />
        </div>

        <Button
          type="button"
          icon="pi pi-filter"
          label="Фильтры"
          class="p-2"
          @click="toggleFilter"
          severity="secondary"
        />
      </div>

      <Popover ref="op">
        <div class="flex flex-col gap-4 p-2 w-64">
          <span class="font-medium">Сектор</span>
          <Select
            v-model="queryParams.sectorId"
            :options="sectorStore.sectors"
            optionLabel="name"
            optionValue="id"
            placeholder="Любой сектор"
            showClear
            filter
            :loading="sectorStore.isLoading"
            class="w-full"
          />
          <Button label="Применить" @click="loadCompanies" size="small" />
        </div>
      </Popover>
    </div>

    <DataTable
      :value="companies"
      paginator
      :rows="10"
      :totalRecords="totalRecords"
      :loading="loading"
      @sort="onSort"
      tableStyle="min-width: 70rem"
    >
      <Column field="ticker" header="Тикер" sortable style="min-width: 180px;"></Column>
      <Column field="name" header="Компания" sortable style="min-width: 200px;"></Column>
      <Column field="sectorName" header="Сектор" style="min-width: 150px;"></Column>
      <Column field="currentPrice" header="Цена" sortable style="min-width: 150px;">
        <template #body="slotProps">
          <span class="font-bold text-lg">${{ slotProps.data.currentPrice.toFixed(2) }}</span>
        </template>
      </Column>
      <Column header="Действия">
        <template #body="slotProps">
          <router-link :to="`/company/${slotProps.data.id}`">
            <Button label="Торговать" size="small" variant="outlined" class="!text-brand-bg !bg-brand-primary !border-brand-primary px-5 py-2"/>
          </router-link>
        </template>
      </Column>
    </DataTable>
  </div>
</template>