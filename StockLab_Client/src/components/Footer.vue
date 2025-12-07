<script setup lang="ts">
// Здесь логики пока нет, только статика
</script>

<template>
  <footer class="bg-brand-primary text-brand-bg py-8 mt-auto border-t border-brand-secondary">
    <div class="container mx-auto px-4">
      <div class="flex flex-col md:flex-row justify-between items-center gap-4">
        <div class="text-center md:text-left">
          <h3 class="font-bold text-lg mb-1">StockLab Development</h3>
          <p class="text-sm opacity-80">
            Симулятор фондовой биржи для обучения и тестирования стратегий.
          </p>
          <p class="text-xs mt-2 opacity-60">
            &copy; {{ new Date().getFullYear() }} Все права защищены.
          </p>
        </div>

        <div class="flex flex-col items-center md:items-end gap-2 text-sm">
          <span class="font-bold text-brand-bg opacity-90">Контакты</span>

          <a
            href="https://github.com/ksayron/"
            target="_blank"
            class="hover:text-white transition-colors flex items-center gap-2"
          >
            <i class="pi pi-github"></i>
            GitHub
          </a>

          <span class="flex items-center gap-2 opacity-80">
            <i class="pi pi-map-marker"></i>
            Paphos, Cyprus
          </span>
        </div>
      </div>
    </div>
  </footer>
</template>
