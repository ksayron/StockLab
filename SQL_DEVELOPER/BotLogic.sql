CREATE OR REPLACE PACKAGE pkg_market_bots AS
    TYPE t_cursor IS REF CURSOR;

    -- === 1. УПРАВЛЕНИЕ ЖИЗНЕННЫМ ЦИКЛОМ (Soft Error Handling) ===
    
    -- Генерация: Хард ресет + Старт нового турнира
    PROCEDURE generate_and_start_new_season(
        p_bot_count IN NUMBER DEFAULT 100,
        p_status    OUT VARCHAR2,
        p_message   OUT VARCHAR2
    );

    -- Ручной старт (или возобновление после паузы)
    PROCEDURE start_tournament(
        p_status  OUT VARCHAR2,
        p_message OUT VARCHAR2
    );

    -- Пауза (остановка тиков)
    PROCEDURE pause_tournament(
        p_status  OUT VARCHAR2,
        p_message OUT VARCHAR2
    );

    -- Финал (подсчет итогов, архивация, удаление джобов)
    PROCEDURE finalize_tournament(
        p_status  OUT VARCHAR2,
        p_message OUT VARCHAR2
    );

    -- === 2. ЛОГИКА (Internal / Scheduler) ===
    
    -- Тик (вызывается Шедулером, ошибок наружу не возвращает, пишет в лог)
    PROCEDURE execute_bot_tick;
    
    -- Вспомогательная: Состояние турнира ('ACTIVE', 'PAUSED', 'FINISHED')
    FUNCTION get_current_status_code RETURN VARCHAR2;

    -- Вспомогательная: Изменение цены
    FUNCTION get_price_change(p_company_id NUMBER, p_ticks_ago NUMBER) RETURN NUMBER;

    -- === 3. API ===
    
    -- Список всех ботов
    PROCEDURE get_all_bots(
        p_cursor  OUT t_cursor,
        p_status  OUT VARCHAR2,
        p_message OUT VARCHAR2
    );

    -- Детали конкретного бота
    PROCEDURE get_bot_details(
        p_bot_id  IN NUMBER,
        p_cursor  OUT t_cursor,
        p_status  OUT VARCHAR2,
        p_message OUT VARCHAR2
    );
    
    PROCEDURE clean_old_orders; 
    PROCEDURE company_market_maker_action; 

END pkg_market_bots;
/
CREATE OR REPLACE PACKAGE BODY pkg_market_bots AS
    -- === КОНСТАНТЫ (Магические числа) ===
    STATUS_PLANNED  CONSTANT NUMBER := 0;
    STATUS_ACTIVE   CONSTANT NUMBER := 1;
    STATUS_PAUSED   CONSTANT NUMBER := 2;
    STATUS_FINISHED CONSTANT NUMBER := 3;
    
    -- === PRIVATE HELPERS ===
    
    PROCEDURE notify_admins(p_title VARCHAR2, p_msg VARCHAR2) IS
    BEGIN
        INSERT INTO notifications (title, message, type) VALUES (p_title, p_msg, 'INFO');
        INSERT INTO user_notifications (user_id, notification_id)
        SELECT u.user_id, (SELECT MAX(notification_id) FROM notifications)
        FROM users u WHERE u.role_id = (SELECT role_id FROM roles WHERE name = 'Admin');
    EXCEPTION WHEN OTHERS THEN NULL;
    END;

    FUNCTION get_price_change(p_company_id NUMBER, p_ticks_ago NUMBER) RETURN NUMBER IS
        v_curr NUMBER; v_old NUMBER;
    BEGIN
        SELECT current_price INTO v_curr FROM companies WHERE company_id = p_company_id;
        BEGIN
            SELECT price INTO v_old FROM (
                SELECT price FROM price_log WHERE company_id = p_company_id ORDER BY log_time DESC
            ) WHERE ROWNUM <= p_ticks_ago + 1 OFFSET p_ticks_ago ROWS FETCH NEXT 1 ROW ONLY;
        EXCEPTION WHEN NO_DATA_FOUND THEN RETURN 0; END;
        IF v_old = 0 THEN RETURN 0; END IF;
        RETURN (v_curr - v_old) / v_old;
    EXCEPTION WHEN OTHERS THEN RETURN 0; END;

PROCEDURE clean_old_orders IS
        v_role_id NUMBER;
        -- Переменные для получения результатов от процедуры отмены
        v_cancel_status  VARCHAR2(50);
        v_cancel_message VARCHAR2(4000);
    BEGIN
        -- 1. Получаем ID роли бота
        BEGIN
            SELECT role_id INTO v_role_id FROM roles WHERE name = 'Bot';
        EXCEPTION WHEN NO_DATA_FOUND THEN
            stock_admin.pkg_logger.log_error('clean_old_orders', NULL, SQLCODE, 'Role Bot not found');
            RETURN;
        END;

        -- 2. Проходим циклом по всем старым ордерам ботов
        FOR r IN (
            SELECT o.order_id, o.user_id
            FROM orders o
            JOIN users u ON o.user_id = u.user_id
            WHERE u.role_id = v_role_id
              AND o.status IN ('OPEN', 'PARTIAL')
              AND o.created_at < SYSTIMESTAMP - INTERVAL '2' MINUTE
        ) LOOP
            -- 3. Вызываем процедуру отмены для каждого ордера
            -- Оборачиваем в отдельный блок BEGIN-EXCEPTION, чтобы ошибка на одном ордере
            -- (например, блокировка строки) не прерывала очистку остальных.
            BEGIN
                stock_admin.pkg_trading_user.cancel_order(
                    p_user_id  => r.user_id,
                    p_order_id => r.order_id,
                    o_status   => v_cancel_status,
                    o_message  => v_cancel_message
                );

                -- (Опционально) Можно логировать, если статус не SUCCESS
                IF v_cancel_status != 'SUCCESS' THEN
                     stock_admin.pkg_logger.log_error(
                        'clean_old_orders_item', 
                        r.user_id, 
                        NULL, 
                        'Failed to cancel order ' || r.order_id || ': ' || v_cancel_message
                     );
                END IF;

            EXCEPTION 
                WHEN OTHERS THEN
                    stock_admin.pkg_logger.log_error(
                        'clean_old_orders_loop', 
                        r.user_id, 
                        SQLCODE, 
                        'Critical error cancelling order ' || r.order_id || ': ' || SQLERRM
                    );
            END;
        END LOOP;

    EXCEPTION 
        WHEN OTHERS THEN
            stock_admin.pkg_logger.log_error('clean_old_orders_global', NULL, SQLCODE, SQLERRM);
    END clean_old_orders;
    
    PROCEDURE company_market_maker_action IS
        v_role_id     NUMBER;
        v_order_id    NUMBER;
        v_status      VARCHAR2(50);
        v_msg         VARCHAR2(4000);
        v_buy_price   NUMBER;
        v_active_buys NUMBER;
    BEGIN
        SELECT role_id INTO v_role_id FROM roles WHERE name = 'Issuer';

        -- Проходим по всем Эмитентам (их столько же, сколько компаний)
        FOR r IN (
            SELECT u.user_id, u.balance, c.company_id, c.current_price, c.ticker_symbol
            FROM users u
            JOIN portfolios p ON u.user_id = p.user_id -- Эмитент владеет акциями своей компании
            JOIN companies c ON p.company_id = c.company_id
            WHERE u.role_id = v_role_id 
              AND c.status = 'ACTIVE'
              -- Хак: находим именно эмитента этой компании по владению > 0 (или по имени)
              -- Надежнее по имени, как в твоем коде:
              AND u.username = 'ISSUER_' || c.ticker_symbol
        ) LOOP
            BEGIN
                -- 1. Чистим старые ордера этого эмитента
                -- (можно вызвать clean_old_orders, но она для ботов, тут локально)
                NULL; -- Эмитенты обычно держат ордера дольше, оставим как есть

                -- 2. Проверяем стакан на покупку (Buyback)
                SELECT COUNT(*) INTO v_active_buys 
                FROM orders 
                WHERE user_id = r.user_id AND type = 'BUY' AND status = 'OPEN';

                -- Если ордеров мало и есть деньги
                IF v_active_buys < 3 AND r.balance > (r.current_price * 5) THEN
                    -- Ставим Support Level (-2% ... -5%)
                    v_buy_price := r.current_price * (1 - DBMS_RANDOM.VALUE(0.02, 0.05));
                    v_buy_price := ROUND(GREATEST(v_buy_price, 0.01), 2);

                    stock_admin.pkg_trading_user.place_order(
                        p_user_id     => r.user_id,
                        p_company_id  => r.company_id,
                        p_type        => 'BUY',
                        p_qty         => ROUND(DBMS_RANDOM.VALUE(5, 20)), -- Выкупаем по чуть-чуть
                        p_limit_price => v_buy_price,
                        o_order_id    => v_order_id,
                        o_status      => v_status,
                        o_message     => v_msg
                    );
                END IF;
                
                -- (Можно добавить логику доп. продажи, если цена улетела вверх, чтобы сбить памп)
                
            EXCEPTION WHEN OTHERS THEN
                pkg_logger.log_error('market_maker', r.user_id, SQLCODE, SQLERRM);
            END;
        END LOOP;
    EXCEPTION WHEN OTHERS THEN
        pkg_logger.log_error('market_maker_global', NULL, SQLCODE, SQLERRM);
    END;
    
    -- Внутреннее управление джобами
    PROCEDURE manage_jobs(p_action VARCHAR2) IS
    BEGIN
        IF p_action = 'ENABLE' THEN
            -- 1. СТАРТ НОВОГО ТУРНИРА
        
            -- Сначала ЖЕСТКО чистим хвосты от старых турниров. 
            -- Если вдруг старый джоб завис или не удалился, мы его сносим перед созданием нового.
            BEGIN DBMS_SCHEDULER.DROP_JOB('JOB_BOT_TICK', force => TRUE); EXCEPTION WHEN OTHERS THEN NULL; END;
            BEGIN DBMS_SCHEDULER.DROP_JOB('JOB_TOURNAMENT_END', force => TRUE); EXCEPTION WHEN OTHERS THEN NULL; END;

            -- Создаем тикер
            DBMS_SCHEDULER.CREATE_JOB (
                job_name => 'JOB_BOT_TICK', 
                job_type => 'PLSQL_BLOCK',
                job_action => 'BEGIN pkg_market_bots.execute_bot_tick; END;',
                start_date => SYSTIMESTAMP, 
                repeat_interval => 'FREQ=SECONDLY;INTERVAL=10', 
                enabled => TRUE
            );

            -- Создаем таймер финала (10 минут)
            DBMS_SCHEDULER.CREATE_JOB (
                job_name => 'JOB_TOURNAMENT_END', 
                job_type => 'PLSQL_BLOCK',
                job_action => 'DECLARE s VARCHAR2(20); m VARCHAR2(200); BEGIN pkg_market_bots.finalize_tournament(s, m); END;',
                start_date => SYSTIMESTAMP + INTERVAL '15' MINUTE, 
                enabled => TRUE,
                auto_drop => TRUE
            );

        ELSIF p_action = 'DISABLE' THEN
            -- 2. ЗАВЕРШЕНИЕ ТУРНИРА (ФИНАЛИЗАЦИЯ)

            -- Тикер убиваем жестко (force=TRUE), торговля должна встать мгновенно.
            BEGIN 
                DBMS_SCHEDULER.DROP_JOB('JOB_BOT_TICK', force => TRUE); 
            EXCEPTION WHEN OTHERS THEN NULL; 
            END;

            -- Таймер убиваем МЯГКО (force=FALSE)
            -- СЦЕНАРИЙ А (Ручной стоп): Джоб висит в будущем. Удаляется успешно.
            -- СЦЕНАРИЙ Б (Авто стоп): Мы сейчас внутри этого джоба. Удаление падает с ошибкой. 
            -- Мы ловим ошибку в NULL, и джоб продолжает работу (обновляет статусы, пишет логи).
            BEGIN 
                DBMS_SCHEDULER.DROP_JOB('JOB_TOURNAMENT_END', force => FALSE); 
            EXCEPTION WHEN OTHERS THEN 
                -- Здесь можно залогировать для отладки, что "мы внутри джоба, всё ок"
                NULL; 
            END;

        ELSIF p_action = 'PAUSE' THEN
            -- 3. ПАУЗА
        
            -- Убиваем всё. Если пауза, таймер тикать не должен.
            -- ВАЖНО: При возобновлении (RESUME) вам придется пересчитывать оставшееся время,
            -- либо запускать таймер заново.
            BEGIN DBMS_SCHEDULER.DROP_JOB('JOB_BOT_TICK', force => TRUE); EXCEPTION WHEN OTHERS THEN NULL; END;
            BEGIN DBMS_SCHEDULER.DROP_JOB('JOB_TOURNAMENT_END', force => TRUE); EXCEPTION WHEN OTHERS THEN NULL; END;
        
        END IF;

    EXCEPTION WHEN OTHERS THEN
        pkg_logger.log_error('manage_jobs', NULL, SQLCODE, SQLERRM);
    END;
    
    -- Определение статуса
    FUNCTION get_current_status_code RETURN VARCHAR2 IS
        v_sid NUMBER;
    BEGIN
        SELECT status_id INTO v_sid FROM tournaments ORDER BY tournament_id DESC FETCH FIRST 1 ROW ONLY;
        CASE v_sid
            WHEN STATUS_ACTIVE THEN RETURN 'ACTIVE';
            WHEN STATUS_PAUSED THEN RETURN 'PAUSED';
            WHEN STATUS_FINISHED THEN RETURN 'FINISHED';
            ELSE RETURN 'PLANNED';
        END CASE;
    EXCEPTION WHEN NO_DATA_FOUND THEN RETURN 'NONE';
    END;
    
    -- === 1. ГЕНЕРАЦИЯ (HARD RESET) ===
    PROCEDURE generate_and_start_new_season(
        p_bot_count IN NUMBER DEFAULT 100,
        p_status    OUT VARCHAR2,
        p_message   OUT VARCHAR2
    ) IS
        v_role_id NUMBER;
        v_dummy_s VARCHAR2(20); v_dummy_m VARCHAR2(200);
        v_new_tid NUMBER;
    BEGIN
        -- 1. Останавливаем текущее
        finalize_tournament(v_dummy_s, v_dummy_m);
        
        SELECT role_id INTO v_role_id FROM roles WHERE name = 'Bot';

        -- 2. Чистка
        DELETE FROM bot_configs WHERE user_id IN (SELECT user_id FROM users WHERE role_id = v_role_id);
        DELETE FROM portfolios WHERE user_id IN (SELECT user_id FROM users WHERE role_id = v_role_id);
        DELETE FROM trades WHERE buyer_order_id IN (SELECT order_id FROM orders WHERE user_id IN (SELECT user_id FROM users WHERE role_id = v_role_id))
                              OR seller_order_id IN (SELECT order_id FROM orders WHERE user_id IN (SELECT user_id FROM users WHERE role_id = v_role_id));
        DELETE FROM orders WHERE user_id IN (SELECT user_id FROM users WHERE role_id = v_role_id);
        DELETE FROM tournament_history WHERE user_id IN (SELECT user_id FROM users WHERE role_id = v_role_id);
        DELETE FROM networth_snapshots WHERE user_id IN (SELECT user_id FROM users WHERE role_id = v_role_id);
        DELETE FROM tournaments;
        DELETE FROM users WHERE role_id = v_role_id;
        COMMIT;

        -- 3. Создаем ботов
        FOR i IN 1..p_bot_count LOOP
            DECLARE v_uid NUMBER; BEGIN
                INSERT INTO users (username,email,password_hash, role_id, balance) VALUES ('Bot_'||i, 'Bot_'||i||'@sim.bot','bot_'||i||'_pass', v_role_id, 100000) RETURNING user_id INTO v_uid;
                INSERT INTO bot_configs (user_id, greed_factor, panic_level, memory_span, bet_size)
                VALUES (v_uid, ROUND(DBMS_RANDOM.VALUE(1.02,1.3),2), ROUND(DBMS_RANDOM.VALUE(0.5,0.98),2), ROUND(DBMS_RANDOM.VALUE(1,20)), ROUND(DBMS_RANDOM.VALUE(0.1,1),2));
            END;
        END LOOP;

        -- 4. Старт (Запись в Tournaments)
        INSERT INTO tournaments (status_id, start_time) VALUES (STATUS_ACTIVE, SYSTIMESTAMP) RETURNING tournament_id INTO v_new_tid;

        INSERT INTO networth_snapshots (tournament_id, user_id, start_networth)
        SELECT v_new_tid, u.user_id, 10000 FROM users u WHERE u.role_id = v_role_id;

        manage_jobs('ENABLE');
        notify_admins('Сезон начат', 'Турнир #' || v_new_tid || ' запущен.');
        
        p_status := 'SUCCESS';
        p_message := 'Новый сезон запущен.';
        COMMIT;
    EXCEPTION WHEN OTHERS THEN
        pkg_logger.log_error('generate', NULL, SQLCODE, SQLERRM);
        p_status := 'ERROR'; p_message := 'Ошибка: ' || SQLERRM; ROLLBACK;
    END;

    -- === 2. ФИНАЛ ===
    PROCEDURE finalize_tournament(
    p_status  OUT VARCHAR2,
    p_message OUT VARCHAR2
    ) IS
        v_tid NUMBER;
    BEGIN
        pkg_logger.log_error('finalize_tournament start', NULL, 10, 'start of procedure');
        -- 1. Сначала останавливаем джобы
        manage_jobs('DISABLE'); 
         pkg_logger.log_error('finalize_tournament stopped jobs', NULL, 20, 'bot trading sttoped');
        -- 2. Ищем активный или запауженный турнир
        SELECT MAX(tournament_id) INTO v_tid 
        FROM tournaments 
        WHERE status_id IN (STATUS_ACTIVE, STATUS_PAUSED);
        pkg_logger.log_error('finalize_tournament search tournament', NULL, 30, 'searchin currnet tournament'||v_tid);
        IF v_tid IS NOT NULL THEN
            -- 3. Обновляем статус турнира
            UPDATE tournaments 
            SET status_id = STATUS_FINISHED, 
                end_time = SYSTIMESTAMP 
            WHERE tournament_id = v_tid;
            pkg_logger.log_error('finalize_tournament update tournament', NULL, 40, 'updated status of'||v_tid);
        -- 4. Считаем ROI и сохраняем историю
            MERGE INTO tournament_history th
            USING (
                SELECT 
                    v_tid as t_id,      -- Алиас pid тоже лучше заменить для ясности
                    u.user_id as u_id,  -- ИСПРАВЛЕНО: 'uid' -> 'u_id'
                    (
                    (u.balance + COALESCE(
                        (SELECT SUM(p.quantity_owned * c.current_price) 
                         FROM portfolios p 
                         JOIN companies c ON p.company_id = c.company_id 
                         WHERE p.user_id = u.user_id), 0)
                      ) - ns.start_networth
                    ) / GREATEST(ns.start_networth, 1) * 100 as roi
                FROM users u 
                JOIN networth_snapshots ns ON u.user_id = ns.user_id 
                WHERE ns.tournament_id = v_tid
            ) src ON (th.tournament_id = src.t_id AND th.user_id = src.u_id)
            WHEN NOT MATCHED THEN 
                INSERT (tournament_id, user_id, final_roi, final_rank, tier_id) 
                VALUES (src.t_id, src.u_id, src.roi, 1, 1);
         pkg_logger.log_error('finalize_tournament log story', NULL, 50, 'calclulated and written story');
        -- 5. Чистим снапшоты (опционально, если логика требует)
            DELETE FROM networth_snapshots WHERE tournament_id = v_tid;
        pkg_logger.log_error('finalize_tournament clean', NULL, 60, 'cleanded previos snapshots');
            p_status := 'SUCCESS'; 
            p_message := 'Турнир #' || v_tid || ' завершен.';
            notify_admins('Сезон окончен', 'Турнир #' || v_tid || ' окончен.');
             pkg_logger.log_error('finalize_tournament notid', NULL, 80, 'sent out notifications to admins');
        -- Фиксируем изменения
            COMMIT;
            pkg_logger.log_error('finalize_tournament', NULL, 100, SQLERRM);
        ELSE
            p_status := 'WARNING'; 
            p_message := 'Нет активного турнира.';
        -- Даже если турнира нет, джобы мы отключили, возможно стоит сделать COMMIT
        COMMIT; 
    END IF;

    EXCEPTION WHEN OTHERS THEN
        ROLLBACK; -- Откатываем частичные изменения при ошибке
        pkg_logger.log_error('finalize_tournament', NULL, SQLCODE, SQLERRM);
        p_status := 'ERROR'; 
        p_message := 'Ошибка финализации: ' || SQLERRM;
    END;

    -- === 3. РУЧНОЙ СТАРТ / ВОЗОБНОВЛЕНИЕ ===
    PROCEDURE start_tournament(
        p_status  OUT VARCHAR2,
        p_message OUT VARCHAR2
    ) IS
        v_tid NUMBER; v_stat NUMBER; v_role NUMBER;
    BEGIN
        SELECT tournament_id, status_id INTO v_tid, v_stat FROM tournaments ORDER BY tournament_id DESC FETCH FIRST 1 ROW ONLY;

        IF v_stat = STATUS_ACTIVE THEN
            p_status := 'WARNING'; p_message := 'Уже идет.';
        ELSIF v_stat = STATUS_PAUSED THEN
            UPDATE tournaments SET status_id = STATUS_ACTIVE WHERE tournament_id = v_tid;
            manage_jobs('ENABLE');
            p_status := 'SUCCESS'; p_message := 'Возобновлен.';
        ELSE -- FINISHED or NEW
            INSERT INTO tournaments (status_id, start_time) VALUES (STATUS_ACTIVE, SYSTIMESTAMP) RETURNING tournament_id INTO v_tid;
            SELECT role_id INTO v_role FROM roles WHERE name = 'Bot';
            INSERT INTO networth_snapshots (tournament_id, user_id, start_networth)
            SELECT v_tid, u.user_id, u.balance + COALESCE((SELECT SUM(p.quantity_owned * c.current_price) 
                   FROM portfolios p JOIN companies c ON p.company_id = c.company_id WHERE p.user_id = u.user_id), 0)
            FROM users u WHERE u.role_id = v_role;
            manage_jobs('ENABLE');
            p_status := 'SUCCESS'; p_message := 'Новый турнир #' || v_tid;
            notify_admins('Сезон начат', 'Турнир #' || v_tid || ' запущен.');
        END IF;
        COMMIT;
    EXCEPTION WHEN NO_DATA_FOUND THEN -- Совсем пусто
        INSERT INTO tournaments (status_id, start_time) VALUES (STATUS_ACTIVE, SYSTIMESTAMP);
        manage_jobs('ENABLE');
        p_status := 'SUCCESS';
    WHEN OTHERS THEN
        pkg_logger.log_error('start_man', NULL, SQLCODE, SQLERRM);
        p_status := 'ERROR'; p_message := SQLERRM;
    END;
    -- === 4. ПАУЗА ===
    PROCEDURE pause_tournament(
        p_status  OUT VARCHAR2,
        p_message OUT VARCHAR2
    ) IS
        v_tid NUMBER;
    BEGIN
        SELECT MAX(tournament_id) INTO v_tid FROM tournaments WHERE status_id = STATUS_ACTIVE;
        IF v_tid IS NULL THEN
            p_status := 'WARNING'; p_message := 'Нет активного турнира.'; RETURN;
        END IF;
        
        UPDATE tournaments SET status_id = STATUS_PAUSED WHERE tournament_id = v_tid;
        manage_jobs('DISABLE');
        
        p_status := 'SUCCESS'; p_message := 'Турнир на паузе.';
        COMMIT;
    EXCEPTION WHEN OTHERS THEN
        pkg_logger.log_error('pause', NULL, SQLCODE, SQLERRM);
        p_status := 'ERROR'; p_message := 'Ошибка: ' || SQLERRM;
    END;

    -- === 5. ТИК (SCHEDULER) ===
    PROCEDURE execute_bot_tick IS
    v_stat NUMBER;
BEGIN
    -- 1. Проверка статуса
    SELECT status_id INTO v_stat FROM tournaments ORDER BY tournament_id DESC FETCH FIRST 1 ROW ONLY;
    IF v_stat != STATUS_ACTIVE THEN RETURN; END IF;

    -- 2. Обслуживание
    clean_old_orders();          
    company_market_maker_action(); 

    -- 3. ЛОГИКА ТОЛПЫ (Bot Logic v2.0)
    FOR bot IN (
        SELECT u.user_id, u.balance, 
               bc.greed_factor, bc.panic_level, bc.memory_span, bc.bet_size,
               p.company_id AS held_stock_id, 
               p.quantity_owned AS held_amount,
               c.current_price AS current_price
        FROM users u
        JOIN bot_configs bc ON u.user_id = bc.user_id
        LEFT JOIN portfolios p ON u.user_id = p.user_id AND p.quantity_owned > 0
        LEFT JOIN companies c ON p.company_id = c.company_id
        WHERE u.role_id = (SELECT role_id FROM roles WHERE name = 'Bot')
    ) LOOP
        BEGIN
            DECLARE
                v_s VARCHAR2(50); v_m VARCHAR2(4000); v_oid NUMBER;
                v_rnd_comp NUMBER; v_price NUMBER; v_trend NUMBER; v_qty NUMBER;
                v_change_pct NUMBER;
                v_random_factor NUMBER; -- Случайное число для шума
            BEGIN
                v_random_factor := dbms_random.value(0, 1); -- Генерируем от 0 до 1

                -- ==========================================
                -- СЦЕНАРИЙ А: Бот держит акции (Ищем выход)
                -- ==========================================
                IF bot.held_stock_id IS NOT NULL THEN
                    
                    v_change_pct := get_price_change(bot.held_stock_id, bot.memory_span); -- напр. 0.05 (+5%) или -0.03 (-3%)

                    -- 1. PANIC SELL (Стоп-лосс: упало ниже порога паники)
                    IF v_change_pct < (bot.panic_level - 1) THEN 
                         -- Продаем агрессивно по рынку (Market Order через цену 0 или очень низкую)
                         stock_admin.pkg_trading_user.place_order(bot.user_id, bot.held_stock_id, 'SELL', bot.held_amount, bot.current_price * 0.90, v_oid, v_s, v_m);

                    -- 2. TAKE PROFIT (Жадность: выросло выше ожидания)
                    ELSIF v_change_pct > (bot.greed_factor - 1) THEN
                         -- Продаем чуть ниже текущей, чтобы точно забрали, либо по рынку
                         stock_admin.pkg_trading_user.place_order(bot.user_id, bot.held_stock_id, 'SELL', bot.held_amount, bot.current_price * 0.99, v_oid, v_s, v_m);
                    
                    -- 3. [НОВОЕ] СПЕКУЛЯТИВНАЯ ЛИКВИДНОСТЬ (Limit Sell Order)
                    -- Бот выставляет ордер ДОРОЖЕ рынка, наполняя стакан.
                    -- Это решает проблему отсутствия акций у компании.
                    ELSIF v_random_factor < 0.3 THEN -- 30% шанс выставить лимитку "на дурака"
                         -- Ставим цену на 2-10% выше текущей
                         stock_admin.pkg_trading_user.place_order(bot.user_id, bot.held_stock_id, 'SELL', bot.held_amount, bot.current_price * (1 + dbms_random.value(0.02, 0.10)), v_oid, v_s, v_m);
                    
                    -- 4. [НОВОЕ] ПРОДАЖА ОТ СКУКИ (Stagnation Exit)
                    -- Если цена стоит на месте (изменение < 1%), бот может выйти, чтобы найти что-то веселее
                    ELSIF ABS(v_change_pct) < 0.01 AND v_random_factor > 0.9 THEN -- 10% шанс при флэте
                         stock_admin.pkg_trading_user.place_order(bot.user_id, bot.held_stock_id, 'SELL', bot.held_amount, bot.current_price * 0.99, v_oid, v_s, v_m);
                    END IF;

                -- ==========================================
                -- СЦЕНАРИЙ Б: Бот с деньгами (Ищет вход)
                -- ==========================================
                ELSE
                    -- Выбираем случайную цель
                    SELECT company_id, current_price INTO v_rnd_comp, v_price 
                    FROM (SELECT company_id, current_price FROM companies WHERE status='ACTIVE' ORDER BY dbms_random.value) 
                    WHERE ROWNUM = 1;

                    v_trend := get_price_change(v_rnd_comp, bot.memory_span);
                    v_qty := TRUNC((bot.balance * bot.bet_size) / v_price);

                    IF v_qty > 0 THEN
                        -- 1. ПОКУПКА ПО ТРЕНДУ (Как и раньше)
                        IF v_trend > 0 AND v_random_factor > 0.2 THEN
                             -- Агрессивная покупка (Market Buy)
                             stock_admin.pkg_trading_user.place_order(bot.user_id, v_rnd_comp, 'BUY', v_qty, v_price * 1.02, v_oid, v_s, v_m);
                        
                        -- 2. [НОВОЕ] ПОКУПКА НА ОТСКОК (Buy the Dip)
                        -- Если цена упала, но не сильно (коррекция), бот рискует купить
                        ELSIF v_trend < 0 AND v_trend > -0.15 AND v_random_factor < 0.15 THEN -- 15% шанс купить падающее
                             -- Ставим лимитку ЧУТЬ НИЖЕ рынка (ловим дно)
                             stock_admin.pkg_trading_user.place_order(bot.user_id, v_rnd_comp, 'BUY', v_qty, v_price * 0.95, v_oid, v_s, v_m);
                        END IF;
                    END IF;
                END IF;

            EXCEPTION WHEN OTHERS THEN
                -- Логируем, но не ломаем цикл
                pkg_logger.log_error('bot_tick_single', bot.user_id, SQLCODE, SQLERRM);
            END;
        END;
    END LOOP;
    
    COMMIT;
EXCEPTION WHEN OTHERS THEN
    pkg_logger.log_error('tick_executor', NULL, SQLCODE, SQLERRM);
END;
    -- === 6. API: GET ALL BOTS ===
    PROCEDURE get_all_bots(
    p_cursor  OUT t_cursor,
    p_status  OUT VARCHAR2,
    p_message OUT VARCHAR2
) IS
BEGIN
    OPEN p_cursor FOR
        WITH bot_calc AS (
            SELECT 
                u.user_id, 
                u.username,
                (
                    -- 1. Свободный баланс
                    u.balance 
                    + 
                    -- 2. Деньги, заблокированные в ордерах на ПОКУПКУ (BUY)
                    COALESCE((
                        SELECT SUM(o.remaining_qty * o.limit_price)
                        FROM orders o
                        WHERE o.user_id = u.user_id 
                          AND o.type = 'BUY' 
                          AND o.status IN ('OPEN', 'PARTIAL')
                    ), 0) 
                    +
                    -- 3. Стоимость акций в портфеле (Свободные акции * Рыночная цена)
                    COALESCE((
                        SELECT SUM(p.quantity_owned * c.current_price) 
                        FROM portfolios p 
                        JOIN companies c ON p.company_id = c.company_id 
                        WHERE p.user_id = u.user_id
                    ), 0)
                    +
                    -- 4. Стоимость акций, заблокированных в ордерах на ПРОДАЖУ (SELL)
                    -- Оцениваем их по ТЕКУЩЕЙ рыночной цене, т.к. это актив
                    COALESCE((
                        SELECT SUM(o.remaining_qty * c.current_price)
                        FROM orders o
                        JOIN companies c ON o.company_id = c.company_id
                        WHERE o.user_id = u.user_id 
                          AND o.type = 'SELL' 
                          AND o.status IN ('OPEN', 'PARTIAL')
                    ), 0)
                ) as net_worth,
                bc.greed_factor, 
                bc.panic_level, 
                bc.memory_span, 
                bc.bet_size
            FROM users u 
            JOIN bot_configs bc ON u.user_id = bc.user_id 
            WHERE u.role_id = (SELECT role_id FROM roles WHERE name = 'Bot')
        )
        SELECT 
            user_id, 
            username, 
            net_worth as nw, 
            greed_factor, 
            panic_level, 
            memory_span, 
            bet_size,
            RANK() OVER (ORDER BY net_worth DESC) as rnk
        FROM bot_calc;

    p_status := 'SUCCESS';
EXCEPTION WHEN OTHERS THEN 
    p_status := 'ERROR';
    p_message := SQLERRM; 
    pkg_logger.log_error('get_all_bots', NULL, SQLCODE, SQLERRM);
END;

-- === 7. API: GET BOT DETAILS (С УЧЕТОМ ОРДЕРОВ) ===
PROCEDURE get_bot_details(
    p_bot_id  IN NUMBER,
    p_cursor  OUT t_cursor,
    p_status  OUT VARCHAR2,
    p_message OUT VARCHAR2
) IS
BEGIN
    OPEN p_cursor FOR
        SELECT 
            u.user_id, u.username, u.balance,
            -- Тот же полный расчет Net Worth
            (
                u.balance 
                + 
                COALESCE((
                    SELECT SUM(o.remaining_qty * o.limit_price)
                    FROM orders o
                    WHERE o.user_id = u.user_id AND o.type = 'BUY' AND o.status IN ('OPEN', 'PARTIAL')
                ), 0) 
                +
                COALESCE((
                    SELECT SUM(p.quantity_owned * c.current_price) 
                    FROM portfolios p JOIN companies c ON p.company_id = c.company_id WHERE p.user_id = u.user_id
                ), 0)
                +
                COALESCE((
                    SELECT SUM(o.remaining_qty * c.current_price)
                    FROM orders o
                    JOIN companies c ON o.company_id = c.company_id
                    WHERE o.user_id = u.user_id AND o.type = 'SELL' AND o.status IN ('OPEN', 'PARTIAL')
                ), 0)
            ) as networth,
            bc.*,
            (SELECT COUNT(*) FROM tournament_history WHERE user_id = u.user_id) as total_games,
            (SELECT AVG(final_roi) FROM tournament_history WHERE user_id = u.user_id) as avg_roi
        FROM users u
        JOIN bot_configs bc ON u.user_id = bc.user_id
        WHERE u.user_id = p_bot_id;
        
    p_status := 'SUCCESS';
    p_message := 'Детали бота получены.';
EXCEPTION WHEN OTHERS THEN
    p_status := 'ERROR';
    p_message := 'Ошибка получения деталей: ' || SQLERRM;
    pkg_logger.log_error('get_bot_details', NULL, SQLCODE, SQLERRM);
END;

END pkg_market_bots;
/
