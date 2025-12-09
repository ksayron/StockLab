<script setup lang="ts">
import { onMounted,watch } from 'vue'
import { RouterView } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { useNotificationStore } from '@/stores/notifications'
import { useToast } from 'primevue/usetoast';
import Header from '@/components/Header.vue'
import Footer from '@/components/Footer.vue'
import Toast from 'primevue/toast' // Глобальный контейнер для уведомлений

const authStore = useAuthStore()
const notifStore = useNotificationStore();
const toast = useToast();

onMounted(async () => {
  // При старте приложения пытаемся восстановить сессию
  // Если кука AuthToken есть и валидна, стор обновится и статус станет isAuthenticated = true
  await authStore.checkAuth()
  if (authStore.isAuthenticated) {
        notifStore.connect(toast);
        notifStore.fetchHistory();
    }
})

watch(() => authStore.isAuthenticated, (isAuth) => {
    if (isAuth) {
        notifStore.connect(toast);
        notifStore.fetchHistory();
    } else {
        notifStore.disconnect();
    }
});
</script>

<template>
  <Toast />

  <div class="min-h-screen bg-surface-50 dark:bg-surface-900 flex flex-col">
    <Header />

    <main class="flex-grow w-full py-10 px-4 md:px-[200px] justify-items-center">
      <RouterView v-slot="{ Component }">
        <transition name="fade" mode="out-in">
          <component :is="Component" />
        </transition>
      </RouterView>
    </main>

    <footer class="w-full bg-brand-primary text-white mt-auto">
      <Footer />
    </footer>
  </div>
</template>

<style scoped>
/* Анимация перехода между страницами */
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.2s ease;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}
/* Глобальные стили для скроллбара (опционально, чтобы красиво смотрелось на синем) */
::-webkit-scrollbar {
  width: 8px;
}
::-webkit-scrollbar-track {
  background: #edf2fb;
}
::-webkit-scrollbar-thumb {
  background: #1a659e;
  border-radius: 4px;
}
::-webkit-scrollbar-thumb:hover {
  background: #004e89;
}
</style>
