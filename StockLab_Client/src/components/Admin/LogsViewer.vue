<script setup lang="ts">
import { ref, onMounted } from 'vue';
import api from '@/services/api';
import DataTable from 'primevue/datatable';
import Column from 'primevue/column';
import Button from 'primevue/button';
import Tag from 'primevue/tag';

const logs = ref([]);
const loading = ref(true);
const expandedRows = ref({});

const loadLogs = async () => {
    loading.value = true;
    try {
        // GET /api/Admin/logs?minutes=60 (или без параметра для всех)
        const res = await api.get('/Admin/logs');
        logs.value = res.data.data;
    } finally {
        loading.value = false;
    }
};

onMounted(loadLogs);
</script>

<template>
    <div class="flex flex-col gap-6">
        <div class="flex justify-between items-center">
            <h1 class="text-2xl font-bold text-gray-800">Системные Логи</h1>
            <Button icon="pi pi-refresh" label="Обновить" @click="loadLogs" :loading="loading" />
        </div>

        <div class="content-card !p-0 overflow-hidden">
            <DataTable 
                v-model:expandedRows="expandedRows"
                :value="logs" 
                :loading="loading" 
                paginator :rows="20"
                class="p-datatable-sm"
                dataKey="logId"
            >
                <Column expander style="width: 3rem" />
                
                <Column field="logId" header="#" sortable></Column>
                
                <Column field="createdAt" header="Время" sortable>
                    <template #body="{ data }">
                        {{ new Date(data.createdAt).toLocaleString() }}
                    </template>
                </Column>

                <Column field="procName" header="Процедура" sortable class="font-mono text-sm"></Column>
                
                <Column field="errorCode" header="Код">
                    <template #body="{ data }">
                        <Tag :value="data.errorCode" severity="danger" />
                    </template>
                </Column>

                <Column field="userId" header="User ID"></Column>

                <template #expansion="{ data }">
                    <div class="p-4 bg-red-50 text-red-900 font-mono text-sm whitespace-pre-wrap">
                        {{ data.errorMsg }}
                    </div>
                </template>
            </DataTable>
        </div>
    </div>
</template>