<script setup lang="ts">
import { ref, onMounted, reactive } from 'vue';
import { useToast } from 'primevue/usetoast';
import { useConfirm } from 'primevue/useconfirm';
import { useSectorStore } from '@/stores/sectorStore';
import api from '@/services/api';

import DataTable from 'primevue/datatable';
import Column from 'primevue/column';
import Button from 'primevue/button';
import Dialog from 'primevue/dialog';
import InputText from 'primevue/inputtext';
import Textarea from 'primevue/textarea';
import InputNumber from 'primevue/inputnumber';
import Select from 'primevue/select';
import Tag from 'primevue/tag';
import ConfirmPopup from 'primevue/confirmpopup';

const sectorStore = useSectorStore();
const toast = useToast();
const confirm = useConfirm();

const companies = ref([]);
const loading = ref(true);
const dialogVisible = ref(false);
const formLoading = ref(false);

// Форма (Только для создания IPO, редактирование можно упростить или не делать тут)
const form = reactive({
    name: '',
    ticker: '',
    description: '',
    sectorId: null as number | null,
    initPrice: 100,
    volatility: 0.1,
    totalShares: 100000
});

const loadCompanies = async () => {
    loading.value = true;
    try {
        const res = await api.get('/Company'); // Получаем все
        companies.value = res.data.data;
    } finally {
        loading.value = false;
    }
};

const openNew = () => {
    // Сброс формы
    form.name = ''; form.ticker = ''; form.description = '';
    form.sectorId = null; form.initPrice = 100; 
    form.volatility = 0.1; form.totalShares = 100000;
    dialogVisible.value = true;
};

const createIPO = async () => {
    if (!form.sectorId || !form.name || !form.ticker) return;

    formLoading.value = true;
    try {
        await api.post('/Company', form);
        toast.add({ severity: 'success', summary: 'IPO Запущено', detail: 'Компания создана и акции выставлены', life: 3000 });
        dialogVisible.value = false;
        loadCompanies();
    } catch (e: any) {
        toast.add({ severity: 'error', summary: 'Ошибка', detail: e.response?.data?.message, life: 3000 });
    } finally {
        formLoading.value = false;
    }
};

const delistCompany = (event: any, id: number) => {
    confirm.require({
        target: event.currentTarget,
        message: 'Делистинг обнулит цену и остановит торги. Продолжить?',
        icon: 'pi pi-exclamation-triangle',
        acceptClass: 'p-button-danger',
        accept: async () => {
            try {
                await api.delete(`/Company/${id}`);
                toast.add({ severity: 'warn', summary: 'Делистинг', detail: 'Торги остановлены', life: 3000 });
                loadCompanies();
            } catch (e: any) {
                toast.add({ severity: 'error', detail: e.response?.data?.message, life: 3000 });
            }
        }
    });
};

onMounted(() => {
    loadCompanies();
    sectorStore.fetchSectors(); // Подгружаем сектора для селекта
});
</script>

<template>
    <div class="flex flex-col gap-6">
        <ConfirmPopup />
        
        <div class="flex justify-between items-center">
            <h1 class="text-2xl font-bold text-gray-800">Компании и IPO</h1>
            <Button label="Новое IPO" icon="pi pi-plus" @click="openNew" />
        </div>

        <div class="content-card !p-0 overflow-hidden">
            <DataTable :value="companies" :loading="loading" paginator :rows="10" class="p-datatable-lg">
                <Column field="ticker" header="Тикер" sortable class="font-bold"></Column>
                <Column field="name" header="Название" sortable></Column>
                <Column field="sectorName" header="Сектор"></Column>
                <Column field="status" header="Статус">
                    <template #body="{ data }">
                        <Tag :value="data.status" :severity="data.status === 'ACTIVE' ? 'success' : 'danger'" />
                    </template>
                </Column>
                <Column header="Действия">
                    <template #body="{ data }">
                        <Button 
                            v-if="data.status === 'ACTIVE'"
                            icon="pi pi-ban" 
                            label="Делистинг" 
                            severity="danger" 
                            size="small" 
                            text 
                            @click="delistCompany($event, data.id)" 
                        />
                    </template>
                </Column>
            </DataTable>
        </div>

        <Dialog v-model:visible="dialogVisible" modal header="Запуск нового IPO" class="w-full max-w-lg">
            <div class="flex flex-col gap-4 pt-2">
                <div class="grid grid-cols-2 gap-4">
                    <div class="flex flex-col gap-2">
                        <label class="font-bold">Название</label>
                        <InputText v-model="form.name" placeholder="SpaceX" />
                    </div>
                    <div class="flex flex-col gap-2">
                        <label class="font-bold">Тикер</label>
                        <InputText v-model="form.ticker" placeholder="SPCX" class="uppercase" />
                    </div>
                </div>

                <div class="flex flex-col gap-2">
                    <label class="font-bold">Сектор</label>
                    <Select v-model="form.sectorId" :options="sectorStore.sectors" optionLabel="name" optionValue="id" placeholder="Выберите сектор" class="w-full" />
                </div>

                <div class="flex flex-col gap-2">
                    <label class="font-bold">Описание</label>
                    <Textarea v-model="form.description" rows="2" />
                </div>

                <div class="grid grid-cols-3 gap-4">
                    <div class="flex flex-col gap-2">
                        <label class="font-bold text-sm">Цена ($)</label>
                        <InputNumber v-model="form.initPrice" mode="currency" currency="USD" locale="en-US" />
                    </div>
                    <div class="flex flex-col gap-2">
                        <label class="font-bold text-sm">Акций (шт)</label>
                        <InputNumber v-model="form.totalShares" />
                    </div>
                    <div class="flex flex-col gap-2">
                        <label class="font-bold text-sm">Волатильность</label>
                        <InputNumber v-model="form.volatility" :min="0.01" :max="1.0" :step="0.01" showButtons />
                    </div>
                </div>

                <div class="flex justify-end gap-2 mt-4">
                    <Button label="Отмена" text severity="secondary" @click="dialogVisible = false" />
                    <Button label="Запустить IPO" icon="pi pi-rocket" :loading="formLoading" @click="createIPO" />
                </div>
            </div>
        </Dialog>
    </div>
</template>