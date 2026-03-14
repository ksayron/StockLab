<script setup lang="ts">
import MarketHeatmap from '@/components/Analytics/MarketHeatmap.vue';

</script>

<template>
    <div class="flex flex-col gap-6 h-[calc(100vh-100px)] w-full"> 
        <div class="flex justify-between items-end">
            <div>
                <h1 class="text-3xl font-bold text-brand-primary">Аналитика Биржи</h1>
                <p class="text-gray-500">Глобальное состояние рынка в реальном времени</p>
            </div>
        </div>

        <div class="w-full h-full pb-6">
            <MarketHeatmap />
        </div>
    </div>
</template>