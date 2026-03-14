<script setup lang="ts">
import { ref, onMounted, onUnmounted, computed, reactive } from 'vue';
import { useRouter } from 'vue-router';
import { useBotStore } from '@/stores/bots';
import { useToast } from 'primevue/usetoast';
import { FilterMatchMode } from '@primevue/core/api';

// --- IMPORTS PRIME VUE ---
import DataTable from 'primevue/datatable';
import Column from 'primevue/column';
import Button from 'primevue/button';
import InputText from 'primevue/inputtext';
import IconField from 'primevue/iconfield';
import InputIcon from 'primevue/inputicon';
import Tag from 'primevue/tag';
import Card from 'primevue/card';
import Dialog from 'primevue/dialog';
import InputNumber from 'primevue/inputnumber';
import Message from 'primevue/message';

// --- CUSTOM COMPONENTS ---
import BotRadarAnyChart from '@/components/Bots/BotRadarChart.vue';
import api from '@/services/api'

const router = useRouter();
const store = useBotStore();
const toast = useToast();

const loading = ref(true);
const actionLoading = ref(false); // Для кнопок старт/пауза

const filters = ref({
    global: { value: null, matchMode: FilterMatchMode.CONTAINS }
});

// Данные для графиков (computed реактивны к изменениям в store.windroseStats)
const winnersData = computed(() => store.windroseStats.find(s => s.category.includes('Winners')));
const averageData = computed(() => store.windroseStats.find(s => s.category.includes('Average')));
const losersData = computed(() => store.windroseStats.find(s => s.category.includes('Losers')));

// --- TOURNAMENT CONTROLS ---

// Цвет индикатора статуса
const statusColorClass = computed(() => {
    switch (store.tournamentStatus) {
        case 'ACTIVE': return 'bg-green-500 shadow-[0_0_10px_rgba(34,197,94,0.6)]'; // Зеленый + свечение
        case 'PAUSED': return 'bg-yellow-500';
        case 'FINISHED': return 'bg-blue-500';
        case 'PLANNED': return 'bg-cyan-400';
        default: return 'bg-gray-400';
    }
});

const statusLabel = computed(() => {
    switch (store.tournamentStatus) {
        case 'ACTIVE': return 'Турнир идет';
        case 'PAUSED': return 'Пауза';
        case 'FINISHED': return 'Завершен';
        case 'PLANNED': return 'Ожидание';
        default: return 'Неизвестно';
    }
});

// Действия кнопок управления
const handleTournamentAction = async (action: 'start' | 'pause' | 'finalize') => {
    actionLoading.value = true;
    try {
        if (action === 'start') await api.post('/Bot/start');
        if (action === 'pause') await api.post('/Bot/pause');
        if (action === 'finalize') await api.post('/Bot/finalize');
        
        // Обновляем статус сразу
        await store.checkStatus();
        toast.add({ severity: 'success', summary: 'Успех', detail: 'Статус турнира обновлен', life: 3000 });
    } catch (e: any) {
        toast.add({ severity: 'error', summary: 'Ошибка', detail: e.response?.data?.message || 'Сбой действия', life: 3000 });
    } finally {
        actionLoading.value = false;
    }
};

// --- GENERATION MODAL ---
const genDialog = ref(false);
const genForm = reactive({ count: 100 });

const generateSeason = async () => {
    actionLoading.value = true;
    try {
        await api.post('/Bot/season', { botCount: genForm.count });
        toast.add({ severity: 'success', summary: 'Сезон сброшен', detail: `Создано ${genForm.count} ботов`, life: 3000 });
        genDialog.value = false;
        
        // Перезагрузка данных
        await store.checkStatus();
        loadTableData();
    } catch (e: any) {
        toast.add({ severity: 'error', summary: 'Ошибка генерации', detail: e.response?.data?.message, life: 3000 });
    } finally {
        actionLoading.value = false;
    }
};

// --- LOAD DATA ---
const loadTableData = async () => {
    loading.value = true;
    await store.fetchBots();
    loading.value = false;
};

const goToDetails = (id: number) => {
    
    router.push({ name: 'admin-bot-detail', params: { id } });
    //console.log("Go to bot", id);
};

const getRankSeverity = (rank: number) => {
    if (rank === 1) return 'warn';
    if (rank <= 3) return 'secondary';
    if (rank <= 10) return 'info';
    return 'contrast';
};

// Lifecycle
onMounted(async () => {
    await store.connectHub(); // WS подключение
    await store.checkStatus(); // Проверка статуса турнира
    loadTableData();

    // Обновляем таблицу раз в 5 сек (если не хотим гнать весь список по сокету)
    const interval = setInterval(() => {
        if(store.tournamentStatus === 'ACTIVE') loadTableData();
        store.checkStatus(); // Пингуем статус на всякий случай
    }, 5000);
    
    onUnmounted(() => {
        clearInterval(interval);
        store.disconnectHub();
    });
});
</script>

<template>
    <div class="flex flex-col gap-6 w-full">
        
        <div class="flex flex-col md:flex-row justify-between items-center bg-white p-4 rounded-xl shadow-sm border border-gray-100 gap-4">
            
            <div class="flex items-center gap-6 w-full md:w-auto">
                <div class="flex items-center gap-3">
                    <div 
                        class="w-4 h-4 rounded-full transition-all duration-500"
                        :class="statusColorClass"
                    ></div>
                    <div class="flex flex-col">
                        <span class="text-xs text-gray-500 uppercase tracking-wider font-semibold">Статус</span>
                        <span class="font-bold text-gray-700">{{ statusLabel }}</span>
                    </div>
                </div>

                <div class="h-8 w-px bg-gray-200 mx-2 hidden md:block"></div>

                <div class="flex gap-2">
                    <Button 
                        v-if="store.tournamentStatus !== 'ACTIVE'"
                        label="Старт" 
                        icon="pi pi-play" 
                        severity="success" 
                        size="small"
                        :loading="actionLoading"
                        @click="handleTournamentAction('start')"
                    />
                    
                    <Button 
                        v-if="store.tournamentStatus === 'ACTIVE'"
                        label="Пауза" 
                        icon="pi pi-pause" 
                        severity="warn" 
                        size="small"
                        outlined
                        :loading="actionLoading"
                        @click="handleTournamentAction('pause')"
                    />

                    <Button 
                        v-if="store.tournamentStatus === 'ACTIVE' || store.tournamentStatus === 'PAUSED'"
                        icon="pi pi-stop" 
                        severity="danger" 
                        size="small"
                        text
                        v-tooltip.top="'Завершить турнир'"
                        :loading="actionLoading"
                        @click="handleTournamentAction('finalize')"
                    />
                </div>
            </div>

            <div>
                <Button 
                    label="Новое поколение" 
                    icon="pi pi-bolt" 
                    severity="help" 
                    @click="genDialog = true"
                />
            </div>
        </div>

        
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4" v-if="store.windroseStats.length > 0">
            <Card class="shadow-sm border-t-4 border-t-emerald-500">
                <template #title>
                    <div class="flex justify-between items-center">
                        <span class="text-emerald-700 font-bold text-lg">Лидеры (Top 10%)</span>
                        <i class="pi pi-trophy text-emerald-500 text-xl"></i>
                    </div>
                </template>
                <template #content>
                    <BotRadarAnyChart v-if="winnersData" :data="winnersData" color="#10B981" />
                </template>
            </Card>

            <Card class="shadow-sm border-t-4 border-t-blue-500">
                <template #title>
                    <div class="flex justify-between items-center">
                        <span class="text-blue-700 font-bold text-lg">Толпа (Avg)</span>
                        <i class="pi pi-users text-blue-500 text-xl"></i>
                    </div>
                </template>
                <template #content>
                    <BotRadarAnyChart v-if="averageData" :data="averageData" color="#3B82F6" />
                </template>
            </Card>

            <Card class="shadow-sm border-t-4 border-t-red-500">
                <template #title>
                    <div class="flex justify-between items-center">
                        <span class="text-red-700 font-bold text-lg">Аутсайдеры</span>
                        <i class="pi pi-arrow-down-right text-red-500 text-xl"></i>
                    </div>
                </template>
                <template #content>
                    <BotRadarAnyChart v-if="losersData" :data="losersData" color="#EF4444" />
                </template>
            </Card>
        </div>
        
        <div v-else class="text-center p-8 bg-gray-50 rounded-xl border border-dashed border-gray-300">
            <i class="pi pi-chart-pie text-4xl text-gray-300 mb-2"></i>
            <p class="text-gray-500">Ожидание данных аналитики...</p>
        </div>

        <div class="content-card !p-0 overflow-hidden shadow-lg rounded-xl bg-white">
            <DataTable 
                :value="store.bots" 
                :loading="loading" 
                paginator 
                :rows="10" 
                v-model:filters="filters"
                :globalFilterFields="['username']"
                class="p-datatable-lg"
                stripedRows
            >
                <template #header>
                    <div class="flex justify-between items-center px-4 py-2">
                        <span class="text-xl font-semibold text-gray-700">Рейтинг Ботов</span>
                        <IconField>
                            <InputIcon class="pi pi-search" />
                            <InputText v-model="filters['global'].value" placeholder="Найти бота..." />
                        </IconField>
                    </div>
                </template>

                <Column field="currentRank" header="Место" sortable style="width: 80px">
                    <template #body="{ data }">
                        <div class="flex justify-center">
                            <Tag :value="data.currentRank" :severity="getRankSeverity(data.currentRank)" rounded />
                        </div>
                    </template>
                </Column>

                <Column field="username" header="Имя" sortable>
                    <template #body="{ data }">
                        <span class="font-bold text-primary cursor-pointer hover:underline" @click="goToDetails(data.userId)">
                            {{ data.username }}
                        </span>
                    </template>
                </Column>

                <Column field="netWorth" header="Капитал" sortable>
                    <template #body="{ data }">
                        <span class="font-mono font-bold" :class="data.netWorth >= 10000 ? 'text-green-600' : 'text-red-500'">
                            ${{ data.netWorth.toFixed(2) }}
                        </span>
                    </template>
                </Column>

                <Column header="Характеристики" style="min-width: 200px; text-align: center;">
                    <template #body="{ data }">
                        <div class="flex gap-2 text-xs text-gray-600 bg-gray-50 p-2 rounded-lg border border-gray-100 justify-center">
                            <div class="flex flex-col items-center" v-tooltip.top="'Жадность'">
                                <span class="font-bold text-purple-600">Жадность</span>
                                <span>{{ data.greedFactor.toFixed(2) }}</span>
                            </div>
                            <div class="w-px bg-gray-300 h-6"></div>
                            <div class="flex flex-col items-center" v-tooltip.top="'Паника'">
                                <span class="font-bold text-orange-600">Паника</span>
                                <span>{{ data.panicLevel.toFixed(2) }}</span>
                            </div>
                            <div class="w-px bg-gray-300 h-6"></div>
                            <div class="flex flex-col items-center" v-tooltip.top="'Память'">
                                <span class="font-bold text-blue-600">Память</span>
                                <span>{{ data.memorySpan }}</span>
                            </div>
                             <div class="w-px bg-gray-300 h-6"></div>
                            <div class="flex flex-col items-center" v-tooltip.top="'Риск'">
                                <span class="font-bold text-red-600">Риск</span>
                                <span>{{ data.betSize.toFixed(2) }}</span>
                            </div>
                        </div>
                    </template>
                </Column>

                <Column header="" style="width: 100px">
                    <template #body="{ data }">
                        <Button 
                            icon="pi pi-angle-right" 
                            severity="secondary" 
                            text 
                            rounded 
                            @click="goToDetails(data.userId)"
                        />
                    </template>
                </Column>
            </DataTable>
        </div>

        <Dialog v-model:visible="genDialog" modal header="Генерация Популяции" class="w-full max-w-md">
            <div class="flex flex-col gap-4">
                <Message severity="warn" icon="pi pi-exclamation-triangle" :closable="false">
                    Внимание! Это действие выполнит <b>Полный Сброс</b> (Hard Reset) текущего сезона.
                    Все текущие боты, их сделки и история турнира будут удалены безвозвратно.
                </Message>
                
                <div class="flex flex-col gap-2">
                    <label class="font-bold text-gray-700">Количество новых ботов</label>
                    <InputNumber 
                        v-model="genForm.count" 
                        showButtons 
                        :min="10" 
                        :max="1500" 
                        suffix=" шт" 
                        class="w-full"
                    />
                    <small class="text-gray-500">Рекомендуется: 100 - 500 для оптимальной производительности.</small>
                </div>

                <div class="flex justify-end gap-2 mt-4">
                    <Button label="Отмена" text severity="secondary" @click="genDialog = false" />
                    <Button 
                        label="Уничтожить и Создать" 
                        icon="pi pi-bolt" 
                        severity="danger" 
                        :loading="actionLoading" 
                        @click="generateSeason" 
                    />
                </div>
            </div>
        </Dialog>

    </div>
</template>