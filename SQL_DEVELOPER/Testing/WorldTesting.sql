SET SERVEROUTPUT ON;

DECLARE
    -- ID сущностей
    v_sector_id    NUMBER;
    v_company_id   NUMBER;
    v_user1_id     NUMBER;
    v_user2_id     NUMBER;
    
    -- Временные переменные
    v_role_dummy   VARCHAR2(50);
    v_order_id     NUMBER;
    v_banned_dummy NUMBER;
    v_cursor       SYS_REFCURSOR;
    
    -- Переменные для проверок
    v_balance      NUMBER;
    v_stocks       NUMBER;
    v_price        NUMBER;
    
    -- Настройки теста
    c_ipo_price    CONSTANT NUMBER := 100.00;
    c_volatility   CONSTANT NUMBER := 0.20; -- 20% (Коридор 80-120)
    c_total_shares CONSTANT NUMBER := 10;   -- Мало акций, чтобы легко выкупить
    c_deposit      CONSTANT NUMBER := 5000; -- У каждого по $5000

BEGIN
    DBMS_OUTPUT.PUT_LINE('=== НАЧАЛО СИМУЛЯЦИИ РЫНКА ===');

    -- =========================================================
    -- 1. НАСТРОЙКА ОКРУЖЕНИЯ (Сектор, Компания, Юзеры)
    -- =========================================================
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- 1. Создание мира ---');

    -- 1.1 Сектор
    stock_admin.pkg_market_admin.add_sector('Test_Auto', 'Simulation Sector', v_sector_id);
    
    -- 1.2 Компания (IPO: 10 акций по $100)
    -- В этот момент создается бот ISSUER_TESLA и ставит ордер SELL на 10 шт.
    stock_admin.pkg_companies_admin.add_company(
        p_sector_id    => v_sector_id,
        p_name         => 'Tesla Sim',
        p_ticker       => 'TSLA_SIM',
        p_description  => 'Electric cars test',
        p_init_price   => c_ipo_price,
        p_volatility   => c_volatility,
        p_total_shares => c_total_shares,
        o_company_id   => v_company_id
    );
    DBMS_OUTPUT.PUT_LINE('>> Компания создана. IPO запущено: 10 акций по $' || c_ipo_price);

    -- 1.3 Пользователи (Trader A и Trader B)
    -- Trader A
    stock_admin.pkg_users.register_user('Trader_A', 'a@test.com', 'hash1', v_user1_id, v_role_dummy);
    stock_admin.pkg_users.deposit_cash(v_user1_id, c_deposit);
    
    -- Trader B
    stock_admin.pkg_users.register_user('Trader_B', 'b@test.com', 'hash2', v_user2_id, v_role_dummy);
    stock_admin.pkg_users.deposit_cash(v_user2_id, c_deposit);
    
    DBMS_OUTPUT.PUT_LINE('>> Трейдеры готовы. Баланс каждого: $' || c_deposit);

    -- =========================================================
    -- 2. ВЫКУП IPO (Первичный рынок)
    -- =========================================================
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- 2. Выкуп IPO (Покупка у Бота) ---');

    -- Trader A покупает 6 акций по рынку ($100)
    -- Он ставит лимит $100. Движок находит ордер Бота. Сделка проходит.
    stock_admin.pkg_trading_user.place_order(
        p_user_id     => v_user1_id,
        p_company_id  => v_company_id,
        p_type        => 'BUY',
        p_qty         => 6,
        p_limit_price => 100.00,
        o_order_id    => v_order_id
    );
    DBMS_OUTPUT.PUT_LINE('>> Trader A купил 6 акций.');

    -- Trader B покупает оставшиеся 4 акции
    stock_admin.pkg_trading_user.place_order(
        p_user_id     => v_user2_id,
        p_company_id  => v_company_id,
        p_type        => 'BUY',
        p_qty         => 4,
        p_limit_price => 100.00,
        o_order_id    => v_order_id
    );
    DBMS_OUTPUT.PUT_LINE('>> Trader B купил 4 акции. IPO полностью выкуплено.');

    -- ПРОВЕРКА ПОРТФЕЛЕЙ
    -- Проверим, что акции реально у них
    SELECT quantity_owned INTO v_stocks FROM stock_admin.portfolios WHERE user_id = v_user1_id AND company_id = v_company_id;
    SELECT balance INTO v_balance FROM stock_admin.users WHERE user_id = v_user1_id;
    DBMS_OUTPUT.PUT_LINE('   [CHECK] Trader A -> Акций: ' || v_stocks || ' (Ожидалось 6). Деньги: $' || v_balance || ' (Ожидалось 4400)');

    -- =========================================================
    -- 3. ВТОРИЧНЫЙ РЫНОК (Торговля между людьми)
    -- =========================================================
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- 3. Спекуляция (Trader A продает Trader B) ---');
    
    -- Сценарий: Trader A хочет заработать. Он выставляет 1 акцию на продажу за $110.
    -- Это внутри коридора волатильности (100 +/- 20% = 80..120), так что сделка возможна.
    
    stock_admin.pkg_trading_user.place_order(
        p_user_id     => v_user1_id,
        p_company_id  => v_company_id,
        p_type        => 'SELL',
        p_qty         => 1,
        p_limit_price => 110.00, -- Хочет продать дороже
        o_order_id    => v_order_id
    );
    DBMS_OUTPUT.PUT_LINE('>> Trader A выставил ордер на продажу 1 шт по $110.');

    -- В этот момент ордер висит в стакане, сделки нет.
    -- Trader B решает купить эту акцию. Он готов заплатить $110.
    
    stock_admin.pkg_trading_user.place_order(
        p_user_id     => v_user2_id,
        p_company_id  => v_company_id,
        p_type        => 'BUY',
        p_qty         => 1,
        p_limit_price => 110.00,
        o_order_id    => v_order_id
    );
    DBMS_OUTPUT.PUT_LINE('>> Trader B выставил ордер на покупку 1 шт по $110.');

    -- Движок должен был свести эти ордера.
    
    -- =========================================================
    -- 4. ПРОВЕРКА РЕЗУЛЬТАТОВ
    -- =========================================================
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- 4. Итоговые проверки ---');
    
    -- 1. Проверяем Цену Компании (Должна вырасти до 110)
    SELECT current_price INTO v_price FROM stock_admin.companies WHERE company_id = v_company_id;
    DBMS_OUTPUT.PUT_LINE('>> Текущая цена TSLA_SIM: $' || v_price);
    
    IF v_price = 110 THEN
        DBMS_OUTPUT.PUT_LINE('   [SUCCESS] Цена выросла!');
    ELSE
        DBMS_OUTPUT.PUT_LINE('   [FAIL] Цена не обновилась.');
    END IF;

    -- 2. Проверяем Баланс Trader A (Продавца)
    -- Было 4400. Продал 1 за 110. Стало 4510.
    SELECT balance INTO v_balance FROM stock_admin.users WHERE user_id = v_user1_id;
    DBMS_OUTPUT.PUT_LINE('>> Баланс Trader A: $' || v_balance);
    
    -- 3. Проверяем Акции Trader B (Покупателя)
    -- Было 4. Купил 1. Стало 5.
    SELECT quantity_owned INTO v_stocks FROM stock_admin.portfolios WHERE user_id = v_user2_id AND company_id = v_company_id;
    DBMS_OUTPUT.PUT_LINE('>> Акции Trader B: ' || v_stocks || ' шт.');

    -- 4. Проверяем Лог Сделок
    FOR r IN (SELECT * FROM stock_admin.trades WHERE company_id = v_company_id ORDER BY executed_at) LOOP
        DBMS_OUTPUT.PUT_LINE('   LOG: Trade #' || r.trade_id || ' | Price: $' || r.trade_price || ' | Qty: ' || r.quantity);
    END LOOP;

    DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== СИМУЛЯЦИЯ ЗАВЕРШЕНА УСПЕШНО ===');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('!!! CRITICAL ERROR !!! ' || SQLERRM);
        ROLLBACK;
END;
/


BEGIN
    DBMS_OUTPUT.PUT_LINE('=== НАЧАЛО ОЧИСТКИ ТЕСТОВЫХ ДАННЫХ ===');
    
    -- 1. Удаляем Трейды и Логи цен для тестовых компаний
    -- (Ищем компании с именем Tesla Sim или тикером TSLA_SIM)
    DELETE FROM stock_admin.trades 
    WHERE company_id IN (SELECT company_id FROM stock_admin.companies WHERE ticker_symbol = 'TSLA_SIM');
    
    DELETE FROM stock_admin.price_log 
    WHERE company_id IN (SELECT company_id FROM stock_admin.companies WHERE ticker_symbol = 'TSLA_SIM');

    -- 2. Удаляем Ордера
    DELETE FROM stock_admin.orders 
    WHERE company_id IN (SELECT company_id FROM stock_admin.companies WHERE ticker_symbol = 'TSLA_SIM');

    -- 3. Удаляем Портфели (Связь юзеров и компании)
    DELETE FROM stock_admin.portfolios 
    WHERE company_id IN (SELECT company_id FROM stock_admin.companies WHERE ticker_symbol = 'TSLA_SIM');

    -- 4. Удаляем Компании
    DELETE FROM stock_admin.companies WHERE ticker_symbol = 'TSLA_SIM';
    
    -- 5. Удаляем Сектор
    DELETE FROM stock_admin.sectors WHERE name = 'Test_Auto';

    -- 6. Удаляем Пользователей (Trader_A, Trader_B и бота ISSUER_TSLA_SIM)
    DELETE FROM stock_admin.users 
    WHERE username IN ('Trader_A', 'Trader_B') 
       OR username LIKE 'ISSUER_TSLA_SIM%';

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('=== ОЧИСТКА ЗАВЕРШЕНА ===');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Ошибка очистки: ' || SQLERRM);
        ROLLBACK;
END;
/