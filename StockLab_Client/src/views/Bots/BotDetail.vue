<script setup lang="ts">
import { ref, onMounted, onUnmounted, computed } from 'vue';
import { useRoute } from 'vue-router';
import api from '@/services/api';
import anychart from 'anychart';

// PrimeVue Imports
import DataTable from 'primevue/datatable';
import Column from 'primevue/column';
import Tag from 'primevue/tag';
import Card from 'primevue/card';
import ProgressBar from 'primevue/progressbar';
import Button from 'primevue/button';
import Skeleton from 'primevue/skeleton';

// --- TYPES ---
interface BotInfo {
    id: number;
    username: string;
    cashBalance: number;
    totalEquity: number;
    assetsValue: number;
}

interface PortfolioItem {
    companyId: number;
    ticker: string;
    name: string;
    quantity: number;
    currentPrice: number;
    totalValue: number;
}

interface Order {
    id: number;
    ticker: string;
    type: 'BUY' | 'SELL';
    status: 'OPEN' | 'FILLED' | 'PARTIAL' | 'CANCELLED';
    limitPrice: number;
    originalQty: number;
    remainingQty: number;
    createdAt: string;
}

// --- STATE ---
const route = useRoute();
const botId = route.params.id; // Предполагаем роут /bot/:id

const loading = ref(true);
const botInfo = ref<BotInfo | null>(null);
const assets = ref<PortfolioItem[]>([]);
const orders = ref<Order[]>([]);

// Chart References
const pieContainer = ref<HTMLElement | null>(null);
let pieChart: any = null;

// --- COMPUTED ---
// Фильтруем ордера: убираем отмененные, как просили
const displayedOrders = computed(() => {
    return orders.value.filter(o => o.status !== 'CANCELLED');
});

// --- API LOADING ---
const loadBotData = async () => {
    loading.value = true;
    try {
        // В реальном приложении здесь будут эндпоинты, специфичные для конкретного бота по ID
        // Например: /api/bots/{id}/summary, /api/bots/{id}/portfolio, /api/bots/{id}/orders
        
        const [resInfo, resAssets, resOrders] = await Promise.all([
            api.get(`/Bot/summary/${botId}`),   // Инфо о боте (Имя, Баланс)
            api.get(`/Bot/items/${botId}`), // Список активов
            api.get(`/Bot/orders/${botId}`)     // Список ордеров
        ]);

        botInfo.value = resInfo.data.data;
        assets.value = resAssets.data.data;
        orders.value = resOrders.data.data;

        initPieChart();
    } catch (e) {
        console.error("Ошибка загрузки данных бота:", e);
    } finally {
        loading.value = false;
    }
};

// --- CHART LOGIC ---
const initPieChart = () => {
    if (pieChart) pieChart.dispose();
    if (!assets.value.length || !pieContainer.value) return;

    // Подготовка данных: Топ 5 + Others (чтобы не загромождать)
    const sortedItems = [...assets.value].sort((a, b) => b.totalValue - a.totalValue);
    const topItems = sortedItems.slice(0, 5);
    const others = sortedItems.slice(5);
    
    const chartData = topItems.map(i => ({ x: i.ticker, value: i.totalValue }));
    
    if (others.length > 0) {
        const othersValue = others.reduce((acc, curr) => acc + curr.totalValue, 0);
        chartData.push({ x: 'Other', value: othersValue });
    }

    pieChart = anychart.pie(chartData);
    pieChart.innerRadius("50%");
    pieChart.background().fill("transparent");
    pieChart.legend().position("right");
    pieChart.legend().itemsLayout("vertical");
    pieChart.container(pieContainer.value);
    pieChart.draw();
};

// --- HELPERS ---
const getProgress = (order: Order) => {
    const filled = order.originalQty - order.remainingQty;
    return Math.round((filled / order.originalQty) * 100);
};

const getStatusSeverity = (status: string) => {
    switch (status) {
        case 'FILLED': return 'success';
        case 'PARTIAL': return 'warn';
        case 'OPEN': return 'info';
        default: return 'secondary';
    }
};

onMounted(() => {
    loadBotData();
});

onUnmounted(() => {
    if (pieChart) pieChart.dispose();
});
</script>

<template>
    <div class="flex flex-col gap-6">
        
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div class="content-card bg-white dark:bg-surface-900 border-l-4 border-brand-primary">
                <div v-if="loading">
                    <Skeleton width="50%" class="mb-2"></Skeleton>
                    <Skeleton width="80%"></Skeleton>
                </div>
                <div v-else-if="botInfo">
                    <div class="text-sm text-gray-500 uppercase font-bold tracking-wider mb-1">Бот</div>
                    <h1 class="text-3xl font-bold text-gray-800 dark:text-white">{{ botInfo.username }}</h1>
                    <Tag value="Active" severity="success" class="mt-2" />
                </div>
            </div>

            <div class="content-card flex flex-col justify-center">
                <div class="text-sm text-gray-500 mb-1">Доступный кэш</div>
                <div v-if="loading"><Skeleton width="60%" height="2rem"></Skeleton></div>
                <div v-else class="text-2xl font-mono font-bold text-gray-700">
                    {{ botInfo?.cashBalance.toFixed(2) }} $
                </div>
            </div>

            <div class="content-card flex flex-col justify-center">
                <div class="text-sm text-gray-500 mb-1">Общая ценность (Net Worth)</div>
                <div v-if="loading"><Skeleton width="60%" height="2rem"></Skeleton></div>
                <div v-else class="text-3xl font-mono font-bold text-brand-primary">
                    {{ botInfo?.totalEquity.toFixed(2) }} $
                </div>
                <div v-if="!loading && botInfo" class="text-xs text-gray-400 mt-1">
                    В активах: {{ botInfo.assetsValue }} $
                </div>
            </div>
        </div>

        <div class="grid grid-cols-1 xl:grid-cols-12 gap-6 items-start">
            
            <div class="xl:col-span-7 flex flex-col gap-6">
                <div class="content-card h-[300px] relative">
                    <h3 class="font-bold text-gray-700 absolute top-4 left-4 z-10">Структура портфеля</h3>
                    <div ref="pieContainer" class="w-full h-full"></div>
                </div>

                <div class="content-card !p-0 overflow-hidden">
                    <div class="p-4 border-b border-gray-100 bg-gray-50 dark:bg-surface-800">
                        <h3 class="font-bold text-gray-700">Список Активов</h3>
                    </div>
                    <DataTable :value="assets" :loading="loading" class="p-datatable-sm" scrollable scrollHeight="400px">
                        <template #empty><div class="p-4 text-center text-gray-500">Портфель пуст</div></template>
                        
                        <Column field="ticker" header="Тикер">
                            <template #body="{ data }">
                                <span class="font-bold">{{ data.ticker }}</span>
                            </template>
                        </Column>
                        
                        <Column field="quantity" header="Кол-во" sortable>
                            <template #body="{ data }">
                                <Tag :value="data.quantity" severity="secondary" />
                            </template>
                        </Column>

                        <Column field="currentPrice" header="Цена" sortable>
                            <template #body="{ data }">{{ data.currentPrice.toFixed(2) }}</template>
                        </Column>

                        <Column field="totalValue" header="Стоимость" sortable>
                            <template #body="{ data }">
                                <span class="font-mono font-bold">{{ data.totalValue.toFixed(2) }} $</span>
                            </template>
                        </Column>
                    </DataTable>
                </div>
            </div>

            <div class="xl:col-span-5 flex flex-col gap-6">
                <div class="content-card !p-0 overflow-hidden h-full">
                    <div class="p-4 border-b border-gray-100 bg-gray-50 dark:bg-surface-800 flex justify-between items-center">
                        <h3 class="font-bold text-gray-700">Журнал ордеров</h3>
                        <Button icon="pi pi-refresh" text rounded size="small" @click="loadBotData" :loading="loading" />
                    </div>
                    
                    <DataTable 
                        :value="displayedOrders" 
                        :loading="loading" 
                        class="p-datatable-sm" 
                        paginator 
                        :rows="8"
                        sortField="createdAt" 
                        :sortOrder="-1"
                    >
                        <template #empty><div class="p-4 text-center text-gray-500">Активных ордеров нет</div></template>

                        <Column field="ticker" header="Тикер">
                             <template #body="{ data }">
                                <div class="flex flex-col">
                                    <span class="font-bold">{{ data.ticker }}</span>
                                    <span class="text-[10px] text-gray-400">{{ new Date(data.createdAt).toLocaleTimeString() }}</span>
                                </div>
                            </template>
                        </Column>

                        <Column field="type" header="Тип">
                            <template #body="{ data }">
                                <span :class="data.type === 'BUY' ? 'text-trade-success' : 'text-trade-danger'" class="font-bold text-xs uppercase">
                                    {{ data.type === 'BUY' ? 'Buy' : 'Sell' }}
                                </span>
                            </template>
                        </Column>

                        <Column header="Прогресс">
                            <template #body="{ data }">
                                <div class="w-full" style="max-width: 80px">
                                    <div class="flex justify-between text-[10px] mb-1">
                                        <span>${{ data.limitPrice }}</span>
                                        <span class="font-bold">{{ getProgress(data) }}%</span>
                                    </div>
                                    <ProgressBar 
                                        :value="getProgress(data)" 
                                        :showValue="false" 
                                        style="height: 4px" 
                                    />
                                </div>
                            </template>
                        </Column>

                        <Column field="status" header="Статус">
                            <template #body="{ data }">
                                <Tag :value="data.status" :severity="getStatusSeverity(data.status)" class="!text-[10px] !px-2 !py-0" />
                            </template>
                        </Column>

                    </DataTable>
                </div>
            </div>

        </div>
    </div>
</template>

<style scoped>
.content-card {
    @apply bg-white dark:bg-surface-900 border border-surface-200 dark:border-surface-700 rounded-lg p-5 shadow-sm;
}
.anychart-credits { display: none; }
</style>