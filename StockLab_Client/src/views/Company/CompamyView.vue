<script setup lang="ts">
import { ref, onMounted, onUnmounted, computed, watch } from 'vue';
import { useRoute } from 'vue-router';
import { useToast } from 'primevue/usetoast';
import api from '@/services/api';
import anychart from 'anychart';

// Компоненты PrimeVue
import Button from 'primevue/button';
import Panel from 'primevue/panel';
import Dialog from 'primevue/dialog';
import InputNumber from 'primevue/inputnumber';
import SelectButton from 'primevue/selectbutton';
import Tag from 'primevue/tag';

const route = useRoute();
const toast = useToast();
const companyId = parseInt(route.params.id as string);

// --- ДАННЫЕ ---
const company = ref<any>(null);
const userShares = ref(0);
const historyData = ref<any[]>([]);
const change30m = ref(0); // Изменение за 30 мин
const isLoading = ref(true);

// --- ГРАФИК ---
const chartContainer = ref<HTMLElement | null>(null);
let chart: any = null;
const timePeriod = ref(60); // В минутах (по дефолту 1 час)
const periodOptions = ref([
    { label: '10М', value: 10 },
    { label: '30М', value: 30 },
    { label: '1Ч', value: 60 },
    { label: '12Ч', value: 720 }
]);

// --- ТОРГОВЛЯ ---
const showTradeDialog = ref(false);
const tradeType = ref<'BUY' | 'SELL'>('BUY');
const tradeForm = ref({ quantity: 1, price: 0 });
const tradeLoading = ref(false);

// --- ЗАГРУЗКА ДАННЫХ ---
const loadData = async () => {
    try {
        // 1. Инфо о компании
        const resComp = await api.get(`/Company/${companyId}`);
        company.value = resComp.data.data;
        tradeForm.value.price = company.value.currentPrice; // Дефолтная цена для ордера

        // 2. Портфель (ищем сколько у нас акций этой компании)
        const resPort = await api.get('/Portfolio/items');
        const myItem = resPort.data.data.find((i: any) => i.companyId === companyId);
        userShares.value = myItem ? myItem.quantity : 0;

        // 3. История цен (берем с запасом 24 часа, фильтруем на клиенте)
        const resHist = await api.get(`/Company/${companyId}/history?hours=24`);
        historyData.value = resHist.data.data;
        console.log(historyData.value)
        calculateChange();
        updateChart();
    } catch (e) {
        console.error(e);
    } finally {
        isLoading.value = false;
    }
};

// Расчет изменения за 30 минут
const calculateChange = () => {
    if (!historyData.value.length || !company.value) return;
    
    const now = new Date();
    const thirtyMinsAgo = new Date(now.getUTCDate() - 30 * 60000);
    
    // Ищем цену, ближайшую к 30 минутам назад
    const oldPoint = historyData.value.find((p: any) => new Date(p.timestamp) >= thirtyMinsAgo);
    console.log(oldPoint);
    if (oldPoint) {
        const startPrice = oldPoint.price;
        const endPrice = company.value.currentPrice;
        // Формула: ((New - Old) / Old) * 100
        change30m.value = ((endPrice - startPrice) / startPrice) * 100;
    } else {
        change30m.value = 0;
    }
};

// --- ЛОГИКА ГРАФИКА (AnyChart) ---
const initChart = () => {
    if (chart) chart.dispose();
    
    // Создаем Stock Chart (лучше подходит для финансов)
    // Но для простоты используем Area Chart, как в обычных приложениях
    chart = anychart.area();
    
    // Настройка внешнего вида
    chart.background().fill("transparent");
    chart.xAxis().labels().format("{%value}{dateTimeFormat:HH:mm}");
    
    const series = chart.area([]);
    series.name("Цена");
    
    // Цвет графика зависит от текущего тренда (зеленый/красный)
    const color = change30m.value >= 0 ? '#06d6a0' : '#ef476f';
    series.fill(anychart.color.lighten(color, 0.8)); // Заливка светлее
    series.stroke(color); // Линия яркая

    chart.container(chartContainer.value);
    chart.draw();
};

const updateChart = () => {
    if (!chart || !historyData.value.length) return initChart();

    const now = new Date();
    const cutoff = new Date(now.getUTCDate() - timePeriod.value * 60000);

    // Фильтруем данные под выбранный период
    const filteredData = historyData.value
        .filter((p: any) => new Date(p.timestamp) >= cutoff)
        .map((p: any) => [
            new Date(p.timestamp).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'}), 
            p.price
        ]);

    chart.getSeries(0).data(filteredData);
    
    // Обновляем цвет при смене тренда
    const color = change30m.value >= 0 ? '#06d6a0' : '#ef476f';
    chart.getSeries(0).fill(anychart.color.lighten(color, 0.8));
    chart.getSeries(0).stroke(color);
};

// Следим за переключением кнопок времени
watch(timePeriod, () => updateChart());

// --- ЛОГИКА ТОРГОВЛИ ---
const openTradeModal = (type: 'BUY' | 'SELL') => {
    tradeType.value = type;
    tradeForm.value.quantity = 1;
    // Предлагаем текущую цену
    tradeForm.value.price = company.value?.currentPrice || 0;
    showTradeDialog.value = true;
};

const submitOrder = async () => {
    tradeLoading.value = true;
    try {
        await api.post('/Trading/order', {
            companyId: companyId,
            type: tradeType.value,
            quantity: tradeForm.value.quantity,
            limitPrice: tradeForm.value.price
        });
        
        toast.add({ severity: 'success', summary: 'Успех', detail: 'Ордер создан', life: 3000 });
        showTradeDialog.value = false;
        
        // Перезагружаем данные (чтобы обновить баланс акций, если сделка прошла мгновенно)
        // В идеале ждать сокета, но для UX обновим сразу
        setTimeout(loadData, 1000);
        
    } catch (e: any) {
        toast.add({ severity: 'error', summary: 'Ошибка', detail: e.response?.data?.message || 'Сбой', life: 3000 });
    } finally {
        tradeLoading.value = false;
    }
};

onMounted(() => {
    loadData();
    // Инициализация графика с задержкой, чтобы DOM отрисовался
    setTimeout(initChart, 100);
});

onUnmounted(() => {
    if (chart) chart.dispose();
});
</script>

<template>
    <div v-if="!isLoading && company" class="flex flex-col gap-6 w-3/4">
        
        <div class="text-center py-4 bg-white dark:bg-surface-800 shadow-sm rounded-lg border border-gray-400"
             :class="change30m >= 0 ? 'border-trade-success' : 'border-trade-danger'">
            
            <h1 class="text-3xl font-bold text-brand-primary">{{ company.name }}</h1>
            <div class="flex items-center justify-center gap-3 mt-2">
                <span class="text-4xl font-mono font-bold text-gray-800">
                    {{ company.currentPrice.toFixed(2) }} $
                </span>
                
                <Tag :severity="change30m >= 0 ? 'success' : 'danger'" class="text-lg px-3 py-1">
                    <i :class="change30m >= 0 ? 'pi pi-arrow-up' : 'pi pi-arrow-down'" class="text-xs mr-1"></i>
                    {{ Math.abs(change30m).toFixed(2) }}% (30м)
                </Tag>
            </div>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-12 gap-6 h-[500px]">
            
            <div class="md:col-span-8 content-card flex flex-col h-full relative">
                <div class="absolute top-4 right-4 z-10">
                    <SelectButton v-model="timePeriod" :options="periodOptions" optionLabel="label" optionValue="value" />
                </div>
                
                <div ref="chartContainer" class="w-full h-full min-h-[400px]"></div>
            </div>

            <div class="md:col-span-4 flex flex-col gap-4">
                
                <div class="content-card bg-brand-primary text-white !border-none" style="background-color: rgb(0 78 137 / var(--tw-bg-opacity, 1));">
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
                <span><i class="pi pi-chart-bar mr-1"></i> Волатильность: {{ (company.volatility * 100).toFixed(0) }}%</span>
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
                    <InputNumber v-model="tradeForm.quantity" showButtons :min="1" :max="tradeType === 'SELL' ? userShares : 1000000" inputClass="w-full" />
                </div>

                <div class="flex flex-col gap-2">
                    <label class="font-bold">Цена за акцию (Лимит)</label>
                    <InputNumber v-model="tradeForm.price" mode="currency" currency="USD" locale="en-US" :minFractionDigits="2" inputClass="w-full" />
                    <small class="text-gray-500">Текущая: ${{ company.currentPrice }}</small>
                </div>

                <div class="bg-gray-100 p-3 rounded text-center my-2">
                    <div class="text-xs text-gray-500">Итоговая сумма</div>
                    <div class="font-bold text-xl">${{ (tradeForm.quantity * tradeForm.price).toFixed(2) }}</div>
                </div>

                <div class="flex justify-end gap-2">
                    <Button label="Отмена" text severity="secondary" @click="showTradeDialog = false" />
                    <Button 
                        :label="tradeType === 'BUY' ? 'Подтвердить покупку' : 'Подтвердить продажу'" 
                        :class="tradeType === 'BUY' ? '!bg-trade-success !border-trade-success' : '!bg-trade-danger !border-trade-danger'"
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
.anychart-credits { display: none; } /* Скрыть лого AnyChart (для демо) */
</style>