<script setup lang="ts">
import { ref, onMounted, onUnmounted, computed } from 'vue';
import api from '@/services/api';
import anychart from 'anychart';
import TradeDialog from '@/components/TradeDialog.vue'; // Наш новый компонент

// PrimeVue
import DataTable from 'primevue/datatable';
import Column from 'primevue/column';
import Button from 'primevue/button';
import Tag from 'primevue/tag';
import Card from 'primevue/card';

// DTOs
interface PortfolioItem {
    companyId: number;
    ticker: string;
    name: string;
    quantity: number;
    currentPrice: number;
    totalValue: number;
    priceChangeAbs: number;
    priceChangePercent: number;
}

interface PortfolioSummary {
    cashBalance: number;
    stocksValue: number;
    totalEquity: number;
    changeAbs: number;
    changePercent: number;
}

// State
const items = ref<PortfolioItem[]>([]);
const summary = ref<PortfolioSummary | null>(null);
const orders = ref<any[]>([]); // История всех ордеров для раскрытия
const loading = ref(true);
const expandedRows = ref({}); // Для управления раскрытыми строками

// Chart State
const pieContainer = ref<HTMLElement | null>(null);
let pieChart: any = null;

// Trade State
const tradeDialog = ref({ visible: false, type: 'BUY' as 'BUY' | 'SELL', company: null as any, maxQty: 0 });

// --- ЗАГРУЗКА ---
const loadData = async () => {
    loading.value = true;
    try {
        // 1. Загружаем Items и Summary параллельно
        const [resItems, resSum, resOrders] = await Promise.all([
            api.get('/Portfolio/items'),
            api.get('/Portfolio/summary'),
            api.get('/Trading/orders') // Берем все ордера, фильтруем на клиенте
        ]);

        items.value = resItems.data.data;
        summary.value = resSum.data.data;
        orders.value = resOrders.data.data;

        initPieChart();
    } catch (e) {
        console.error(e);
    } finally {
        loading.value = false;
    }
};

// --- ГРАФИК (PIE) ---
const initPieChart = () => {
    if (pieChart) pieChart.dispose();
    if (!items.value.length) return;

    // Подготовка данных: Топ 9 + Others
    const sortedItems = [...items.value].sort((a, b) => b.totalValue - a.totalValue);
    const top9 = sortedItems.slice(0, 9);
    const others = sortedItems.slice(9);
    
    const chartData = top9.map(i => ({ x: i.ticker, value: i.totalValue }));
    
    if (others.length > 0) {
        const othersValue = others.reduce((acc, curr) => acc + curr.totalValue, 0);
        chartData.push({ x: 'Other', value: othersValue });
    }

    // Рисуем
    pieChart = anychart.pie(chartData);
    pieChart.innerRadius("40%"); // Donut chart
    pieChart.background().fill("transparent");
    
    // Цвета (опционально, можно задать палитру)
    // pieChart.palette(["#004e89", "#1a659e", ...]);

    pieChart.container(pieContainer.value);
    pieChart.draw();
};

// --- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ---
const getAssetTransactions = (companyId: number) => {
    return orders.value
        .filter(o => o.ticker === items.value.find(i => i.companyId === companyId)?.ticker)
        .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
};

const openTrade = (type: 'BUY' | 'SELL', item: PortfolioItem) => {
    tradeDialog.value = {
        visible: true,
        type,
        company: item,
        maxQty: item.quantity
    };
};

onMounted(() => {
    loadData();
});

onUnmounted(() => {
    if (pieChart) pieChart.dispose();
});
</script>

<template>
    <div class="flex flex-col gap-6">
        <h1 class="text-3xl font-bold text-brand-primary">Мой Портфель</h1>

        <div class="grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">
            
            <div class="lg:col-span-9 flex flex-col gap-4">
                <div class="content-card !p-0 overflow-hidden">
                    <DataTable 
                        v-model:expandedRows="expandedRows"
                        :value="items" 
                        :loading="loading" 
                        dataKey="companyId"
                        class="p-datatable-lg"
                    >
                        <Column expander style="width: 3rem" />

                        <Column header="Актив" field="name">
                            <template #body="{ data }">
                                <div class="flex flex-col">
                                    <span class="font-bold text-lg">{{ data.ticker }}</span>
                                    <span class="text-sm text-gray-500">{{ data.name }}</span>
                                </div>
                            </template>
                        </Column>

                        <Column header="Цена" field="currentPrice" sortable>
                            <template #body="{ data }">
                                {{ data.currentPrice.toFixed(2) }} $
                            </template>
                        </Column>

                        <Column header="Кол-во" field="quantity" sortable>
                            <template #body="{ data }">
                                <Tag :value="data.quantity" severity="info"  />
                            </template>
                        </Column>

                        <Column header="Стоимость" field="totalValue" sortable>
                            <template #body="{ data }">
                                <span class="font-mono font-bold">{{ data.totalValue.toFixed(2) }} $</span>
                            </template>
                        </Column>

                        <Column header="Действия">
                            <template #body="{ data }">
                                <div class="flex gap-2">
                                    <Button icon="pi pi-plus" size="small" class="!bg-trade-success !border-trade-success" @click="openTrade('BUY', data)" />
                                    <Button icon="pi pi-minus" size="small" class="!bg-trade-danger !border-trade-danger" @click="openTrade('SELL', data)" />
                                </div>
                            </template>
                        </Column>

                        <template #expansion="{ data }">
                            <div class="p-4 bg-surface-50 dark:bg-surface-900 border-t border-surface-200">
                                <h4 class="font-bold mb-2 text-brand-primary">История операций: {{ data.name }}</h4>
                                <DataTable :value="getAssetTransactions(data.companyId)" size="small" class="p-datatable-sm">
                                    <template #empty>Нет операций.</template>
                                    <Column field="createdAt" header="Дата (UTC)">
                                        <template #body="sp">
                                            {{ new Date(sp.data.createdAt).toLocaleString() }}
                                        </template>
                                    </Column>
                                    <Column field="type" header="Тип">
                                        <template #body="sp">
                                            <Tag :value="sp.data.type" :severity="sp.data.type === 'BUY' ? 'success' : 'danger'" />
                                        </template>
                                    </Column>
                                    <Column field="limitPrice" header="Цена">
                                        <template #body="sp">${{ sp.data.limitPrice }}</template>
                                    </Column>
                                    <Column field="originalQty" header="Кол-во"></Column>
                                    <Column field="status" header="Статус"></Column>
                                </DataTable>
                            </div>
                        </template>
                    </DataTable>
                </div>
            </div>

            <div class="lg:col-span-3 flex flex-col gap-6">
                
                <div v-if="summary" class="content-card flex flex-col gap-4">
                    <h2 class="text-xl font-bold text-gray-700">Сводка</h2>
                    
                    <div class="flex justify-between items-center border-b pb-2 border-gray-200">
                        <span class="text-gray-500">Баланс</span>
                        <span class="font-mono font-bold">{{ summary.cashBalance.toFixed(2) }} $</span>
                    </div>
                    
                    <div class="flex justify-between items-center border-b pb-2 border-gray-200">
                        <span class="text-gray-500">Акции</span>
                        <span class="font-mono font-bold">{{ summary.stocksValue.toFixed(2) }} $</span>
                    </div>

                    <div class="mt-2">
                        <div class="text-sm text-gray-500">Общая ценность</div>
                        <div class="text-3xl font-bold text-brand-primary">
                            {{ summary.totalEquity.toFixed(2) }} $
                        </div>
                    </div>

                    <div class="bg-white p-3 rounded border border-gray-100 shadow-sm">
                        <div class="text-xs text-gray-400 mb-1">Изменение (30 мин)</div>
                        <div class="flex items-center gap-2" :class="summary.changeAbs >= 0 ? 'text-trade-success' : 'text-trade-danger'">
                            <i :class="summary.changeAbs >= 0 ? 'pi pi-arrow-up' : 'pi pi-arrow-down'"></i>
                            <span class="font-bold text-lg">
                                {{ Math.abs(summary.changeAbs).toFixed(2) }} $
                            </span>
                            <span class="text-sm">
                                ({{ Math.abs(summary.changePercent).toFixed(2) }}%)
                            </span>
                        </div>
                    </div>
                </div>

                <div class="content-card h-[350px] flex flex-col">
                    <h3 class="font-bold mb-2 text-gray-700">Структура</h3>
                    <div ref="pieContainer" class="flex-grow w-full h-full"></div>
                </div>

            </div>
        </div>

        <TradeDialog 
            v-model:visible="tradeDialog.visible" 
            :type="tradeDialog.type"
            :company="tradeDialog.company"
            :max-qty="tradeDialog.maxQty"
            @success="loadData"
        />
    </div>
</template>

<style scoped>
.anychart-credits { display: none; }
</style>