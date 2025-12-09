<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { useToast } from 'primevue/usetoast';
import { useConfirm } from 'primevue/useconfirm';
import api from '@/services/api';

import DataTable from 'primevue/datatable';
import Column from 'primevue/column';
import Button from 'primevue/button';
import Dialog from 'primevue/dialog';
import InputText from 'primevue/inputtext';
import Textarea from 'primevue/textarea';
import ConfirmPopup from 'primevue/confirmpopup';

interface Sector {
    id: number;
    name: string;
    description: string;
}

const sectors = ref<Sector[]>([]);
const loading = ref(true);
const toast = useToast();
const confirm = useConfirm();

// State диалога
const dialogVisible = ref(false);
const isEditMode = ref(false);
const form = ref({ id: 0, name: '', description: '' });
const saving = ref(false);

const loadSectors = async () => {
    loading.value = true;
    try {
        const res = await api.get('/Sector');
        sectors.value = res.data.data;
    } catch (e) {
        console.error(e);
    } finally {
        loading.value = false;
    }
};

const openNew = () => {
    form.value = { id: 0, name: '', description: '' };
    isEditMode.value = false;
    dialogVisible.value = true;
};

const openEdit = (sector: Sector) => {
    form.value = { ...sector };
    isEditMode.value = true;
    dialogVisible.value = true;
};

const saveSector = async () => {
    if (!form.value.name) return;
    
    saving.value = true;
    try {
        if (isEditMode.value) {
            await api.put(`/Sector/${form.value.id}`, form.value);
            toast.add({ severity: 'success', summary: 'Обновлено', detail: 'Сектор изменен', life: 3000 });
        } else {
            await api.post('/Sector', form.value);
            toast.add({ severity: 'success', summary: 'Создано', detail: 'Новый сектор добавлен', life: 3000 });
        }
        dialogVisible.value = false;
        loadSectors();
    } catch (e: any) {
        toast.add({ severity: 'error', summary: 'Ошибка', detail: e.response?.data?.message, life: 3000 });
    } finally {
        saving.value = false;
    }
};

const deleteSector = (event: any, id: number) => {
    confirm.require({
        target: event.currentTarget,
        message: 'Удалить сектор? Это невозможно, если к нему привязаны компании.',
        icon: 'pi pi-exclamation-triangle',
        acceptClass: 'p-button-danger',
        accept: async () => {
            try {
                await api.delete(`/Sector/${id}`);
                toast.add({ severity: 'success', summary: 'Удалено', detail: 'Сектор удален', life: 3000 });
                loadSectors();
            } catch (e: any) {
                toast.add({ severity: 'error', summary: 'Ошибка', detail: e.response?.data?.message, life: 3000 });
            }
        }
    });
};

onMounted(() => loadSectors());
</script>

<template>
    <div class="flex flex-col gap-6">
        <ConfirmPopup />
        
        <div class="flex justify-between items-center">
            <h1 class="text-2xl font-bold text-gray-800">Сектора экономики</h1>
            <Button label="Добавить" icon="pi pi-plus" @click="openNew" />
        </div>

        <div class="content-card !p-0 overflow-hidden">
            <DataTable :value="sectors" :loading="loading" class="p-datatable-lg">
                <template #empty>Нет данных.</template>
                <Column field="id" header="ID" style="width: 50px"></Column>
                <Column field="name" header="Название" sortable class="font-bold"></Column>
                <Column field="description" header="Описание"></Column>
                <Column header="Действия" style="width: 120px">
                    <template #body="{ data }">
                        <div class="flex gap-2">
                            <Button icon="pi pi-pencil" text rounded severity="info" @click="openEdit(data)" />
                            <Button icon="pi pi-trash" text rounded severity="danger" @click="deleteSector($event, data.id)" />
                        </div>
                    </template>
                </Column>
            </DataTable>
        </div>

        <Dialog v-model:visible="dialogVisible" modal :header="isEditMode ? 'Редактировать' : 'Новый сектор'" class="w-full max-w-md">
            <div class="flex flex-col gap-4 pt-2">
                <div class="flex flex-col gap-2">
                    <label class="font-bold">Название</label>
                    <InputText v-model="form.name" autofocus />
                </div>
                <div class="flex flex-col gap-2">
                    <label class="font-bold">Описание</label>
                    <Textarea v-model="form.description" rows="3" />
                </div>
                <div class="flex justify-end gap-2 mt-2">
                    <Button label="Отмена" text severity="secondary" @click="dialogVisible = false" />
                    <Button label="Сохранить" icon="pi pi-check" :loading="saving" @click="saveSector" />
                </div>
            </div>
        </Dialog>
    </div>
</template>