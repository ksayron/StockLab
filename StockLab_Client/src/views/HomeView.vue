<script setup lang="ts">
import { ref, onMounted, reactive } from 'vue'
import api from '@/services/api'
import DataTable from 'primevue/datatable'
import Column from 'primevue/column'
import InputText from 'primevue/inputtext'
import Button from 'primevue/button'
import Popover from 'primevue/popover'
import Select from 'primevue/select' // В PrimeVue 3 это 'primevue/dropdown'
import { useSectorStore } from '@/stores/sectorStore'

// Данные
const companies = ref([])
const totalRecords = ref(0)
const loading = ref(false)
const op = ref() // Ref для Popover (фильтры)
const sectorStore = useSectorStore()

// Параметры запроса (соответствуют аргументам контроллера)
const queryParams = reactive({
  search: '',
  sectorId: null as number | null,
  sortBy: 'NAME',
  sortDir: 'ASC',
  // Пагинация (наш API пока возвращает всё, но DataTable умеет резать.
  // Если бы API поддерживало skip/take, мы бы их тут использовали)
})

// Загрузка данных
const loadCompanies = async () => {
  loading.value = true
  try {
    // GET /api/Company?search=...&sortBy=...
    const res = await api.get('/Company', { params: queryParams })
    if (res.data.success) {
      companies.value = res.data.data
      totalRecords.value = res.data.data.length // Пока так
    }
  } finally {
    loading.value = false
  }
}

// Обработчик сортировки таблицы
const onSort = (event: any) => {
  // Маппинг полей таблицы на поля API
  const fieldMap: Record<string, string> = {
    name: 'NAME',
    currentPrice: 'PRICE',
    volatility: 'VOLATILITY',
  }

  queryParams.sortBy = fieldMap[event.sortField] || 'NAME'
  queryParams.sortDir = event.sortOrder === 1 ? 'ASC' : 'DESC'
  loadCompanies()
}

// Поиск (Debounce можно добавить позже)
const onSearch = () => {
  loadCompanies()
}

const toggleFilter = (event: any) => {
  op.value.toggle(event)
}

onMounted(() => {
  loadCompanies()
  sectorStore.fetchSectors()
})
</script>

<template>
  <div class="flex flex-col gap-10">
    <div class="flex flex-col items-center justify-center gap-6 py-10">

      <h1 class="text-3xl font-bold text-brand-primary">Рынок Акций</h1>

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
      lazy
      paginator
      :rows="10"
      :totalRecords="totalRecords"
      :loading="loading"
      @sort="onSort"
      tableStyle="min-width: 70rem"
    >
      <Column field="ticker" header="Тикер" sortable></Column>
      <Column field="name" header="Компания" sortable></Column>
      <Column field="sectorName" header="Сектор"></Column>
      <Column field="currentPrice" header="Цена" sortable>
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
