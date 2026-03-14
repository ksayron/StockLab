<script setup lang="ts">
import { ref, onMounted, onUnmounted, watch } from 'vue';
import anychart from 'anychart'; // Убедись, что пакет установлен: npm i anychart

// Интерфейс данных из стора
import type { WindroseData } from '@/stores/bots';

const props = defineProps<{
    data: WindroseData | null;
    color: string;
}>();

const chartContainer = ref<HTMLElement | null>(null);
let chart: any = null;

const normalize = (val: number, min: number, max: number) => {
        if (val === undefined || val === null) return 0;
        
        // Формула: (X - Min) / (Max - Min)
        const result = (val - min) / (max - min);
        
        // Ограничиваем результат диапазоном 0..1, чтобы график не ломался,
        // если вдруг придут данные выходящие за пределы (например, жадность 1.35)
        return Math.max(0, Math.min(1, result));
    };

const prepareData = (d: WindroseData) => {


    return [
        { 
            x: 'Жадность', 
            // Диапазон 1.0 ... 1.3 (разница 0.3)
            // Пример: если 1.15 -> (1.15 - 1.0) / 0.3 = 0.5 (середина графика)
            value: normalize(d.avgGreed, 1.0, 1.3) 
        },
        { 
            x: 'Паника', 
            // Диапазон 0.5 ... 1.0 (разница 0.5)
            // Пример: если 0.75 -> (0.75 - 0.5) / 0.5 = 0.5
            value: normalize(d.avgPanic, 0.5, 1.0) 
        },
        { 
            x: 'Память', 
            // Уже нормализована делением на 20 (если 20 это максимум)
            // Добавим clamp на всякий случай
            value: Math.max(0, Math.min(1, d.avgMemory / 20)) 
        },
        { 
            x: 'Риск', 
            // Уже в диапазоне 0-1
            value: Math.max(0, Math.min(1, d.avgBetSize)) 
        }
    ];
};

const createChart = () => {
    if (!chartContainer.value || !props.data) return;

    // Очищаем контейнер если там что-то было
    chartContainer.value.innerHTML = '';

    // Создаем Radar Chart
    chart = anychart.radar();

    // Настройки данных
    const chartData = anychart.data.set(prepareData(props.data));
    
    // Создаем серию Area (залитая область)
    const series = chart.area(chartData);
    
    // Стилизация
    series.name(props.data.category);
    series.fill(props.color + '33'); // 20% прозрачности (HEX + 33)
    series.stroke(props.color, 2);
    series.markers().enabled(true).size(3).fill(props.color).stroke('white');

    // Настройка осей (фиксируем масштаб, чтобы графики были сравнимы)
    chart.yScale().minimum(0);
    chart.yScale().maximum(1.5);
    chart.yScale().ticks().interval(0.5);
    
    // Убираем лишние подписи оси Y для чистоты
    chart.yAxis().labels(false);
    
    // Сетка
    chart.xGrid().stroke("#e0e0e0");
    chart.yGrid().stroke("#e0e0e0");

    // Легенда и Тультип
    chart.tooltip().format("Значение: {%Value}");
    chart.interactivity().hoverMode('by-x');

    // Убираем водяной знак (только для учебных целей)
    const credits = chart.credits();
    credits.enabled(false);

    // Рендер
    chart.container(chartContainer.value);
    chart.draw();
};

// Реактивное обновление данных при приходе пакета по WebSocket
watch(() => props.data, (newVal) => {
    if (chart && newVal) {
        // Обновляем данные без перерисовки всего графика
        const newData = prepareData(newVal);
        chart.data(newData);
    } else if (newVal) {
        createChart();
    }
}, { deep: true });

onMounted(() => {
    if (props.data) createChart();
});

onUnmounted(() => {
    if (chart) {
        chart.dispose();
        chart = null;
    }
});
</script>

<template>
    <div ref="chartContainer" class="w-full h-64"></div>
</template>