<script setup lang="ts">
import { ref,watch } from 'vue';
import { useRouter } from 'vue-router';
import Drawer from 'primevue/drawer';
import Menu from 'primevue/menu';
import Button from 'primevue/button';
import InputSwitch from 'primevue/inputswitch';
import { useToast } from 'primevue/usetoast';
import api from '@/services/api';

// Пропсы для управления видимостью из родителя (Header)
const visible = defineModel<boolean>('visible');

const router = useRouter();
const toast = useToast();
const isSimRunning = ref(false);
const simLoading = ref(false);

const items = ref([
    {
        label: 'Управление',
        items: [
            { label: 'Пользователи', icon: 'pi pi-users', command: () => router.push('/admin/users') },
            { label: 'Боты', icon: 'pi pi-microchip-ai', command: () => router.push('/admin/bots') },
            { label: 'Сектора', icon: 'pi pi-tags', command: () => router.push('/admin/sectors') },
            { label: 'Компании', icon: 'pi pi-building', command: () => router.push('/admin/companies') }
        ]
    },
    {
        label: 'Система',
        items: [
            { label: 'Импорт / Экспорт', icon: 'pi pi-database', command: () => router.push('/admin/data') },
            { label: 'Логи ошибок', icon: 'pi pi-exclamation-circle', command: () => router.push('/admin/logs') },
            { label: 'Hangfire Dashboard', icon: 'pi pi-server', command: () => window.open('http://localhost:5147/hangfire', '_blank') }
        ]
    }
]);

const navigate = (path: string) => {
    visible.value = false; // Закрываем меню
    router.push(path);
};

const checkSimStatus = async () => {
    try {
        const res = await api.get('/Admin/simulation');
        isSimRunning.value = res.data.isRunning;
    } catch (e) { console.error(e); }
};

const toggleSim = async () => {
    simLoading.value = true;
    try {
        // Отправляем новое состояние
        await api.post('/Admin/simulation', isSimRunning.value);
        
        toast.add({ 
            severity: isSimRunning.value ? 'success' : 'info', 
            summary: 'Симуляция', 
            detail: isSimRunning.value ? 'Боты запущены' : 'Боты остановлены', 
            life: 3000 
        });
    } catch (e) {
        // Если ошибка, возвращаем свитч обратно
        isSimRunning.value = !isSimRunning.value;
        toast.add({ severity: 'error', summary: 'Ошибка', detail: 'Не удалось переключить', life: 3000 });
    } finally {
        simLoading.value = false;
    }
};

watch(() => visible.value, (newVal) => {
    if (newVal) checkSimStatus();
});

</script>

<template>
    <Drawer v-model:visible="visible" header="Панель Администратора">
        <div class="flex flex-col h-full">
            <div class="mb-4 text-sm text-gray-500">
                Добро пожаловать в центр управления StockLab.
            </div>

            <Menu :model="items" class="w-full !border-none" />
            <div class="mt-auto">
                <Button label="Выйти из админки" severity="secondary" text class="w-full" @click="visible = false" />
            </div>
            
        </div>
    </Drawer>
</template>