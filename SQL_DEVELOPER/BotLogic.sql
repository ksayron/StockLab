GRANT EXECUTE ON DBMS_LOCK TO STOCK_ADMIN;
GRANT CREATE JOB TO stock_admin;
GRANT MANAGE SCHEDULER TO stock_admin;
alter session set container =  STOCKLABDB;
show pdbs;

CREATE OR REPLACE PACKAGE pkg_market_bots AS
    
    PROCEDURE clean_old_bot_orders(
        p_user_id IN NUMBER
    );
    
    PROCEDURE perform_issuer_maintenance;
    
    -- 1. Создать тестовый мир (Компании + Трейдеры)
    PROCEDURE setup_simulation_world;

    -- 2. Выполнить одно действие случайного бота
    PROCEDURE perform_bot_action;

    -- Управление симуляцией (НОВОЕ)
    PROCEDURE start_simulation (
        o_status  OUT VARCHAR2,
        o_message OUT VARCHAR2
    );

    PROCEDURE stop_simulation (
        o_status  OUT VARCHAR2,
        o_message OUT VARCHAR2
    );

    PROCEDURE get_simulation_status (
        o_is_running OUT NUMBER -- 1 = Running, 0 = Stopped
    );
    
    -- 4. Удалить всё, что насоздавали боты
    PROCEDURE cleanup_simulation;
    
    PROCEDURE job_runner;
END pkg_market_bots;
/


CREATE OR REPLACE PACKAGE BODY pkg_market_bots AS
        c_bot_prefix CONSTANT VARCHAR2(4) := 'BOT_';
        c_job_name   CONSTANT VARCHAR2(30) := 'JOB_BOT_TRADING';
        c_wakeup_job_name   CONSTANT VARCHAR2(30) := 'JOB_MARKET_WAKEUP_SERVICE';
    
        -- =========================================================
        -- 1. CLEANUP OLD ORDERS (TTL)
        -- =========================================================
        PROCEDURE clean_old_bot_orders(p_user_id IN NUMBER) IS
            v_status  VARCHAR2(50);
            v_msg     VARCHAR2(4000);
        BEGIN
            -- Ищем ордера этого бота старше 3 минут
            FOR r IN (
                SELECT order_id 
                FROM orders 
                WHERE user_id = p_user_id 
                  AND status IN ('OPEN', 'PARTIAL') 
                  AND created_at < SYSTIMESTAMP - INTERVAL '2' MINUTE
            ) LOOP
                BEGIN
                    stock_admin.pkg_trading_user.cancel_order(
                        p_user_id  => p_user_id,
                        p_order_id => r.order_id,
                        o_status   => v_status,
                        o_message  => v_msg
                    );
                EXCEPTION WHEN OTHERS THEN NULL; END;
            END LOOP;
        END clean_old_bot_orders;
    
        -- =========================================================
        -- 2. ISSUER LOGIC (BUYBACK & MARKET MAKING)
        -- =========================================================
        PROCEDURE perform_issuer_maintenance IS
            v_issuer_id   NUMBER;
            v_balance     NUMBER;
            v_price       NUMBER;
            v_buy_price   NUMBER;
            v_active_buys NUMBER;
            v_status      VARCHAR2(50);
            v_msg         VARCHAR2(4000);
            v_order_id    NUMBER;
        BEGIN
            -- Проходим по всем активным компаниям
            FOR r IN (SELECT company_id, ticker_symbol, current_price, volatility_factor FROM companies WHERE status = 'ACTIVE') LOOP
                BEGIN
                    -- Находим ID пользователя-эмитента
                    SELECT user_id, balance INTO v_issuer_id, v_balance
                    FROM users 
                    WHERE username = 'ISSUER_' || r.ticker_symbol;
                    
                    clean_old_bot_orders(v_issuer_id);
                    -- Проверяем, сколько у него уже активных ордеров на покупку
                    SELECT COUNT(*) INTO v_active_buys 
                    FROM orders 
                    WHERE user_id = v_issuer_id AND type = 'BUY' AND status = 'OPEN';
    
                    -- Логика:
                    -- 1. Если ордеров на покупку мало (< 3)
                    -- 2. И есть деньги (баланс > 10 * цена акции)
                    IF v_active_buys < 3 AND v_balance > (r.current_price * 3) THEN
                        -- Ставим цену ПОКУПКИ чуть ниже рынка (Support Level)
                        -- Например, на 2-5% ниже текущей
                        v_buy_price := r.current_price * (1 - DBMS_RANDOM.VALUE(0.02, 0.05));
                        v_buy_price := ROUND(GREATEST(v_buy_price, 0.01), 2);
    
                        -- Покупаем немного (5-20 акций), чтобы просто влить деньги в рынок
                        stock_admin.pkg_trading_user.place_order(
                            p_user_id     => v_issuer_id,
                            p_company_id  => r.company_id,
                            p_type        => 'BUY',
                            p_qty         => ROUND(DBMS_RANDOM.VALUE(5, 20)),
                            p_limit_price => v_buy_price,
                            o_order_id    => v_order_id,
                            o_status      => v_status,
                            o_message     => v_msg
                        );
                    END IF;
                    
                EXCEPTION WHEN OTHERS THEN 
                stock_admin.pkg_logger.log_error('pkg_market_bot.perform_issuer_maintenance', null, SQLCODE, SQLERRM);
                END;
            END LOOP;
        END perform_issuer_maintenance;
    
        -- =========================================================
        -- 3. BOT ACTION (SMART PRICING)
        -- =========================================================
        PROCEDURE perform_bot_action IS
            v_user_id       NUMBER;
            v_company_id    NUMBER;
            v_balance       NUMBER;
            v_owned_stocks  NUMBER;
            v_current_price NUMBER;
            v_volatility    NUMBER;
            
            v_action        VARCHAR2(10);
            v_qty           NUMBER;
            v_limit_price   NUMBER;
            
            v_min_allowed   NUMBER;
            v_max_allowed   NUMBER;
    
    -- Коэффициенты агрессии
            v_risk_factor   NUMBER; 
            v_price_skew    NUMBER;
            v_market_mood   NUMBER;
            
            v_order_id      NUMBER;
            v_status        VARCHAR2(50);
            v_msg           VARCHAR2(4000);
        BEGIN
            -- 1. Выбираем Бота
            BEGIN
                SELECT user_id, balance INTO v_user_id, v_balance
                FROM (SELECT user_id, balance FROM users WHERE username LIKE c_bot_prefix || '%' ORDER BY DBMS_RANDOM.VALUE)
                WHERE ROWNUM = 1;
                
                IF v_balance < 1000 THEN
                v_balance := 50000;
                UPDATE users SET balance = v_balance WHERE user_id = v_user_id;
                COMMIT; 
                END IF;
                
            EXCEPTION WHEN NO_DATA_FOUND THEN RETURN; END;
    
            clean_old_bot_orders(v_user_id);
            SELECT balance INTO v_balance FROM users WHERE user_id = v_user_id;
    
    
            -- 2. Выбираем Компанию
            BEGIN
                SELECT company_id, current_price, volatility_factor 
                INTO v_company_id, v_current_price, v_volatility
                FROM (SELECT company_id, current_price, volatility_factor FROM companies WHERE name LIKE c_bot_prefix || '%' AND status='ACTIVE' ORDER BY DBMS_RANDOM.VALUE)
                WHERE ROWNUM = 1;
            EXCEPTION WHEN NO_DATA_FOUND THEN RETURN; END;
    
            -- 3. Портфель
            BEGIN
                SELECT quantity_owned INTO v_owned_stocks 
                FROM portfolios WHERE user_id = v_user_id AND company_id = v_company_id;
            EXCEPTION WHEN NO_DATA_FOUND THEN v_owned_stocks := 0; END;
            
            -- Параметры настроения
            v_market_mood := DBMS_RANDOM.VALUE(-0.1, 1);   -- Настроение рынка
            v_risk_factor := DBMS_RANDOM.VALUE(0.2, 0.9);
            
            -- Skew определяет разброс цен
            v_price_skew  := v_volatility * DBMS_RANDOM.VALUE(0.1, 1.2);
            -- 4. Стратегия (BUY/SELL)
            IF v_owned_stocks = 0 THEN
        -- Если акций нет, покупаем только если настроение не "депрессивное" (> 0.2)
        IF v_market_mood > 0.2 THEN v_action := 'BUY'; ELSE RETURN; END IF;
    ELSE
        -- Если акции есть:
        -- 1. Паника (< 0.35) -> SELL
        -- 2. Эйфория (> 0.65) + Есть деньги -> BUY
        -- 3. Нейтрально -> 50/50
        IF v_market_mood < 0.35 THEN
            v_action := 'SELL';
            v_risk_factor := 1.0; -- ПРИ ПАНИКЕ СЛИВАЕМ ВСЁ (Risk Factor повышается до максимума)
        ELSIF v_market_mood > 0.65 AND v_balance > v_current_price * 10 THEN
            v_action := 'BUY';
        ELSE
            IF DBMS_RANDOM.VALUE > 0.5 THEN v_action := 'BUY'; ELSE v_action := 'SELL'; END IF;
        END IF;
    END IF;
    
            -- 5. ЦЕНООБРАЗОВАНИЕ (Строго внутри волатильности)
            -- Рассчитываем границы, которые примет движок
            v_min_allowed := v_current_price * (1 - v_volatility);
            v_max_allowed := v_current_price * (1 + v_volatility);
                
    
            IF v_action = 'BUY' THEN
        -- BUY STRATEGY
        IF v_market_mood > 0.8 THEN
            -- FOMO (Fear Of Missing Out): Покупаем агрессивно ВЫШЕ рынка
            -- Цена = Current + Skew (сдвиг вверх)
            v_limit_price := v_current_price * (1 + v_price_skew);
        ELSE
            -- Обычная покупка: пытаемся купить чуть дешевле или по рынку
            v_limit_price := v_current_price * (1 + DBMS_RANDOM.VALUE(-0.01, v_price_skew/2));
        END IF;
        
        IF v_limit_price > v_max_allowed THEN v_limit_price := v_max_allowed; END IF;

    ELSE 
        -- SELL STRATEGY
        IF v_market_mood < 0.3 THEN
            -- PANIC DUMP: Продаем агрессивно НИЖЕ рынка
            -- Цена = Current - Skew (сдвиг вниз)
            -- Чем сильнее паника, тем больше Skew
            v_limit_price := v_current_price * (1 - (v_price_skew * 1.5)); 
        ELSE
            -- Обычная продажа: чуть дороже или по рынку
            v_limit_price := v_current_price * (1 - DBMS_RANDOM.VALUE(-0.01, v_price_skew/2));
        END IF;

        IF v_limit_price < v_min_allowed THEN v_limit_price := v_min_allowed; END IF;
    END IF;
    
    v_limit_price := ROUND(v_limit_price, 2);
    IF v_limit_price <= 0.01 THEN v_limit_price := 0.01; END IF;
        IF v_action = 'BUY' THEN
        IF v_balance > v_limit_price THEN
            -- Используем Risk Factor: тратим от 20% до 90% баланса
            v_qty := FLOOR((v_balance * v_risk_factor) / v_limit_price);
        ELSE v_qty := 0; END IF;
    ELSE
        -- SELL
        -- Используем Risk Factor: продаем от 20% до 100% портфеля
        -- (При панике v_risk_factor был выставлен в 1.0 выше)
        v_qty := CEIL(v_owned_stocks * v_risk_factor);
    END IF;

    -- Санити-чеки
    IF v_qty < 1 THEN v_qty := 1; END IF;
    IF v_action = 'BUY' AND (v_qty * v_limit_price) > v_balance THEN
         v_qty := FLOOR(v_balance / v_limit_price);
    END IF;
            -- 7. Размещаем ордер
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
            END IF;
    
        EXCEPTION WHEN OTHERS THEN NULL;
        END perform_bot_action;
    
        -- ==========================================
        -- 4. JOB RUNNER
        -- ==========================================
        PROCEDURE job_runner IS
        BEGIN
            -- 1. Эмитенты подливают ликвидность (возвращают деньги)
            perform_issuer_maintenance();
    
            -- 2. Боты торгуют
            FOR i IN 1..15 LOOP -- Увеличили активность до 15 действий за такт
                perform_bot_action();
            END LOOP;
            
            COMMIT;
        END job_runner;

        PROCEDURE setup_simulation_world IS
            v_dummy_id NUMBER; v_dummy_str VARCHAR2(100); v_status VARCHAR2(50); v_msg VARCHAR2(4000); v_price NUMBER; v_target_sector_id NUMBER;
        BEGIN
            BEGIN SELECT sector_id INTO v_target_sector_id FROM sectors FETCH FIRST 1 ROW ONLY;
            EXCEPTION WHEN NO_DATA_FOUND THEN stock_admin.pkg_market_admin.add_sector('Bot_Sector','Auto',v_target_sector_id,v_status,v_msg); END;
    
            FOR i IN 1..15 LOOP
                BEGIN
                    v_price := ROUND(DBMS_RANDOM.VALUE(20, 1000), 2);
                    stock_admin.pkg_companies_admin.add_company(
                        v_target_sector_id, c_bot_prefix||'Comp_'||i, 'B'||i, 'AI Comp', v_price, 
                        ROUND(DBMS_RANDOM.VALUE(0.05, 0.30), 2), ROUND(DBMS_RANDOM.VALUE(50, 100)), v_dummy_id, v_status, v_msg);
                EXCEPTION WHEN OTHERS THEN NULL; END;
            END LOOP;
    
            FOR i IN 1..100 LOOP
                DECLARE v_uname VARCHAR2(50):=c_bot_prefix||'User_'||i; v_bal NUMBER:=ROUND(DBMS_RANDOM.VALUE(5000, 100000), 2);
                BEGIN stock_admin.pkg_users.register_user(v_uname, v_uname||'@sim.bot', 'pass', v_dummy_id, v_dummy_str, v_status, v_msg);
                IF v_status='SUCCESS' THEN stock_admin.pkg_users.deposit_cash(v_dummy_id, v_bal, v_status, v_msg); END IF;
                EXCEPTION WHEN OTHERS THEN NULL; END;
            END LOOP;
            COMMIT;
        END setup_simulation_world;
    
        PROCEDURE start_simulation (o_status OUT VARCHAR2, o_message OUT VARCHAR2) IS
            v_cnt NUMBER;
        BEGIN
            o_status:='SUCCESS'; o_message:='Running';
            
            SELECT COUNT(*) INTO v_cnt FROM user_scheduler_jobs WHERE job_name = c_job_name;
            IF v_cnt = 0 THEN
                -- Создаем джоб: Запускать каждые 5 секунд
                DBMS_SCHEDULER.create_job (
                    job_name        => c_job_name,
                    job_type        => 'PLSQL_BLOCK',
                    job_action      => 'BEGIN stock_admin.pkg_market_bots.job_runner; END;',
                    start_date      => SYSTIMESTAMP,
                    repeat_interval => 'FREQ=SECONDLY; INTERVAL=5', 
                    enabled         => TRUE,
                    comments        => 'Bot Trading Simulation'
                );
            ELSE DBMS_SCHEDULER.enable(c_job_name); END IF;
            SELECT COUNT(*) INTO v_cnt FROM user_scheduler_jobs WHERE job_name = c_wakeup_job_name;
        IF v_cnt = 0 THEN
            DBMS_SCHEDULER.create_job (
                job_name        => c_wakeup_job_name,
                job_type        => 'PLSQL_BLOCK',
                -- Вызываем процедуру из пакета динамики
                job_action      => 'BEGIN stock_admin.pkg_market_dynamics.wake_up_stagnant_market; END;',
                start_date      => SYSTIMESTAMP,
                -- Раз в минуту достаточно, чтобы "пнуть" заснувшие компании
                repeat_interval => 'FREQ=MINUTELY; INTERVAL=1', 
                enabled         => TRUE,
                comments        => 'Market Volatility Injector'
            );
        ELSE 
            DBMS_SCHEDULER.enable(c_wakeup_job_name); 
        END IF;
            
        EXCEPTION WHEN OTHERS THEN o_status:='ERROR'; o_message:=SQLERRM; END start_simulation;
    
        PROCEDURE stop_simulation (o_status OUT VARCHAR2, o_message OUT VARCHAR2) IS
        BEGIN
            o_status:='SUCCESS'; o_message:='Stopped';
            BEGIN DBMS_SCHEDULER.disable(c_job_name); EXCEPTION WHEN OTHERS THEN NULL; END;
        END stop_simulation;
    
        PROCEDURE get_simulation_status (o_is_running OUT NUMBER) IS
            v_st VARCHAR2(20);
        BEGIN
            BEGIN SELECT state INTO v_st FROM user_scheduler_jobs WHERE job_name=c_job_name;
            o_is_running := CASE WHEN v_st='RUNNING' OR v_st='SCHEDULED' THEN 1 ELSE 0 END;
            EXCEPTION WHEN NO_DATA_FOUND THEN o_is_running:=0; END;
            
            BEGIN 
                DBMS_SCHEDULER.disable(c_wakeup_job_name); 
            EXCEPTION WHEN OTHERS THEN NULL; END;
        END get_simulation_status;
    
        PROCEDURE cleanup_simulation IS
        BEGIN
            BEGIN DBMS_SCHEDULER.drop_job(c_job_name, TRUE); EXCEPTION WHEN OTHERS THEN NULL; END;
            DELETE FROM trades WHERE company_id IN (SELECT company_id FROM companies WHERE name LIKE c_bot_prefix||'%');
            DELETE FROM orders WHERE company_id IN (SELECT company_id FROM companies WHERE name LIKE c_bot_prefix||'%');
            DELETE FROM price_log WHERE company_id IN (SELECT company_id FROM companies WHERE name LIKE c_bot_prefix||'%');
            DELETE FROM user_notifications WHERE user_id IN (SELECT user_id FROM users WHERE username LIKE c_bot_prefix||'%');
            DELETE FROM portfolios WHERE company_id IN (SELECT company_id FROM companies WHERE name LIKE c_bot_prefix||'%');
            DELETE FROM portfolios WHERE user_id IN (SELECT user_id FROM users WHERE username LIKE c_bot_prefix||'%');
            DELETE FROM companies WHERE name LIKE c_bot_prefix||'%';
            DELETE FROM users WHERE username LIKE c_bot_prefix||'%';
            COMMIT;
        END cleanup_simulation;
    
        
    END pkg_market_bots;
/
