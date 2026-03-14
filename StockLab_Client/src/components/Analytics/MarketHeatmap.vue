<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { use } from 'echarts/core';
import { TreemapChart } from 'echarts/charts';
import { TitleComponent, TooltipComponent, VisualMapComponent } from 'echarts/components';
import { CanvasRenderer } from 'echarts/renderers';
import VChart, { THEME_KEY } from 'vue-echarts';
import api from '@/services/api';

// Регистрируем нужные модули ECharts (для уменьшения размера бандла)
use([TreemapChart, TitleComponent, TooltipComponent, VisualMapComponent, CanvasRenderer]);

const loading = ref(true);
const chartData = ref<any[]>([]);

// --- ТРАНСФОРМАЦИЯ ДАННЫХ ---
const transformData = (rawData: any[]) => {
  // Группировка по секторам
  const groups: Record<string, any[]> = {};

  rawData.forEach(item => {
    if (!groups[item.level1]) groups[item.level1] = [];

    groups[item.level1]?.push({
      name: item.level2, // Имя компании
      // В ECharts value может быть массивом!
      // [0] = Размер (Объем)
      // [1] = Цвет (Изменение %)
      // [2] = Статус (Для тултипа)
      value: [
        item.totalVolume || 1, 
        item.weightedChange || 0,
        item.status
      ],
    });
  });

  // Формируем структуру для ECharts
  return Object.keys(groups).map(sector => ({
    name: sector,
    children: groups[sector],
    // Настройки отображения уровня Секторов
    itemStyle: {
      borderColor: '#fff',
      borderWidth: 2,
      gapWidth: 2
    }
  }));
};

// --- НАСТРОЙКИ ГРАФИКА (OPTION) ---
const option = computed(() => {
  return {
    tooltip: {
      formatter: function (info: any) {
        // info.data - это наш объект из transformData
        // info.value - это массив [vol, change, status]
        if (!info.value || !Array.isArray(info.value)) return ''; 

        const name = info.name;
        const vol = Math.floor(info.value[0]).toLocaleString();
        const change = info.value[1].toFixed(2);
        const status = info.value[2];
        
        // Цвет текста изменения
        const color = info.value[1] >= 0 ? '#4ade80' : '#f87171'; // Green : Red

        return `
          <div class="text-sm font-sans">
            <div class="font-bold mb-1">${name}</div>
            <div class="flex justify-between gap-4 text-gray-300">
              <span>Объем:</span> <span class="text-white font-mono">$${vol}</span>
            </div>
            <div class="flex justify-between gap-4 text-gray-300">
              <span>Изменение:</span> <span style="color: ${color}" class="font-bold">${change}%</span>
            </div>
            <div class="mt-1 text-xs text-gray-500">${status}</div>
          </div>
        `;
      },
      backgroundColor: 'rgba(30, 41, 59, 0.9)', // Dark slate bg
      borderColor: '#334155',
      textStyle: { color: '#fff' }
    },
    
    // --- ЦВЕТОВАЯ ШКАЛА (VISUAL MAP) ---
    // Это сердце раскраски. Мы мапим index 1 (weightedChange) на цвета.
    visualMap: {
      type: 'continuous',
      dimension: 1, // Используем второй элемент массива value ([vol, CHANGE, status])
      min: -5,
      max: 5,
      text: ['Рост', 'Падение'],
      calculable: true,
      inRange: {
        // Градиент: Красный -> Серый -> Зеленый
        color: ['#ef4444', '#f3f4f6', '#22c55e'] 
      },
      orient: 'horizontal',
      left: 'center',
      bottom: 0
    },

    series: [
      {
        name: 'Market',
        type: 'treemap',
        width: '100%',
        height: '90%',
        top: 0,
        data: chartData.value,
        
        // Настройка лейблов (текста)
        label: {
          show: true,
          formatter: function(params: any) {
             // params.value[1] это change
             const change = params.value[1] ? params.value[1].toFixed(1) + '%' : '0%';
             return `{name|${params.name}}\n{val|${change}}`;
          },
          rich: {
            name: {
              fontSize: 14,
              fontWeight: 'bold',
              color: '#fff',
              textBorderColor: 'rgba(0,0,0,0.5)',
              textBorderWidth: 2
            },
            val: {
              fontSize: 11,
              color: '#f1f5f9',
              textBorderColor: 'rgba(0,0,0,0.5)',
              textBorderWidth: 2,
              align: 'center',
              padding: [2, 0, 0, 0]
            }
          }
        },
        
        // Настройка уровней вложенности
        itemStyle: {
          borderColor: '#fff'
        },
        levels: [
          {
            itemStyle: {
              borderColor: '#fff',
              borderWidth: 0,
              gapWidth: 1
            }
          },
          {
            colorSaturation: [0.35, 0.5],
            itemStyle: {
              borderColor: '#fff',
              borderWidth: 2,
              gapWidth: 1
            }
          }
        ],
        breadcrumb: { show: false } // Отключаем "хлебные крошки" снизу
      }
    ]
  };
});

const loadData = async () => {
  loading.value = true;
  try {
    const res = await api.get('/Analytics/heatmap');
    if (res.data.success) {
      chartData.value = transformData(res.data.data);
    }
  } catch (e) {
    console.error(e);
  } finally {
    loading.value = false;
  }
};

onMounted(() => {
  loadData();
});
</script>

<template>
  <div class="w-full h-full flex flex-col bg-white rounded-lg shadow border border-surface-200 overflow-hidden">
    <div class="p-4 border-b border-gray-100 flex justify-between items-center bg-gray-50">
      <h3 class="font-bold text-gray-700">Карта Рынка</h3>
      <div v-if="loading"><i class="pi pi-spin pi-spinner text-brand-primary"></i></div>
    </div>
    
    <div class="flex-grow w-full min-h-[500px] relative">
      <v-chart class="chart" :option="option" autoresize />
    </div>
  </div>
</template>

<style scoped>
.chart {
  height: 100%;
  width: 100%;
}
</style>