import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import { HubConnectionBuilder, HubConnection } from '@microsoft/signalr';
import api from '@/services/api';
import type { ToastServiceMethods } from 'primevue/toastservice'; // Типизация для Toast

export interface Notification {
    id: number;
    title: string;
    message: string;
    type: 'INFO' | 'SUCCESS' | 'WARNING' | 'ERROR' | 'TRADE';
    isRead: boolean;
    createdAt: string;
}

export const useNotificationStore = defineStore('notifications', () => {
    const notifications = ref<Notification[]>([]);
    const connection = ref<HubConnection | null>(null);
    const isConnected = ref(false);

    // Геттер для бейджика (строка для PrimeVue, или null чтобы скрыть)
    const unreadCount = computed(() => {
        const count = notifications.value.filter(n => !n.isRead).length;
        return count > 0 ? count.toString() : null;
    });

    // 1. Загрузка истории (REST)
    async function fetchHistory() {
        try {
            const res = await api.get('/Notification'); // ?unreadOnly=false по умолчанию
            notifications.value = res.data.data;
            console.log(notifications.value)
        } catch (e) {
            console.error('Failed to fetch notifications', e);
        }
    }

    // 2. Пометить как прочитанное
    async function markAsRead(id: number) {
        // Оптимистичное обновление UI (сразу красим в прочитанное)
        const notif = notifications.value.find(n => n.id === id);
        if (notif && !notif.isRead) {
            notif.isRead = true;
            // Отправляем на сервер
            try {
                await api.post(`/Notification/${id}/read`);
            } catch (e) {
                console.error('Failed to mark read', e);
                notif.isRead = false; // Откат при ошибке
            }
        }
    }

    // 3. Подключение к SignalR
    async function connect(toast: ToastServiceMethods) {
        if (connection.value || isConnected.value) return;

        const hubUrl = `${import.meta.env.VITE_API_URL?.replace('/api', '')}/hubs/notifications`;

        connection.value = new HubConnectionBuilder()
            .withUrl(hubUrl) // Куки отправятся автоматически благодаря withCredentials браузера
            .withAutomaticReconnect()
            .build();

        // === СЛУШАТЕЛЬ СОБЫТИЙ ===
        connection.value.on('ReceiveNotifications', (newNotifs: Notification[]) => {
            // 1. Добавляем в начало списка
            notifications.value.unshift(...newNotifs);

            // 2. Показываем Toast для каждого нового сообщения
            newNotifs.forEach(n => {
                toast.add({
                    severity: mapTypeToSeverity(n.type),
                    summary: n.title,
                    detail: n.message,
                    life: 5000,
                    group: 'br' // Можно настроить позицию (bottom-right)
                });
            });
        });

        try {
            await connection.value.start();
            isConnected.value = true;
            console.log('SignalR Connected');
            
            // Сразу после подключения грузим историю, чтобы синхронизироваться
            await fetchHistory();
        } catch (err) {
            console.error('SignalR Connection Error: ', err);
        }
    }

    // 4. Отключение (при логауте)
    function disconnect() {
        if (connection.value) {
            connection.value.stop();
            connection.value = null;
            isConnected.value = false;
            notifications.value = []; // Чистим список при выходе
        }
    }

    // Хелпер для цветов Toast
    function mapTypeToSeverity(type: string) {
        switch (type) {
            case 'ERROR': return 'error';
            case 'WARNING': return 'warn';
            case 'SUCCESS': return 'success';
            case 'TRADE': return 'info'; // Для сделок синий цвет
            default: return 'info';
        }
    }

    return { notifications, unreadCount, connect, disconnect, markAsRead, fetchHistory };
});