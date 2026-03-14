<script setup lang="ts">
import { ref, onMounted, reactive } from 'vue';
import { useToast } from 'primevue/usetoast';
import { useConfirm } from 'primevue/useconfirm';
import { FilterMatchMode } from '@primevue/core/api';
import api from '@/services/api';

// Компоненты PrimeVue
import DataTable from 'primevue/datatable';
import Column from 'primevue/column';
import Button from 'primevue/button';
import InputText from 'primevue/inputtext';
import InputNumber from 'primevue/inputnumber';
import Password from 'primevue/password';
import Tag from 'primevue/tag';
import Dialog from 'primevue/dialog';
import IconField from 'primevue/iconfield';
import InputIcon from 'primevue/inputicon';
import ConfirmPopup from 'primevue/confirmpopup';
import Avatar from 'primevue/avatar';

// DTO
interface AdminUser {
    userId: number;
    username: string;
    email: string;
    balance: number;
    isBanned: boolean;
    roleName: string;
    createdAt: string;
}

const users = ref<AdminUser[]>([]);
const loading = ref(true);
const toast = useToast();
const confirm = useConfirm();

// Фильтры таблицы
const filters = ref({
    global: { value: null, matchMode: FilterMatchMode.CONTAINS }
});

// --- ЗАГРУЗКА ---
const loadUsers = async () => {
    loading.value = true;
    try {
        const res = await api.get('/Admin/users');
        users.value = res.data.data;
    } catch (e: any) {
        toast.add({ severity: 'error', summary: 'Ошибка', detail: 'Не удалось загрузить пользователей', life: 3000 });
    } finally {
        loading.value = false;
    }
};

// --- СОЗДАНИЕ АДМИНА ---
const adminDialog = ref(false);
const adminForm = reactive({ username: '', password: '' });
const adminLoading = ref(false);

const createAdmin = async () => {
    if (!adminForm.username || !adminForm.password) return;
    
    adminLoading.value = true;
    try {
        await api.post('/Admin/create', adminForm);
        toast.add({ severity: 'success', summary: 'Успех', detail: `Администратор ${adminForm.username} создан`, life: 3000 });
        adminDialog.value = false;
        adminForm.username = '';
        adminForm.password = '';
        loadUsers(); // Обновляем список
    } catch (e: any) {
        toast.add({ severity: 'error', summary: 'Ошибка', detail: e.response?.data?.message || 'Сбой', life: 3000 });
    } finally {
        adminLoading.value = false;
    }
};

// --- БЛОКИРОВКА / РАЗБЛОКИРОВКА ---
const toggleBan = (event: any, user: AdminUser) => {
    const isBanning = !user.isBanned;
    
    confirm.require({
        target: event.currentTarget,
        message: `Вы уверены, что хотите ${isBanning ? 'ЗАБЛОКИРОВАТЬ' : 'разблокировать'} ${user.username}?`,
        icon: isBanning ? 'pi pi-lock' : 'pi pi-lock-open',
        acceptClass: isBanning ? 'p-button-danger' : 'p-button-success',
        accept: async () => {
            try {
                const action = isBanning ? 'ban' : 'unban';
                await api.post(`/Admin/users/${user.userId}/${action}`);
                
                // Обновляем локально для скорости
                user.isBanned = isBanning;
                
                toast.add({ 
                    severity: isBanning ? 'warn' : 'success', 
                    summary: 'Статус изменен', 
                    detail: `Пользователь ${isBanning ? 'заблокирован' : 'активен'}`, 
                    life: 3000 
                });
            } catch (e: any) {
                toast.add({ severity: 'error', summary: 'Ошибка', detail: e.response?.data?.message, life: 3000 });
            }
        }
    });
};

// --- БАЛАНС ---
const balanceDialog = ref(false);
const balanceForm = reactive({ userId: 0, currentBalance: 0, newBalance: 0 });
const balanceLoading = ref(false);

const openBalanceDialog = (user: AdminUser) => {
    balanceForm.userId = user.userId;
    balanceForm.currentBalance = user.balance;
    balanceForm.newBalance = user.balance; // Начинаем с текущего
    balanceDialog.value = true;
};

const saveBalance = async () => {
    balanceLoading.value = true;
    try {
        await api.post(`/Admin/users/${balanceForm.userId}/balance`, {
            newBalance: balanceForm.newBalance
        });
        
        toast.add({ severity: 'success', summary: 'Баланс обновлен', detail: `Новый баланс: $${balanceForm.newBalance}`, life: 3000 });
        
        // Обновляем в списке
        const user = users.value.find(u => u.userId === balanceForm.userId);
        if (user) user.balance = balanceForm.newBalance;
        
        balanceDialog.value = false;
    } catch (e: any) {
        toast.add({ severity: 'error', summary: 'Ошибка', detail: e.response?.data?.message, life: 3000 });
    } finally {
        balanceLoading.value = false;
    }
};

onMounted(() => {
    loadUsers();
});
</script>

<template>
    <div class="flex flex-col gap-6">
        <ConfirmPopup />

        <div class="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
            <div>
                <h1 class="text-2xl font-bold text-gray-800">Управление пользователями</h1>
                <p class="text-sm text-gray-500">База данных трейдеров и администраторов</p>
            </div>
            <Button label="Новый Админ" icon="pi pi-user-plus" class="hover-lift" @click="adminDialog = true" />
        </div>

        <div class="content-card !p-0 overflow-hidden">
            <DataTable 
                :value="users" 
                :loading="loading" 
                paginator 
                :rows="10" 
                v-model:filters="filters"
                :globalFilterFields="['username', 'email', 'roleName']"
                class="p-datatable-lg"
            >
                <template #header>
                    <div class="flex justify-end">
                        <IconField>
                            <InputIcon class="pi pi-search" />
                            <InputText v-model="filters['global'].value" placeholder="Поиск пользователя..." />
                        </IconField>
                    </div>
                </template>

                <template #empty>Пользователи не найдены.</template>

                <Column header="Пользователь" sortable field="username" style="min-width: 250px">
                    <template #body="{ data }">
                        <div class="flex items-center gap-3">
                            <Avatar :label="data.username[0].toUpperCase()" shape="circle" class="bg-brand-secondary text-white" />
                            <div class="flex flex-col">
                                <span class="font-bold">{{ data.username }}</span>
                                <span class="text-xs text-gray-500">{{ data.email }}</span>
                            </div>
                        </div>
                    </template>
                </Column>

                <Column header="Роль" field="roleName" sortable style="min-width: 100px">
                    <template #body="{ data }">
                        <Tag :value="data.roleName" :severity="data.roleName === 'Admin' ? 'info' : 'secondary'" />
                    </template>
                </Column>

                <Column header="Статус" field="isBanned" sortable style="min-width: 100px">
                    <template #body="{ data }">
                        <Tag 
                            :value="data.isBanned ? 'BANNED' : 'ACTIVE'" 
                            :severity="data.isBanned ? 'danger' : 'success'" 
                        />
                    </template>
                </Column>

                <Column header="Баланс" field="balance" sortable style="min-width: 150px">
                    <template #body="{ data }">
                        <span class="font-mono font-bold" :class="{'text-green-600': data.balance > 0}">
                            ${{ data.balance.toFixed(2) }}
                        </span>
                    </template>
                </Column>

                <Column header="Действия" style="min-width: 150px">
                    <template #body="{ data }">
                        <div class="flex gap-2">
                            <Button 
                                icon="pi pi-dollar" 
                                severity="success" 
                                text 
                                rounded 
                                v-tooltip="'Изменить баланс'"
                                @click="openBalanceDialog(data)"
                            />
                            
                            <Button 
                                v-if="data.roleName !== 'Admin' || data.userId !== 1"
                                :icon="data.isBanned ? 'pi pi-lock-open' : 'pi pi-lock'" 
                                :severity="data.isBanned ? 'success' : 'danger'" 
                                text 
                                rounded 
                                v-tooltip="data.isBanned ? 'Разблокировать' : 'Заблокировать'"
                                @click="toggleBan($event, data)"
                            />
                        </div>
                    </template>
                </Column>
            </DataTable>
        </div>

        <Dialog v-model:visible="adminDialog" modal header="Назначить Администратора" class="w-full max-w-sm">
            <div class="flex flex-col gap-4 pt-2">
                <div class="flex flex-col gap-2">
                    <label class="font-bold">Логин</label>
                    <InputText v-model="adminForm.username" placeholder="Admin_Alex" />
                </div>
                <div class="flex flex-col gap-2">
                    <label class="font-bold">Пароль</label>
                    <Password v-model="adminForm.password" :feedback="false" toggleMask inputClass="w-full" />
                </div>
                <Button label="Создать" icon="pi pi-check" :loading="adminLoading" @click="createAdmin" />
            </div>
        </Dialog>

        <Dialog v-model:visible="balanceDialog" modal header="Корректировка Баланса" class="w-full max-w-sm">
            <div class="flex flex-col gap-4 pt-2">
                <div class="bg-blue-50 p-3 rounded text-sm text-blue-700">
                    Текущий баланс: <b>${{ balanceForm.currentBalance.toFixed(2) }}</b>
                </div>
                
                <div class="flex flex-col gap-2">
                    <label class="font-bold">Новый баланс</label>
                    <InputNumber 
                        v-model="balanceForm.newBalance" 
                        mode="currency" 
                        currency="USD" 
                        locale="en-US" 
                        class="w-full" 
                        inputClass="w-full"
                    />
                </div>
                
                <div class="flex justify-end gap-2 mt-2">
                    <Button label="Отмена" text severity="secondary" @click="balanceDialog = false" />
                    <Button label="Сохранить" icon="pi pi-save" :loading="balanceLoading" @click="saveBalance" />
                </div>
            </div>
        </Dialog>

    </div>
</template>