<script setup lang="ts">
import { ref } from 'vue';
import { useToast } from 'primevue/usetoast';
import api from '@/services/api';
import Button from 'primevue/button';
import FileUpload from 'primevue/fileupload'; // Используем только для UI (mode="basic")

const toast = useToast();
const importing = ref(false);
const exporting = ref(false);

const handleExport = async () => {
    exporting.value = true;
    try {
        // Важно: responseType: 'blob' для скачивания файла
        const response = await api.get('/Admin/export', { responseType: 'blob' });
        
        // Создаем ссылку для скачивания
        const url = window.URL.createObjectURL(new Blob([response.data]));
        const link = document.createElement('a');
        link.href = url;
        // Генерируем имя файла с датой
        link.setAttribute('download', `backup_${new Date().toISOString().slice(0,10)}.json`);
        document.body.appendChild(link);
        link.click();
        link.remove();
        
        toast.add({ severity: 'success', summary: 'Экспорт', detail: 'Файл скачан', life: 3000 });
    } catch (e) {
        toast.add({ severity: 'error', summary: 'Ошибка', detail: 'Не удалось скачать дамп', life: 3000 });
    } finally {
        exporting.value = false;
    }
};

const onFileSelect = async (event: any) => {
    const file = event.files[0];
    if (!file) return;

    importing.value = true;
    const formData = new FormData();
    formData.append('file', file);

    try {
        await api.post('/Admin/import', formData, {
            headers: { 'Content-Type': 'multipart/form-data' }
        });
        toast.add({ severity: 'success', summary: 'Импорт', detail: 'База данных успешно восстановлена', life: 5000 });
    } catch (e: any) {
        toast.add({ severity: 'error', summary: 'Ошибка импорта', detail: e.response?.data?.message || 'Сбой', life: 5000 });
    } finally {
        importing.value = false;
    }
};
</script>

<template>
    <div class="flex flex-col gap-6 max-w-2xl mx-auto">
        <h1 class="text-2xl font-bold text-gray-800">Управление данными (Backup)</h1>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            
            <div class="content-card flex flex-col items-center text-center gap-4">
                <div class="bg-blue-50 p-4 rounded-full">
                    <i class="pi pi-download text-4xl text-brand-primary"></i>
                </div>
                <h3 class="font-bold text-lg">Экспорт БД</h3>
                <p class="text-sm text-gray-500">
                    Скачать полный JSON-дамп базы данных (пользователи, компании, история).
                </p>
                <Button 
                    label="Скачать Backup" 
                    icon="pi pi-download" 
                    class="w-full mt-auto" 
                    :loading="exporting"
                    @click="handleExport"
                />
            </div>

            <div class="content-card flex flex-col items-center text-center gap-4">
                <div class="bg-orange-50 p-4 rounded-full">
                    <i class="pi pi-upload text-4xl text-orange-500"></i>
                </div>
                <h3 class="font-bold text-lg">Импорт БД</h3>
                <p class="text-sm text-gray-500">
                    Восстановить данные из JSON. <br>
                    <span class="text-red-500 font-bold">Внимание: Существующие данные будут перезаписаны!</span>
                </p>
                
                <FileUpload 
                    mode="basic" 
                    name="file" 
                    accept=".json" 
                    :maxFileSize="400000000" 
                    @select="onFileSelect"
                    :auto="true"
                    chooseLabel="Загрузить файл"
                    class="w-full mt-auto"
                    :disabled="importing"
                />
                <small v-if="importing" class="text-brand-secondary animate-pulse">Загрузка...</small>
            </div>

        </div>
    </div>
</template>