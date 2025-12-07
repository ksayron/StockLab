<script setup lang="ts">
import { ref } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { useRouter } from 'vue-router'
import Menubar from 'primevue/menubar'
import Button from 'primevue/button'
import Avatar from 'primevue/avatar'
import Badge from 'primevue/badge'
import Drawer from 'primevue/drawer'
// import NotificationList from ...

const auth = useAuthStore()
const router = useRouter()
const isNotificationOpen = ref(false)

const items = ref([
  {
    label: 'Рынок',
    icon: 'pi pi-chart-line',
    command: () => router.push('/'),
    // Стилизуем пункты меню, чтобы их было видно на синем
    class: 'text-brand-bg',
  },
  {
    label: 'Портфель',
    icon: 'pi pi-briefcase',
    visible: () => auth.isAuthenticated,
    command: () => router.push('/portfolio'),
    class: 'text-brand-bg ',
  },
    {
    label: 'Ордера',
    icon: 'pi pi-list',
    visible: () => auth.isAuthenticated,
    command: () => router.push('/orders'),
    class: 'text-brand-bg ',
  },
])

const onLogout = async () => {
  await auth.logout()
  router.push('/login')
}
</script>

<template>
  <div class="w-full bg-brand-primary text-brand-bg shadow-md">
    <div class="container mx-auto">
      <Menubar
        :model="items"
        class="!bg-transparent !border-none !rounded-none px-4 py-3 custom-menubar"
      >
        <template #start>
          <div
            class="font-bold text-2xl mr-8 flex items-center gap-2 cursor-pointer text-white"
            @click="router.push('/')"
          >
            <i class="pi pi-chart-bar text-brand-bg" />
            <span>StockLab</span>
          </div>
        </template>

        <template #end>
          <div class="flex items-center gap-3">
            <template v-if="auth.isAuthenticated">
              <div class="hidden md:flex flex-col items-end mr-2">
                <span class="font-mono font-bold text-lg text-green-400">
                  {{ auth.user?.balance.toFixed(2) }} $
                </span>
              </div>

              <Button
                icon="pi pi-bell"
                text
                rounded
                class="!text-brand-bg hover:!bg-brand-secondary"
                badge="2"
                @click="isNotificationOpen = true"
              >
                
              </Button>

              <Avatar
                :label="auth.user?.username[0]!.toUpperCase()"
                shape="circle"
                class="bg-brand-secondary text-white"
              />
              <div class="!text-brand-bg md:flex flex-col items-end mr-2">
                  {{ auth.user?.username }}
              </div>

              <Button
                icon="pi pi-sign-out"
                text
                rounded
                class="!text-brand-bg hover:!bg-brand-secondary"
                @click="onLogout"
                tooltip="Выйти"
              />
            </template>

            <template v-else>
              <router-link to="/login">
                <Button
                  label="Войти"
                  class="!bg-brand-secondary !border-brand-secondary hover:!bg-white hover:!text-brand-primary mr-2"
                />
              </router-link>
              <router-link to="/register">
                <Button
                  label="Регистрация"
                  outlined
                  class="!text-brand-bg !border-brand-bg hover:!bg-brand-bg hover:!text-brand-primary"
                />
              </router-link>
            </template>
          </div>
        </template>
      </Menubar>
    </div>

    <Drawer
      v-model:visible="isNotificationOpen"
      position="right"
      header="Уведомления"
      class="!w-full md:!w-80 lg:!w-[30rem]"
    >
      <p class="text-gray-600">Здесь будет список уведомлений...</p>
    </Drawer>
  </div>
</template>

<style>
.custom-menubar .p-menubar-item-link {
  color: #edf2fb !important; /* brand-bg */
}
.custom-menubar .p-menubar-item-link:hover {
  background-color: #1a659e !important; /* brand-secondary */
}
.custom-menubar .p-menubar-item-icon {
  color: #edf2fb !important;
}
</style>
