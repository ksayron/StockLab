import { defineStore } from 'pinia';
import { ref } from 'vue';
import { HubConnectionBuilder, HubConnection } from '@microsoft/signalr';
import api from '@/services/api';

// DTOs
export interface BotSummary {
    userId: number;
    username: string;
    netWorth: number;
    greedFactor: number;
    panicLevel: number;
    memorySpan: number;
    betSize: number;
    currentRank: number;
    lastRank: number | null;
}

export interface WindroseData {
    category: string; 
    avgGreed: number;
    avgPanic: number;
    avgMemory: number;
    avgBetSize: number;
    avgRoi: number;
}

export const useBotStore = defineStore('botStore', () => {
    const bots = ref<BotSummary[]>([]);
    const windroseStats = ref<WindroseData[]>([]);
    const connection = ref<HubConnection | null>(null);
    const isConnected = ref(false);
    const tournamentStatus = ref<string>('UNKNOWN');

    // --- REST ACTIONS ---
    async function fetchBots() {
        try {
            const res = await api.get('/Bot');
            bots.value = res.data.data;
        } catch (e) {
            console.error('Error fetching bots', e);
        }
    }

    async function fetchInitialAnalytics() {
        try {
            // Загружаем начальное состояние, пока не прилетел WS пакет
            const res = await api.get('/Analytics/windrose');
            if(res.data.success) windroseStats.value = res.data.data;
        } catch (e) {
            console.error('Error fetching analytics', e);
        }
    }

    async function checkStatus() {
        try {
            const res = await api.get('/Bot/status');
            tournamentStatus.value = res.data.status;
        } catch (e) { console.error(e); }
    }

    // --- SIGNALR ACTIONS ---
    async function connectHub() {
        if (connection.value || isConnected.value) return;

        const hubUrl = `${import.meta.env.VITE_API_URL?.replace('/api', '')}/hubs/dashboard`;

        connection.value = new HubConnectionBuilder()
            .withUrl(hubUrl)
            .withAutomaticReconnect()
            .build();

        // Слушаем обновление Розы ветров
        connection.value.on('ReceiveWindrose', (data: WindroseData[]) => {
            windroseStats.value = data;
        });
        
        // Слушаем обновление списка (если реализуем событие обновления списка в будущем)
        // Пока список обновляем вручную или по таймеру, т.к. он тяжелый

        try {
            await connection.value.start();
            isConnected.value = true;
            console.log('Dashboard Hub Connected');
            
            // Грузим начальные данные
            await fetchInitialAnalytics();
            await checkStatus();
        } catch (err) {
            console.error('Dashboard Hub Error:', err);
        }
    }

    function disconnectHub() {
        if (connection.value) {
            connection.value.stop();
            connection.value = null;
            isConnected.value = false;
        }
    }

    return { 
        bots, 
        windroseStats, 
        tournamentStatus,
        fetchBots, 
        connectHub, 
        disconnectHub,
        checkStatus
    };
});