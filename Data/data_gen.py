import json
import random
import datetime
from math import sqrt

# --- КОНФИГУРАЦИЯ ---
TARGET_TOTAL_LOGS = 2500000  # Целевое количество логов (попадем в диапазон 100k-150k)
TIME_STEP_SECONDS = 60      # Шаг времени (1 минута)
OUTPUT_FILENAME = "business_scenario.json"

# --- ДАННЫЕ ИЗ ПРЕДЫДУЩЕГО ШАГА ---
sectors = [
    { "id": 10, "name": "Искусственный Интеллект (AI)", "desc": "Разработка LLM моделей, генеративные нейросети и AGI" },
    { "id": 11, "name": "Полупроводники и Чипы", "desc": "Производство процессоров, GPU и микросхем памяти" },
    { "id": 12, "name": "Облачные Вычисления", "desc": "Дата-центры, серверная инфраструктура и SaaS решения" },
    { "id": 13, "name": "Кибербезопасность", "desc": "Защита данных, шифрование и корпоративная безопасность" },
    { "id": 21, "name": "Метавселенные и AR/VR", "desc": "Виртуальная реальность и иммерсивные технологии" },
]

companies = [
    { "id": 1001, "sec_id": 10, "name": "OpenAI", "ticker": "OAI", "desc": "Лидер в области генеративного ИИ и создатель ChatGPT", "price": 850.50, "vol": 0.8, "stat": "ACTIVE", "shares": 500, "last_tr": "" },
    { "id": 1003, "sec_id": 11, "name": "NVIDIA", "ticker": "NVDA", "desc": "Главный поставщик железа для обучения нейросетей", "price": 1450.00, "vol": 0.6, "stat": "ACTIVE", "shares": 1000, "last_tr": "" },
    { "id": 1004, "sec_id": 11, "name": "TSMC", "ticker": "TSM", "desc": "Крупнейший в мире производитель полупроводников", "price": 210.15, "vol": 0.4, "stat": "ACTIVE", "shares": 800, "last_tr": "" },
    { "id": 1007, "sec_id": 12, "name": "Microsoft", "ticker": "MSFT", "desc": "Облако Azure и интеграция ИИ в офисные продукты", "price": 490.50, "vol": 0.3, "stat": "ACTIVE", "shares": 1500, "last_tr": "" },
    { "id": 1008, "sec_id": 12, "name": "Amazon Web Services", "ticker": "AMZN", "desc": "Лидер рынка облачной инфраструктуры", "price": 230.20, "vol": 0.4, "stat": "ACTIVE", "shares": 1200, "last_tr": "" },
    { "id": 1010, "sec_id": 13, "name": "Palantir", "ticker": "PLTR", "desc": "Аналитика больших данных и безопасность", "price": 45.80, "vol": 0.7, "stat": "ACTIVE", "shares": 900, "last_tr": "" },
    { "id": 1022, "sec_id": 21, "name": "Meta Platforms", "ticker": "META", "desc": "Социальные сети и VR гарнитуры Quest", "price": 610.10, "vol": 0.4, "stat": "ACTIVE", "shares": 950, "last_tr": "" },
    { "id": 1023, "sec_id": 21, "name": "Apple", "ticker": "AAPL", "desc": "Электроника, сервисы и гарнитуры Vision", "price": 245.00, "vol": 0.3, "stat": "ACTIVE", "shares": 200, "last_tr": "" },
    { "id": 1029, "sec_id": 11, "name": "Intel", "ticker": "INTC", "desc": "Производство процессоров и развитие фаундри-бизнеса", "price": 40.50, "vol": 0.4, "stat": "ACTIVE", "shares": 900, "last_tr": "" },
    { "id": 1031, "sec_id": 10, "name": "Google DeepMind", "ticker": "GOOGL_AI", "desc": "Подразделение Alphabet, сфокусированное на ИИ", "price": 195.00, "vol": 0.4, "stat": "ACTIVE", "shares": 11000, "last_tr": "" },
    { "id": 1034, "sec_id": 12, "name": "Oracle", "ticker": "ORCL", "desc": "Облачные базы данных и корпоративное ПО", "price": 175.40, "vol": 0.3, "stat": "ACTIVE", "shares": 600, "last_tr": "" },
    { "id": 1035, "sec_id": 13, "name": "Kaspersky Lab", "ticker": "KASP", "desc": "Антивирусное ПО и исследования угроз", "price": 65.00, "vol": 0.4, "stat": "ACTIVE", "shares": 300, "last_tr": "" }
]

def generate_price_logs():
    price_logs = []
    
    num_companies = len(companies)
    logs_per_company = TARGET_TOTAL_LOGS // num_companies
    
    # Время окончания - сейчас (UTC)
    end_time = datetime.datetime.utcnow()+datetime.timedelta(minutes=25)
    # Время начала = сейчас минус (количество логов * шаг времени)
    start_time = end_time - datetime.timedelta(seconds=logs_per_company * TIME_STEP_SECONDS)
    
    global_log_id = 1
    
    print(f"Генерация данных...")
    print(f"Компаний: {num_companies}")
    print(f"Логов на компанию: {logs_per_company}")
    print(f"Старт симуляции: {start_time}")
    print(f"Конец симуляции: {end_time}")

    for company in companies:
        current_price = company['price']
        volatility = company['vol']
        
        # Симулируем движение цены "в прошлом", чтобы прийти к текущей цене ('price')
        # Для реалистичности мы пойдем наоборот: начнем с некой цены в прошлом и приведем её к текущей
        # Или проще: возьмем текущую цену как финал, и сгенерируем "Random Walk" назад, 
        # но для хронологической правильности логов лучше сгенерировать путь вперед.
        
        # Чтобы график был красивым, допустим, что current_price из конфига - это цена НАЧАЛА периода.
        # Цена в конце периода (last_tr) обновится автоматически.
        
        simulated_price = current_price
        
        # Временной курсор для этой компании
        cursor_time = start_time
        
        company_logs = []
        
        for _ in range(logs_per_company):
            # Генерация изменения цены (Random Walk с нормальным распределением)
            # volatility в конфиге годовая (0.5 = 50%). Масштабируем до минутного шага.
            # Упрощенная формула волатильности для малых шагов.
            # 0.002 - коэффициент "шума" для красоты графика.
            
            shock = random.gauss(0, volatility * 0.002) 
            simulated_price = simulated_price * (1 + shock)
            
            # Округляем до 2 знаков
            final_price = round(simulated_price, 2)
            if final_price < 0.01: final_price = 0.01 # Защита от отрицательных цен
            
            log_entry = {
                "id": 0, # Временно 0, проставим глобальные ID позже при сортировке
                "cid": company['id'],
                "pr": final_price,
                "tm": cursor_time.strftime('%Y-%m-%dT%H:%M:%S.%f') # Добавляем Z для указания UTC
            }
            
            company_logs.append(log_entry)
            cursor_time += datetime.timedelta(seconds=TIME_STEP_SECONDS)
            
        # Обновляем 'last_tr' и цену компании в основном списке на основе последнего лога
        if company_logs:
            last_log = company_logs[-1]
            company['price'] = last_log['pr']
            company['last_tr'] = last_log['tm']
            
        price_logs.extend(company_logs)

    # Сортируем все логи по времени, чтобы они шли в хронологическом порядке (имитация потока данных)
    print("Сортировка логов по времени...")
    price_logs.sort(key=lambda x: x['tm'])
    
    # Присваиваем уникальные ID по порядку
    for idx, log in enumerate(price_logs):
        log['id'] = idx + 1

    return price_logs

# --- ЗАПУСК ---
if __name__ == "__main__":
    generated_logs = generate_price_logs()
    
    final_data = {
        "sectors": sectors,
        "companies": companies,
        "price_logs": generated_logs
    }
    
    with open(OUTPUT_FILENAME, 'w', encoding='utf-8') as f:
        json.dump(final_data, f, ensure_ascii=False, indent=2)
        
    print(f"Готово! Сгенерировано {len(generated_logs)} записей.")
    print(f"Файл сохранен как: {OUTPUT_FILENAME}")