<script setup lang="ts">
import { ref, onMounted, onUnmounted, computed, watch } from 'vue'
import { useRoute } from 'vue-router'
import { useToast } from 'primevue/usetoast'
import { useAuthStore } from '@/stores/auth'
import api from '@/services/api'
import anychart from 'anychart'

// Компоненты PrimeVue
import Button from 'primevue/button'
import Panel from 'primevue/panel'
import Dialog from 'primevue/dialog'
import InputNumber from 'primevue/inputnumber'
import SelectButton from 'primevue/selectbutton'
import Tag from 'primevue/tag'
import ProgressSpinner from 'primevue/progressspinner'
import TradeDialog from '@/components/TradeDialog.vue'

const route = useRoute()
const toast = useToast()
const companyId = parseInt(route.params.id as string)
const authStore = useAuthStore()
// --- ДАННЫЕ ---
const company = ref<any>(null)
const userShares = ref(0)
const historyData = ref<any[]>([])
const change24h = ref(0);
const isLoading = ref(true)
const isChartReady = ref(false)

// --- ГРАФИК ---
const chartContainer = ref<HTMLElement | null>(null)
let chart: any = null

// --- ТОРГОВЛЯ ---
const showTradeDialog = ref(false)
const tradeType = ref<'BUY' | 'SELL'>('BUY')
const tradeForm = ref({ quantity: 1, price: 0 })
const tradeLoading = ref(false)

  

// --- ХЕЛПЕР ДЛЯ ДАТ ---
const parseUtcDate = (dateStr: string): number => {
    if (dateStr && !dateStr.endsWith('Z')) {
        return new Date(dateStr + 'Z').getTime();
    }
    return new Date(dateStr).getTime();
};

// --- ЗАГРУЗКА ДАННЫХ ---
const loadData = async () => {
  try {
    // 1. Инфо о компании
    const resComp = await api.get(`/Company/${companyId}`)
    company.value = resComp.data.data
    tradeForm.value.price = company.value.currentPrice // Дефолтная цена для ордера

    // 2. Портфель (ищем сколько у нас акций этой компании)
    const resPort = await api.get('/Portfolio/items')
    const myItem = resPort.data.data.find((i: any) => i.companyId === companyId)
    userShares.value = myItem ? myItem.quantity : 0

    // 3. История цен (берем с запасом 24 часа, фильтруем на клиенте)
    const resHist = await api.get(`/Company/${companyId}/history?hours=24`)
    historyData.value = resHist.data.data.sort(
      (a: any, b: any) => parseUtcDate(a.timestamp) - parseUtcDate(b.timestamp),
    )
    console.log(historyData.value)
    calculateChange()
    // Инициализация графика с задержкой, чтобы DOM отрисовался
    setTimeout(initChart, 1000)
    
    if (!isChartReady.value) {
      setTimeout(() => {
      isChartReady.value = true
    }, 2000)
    } else {
      // Если график уже есть (обновление данных), просто обновляем серию
      updateChartData(chart.getSeries(0))
    }
  } catch (e) {
    console.error(e)
  } finally {
    isLoading.value = false
  }
}

// Расчет изменения за 24 часа
const calculateChange = () => {
    if (!historyData.value.length || !company.value) return;
    
    // Сортируем (старые -> новые)
    const sorted = [...historyData.value].sort((a, b) => parseUtcDate(a.timestamp) - parseUtcDate(b.timestamp));
    
    // Берем самую первую доступную точку (это и есть "24 часа назад" или момент IPO)
    const startPrice = sorted[0].price;
    const endPrice = company.value.currentPrice;

    if (startPrice > 0) {
        change24h.value = ((endPrice - startPrice) / startPrice) * 100;
    } else {
        change24h.value = 0;
    }
};

// --- ЛОГИКА ГРАФИКА (AnyChart) ---
const initChart = () => {
    if (chart) chart.dispose();
    
    chart = anychart.area();
    chart.background().fill("transparent");

    // 1. ВАЖНО: Указываем, что ось X — это шкала времени
    // Без этого AnyChart будет думать, что это просто большие числа
    const xScale = anychart.scales.dateTime();
    chart.xScale(xScale);

    // 2. Убираем подписи снизу (как вы просили)
    chart.xAxis().labels().enabled(false);
    chart.xAxis().ticks().enabled(false); // Черточки тоже лучше убрать для чистоты
    
    // 3. Настраиваем ТУЛТИП (Всплывающее окно при наведении)
    const tooltip = chart.tooltip();
    // this.x — это timestamp (число), который мы передали.
    // Превращаем его в читаемое локальное время "14:30"
    tooltip.titleFormat(function(this: any) {
        return new Date(this.x).toLocaleTimeString([], {
            hour: '2-digit', 
            minute: '2-digit'
        });
    });

    // 4. Настраиваем ПЕРЕКРЕСТИЕ (Линия и метка на оси при наведении)
    const crosshair = chart.crosshair();
    crosshair.enabled(false);
    crosshair.yLabel(false); // Скрываем метку на оси Y (цену и так видно в тултипе)
    
    // Форматируем метку на оси X (внизу), которая появляется при наведении
    crosshair.xLabel().format(function(this: any) {
        return new Date(this.value).toLocaleTimeString([], {
            hour: '2-digit', 
            minute: '2-digit'
        });
    });

    const series = chart.area([]);
    series.name("Цена");
    
    // Заполняем данными
    updateChartData(series);

    chart.container(chartContainer.value);
    chart.draw();
};

const updateChartData = (series: any) => {
    // Получаем точку отсчета (текущее время минус 24 часа)
    const now = new Date();
    const cutoff = now.getTime() - 24 * 60 * 60 * 1000; // 24 часа в мс

    // Фильтруем и маппим данные
    const filteredData = historyData.value
        .map((p: any) => ({
            timestamp: parseUtcDate(p.timestamp),
            price: p.price
        }))
        .filter((p: any) => p.timestamp >= cutoff)
        .map((p: any) => [
            p.timestamp, // X: Числовой Timestamp
            p.price      // Y: Цена
        ]);

    // Сортируем (AnyChart требует сортировку по X)
    filteredData.sort((a: number[], b: number[]) => a[0] - b[0]);

    // Загружаем в график
    series.data(filteredData);

    // Красим график
    const color = change24h.value >= 0 ? '#06d6a0' : '#ef476f';
    series.fill(anychart.color.lighten(color, 0.8));
    series.stroke({ color: color, thickness: 2 });
};

// --- ЛОГИКА ТОРГОВЛИ ---
const openTradeModal = (type: 'BUY' | 'SELL') => {
  tradeType.value = type
  tradeForm.value.quantity = 1
  tradeForm.value.price = company.value?.currentPrice || 0
  showTradeDialog.value = true
}

const submitOrder = async () => {
  tradeLoading.value = true
  try {
    await api.post('/Trading/order', {
      companyId: companyId,
      type: tradeType.value,
      quantity: tradeForm.value.quantity,
      limitPrice: tradeForm.value.price,
    })

    toast.add({ severity: 'success', summary: 'Успех', detail: 'Ордер создан', life: 3000 })
    showTradeDialog.value = false

    setTimeout(loadData, 1000)
  } catch (e: any) {
    toast.add({
      severity: 'error',
      summary: 'Ошибка',
      detail: e.response?.data?.message || 'Сбой',
      life: 3000,
    })
  } finally {
    tradeLoading.value = false
  }
}

onMounted(() => {
  loadData()
})

onUnmounted(() => {
  if (chart) chart.dispose()
})
</script>

<template>
  <div v-if="!isLoading && company" class="flex flex-col gap-6 w-3/4">
    <div
      class="text-center py-4 bg-white dark:bg-surface-800 shadow-sm rounded-lg border border-gray-400"
      :class="change24h >= 0 ? 'border-trade-success' : 'border-trade-danger'"
    >
      <h1 class="text-3xl font-bold text-brand-primary">{{ company.name }}</h1>
      <div class="flex items-center justify-center gap-3 mt-2">
        <span class="text-4xl font-mono font-bold text-gray-800">
          {{ company.currentPrice.toFixed(2) }} $
        </span>

        <Tag :severity="change24h >= 0 ? 'success' : 'danger'" class="text-lg px-3 py-1">
          <i
            :class="change24h >= 0 ? 'pi pi-arrow-up' : 'pi pi-arrow-down'"
            class="text-xs mr-1"
          ></i>
          {{ Math.abs(change24h).toFixed(2) }}% (24ч)
        </Tag>
      </div>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-12 gap-6 h-[500px]">
      <div class="md:col-span-8 content-card flex flex-col h-full relative p-4">
        <div
          v-if="!isChartReady"
          class="absolute inset-0 flex justify-center items-center bg-white/50 z-0 rounded-lg"
        >
          <ProgressSpinner
            style="width: 50px; height: 50px"
            strokeWidth="4"
            fill="transparent"
            animationDuration=".5s"
          />
        </div>

        <div v-show="isChartReady" ref="chartContainer" class="w-full h-full min-h-[400px]"></div>
      </div>

      <div class="md:col-span-4 flex flex-col gap-4">
        <div
          class="content-card bg-brand-primary text-white !border-none"
          style="background-color: rgb(0 78 137 / var(--tw-bg-opacity, 1))"
        >
          <h3 class="text-sm opacity-80 mb-1">Ваш портфель</h3>
          <div class="text-3xl font-bold font-mono">
            {{ userShares }} <span class="text-lg font-sans font-normal opacity-70">акций</span>
          </div>
          <div class="text-sm mt-2 opacity-60">
            Стоимость: {{ (userShares * company.currentPrice).toFixed(2) }} $
          </div>
        </div>

        <div class="flex flex-col gap-3 flex-grow">
          <Button
            label="КУПИТЬ"
            class="!bg-trade-success !border-trade-success border border-gray-400 h-16 text-xl font-bold shadow-lg hover:brightness-110"
            @click="openTradeModal('BUY')"
          />

          <Button
            label="ПРОДАТЬ"
            class="!bg-trade-danger !border-trade-danger border border-gray-400 h-16 text-xl font-bold shadow-lg hover:brightness-110"
            :disabled="userShares <= 0"
            @click="openTradeModal('SELL')"
          />
        </div>
      </div>
    </div>

    <Panel header="Информация о компании" toggleable>
      <p class="text-gray-700 leading-relaxed">
        {{ company.description || 'Описание отсутствует.' }}
      </p>
      <div class="mt-4 flex gap-4 text-sm text-gray-500">
        <span><i class="pi pi-tag mr-1"></i> {{ company.sectorName }}</span>
        <span
          ><i class="pi pi-chart-bar mr-1"></i> Волатильность:
          {{ (company.volatility * 100).toFixed(0) }}%</span
        >
        <span><i class="pi pi-hashtag mr-1"></i> {{ company.ticker }}</span>
      </div>
    </Panel>

    <Dialog
      v-model:visible="showTradeDialog"
      modal
      :header="tradeType === 'BUY' ? 'Покупка акций' : 'Продажа акций'"
      class="w-full max-w-sm"
    >
      <div class="flex flex-col gap-4 pt-2">
        <div class="flex flex-col gap-2">
          <label class="font-bold">Количество</label>
          <InputNumber
            v-model="tradeForm.quantity"
            showButtons
            :min="1"
            :max="tradeType === 'SELL' ? userShares : 1000000"
            inputClass="w-full"
          />
        </div>

        <div class="flex flex-col gap-2">
          <label class="font-bold">Цена за акцию (Лимит)</label>
          <InputNumber
            v-model="tradeForm.price"
            mode="currency"
            currency="USD"
            locale="en-US"
            :minFractionDigits="2"
            inputClass="w-full"
          />
          <small class="text-gray-500">Текущая: ${{ company.currentPrice }}</small>
        </div>

        <div class="bg-gray-100 p-3 rounded text-center my-2">
          <div class="text-xs text-gray-500">Итоговая сумма</div>
          <div class="font-bold text-xl">
            ${{ (tradeForm.quantity * tradeForm.price).toFixed(2) }}
          </div>
        </div>

        <div class="flex justify-end gap-2">
          <Button label="Отмена" text severity="secondary" @click="showTradeDialog = false" />
          <Button
            :label="tradeType === 'BUY' ? 'Подтвердить покупку' : 'Подтвердить продажу'"
            :class="
              tradeType === 'BUY'
                ? '!bg-trade-success !border-trade-success'
                : '!bg-trade-danger !border-trade-danger'
            "
            :loading="tradeLoading"
            @click="submitOrder"
          />
        </div>
      </div>
    </Dialog>
  </div>
</template>

<style scoped>
/* Спец. стили для графика, чтобы он не вылезал */
.anychart-credits {
  display: none;
} /* Скрыть лого AnyChart (для демо) */
</style>
