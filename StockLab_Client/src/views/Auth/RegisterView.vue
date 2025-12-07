<script setup lang="ts">
import { ref } from 'vue';
import { useRouter } from 'vue-router';
import { useToast } from 'primevue/usetoast';
import api from '@/services/api'; // Наш настроенный Axios

// Компоненты PrimeVue
import InputText from 'primevue/inputtext';
import Password from 'primevue/password';
import Button from 'primevue/button';
import Message from 'primevue/message';
import IftaLabel from 'primevue/iftalabel'; // Красивые плавающие лейблы (опционально, но стильно)

const router = useRouter();
const toast = useToast();

// Состояние формы
const form = ref({
    username: '',
    email: '',
    password: ''
});

const loading = ref(false);
const errorMsg = ref('');

// Валидация перед отправкой
const isValid = () => {
    if (!form.value.username || !form.value.email || !form.value.password) {
        errorMsg.value = 'Пожалуйста, заполните все поля';
        return false;
    }
    if (form.value.password.length < 4) {
        errorMsg.value = 'Пароль слишком короткий';
        return false;
    }
    return true;
};

const handleRegister = async () => {
    errorMsg.value = '';
    
    if (!isValid()) return;

    loading.value = true;

    try {
        // POST /api/User/register
        const response = await api.post('/User/register', {
            username: form.value.username,
            email: form.value.email,
            passwordHash: form.value.password
        });

        if (response.data.success) {
            toast.add({ 
                severity: 'success', 
                summary: 'Успех', 
                detail: 'Аккаунт создан! Теперь вы можете войти.', 
                life: 3000 
            });
            
            // Даем пользователю секунду прочитать сообщение и перекидываем на логин
            setTimeout(() => {
                router.push('/login');
            }, 1500);
        }
    } catch (err: any) {
        // Обработка ошибок (409 Conflict - имя занято, 500 - сервер)
        if (err.response && err.response.data && err.response.data.message) {
            errorMsg.value = err.response.data.message;
        } else {
            errorMsg.value = 'Ошибка соединения с сервером';
        }
    } finally {
        loading.value = false;
    }
};
</script>

<template>
    <div class="flex justify-center items-center min-h-[80vh] w-full max-w-xl">
        <div class="content-card w-full max-w-3xl shadow-lg !border-t-4 !border-t-brand-primary">
            
            <div class="text-center mb-8">
                <h1 class="text-2xl font-bold text-brand-primary mb-2">Создать аккаунт</h1>
                <p class="text-sm text-gray-500">Присоединяйтесь к StockLab сегодня</p>
            </div>

            <form @submit.prevent="handleRegister" class="flex flex-col gap-5">
                
                <Message v-if="errorMsg" severity="error" :closable="false" class="mb-2">
                    {{ errorMsg }}
                </Message>

                <div class="flex flex-col gap-2">
                    <label for="username" class="font-medium text-gray-700">Имя пользователя</label>
                    <InputText 
                        id="username" 
                        v-model="form.username" 
                        placeholder="Trader_John" 
                        class="w-full"
                        :disabled="loading"
                    />
                </div>

                <div class="flex flex-col gap-2">
                    <label for="email" class="font-medium text-gray-700">Email</label>
                    <InputText 
                        id="email" 
                        v-model="form.email" 
                        type="email" 
                        placeholder="yourmail@example.com" 
                        class="w-full"
                        :disabled="loading"
                    />
                </div>

                <div class="flex flex-col gap-2">
                    <label for="password" class="font-medium text-gray-700">Пароль</label>
                    <Password 
                        id="password" 
                        v-model="form.password" 
                        :feedback="true" 
                        toggleMask 
                        placeholder="••••••••"
                        class="w-full"
                        inputClass="w-full"
                        :disabled="loading"
                        promptLabel="Введите пароль"
                        weakLabel="Слабый"
                        mediumLabel="Средний"
                        strongLabel="Надежный"
                    />
                </div>

                <Button 
                    type="submit" 
                    label="Зарегистрироваться" 
                    icon="pi pi-user-plus" 
                    :loading="loading"
                    class="w-full mt-2 font-bold"
                />

                <div class="text-center mt-4 text-sm text-gray-600">
                    Уже есть аккаунт? 
                    <router-link to="/login" class="text-brand-secondary font-bold hover:underline">
                        Войти
                    </router-link>
                </div>
            </form>
        </div>
    </div>
</template>

<style scoped>
/* Дополнительная настройка для PrimeVue Password, чтобы он занимал 100% ширины */
:deep(.p-password) {
    width: 100%;
}
</style>