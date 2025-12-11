import json
import random
import datetime
from math import sqrt

# --- КОНФИГУРАЦИЯ ---
TARGET_TOTAL_LOGS = 125000  # Целевое количество логов (попадем в диапазон 100k-150k)
TIME_STEP_SECONDS = 60      # Шаг времени (1 минута)
OUTPUT_FILENAME = "business_scenario.json"

# --- ДАННЫЕ ИЗ ПРЕДЫДУЩЕГО ШАГА ---
sectors = [
    { "id": 10, "name": "Искусственный Интеллект (AI)", "desc": "Разработка LLM моделей, генеративные нейросети и AGI" },
    { "id": 11, "name": "Полупроводники и Чипы", "desc": "Производство процессоров, GPU и микросхем памяти" },
    { "id": 12, "name": "Облачные Вычисления", "desc": "Дата-центры, серверная инфраструктура и SaaS решения" },
    { "id": 13, "name": "Кибербезопасность", "desc": "Защита данных, шифрование и корпоративная безопасность" },
    { "id": 14, "name": "Квантовые Технологии", "desc": "Квантовые компьютеры и постквантовое шифрование" },
    { "id": 15, "name": "Робототехника", "desc": "Промышленные роботы, андроиды и автоматизация складов" },
    { "id": 16, "name": "Космическая Индустрия", "desc": "Спутниковый интернет, ракетостроение и освоение космоса" },
    { "id": 17, "name": "Нейротехнологии", "desc": "Интерфейсы мозг-компьютер и биотехнологические импланты" },
    { "id": 18, "name": "Зеленая Энергетика", "desc": "Солнечная, ветровая энергия и ядерный синтез" },
    { "id": 19, "name": "Электромобили (EV)", "desc": "Производство электрокаров и аккумуляторных батарей" },
    { "id": 20, "name": "Финтех и Крипто", "desc": "Цифровые платежи, блокчейн и биржи" },
    { "id": 21, "name": "Метавселенные и AR/VR", "desc": "Виртуальная реальность и иммерсивные технологии" },
    { "id": 22, "name": "Нефть и Газ", "desc": "Традиционная энергетика и добыча ресурсов" },
    { "id": 23, "name": "Логистика и Supply Chain", "desc": "Глобальные цепочки поставок и доставка" },
    { "id": 24, "name": "Медицина и Фарма", "desc": "Разработка лекарств и медицинское оборудование" }
]

companies = [
    { "id": 1001, "sec_id": 10, "name": "OpenAI", "ticker": "OAI", "desc": "Лидер в области генеративного ИИ и создатель ChatGPT", "price": 850.50, "vol": 0.8, "stat": "ACTIVE", "shares": 5000, "last_tr": "" },
    { "id": 1002, "sec_id": 10, "name": "Anthropic", "ticker": "ANTH", "desc": "Разработчик безопасного ИИ, конкурент OpenAI", "price": 420.30, "vol": 0.7, "stat": "ACTIVE", "shares": 3000, "last_tr": "" },
    { "id": 1003, "sec_id": 11, "name": "NVIDIA", "ticker": "NVDA", "desc": "Главный поставщик железа для обучения нейросетей", "price": 1450.00, "vol": 0.6, "stat": "ACTIVE", "shares": 10000, "last_tr": "" },
    { "id": 1004, "sec_id": 11, "name": "TSMC", "ticker": "TSM", "desc": "Крупнейший в мире производитель полупроводников", "price": 210.15, "vol": 0.4, "stat": "ACTIVE", "shares": 8000, "last_tr": "" },
    { "id": 1005, "sec_id": 11, "name": "AMD", "ticker": "AMD", "desc": "Производство процессоров и графических карт", "price": 185.90, "vol": 0.5, "stat": "ACTIVE", "shares": 6000, "last_tr": "" },
    { "id": 1006, "sec_id": 11, "name": "ASML", "ticker": "ASML", "desc": "Оборудование для литографии чипов", "price": 980.00, "vol": 0.4, "stat": "ACTIVE", "shares": 2000, "last_tr": "" },
    { "id": 1007, "sec_id": 12, "name": "Microsoft", "ticker": "MSFT", "desc": "Облако Azure и интеграция ИИ в офисные продукты", "price": 490.50, "vol": 0.3, "stat": "ACTIVE", "shares": 15000, "last_tr": "" },
    { "id": 1008, "sec_id": 12, "name": "Amazon Web Services", "ticker": "AMZN", "desc": "Лидер рынка облачной инфраструктуры", "price": 230.20, "vol": 0.4, "stat": "ACTIVE", "shares": 12000, "last_tr": "" },
    { "id": 1009, "sec_id": 13, "name": "CrowdStrike", "ticker": "CRWD", "desc": "Облачная защита конечных устройств", "price": 340.00, "vol": 0.6, "stat": "ACTIVE", "shares": 4000, "last_tr": "" },
    { "id": 1010, "sec_id": 13, "name": "Palantir", "ticker": "PLTR", "desc": "Аналитика больших данных и безопасность", "price": 45.80, "vol": 0.7, "stat": "ACTIVE", "shares": 9000, "last_tr": "" },
    { "id": 1011, "sec_id": 14, "name": "IonQ", "ticker": "IONQ", "desc": "Разработка квантовых компьютеров на ионах", "price": 28.50, "vol": 0.9, "stat": "ACTIVE", "shares": 2500, "last_tr": "" },
    { "id": 1012, "sec_id": 15, "name": "Boston Dynamics", "ticker": "BOS_DYN", "desc": "Передовая робототехника и мобильные роботы", "price": 150.00, "vol": 0.6, "stat": "ACTIVE", "shares": 3000, "last_tr": "" },
    { "id": 1013, "sec_id": 16, "name": "SpaceX", "ticker": "SPACE", "desc": "Запуски ракет Starship и спутники Starlink", "price": 2500.00, "vol": 0.5, "stat": "ACTIVE", "shares": 1000, "last_tr": "" },
    { "id": 1014, "sec_id": 16, "name": "Rocket Lab", "ticker": "RKLB", "desc": "Частная аэрокосмическая компания, доставка спутников", "price": 12.40, "vol": 0.8, "stat": "ACTIVE", "shares": 5000, "last_tr": "" },
    { "id": 1015, "sec_id": 17, "name": "Neuralink", "ticker": "NEURA", "desc": "Имплантируемые нейрокомпьютерные интерфейсы", "price": 600.00, "vol": 0.9, "stat": "ACTIVE", "shares": 1500, "last_tr": "" },
    { "id": 1016, "sec_id": 19, "name": "Tesla", "ticker": "TSLA", "desc": "Электромобили, автопилот и робот Optimus", "price": 350.75, "vol": 0.7, "stat": "ACTIVE", "shares": 12000, "last_tr": "" },
    { "id": 1017, "sec_id": 19, "name": "Rivian", "ticker": "RIVN", "desc": "Производство электрических внедорожников и пикапов", "price": 25.30, "vol": 0.6, "stat": "ACTIVE", "shares": 6000, "last_tr": "" },
    { "id": 1018, "sec_id": 18, "name": "NextEra Energy", "ticker": "NEE", "desc": "Крупнейший генератор солнечной и ветровой энергии", "price": 88.90, "vol": 0.2, "stat": "ACTIVE", "shares": 7000, "last_tr": "" },
    { "id": 1019, "sec_id": 18, "name": "First Solar", "ticker": "FSLR", "desc": "Производство тонкопленочных солнечных модулей", "price": 190.50, "vol": 0.5, "stat": "ACTIVE", "shares": 3000, "last_tr": "" },
    { "id": 1020, "sec_id": 20, "name": "Coinbase", "ticker": "COIN", "desc": "Криптовалютная биржа и инфраструктура", "price": 280.00, "vol": 0.9, "stat": "ACTIVE", "shares": 4500, "last_tr": "" },
    { "id": 1021, "sec_id": 20, "name": "Block (Square)", "ticker": "SQ", "desc": "Финансовые услуги и мобильные платежи", "price": 95.20, "vol": 0.5, "stat": "ACTIVE", "shares": 5000, "last_tr": "" },
    { "id": 1022, "sec_id": 21, "name": "Meta Platforms", "ticker": "META", "desc": "Социальные сети и VR гарнитуры Quest", "price": 610.10, "vol": 0.4, "stat": "ACTIVE", "shares": 9500, "last_tr": "" },
    { "id": 1023, "sec_id": 21, "name": "Apple", "ticker": "AAPL", "desc": "Электроника, сервисы и гарнитуры Vision", "price": 245.00, "vol": 0.3, "stat": "ACTIVE", "shares": 20000, "last_tr": "" },
    { "id": 1024, "sec_id": 22, "name": "ExxonMobil", "ticker": "XOM", "desc": "Международная нефтегазовая корпорация", "price": 115.50, "vol": 0.2, "stat": "ACTIVE", "shares": 15000, "last_tr": "" },
    { "id": 1025, "sec_id": 22, "name": "Gazprom Energy", "ticker": "GAZP", "desc": "Крупнейшая газовая компания (региональная)", "price": 15.00, "vol": 0.4, "stat": "ACTIVE", "shares": 50000, "last_tr": "" },
    { "id": 1026, "sec_id": 23, "name": "FedEx", "ticker": "FDX", "desc": "Глобальная служба доставки и логистики", "price": 290.80, "vol": 0.2, "stat": "ACTIVE", "shares": 4000, "last_tr": "" },
    { "id": 1027, "sec_id": 24, "name": "Pfizer", "ticker": "PFE", "desc": "Фармацевтический гигант, производство вакцин", "price": 32.40, "vol": 0.2, "stat": "ACTIVE", "shares": 12000, "last_tr": "" },
    { "id": 1028, "sec_id": 24, "name": "Moderna", "ticker": "MRNA", "desc": "Биотехнологии на основе мРНК", "price": 110.00, "vol": 0.6, "stat": "ACTIVE", "shares": 2500, "last_tr": "" },
    { "id": 1029, "sec_id": 11, "name": "Intel", "ticker": "INTC", "desc": "Производство процессоров и развитие фаундри-бизнеса", "price": 40.50, "vol": 0.4, "stat": "ACTIVE", "shares": 9000, "last_tr": "" },
    { "id": 1030, "sec_id": 11, "name": "ARM Holdings", "ticker": "ARM", "desc": "Архитектура процессоров для мобильных устройств", "price": 130.00, "vol": 0.5, "stat": "ACTIVE", "shares": 3500, "last_tr": "" },
    { "id": 1031, "sec_id": 10, "name": "Google DeepMind", "ticker": "GOOGL_AI", "desc": "Подразделение Alphabet, сфокусированное на ИИ", "price": 195.00, "vol": 0.4, "stat": "ACTIVE", "shares": 11000, "last_tr": "" },
    { "id": 1032, "sec_id": 18, "name": "Uranium Corp", "ticker": "URA", "desc": "Добыча урана для атомной энергетики", "price": 45.60, "vol": 0.6, "stat": "ACTIVE", "shares": 5500, "last_tr": "" },
    { "id": 1033, "sec_id": 15, "name": "Siemens", "ticker": "SIEM", "desc": "Автоматизация производства и инфраструктуры", "price": 160.20, "vol": 0.2, "stat": "ACTIVE", "shares": 5000, "last_tr": "" },
    { "id": 1034, "sec_id": 12, "name": "Oracle", "ticker": "ORCL", "desc": "Облачные базы данных и корпоративное ПО", "price": 175.40, "vol": 0.3, "stat": "ACTIVE", "shares": 6000, "last_tr": "" },
    { "id": 1035, "sec_id": 13, "name": "Kaspersky Lab", "ticker": "KASP", "desc": "Антивирусное ПО и исследования угроз", "price": 65.00, "vol": 0.4, "stat": "ACTIVE", "shares": 3000, "last_tr": "" }
]

def generate_price_logs():
    price_logs = []
    
    # 1. Расчет параметров времени
    num_companies = len(companies)
    logs_per_company = TARGET_TOTAL_LOGS // num_companies
    
    # Время окончания - сейчас (UTC)
    end_time = datetime.datetime.utcnow()
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