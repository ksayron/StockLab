,<script setup lang="ts">
import { useNotificationStore } from '@/stores/notifications';
import { computed } from 'vue';
import Button from 'primevue/button';
import Tag from 'primevue/tag';

const store = useNotificationStore();

// Сортировка: Сначала новые, потом старые
const sortedNotifications = computed(() => {
    return [...store.notifications].sort((a, b) => 
        new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
    );
});

const getIcon = (type: string) => {
    switch (type) {
        case 'TRADE': return 'pi pi-wallet';
        case 'SUCCESS': return 'pi pi-check-circle';
        case 'ERROR': return 'pi pi-times-circle';
        case 'WARNING': return 'pi pi-exclamation-triangle';
        default: return 'pi pi-info-circle';
    }
};

const getBgColor = (type: string) => {
    switch (type) {
        case 'TRADE': return 'bg-blue-50 text-blue-600';
        case 'SUCCESS': return 'bg-green-50 text-green-600';
        case 'ERROR': return 'bg-red-50 text-red-600';
        default: return 'bg-gray-50 text-gray-600';
    }
};

const formatTime = (isoString: string) => {
    return new Date(isoString).toLocaleString('ru-RU', {
        day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit'
    });
};
</script>

<template>
    <div class="flex flex-col gap-3 pb-4">
        <div v-if="store.notifications.length === 0" class="text-center text-gray-500 mt-10">
            <i class="pi pi-bell-slash text-4xl mb-2 opacity-50"></i>
            <p>Нет новых уведомлений</p>
        </div>

        <div 
            v-for="item in sortedNotifications" 
            :key="item.id"
            class="relative p-3 rounded-lg border transition-all hover:shadow-md cursor-pointer group"
            :class="[
                item.isRead ? 'bg-white border-gray-100 opacity-70' : 'bg-white border-brand-secondary shadow-sm'
            ]"
            @click="store.markAsRead(item.id)"
        >
            <div v-if="!item.isRead" class="absolute top-3 right-3 w-2 h-2 rounded-full bg-brand-secondary"></div>

            <div class="flex gap-3">
                <div class="flex-shrink-0 w-10 h-10 rounded-full flex items-center justify-center" :class="getBgColor(item.type)">
                    <i :class="getIcon(item.type)" class="text-lg"></i>
                </div>

                <div class="flex flex-col flex-grow">
                    <div class="flex justify-between items-start pr-4">
                        <span class="font-bold text-sm text-gray-800">{{ item.title }}</span>
                    </div>
                    
                    <p class="text-xs text-gray-600 mt-1 leading-relaxed whitespace-pre-line">
                        {{ item.message }}
                    </p>
                    
                    <span class="text-[10px] text-gray-400 mt-2 text-right w-full block">
                        {{ formatTime(item.createdAt) }}
                    </span>
                </div>
            </div>
        </div>
    </div>
</template>