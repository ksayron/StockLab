<script setup lang="ts">
import { ref } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { useRouter } from 'vue-router'
import InputText from 'primevue/inputtext'
import Password from 'primevue/password'
import Button from 'primevue/button'
import Message from 'primevue/message'
import { useToast } from 'primevue/usetoast';

const auth = useAuthStore()
const router = useRouter()
const toast = useToast();

const form = ref({
    username: '',
    password: ''
});
const errorMsg = ref('')

const handleLogin = async () => {
  errorMsg.value = ''
  try {
    await auth.login({ username: form.value.username, passwordHash: form.value.password })
    toast.add({ 
                severity: 'success', 
                summary: 'Успех', 
                detail: 'С возвращением, '+form.value.username+'!', 
                life: 3000 
            });
            
            // Даем пользователю секунду прочитать сообщение и перекидываем на логин
            setTimeout(() => {
                router.push('/');
            }, 1500);
  } catch (err: any) {
    errorMsg.value = err.response?.data?.message || 'Ошибка входа'
  }
}
</script>

<template>
  <div class="flex justify-center items-center min-h-[80vh] w-full max-w-xl">
        <div class="content-card w-full max-w-3xl shadow-lg !border-t-4 !border-t-brand-primary">
            
            <div class="text-center mb-8">
                <h1 class="text-2xl font-bold text-brand-primary mb-2">Создать аккаунт</h1>
                <p class="text-sm text-gray-500">Присоединяйтесь к StockLab сегодня</p>
            </div>

            <form @submit.prevent="handleLogin" class="flex flex-col gap-5">
                
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
                        :disabled="auth.isLoading"
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
                        :disabled="auth.isLoading"
                        promptLabel="Введите пароль"
                        weakLabel="Слабый"
                        mediumLabel="Средний"
                        strongLabel="Надежный"
                    />
                </div>

                <Button 
                    type="submit" 
                    label="Войти" 
                    icon="pi pi-user-plus" 
                    :loading="auth.isLoading"
                    class="w-full mt-2 font-bold"
                />

                <div class="text-center mt-4 text-sm text-gray-600">
          Нет аккаунта? <router-link to="/register" class="text-brand-secondary font-bold hover:underline">Регистрация</router-link>
                </div>
            </form>
        </div>
    </div>
</template>
