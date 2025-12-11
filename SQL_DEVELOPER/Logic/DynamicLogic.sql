CREATE OR REPLACE PACKAGE pkg_market_dynamics AS
    
    -- Вызывается после каждой успешной сделки
    PROCEDURE on_trade_executed (
        p_company_id IN NUMBER
    );

    -- Вызывается по расписанию
    PROCEDURE wake_up_stagnant_market;

END pkg_market_dynamics;
/

CREATE OR REPLACE PACKAGE BODY pkg_market_dynamics AS

    -- Константы
    c_vol_min CONSTANT NUMBER := 0.01; 
    c_vol_max CONSTANT NUMBER := 0.50; 
    c_stagnation_minutes CONSTANT NUMBER := 15; 
    c_overheat_threshold CONSTANT NUMBER := 15; 

    -- ==========================================
    -- 1. ON TRADE EXECUTED
    -- ==========================================
    PROCEDURE on_trade_executed (p_company_id IN NUMBER) IS
        v_trade_count NUMBER;
        v_current_vol NUMBER;
        v_new_vol     NUMBER;
    BEGIN
        -- Этот код выполняется внутри транзакции Трейдинга.
        -- Мы НЕ делаем здесь COMMIT, чтобы сохранить атомарность сделки.
        
        -- 1. Обновляем время последней сделки
        UPDATE companies SET last_trade_at = SYSTIMESTAMP 
        WHERE company_id = p_company_id 
        RETURNING volatility_factor INTO v_current_vol;

        -- 2. Считаем сделки за минуту
        SELECT COUNT(*) INTO v_trade_count FROM trades
        WHERE company_id = p_company_id AND executed_at > SYSTIMESTAMP - INTERVAL '1' MINUTE;

        -- 3. Логика перегрева
        IF v_trade_count >= c_overheat_threshold THEN
            v_new_vol := GREATEST(v_current_vol * 0.95, c_vol_min);
            
            IF v_new_vol != v_current_vol THEN
                UPDATE companies SET volatility_factor = v_new_vol WHERE company_id = p_company_id;
            END IF;
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            -- Если динамика упала, мы НЕ хотим отменять сделку пользователя.
            -- Мы просто логируем ошибку и позволяем процедуре завершиться "успешно".
            stock_admin.pkg_logger.log_error(
                p_proc_name => 'pkg_market_dynamics.on_trade_executed', 
                p_user_id   => NULL, -- Система
                p_err_code  => SQLCODE, 
                p_err_msg   => 'Ошибка расчета динамики для CompID=' || p_company_id || ': ' || SQLERRM
            );
            -- Нет RAISE -> Транзакция продолжится
    END on_trade_executed;

    -- ==========================================
    -- 2. WAKE UP STAGNANT (JOB)
    -- ==========================================
    PROCEDURE wake_up_stagnant_market IS
        CURSOR c_stagnant IS
            SELECT company_id, volatility_factor, name
            FROM companies
            WHERE status = 'ACTIVE'
              AND last_trade_at < SYSTIMESTAMP - NUMTODSINTERVAL(c_stagnation_minutes, 'MINUTE')
              AND volatility_factor < c_vol_max;
              
        v_new_vol NUMBER;
    BEGIN
        FOR r IN c_stagnant LOOP
            -- Оборачиваем каждую итерацию в отдельный блок,
            -- чтобы ошибка в одной компании не остановила обработку остальных
            BEGIN
                -- Увеличиваем волатильность
                v_new_vol := LEAST(r.volatility_factor * 1.10, c_vol_max);
                
                UPDATE companies 
                SET volatility_factor = v_new_vol 
                WHERE company_id = r.company_id;

                -- Запускаем мэтчинг (он сам обработает свои ошибки)
                stock_admin.pkg_trading_engine.match_orders(r.company_id);
                
                -- Коммитим успех по этой конкретной компании
                COMMIT; 
                
            EXCEPTION
                WHEN OTHERS THEN
                    ROLLBACK; -- Откатываем только эту итерацию
                    stock_admin.pkg_logger.log_error(
                        p_proc_name => 'pkg_market_dynamics.wake_up_loop', 
                        p_user_id   => NULL, 
                        p_err_code  => SQLCODE, 
                        p_err_msg   => 'Ошибка пробуждения компании ' || r.name || ': ' || SQLERRM
                    );
            END;
        END LOOP;
        
    EXCEPTION
        WHEN OTHERS THEN
            -- Общая ошибка курсора или пакета
            stock_admin.pkg_logger.log_error('pkg_market_dynamics.wake_up_stagnant_market', NULL, SQLCODE, SQLERRM);
    END wake_up_stagnant_market;

END pkg_market_dynamics;
/