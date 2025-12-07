<script setup lang="ts">
import { ref, computed } from 'vue';
import { useToast } from 'primevue/usetoast';
import api from '@/services/api';
import Dialog from 'primevue/dialog';
import InputNumber from 'primevue/inputnumber';
import Button from 'primevue/button';

const props = defineProps<{
    visible: boolean;
    type: 'BUY' | 'SELL';
    company: any; // CompanyDto или PortfolioItemDto
    maxQty?: number; // Для продажи (сколько есть в наличии)
}>();

const emit = defineEmits(['update:visible', 'success']);

const toast = useToast();
const loading = ref(false);
const form = ref({ quantity: 1, price: 0 });

// При открытии инициализируем цену
const onShow = () => {
    form.value.quantity = 1;
    form.value.price = props.company.currentPrice;
};

const total = computed(() => form.value.quantity * form.value.price);

const submit = async () => {
    loading.value = true;
    try {
        await api.post('/Trading/order', {
            companyId: props.company.companyId || props.company.id, // Поддержка разных DTO
            type: props.type,
            quantity: form.value.quantity,
            limitPrice: form.value.price
        });
        
        toast.add({ severity: 'success', summary: 'Успех', detail: 'Ордер создан', life: 3000 });
        emit('update:visible', false);
        emit('success');
    } catch (e: any) {
        toast.add({ severity: 'error', summary: 'Ошибка', detail: e.response?.data?.message || 'Сбой', life: 3000 });
    } finally {
        loading.value = false;
    }
};
</script>

<template>
    <Dialog 
        :visible="visible" 
        @update:visible="emit('update:visible', $event)"
        modal 
        @show="onShow"
        :header="type === 'BUY' ? `Покупка ${company?.name}` : `Продажа ${company?.name}`" 
        class="w-full max-w-sm"
    >
        <div class="flex flex-col gap-4 pt-2">
            <div class="flex flex-col gap-2">
                <label class="font-bold">Количество</label>
                <InputNumber v-model="form.quantity" showButtons :min="1" :max="type === 'SELL' ? maxQty : 1000000" inputClass="w-full" />
                <small v-if="type === 'SELL'" class="text-gray-500">Доступно: {{ maxQty }} шт.</small>
            </div>

            <div class="flex flex-col gap-2">
                <label class="font-bold">Цена (Лимит)</label>
                <InputNumber v-model="form.price" mode="currency" currency="USD" locale="en-US" :minFractionDigits="2" inputClass="w-full" />
            </div>

            <div class="bg-surface-100 dark:bg-surface-800 p-3 rounded text-center my-2">
                <div class="text-xs text-gray-500">Итого</div>
                <div class="font-bold text-xl text-brand-primary">${{ total.toFixed(2) }}</div>
            </div>

            <div class="flex justify-end gap-2">
                <Button label="Отмена" text severity="secondary" @click="emit('update:visible', false)" />
                <Button 
                    :label="type === 'BUY' ? 'Купить' : 'Продать'" 
                    :class="type === 'BUY' ? '!bg-trade-success !border-trade-success' : '!bg-trade-danger !border-trade-danger'"
                    :loading="loading"
                    @click="submit"
                />
            </div>
        </div>
    </Dialog>
</template>