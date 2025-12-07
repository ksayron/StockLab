<script setup lang="ts">
import { ref, onMounted, computed } from 'vue';
import { useToast } from 'primevue/usetoast';
import { useConfirm } from 'primevue/useconfirm'; // Для подтверждения отмены
import api from '@/services/api';

// Компоненты PrimeVue
import DataTable from 'primevue/datatable';
import Column from 'primevue/column';
import Tag from 'primevue/tag';
import Button from 'primevue/button';
import ProgressBar from 'primevue/progressbar';
import ConfirmPopup from 'primevue/confirmpopup';

// Типы
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

const orders = ref<Order[]>([]);
const loading = ref(true);
const toast = useToast();
const confirm = useConfirm();

// --- ЗАГРУЗКА ---
const loadOrders = async () => {
    loading.value = true;
    try {
        const res = await api.get('/Trading/orders');
        orders.value = res.data.data;
    } catch (e) {
        console.error(e);
    } finally {
        loading.value = false;
    }
};

// --- ОТМЕНА ---
const cancelOrder = (event: any, orderId: number) => {
    confirm.require({
        target: event.currentTarget,
        message: 'Вы уверены, что хотите отменить ордер?',
        icon: 'pi pi-exclamation-triangle',
        acceptClass: 'p-button-danger',
        accept: async () => {
            try {
                await api.delete(`/Trading/order/${orderId}`);
                toast.add({ severity: 'success', summary: 'Успех', detail: 'Ордер отменен', life: 3000 });
                loadOrders(); // Обновляем список
            } catch (e: any) {
                toast.add({ severity: 'error', summary: 'Ошибка', detail: e.response?.data?.message || 'Не удалось отменить', life: 3000 });
            }
        }
    });
};

// --- ХЕЛПЕРЫ ДЛЯ UI ---
const getStatusSeverity = (status: string) => {
    switch (status) {
        case 'FILLED': return 'success';
        case 'PARTIAL': return 'warn';
        case 'CANCELLED': return 'secondary';
        case 'OPEN': return 'info';
        default: return 'secondary';
    }
};

const getProgress = (order: Order) => {
    const filled = order.originalQty - order.remainingQty;
    return Math.round((filled / order.originalQty) * 100);
};

onMounted(() => {
    loadOrders();
});
</script>

<template>
    <div class="flex flex-col gap-6">
        <ConfirmPopup />

        <div class="flex justify-between items-center">
            <h1 class="text-3xl font-bold text-brand-primary">Мои Ордера</h1>
            <Button icon="pi pi-refresh" text rounded @click="loadOrders" :loading="loading" />
        </div>

        <div class="content-card !p-0 overflow-hidden">
            <DataTable 
                :value="orders" 
                :loading="loading" 
                paginator 
                :rows="10"
                class="p-datatable-lg"
                sortField="createdAt"
                :sortOrder="-1"
            >
                <template #empty>
                    <div class="p-4 text-center text-gray-500">У вас пока нет ордеров.</div>
                </template>

                <Column field="createdAt" header="Дата" sortable>
                    <template #body="{ data }">
                        <div class="text-sm">
                            {{ new Date(data.createdAt).toLocaleDateString() }}
                            <div class="text-gray-400 text-xs">
                                {{ new Date(data.createdAt).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'}) }}
                            </div>
                        </div>
                    </template>
                </Column>

                <Column field="ticker" header="Тикер" sortable>
                    <template #body="{ data }">
                        <span class="font-bold text-lg">{{ data.ticker }}</span>
                    </template>
                </Column>

                <Column field="type" header="Тип" sortable>
                    <template #body="{ data }">
                        <Tag 
                            :value="data.type === 'BUY' ? 'ПОКУПКА' : 'ПРОДАЖА'" 
                            :class="data.type === 'BUY' ? '!bg-trade-success' : '!bg-trade-danger'"
                            class="font-bold"
                        />
                    </template>
                </Column>

                <Column field="limitPrice" header="Цена" sortable>
                    <template #body="{ data }">
                        <div class="font-mono font-bold">${{ data.limitPrice.toFixed(2) }}</div>
                        <div class="text-xs text-gray-400">
                            Всего: ${{ (data.limitPrice * data.originalQty).toFixed(2) }}
                        </div>
                    </template>
                </Column>

                <Column header="Заполнение" style="min-width: 150px">
                    <template #body="{ data }">
                        <div class="flex flex-col gap-1">
                            <div class="flex justify-between text-xs mb-1">
                                <span>{{ data.originalQty - data.remainingQty }} / {{ data.originalQty }}</span>
                                <span class="font-bold">{{ getProgress(data) }}%</span>
                            </div>
                            <ProgressBar 
                                :value="getProgress(data)" 
                                :showValue="false" 
                                style="height: 6px"
                                :class="data.status === 'CANCELLED' ? 'opacity-50' : ''"
                            />
                        </div>
                    </template>
                </Column>

                <Column field="status" header="Статус" sortable>
                    <template #body="{ data }">
                        <Tag :value="data.status" :severity="getStatusSeverity(data.status)" />
                    </template>
                </Column>

                <Column header="" style="width: 5rem">
                    <template #body="{ data }">
                        <Button 
                            v-if="data.status === 'OPEN' || data.status === 'PARTIAL'"
                            icon="pi pi-times" 
                            severity="danger" 
                            text 
                            rounded 
                            tooltip="Отменить ордер"
                            @click="cancelOrder($event, data.id)"
                        />
                    </template>
                </Column>

            </DataTable>
        </div>
    </div>
</template>