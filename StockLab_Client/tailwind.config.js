/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{vue,js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        // Ваша палитра
        brand: {
          primary: '#004e89',   // Основной (Темно-синий)
          secondary: '#1a659e', // Дополнительный (Синий)
          bg: '#edf2fb',        // Фоновый (Светло-голубой/Белый)
          text: '#ffffff'       // Белый для текста на темном фоне (можно использовать brand.bg)
        }
      }
    },
  },
  plugins: [require('tailwindcss-primeui')],
}