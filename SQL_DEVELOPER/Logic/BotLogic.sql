GRANT EXECUTE ON DBMS_LOCK TO STOCK_ADMIN;
CREATE OR REPLACE PACKAGE pkg_market_bots AS

    -- 1. Создать тестовый мир (Компании + Трейдеры)
    PROCEDURE setup_simulation_world;

    -- 2. Выполнить одно действие случайного бота
    PROCEDURE perform_bot_action;

    -- 3. Запустить цикл симуляции на N минут
    PROCEDURE run_simulation_loop (
        p_duration_minutes IN NUMBER DEFAULT 15
    );

    -- 4. Удалить всё, что насоздавали боты
    PROCEDURE cleanup_simulation;

END pkg_market_bots;
/

CREATE OR REPLACE PACKAGE BODY pkg_market_bots AS

    c_bot_prefix CONSTANT VARCHAR2(4) := 'BOT_';

    -- ==========================================
    -- 1. SETUP (Генерация мира)
    -- ==========================================
    PROCEDURE setup_simulation_world IS
        v_dummy_id  NUMBER;
        v_dummy_str VARCHAR2(100);
        v_status    VARCHAR2(50);
        v_msg       VARCHAR2(4000);
        v_price     NUMBER;
        v_target_sector_id NUMBER;
    BEGIN
        -- 1. Находим сектор
        BEGIN
            SELECT sector_id INTO v_target_sector_id FROM sectors where name='TECH' FETCH FIRST 1 ROW ONLY;
        EXCEPTION WHEN NO_DATA_FOUND THEN
            -- Создаем аварийный сектор
            stock_admin.pkg_market_admin.add_sector('Bot_Sector', 'Auto-generated', v_target_sector_id, v_status, v_msg);
            IF v_status = 'ERROR' THEN
                stock_admin.pkg_logger.log_error('pkg_market_bots.setup', NULL, NULL, 'Critical: Failed to create sector: ' || v_msg);
                RETURN;
            END IF;
        END;

        -- 2. Создаем Компании
        FOR i IN 1..5 LOOP
            BEGIN
                v_price := ROUND(DBMS_RANDOM.VALUE(20, 1000), 2);
                
                stock_admin.pkg_companies_admin.add_company(
                    p_sector_id    => v_target_sector_id,
                    p_name         => c_bot_prefix || 'Comp_' || i || '_' || DBMS_RANDOM.STRING('X', 3),
                    p_ticker       => 'B' || i || DBMS_RANDOM.STRING('U', 2),
                    p_description  => 'Simulation AI Company',
                    p_init_price   => v_price,
                    p_volatility   => ROUND(DBMS_RANDOM.VALUE(0.05, 0.30), 2),
                    p_total_shares => ROUND(DBMS_RANDOM.VALUE(50, 100)),
                    o_company_id   => v_dummy_id,
                    o_status       => v_status,
                    o_message      => v_msg
                );

                IF v_status = 'ERROR' THEN
                    stock_admin.pkg_logger.log_error('pkg_market_bots.setup_companies', NULL, NULL, 'Failed to create company ' || i || ': ' || v_msg);
                END IF;
            EXCEPTION WHEN OTHERS THEN
                stock_admin.pkg_logger.log_error('pkg_market_bots.setup_companies_loop', NULL, SQLCODE, SQLERRM);
            END;
        END LOOP;

        -- 3. Создаем Трейдеров
        FOR i IN 1..100 LOOP
            DECLARE
                v_username VARCHAR2(50) := c_bot_prefix || 'User_' || i || '_' || DBMS_RANDOM.STRING('X', 3);
                v_balance  NUMBER := ROUND(DBMS_RANDOM.VALUE(5000, 100000), 2);
            BEGIN
                stock_admin.pkg_users.register_user(
                    p_username      => v_username,
                    p_email         => v_username || '@sim.bot',
                    p_password_hash => 'bot_pass',
                    o_user_id       => v_dummy_id,
                    o_role_name     => v_dummy_str,
                    o_status        => v_status,
                    o_message       => v_msg
                );
                
                IF v_status = 'SUCCESS' THEN
                    stock_admin.pkg_users.deposit_cash(v_dummy_id, v_balance, v_status, v_msg);
                ELSE
                    stock_admin.pkg_logger.log_error('pkg_market_bots.setup_users', NULL, NULL, 'Failed user ' || v_username || ': ' || v_msg);
                END IF;
            EXCEPTION WHEN OTHERS THEN
                stock_admin.pkg_logger.log_error('pkg_market_bots.setup_users_loop', NULL, SQLCODE, SQLERRM);
            END;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            stock_admin.pkg_logger.log_error('pkg_market_bots.setup_global', NULL, SQLCODE, SQLERRM);
    END setup_simulation_world;

    -- ==========================================
    -- 2. BOT ACTION (AI Logic)
    -- ==========================================
    PROCEDURE perform_bot_action IS
        v_user_id      NUMBER;
        v_company_id   NUMBER;
        v_balance      NUMBER;
        v_owned_stocks NUMBER;
        v_current_price NUMBER;
        v_volatility   NUMBER;
        
        v_action       VARCHAR2(10);
        v_qty          NUMBER;
        v_limit_price  NUMBER;
        v_aggression_factor NUMBER; -- Насколько бот готов двигать цену
        v_direction         NUMBER;
        
        v_order_id     NUMBER;
        v_status       VARCHAR2(50);
        v_msg          VARCHAR2(4000);
    BEGIN
        -- 1. Выбираем Бота
        BEGIN
            SELECT user_id, balance INTO v_user_id, v_balance
            FROM (SELECT user_id, balance FROM users WHERE username LIKE c_bot_prefix || '%' ORDER BY DBMS_RANDOM.VALUE)
            WHERE ROWNUM = 1;
        EXCEPTION WHEN NO_DATA_FOUND THEN 
            stock_admin.pkg_logger.log_error('pkg_market_bots.action', NULL, NULL, 'No bots found to perform action');
            RETURN; 
        END;

        -- 2. Выбираем Компанию
        BEGIN
            SELECT company_id, current_price, volatility_factor 
            INTO v_company_id, v_current_price, v_volatility
            FROM (SELECT company_id, current_price, volatility_factor FROM companies WHERE name LIKE c_bot_prefix || '%' AND status='ACTIVE' ORDER BY DBMS_RANDOM.VALUE)
            WHERE ROWNUM = 1;
        EXCEPTION WHEN NO_DATA_FOUND THEN 
            stock_admin.pkg_logger.log_error('pkg_market_bots.action', NULL, NULL, 'No active bot-companies found');
            RETURN; 
        END;

        -- 3. Анализ портфеля
        BEGIN
            SELECT quantity_owned INTO v_owned_stocks 
            FROM portfolios WHERE user_id = v_user_id AND company_id = v_company_id;
        EXCEPTION WHEN NO_DATA_FOUND THEN v_owned_stocks := 0; END;

        -- 4. Стратегия (BUY/SELL)
        IF v_owned_stocks = 0 THEN
            v_action := 'BUY';
        ELSIF v_balance < 500 THEN -- Мало денег, надо продавать
            v_action := 'SELL';
        ELSE
            -- 50/50 случайный выбор
            IF DBMS_RANDOM.VALUE > 0.5 THEN v_action := 'BUY'; ELSE v_action := 'SELL'; END IF;
        END IF;

        -- 5. РАСЧЕТ ДИНАМИЧЕСКОЙ ЦЕНЫ
        -- Мы используем волатильность как максимальное отклонение.
        -- Большинство ордеров будут "пассивными" (не исполняются сразу), создавая ликвидность.
        -- Некоторые ордера будут "агрессивными" (пересекают спред), двигая цену.

        -- Генерируем "настроение" бота (-1 .. +1)
        -- Если настроение совпадает с действием (хочет купить и настроение +), он платит больше -> цена растет.
        v_direction := DBMS_RANDOM.VALUE(-1, 1); 
        
        -- Считаем цену: Текущая + (Волатильность * Настроение)
        -- Например: Цена 100, Вол 0.1 (10%), Настроение -0.5.
        -- Цена заявки = 100 * (1 + (0.1 * -0.5)) = 95.
        v_limit_price := v_current_price * (1 + (v_volatility * v_direction));
        
        -- Округляем до центов
        v_limit_price := ROUND(v_limit_price, 2);
        
        -- Защита от отрицательных цен
        IF v_limit_price <= 0.01 THEN v_limit_price := 0.01; END IF;

        -- 6. Определение объема (Money Management)
        IF v_action = 'BUY' THEN
            -- Если денег мало, берем минимум 1 акцию (если хватает)
            IF v_balance > v_limit_price THEN
                -- Тратим случайную часть бюджета (от 5% до 30%)
                v_qty := FLOOR((v_balance * DBMS_RANDOM.VALUE(0.05, 0.30)) / v_limit_price);
            ELSE
                v_qty := 0; -- Не хватает денег
            END IF;
        ELSE
            -- Продажа: продаем случайную часть пакета (от 10% до 100%)
            v_qty := CEIL(v_owned_stocks * DBMS_RANDOM.VALUE(0.1, 1.0));
        END IF;

        -- Финальная проверка объема
        IF v_qty < 1 THEN v_qty := 1; END IF;
        
        -- Для покупки еще раз проверяем бюджет (на всякий случай)
        IF v_action = 'BUY' AND (v_qty * v_limit_price) > v_balance THEN
             v_qty := FLOOR(v_balance / v_limit_price);
        END IF;

        -- 7. Действие
        IF v_qty > 0 THEN
            stock_admin.pkg_trading_user.place_order(
                p_user_id     => v_user_id,
                p_company_id  => v_company_id,
                p_type        => v_action,
                p_qty         => v_qty,
                p_limit_price => v_limit_price,
                o_order_id    => v_order_id,
                o_status      => v_status,
                o_message     => v_msg
            );
            
            -- Логируем только критические ошибки, игнорируем нехватку средств (это нормально для рандома)
            IF v_status = 'ERROR' AND v_msg NOT LIKE '%Insufficient%' THEN
                stock_admin.pkg_logger.log_error(
                    'pkg_market_bots.perform_action', 
                    v_user_id, 
                    NULL, 
                    'Bot failed to ' || v_action || ': ' || v_msg
                );
            END IF;
            -- Логируем, если что-то пошло не так (например, недостаточно средств, хотя мы проверяли)
            IF v_status = 'ERROR' THEN
                stock_admin.pkg_logger.log_error(
                    'pkg_market_bots.perform_action', 
                    v_user_id, 
                    NULL, 
                    'Bot failed to ' || v_action || ' ' || v_qty || ' shares: ' || v_msg
                );
            END IF;
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            -- Критическая ошибка одного бота не должна останавливать цикл, но мы должны о ней знать
            stock_admin.pkg_logger.log_error('pkg_market_bots.perform_action_CRITICAL', v_user_id, SQLCODE, SQLERRM);
    END perform_bot_action;

    -- ==========================================
    -- 3. RUN LOOP
    -- ==========================================
    PROCEDURE run_simulation_loop (
        p_duration_minutes IN NUMBER DEFAULT 15
    ) IS
        v_end_time DATE;
    BEGIN
        v_end_time := SYSDATE + (p_duration_minutes / 1440);
        
        WHILE SYSDATE < v_end_time LOOP
            perform_bot_action();
            COMMIT; 
            DBMS_LOCK.SLEEP(1); 
        END LOOP;
    EXCEPTION
        WHEN OTHERS THEN
            -- Если упал сам цикл (например, тайм-аут или ошибка пакета LOCK)
            stock_admin.pkg_logger.log_error('pkg_market_bots.run_loop', NULL, SQLCODE, 'Loop crashed: ' || SQLERRM);
            RAISE; -- Здесь пробрасываем, чтобы скрипт остановился
    END run_simulation_loop;

    -- ==========================================
    -- 4. CLEANUP
    -- ==========================================
    PROCEDURE cleanup_simulation IS
    BEGIN
        -- 1. Удаляем Трейды, Ордера, Логи, Уведомления (тут все ок)
        DELETE FROM trades WHERE company_id IN (SELECT company_id FROM companies WHERE name LIKE c_bot_prefix || '%');
        DELETE FROM orders WHERE company_id IN (SELECT company_id FROM companies WHERE name LIKE c_bot_prefix || '%');
        DELETE FROM price_log WHERE company_id IN (SELECT company_id FROM companies WHERE name LIKE c_bot_prefix || '%');
        DELETE FROM user_notifications WHERE user_id IN (SELECT user_id FROM users WHERE username LIKE c_bot_prefix || '%');
        
        -- 2. ВАЖНОЕ ИСПРАВЛЕНИЕ: Удаляем портфели ПО КОМПАНИИ
        -- (Чтобы разорвать FK_PORTFOLIO_COMPANY перед удалением компаний)
        DELETE FROM portfolios WHERE company_id IN (SELECT company_id FROM companies WHERE name LIKE c_bot_prefix || '%');
        
        -- 3. Удаляем портфели ПО ЮЗЕРУ (если боты владели чем-то еще)
        DELETE FROM portfolios WHERE user_id IN (SELECT user_id FROM users WHERE username LIKE c_bot_prefix || '%');
        
        -- 4. Теперь безопасно удаляем компании и юзеров
        DELETE FROM companies WHERE name LIKE c_bot_prefix || '%';
        DELETE FROM users WHERE username LIKE c_bot_prefix || '%';
        
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            stock_admin.pkg_logger.log_error('pkg_market_bots.cleanup', NULL, SQLCODE, SQLERRM);
            RAISE;
    END cleanup_simulation;

END pkg_market_bots;
/

