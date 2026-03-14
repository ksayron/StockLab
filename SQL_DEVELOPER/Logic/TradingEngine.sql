CREATE OR REPLACE PACKAGE pkg_trading_engine AS
    PROCEDURE match_orders (
        p_company_id IN NUMBER
    );
END pkg_trading_engine;
/

CREATE OR REPLACE PACKAGE BODY pkg_trading_engine AS

    -- Вспомогательная процедура для начисления акций (Локальная)
    PROCEDURE credit_stocks(p_user_id IN NUMBER, p_company_id IN NUMBER, p_qty IN NUMBER) IS
    BEGIN
        MERGE INTO portfolios p
        USING dual ON (p.user_id = p_user_id AND p.company_id = p_company_id)
        WHEN MATCHED THEN
            UPDATE SET quantity_owned = quantity_owned + p_qty
        WHEN NOT MATCHED THEN
            INSERT (user_id, company_id, quantity_owned) VALUES (p_user_id, p_company_id, p_qty);
    END;
    
    -- Вспомогательная процедура для отправки уведомлений о сделке
    -- (Чтобы не загромождать основной код)
    PROCEDURE notify_trade_participants(
        p_buyer_id    IN NUMBER,
        p_seller_id   IN NUMBER,
        p_company_id  IN NUMBER,
        p_qty         IN NUMBER,
        p_price       IN NUMBER,
        p_buy_filled  IN NUMBER, -- Сколько стало выполнено у покупателя
        p_buy_target  IN NUMBER, -- Сколько хотел всего
        p_sell_filled IN NUMBER,
        p_sell_target IN NUMBER
    ) IS
        v_buyer_name  VARCHAR2(100);
        v_seller_name VARCHAR2(100);
        v_comp_name   VARCHAR2(100);
        v_ticker      VARCHAR2(50);
        
        v_msg_buyer   VARCHAR2(4000);
        v_msg_seller  VARCHAR2(4000);
        
        -- Переменные-заглушки для OUT параметров (Soft Error нам здесь не важен, мы просто пишем в лог)
        v_status      VARCHAR2(50);
        v_message     VARCHAR2(4000);
    BEGIN
        -- Получаем имена
        SELECT username INTO v_buyer_name FROM users WHERE user_id = p_buyer_id;
        SELECT username INTO v_seller_name FROM users WHERE user_id = p_seller_id;
        SELECT name, ticker_symbol INTO v_comp_name, v_ticker FROM companies WHERE company_id = p_company_id;

        -- === УВЕДОМЛЕНИЕ ПОКУПАТЕЛЮ ===
        v_msg_buyer := 'Пользователь ' || v_seller_name || ' продал вам акции ' || v_comp_name || ' (#' || v_ticker || ').'
                    || CHR(10) || 'Куплено: ' || p_qty || ' шт. за $' || p_price;
        
        IF p_buy_filled < p_buy_target THEN
            v_msg_buyer := v_msg_buyer || CHR(10) || 'Ордер заполнен частично: ' || p_buy_filled || '/' || p_buy_target;
        ELSE
            v_msg_buyer := v_msg_buyer || CHR(10) || 'Ордер успешно выполнен полностью!';
        END IF;

        stock_admin.pkg_notifications.create_personal_notification(
            p_user_id => p_buyer_id, p_title => 'Сделка совершена', p_message => v_msg_buyer, p_type => 'TRADE',
            o_status => v_status, o_message => v_message
        );

        -- === УВЕДОМЛЕНИЕ ПРОДАВЦУ ===
        v_msg_seller := 'Пользователь ' || v_buyer_name || ' купил ваши акции ' || v_comp_name || ' (#' || v_ticker || ').'
                     || CHR(10) || 'Продано: ' || p_qty || ' шт. за $' || p_price;

        IF p_sell_filled < p_sell_target THEN
            v_msg_seller := v_msg_seller || CHR(10) || 'Ордер заполнен частично: ' || p_sell_filled || '/' || p_sell_target;
        ELSE
            v_msg_seller := v_msg_seller || CHR(10) || 'Ордер успешно выполнен полностью!';
        END IF;

        stock_admin.pkg_notifications.create_personal_notification(
            p_user_id => p_seller_id, p_title => 'Сделка совершена', p_message => v_msg_seller, p_type => 'TRADE',
            o_status => v_status, o_message => v_message
        );

    EXCEPTION
        WHEN OTHERS THEN
            -- Если уведомления упали, сделку не отменяем! Просто пишем в лог.
            stock_admin.pkg_logger.log_error('pkg_trading_engine.notify', NULL, SQLCODE, 'Failed to notify: ' || SQLERRM);
    END;

    -- ОСНОВНОЙ МЕХАНИЗМ (MATCH ORDERS)
    PROCEDURE match_orders (
        p_company_id IN NUMBER
    ) IS
        CURSOR c_matches IS
            SELECT 
                b.order_id buy_id, b.user_id buyer_id, b.limit_price buy_limit, 
                b.original_qty buy_orig, b.remaining_qty buy_qty, b.created_at buy_time,
                s.order_id sell_id, s.user_id seller_id, s.limit_price sell_limit, 
                s.original_qty sell_orig, s.remaining_qty sell_qty, s.created_at sell_time
            FROM orders b
            JOIN orders s ON b.company_id = s.company_id
            WHERE b.company_id = p_company_id
              AND b.type = 'BUY' AND b.status IN ('OPEN', 'PARTIAL')
              AND s.type = 'SELL' AND s.status IN ('OPEN', 'PARTIAL')
              AND b.limit_price >= s.limit_price
              AND b.user_id != s.user_id
            ORDER BY 
                b.limit_price DESC, s.limit_price ASC, b.created_at ASC
            FOR UPDATE SKIP LOCKED;

        v_trade_qty     NUMBER;
        v_trade_price   NUMBER;
        v_refund        NUMBER;
        v_current_price NUMBER;
        v_volatility    NUMBER;
        v_min_allowed   NUMBER;
        v_max_allowed   NUMBER;
        
        -- Новые переменные для статуса заполнения
        v_buy_filled_total  NUMBER;
        v_sell_filled_total NUMBER;
    BEGIN
        BEGIN
            SELECT current_price, volatility_factor INTO v_current_price, v_volatility
            FROM companies WHERE company_id = p_company_id;
        EXCEPTION WHEN NO_DATA_FOUND THEN
            stock_admin.pkg_logger.log_error('pkg_trading_engine.match_orders', NULL, SQLCODE, 'Компания не найдена: ' || p_company_id);
            RETURN;
        END;

        FOR m IN c_matches LOOP
            SAVEPOINT sp_before_trade;
            BEGIN
                -- 1. Цена
                IF m.buy_time < m.sell_time THEN v_trade_price := m.buy_limit;
                ELSE v_trade_price := m.sell_limit; END IF;

                -- 2. Волатильность
                IF v_current_price > 0 THEN
                    v_min_allowed := v_current_price * (1 - v_volatility);
                    v_max_allowed := v_current_price * (1 + v_volatility);
                    IF v_trade_price < v_min_allowed OR v_trade_price > v_max_allowed THEN EXIT; END IF;
                END IF;

                -- 3. Объем
                v_trade_qty := LEAST(m.buy_qty, m.sell_qty);
                IF v_trade_qty <= 0 THEN CONTINUE; END IF;

                -- 4. Запись трейда
                INSERT INTO trades (buyer_order_id, seller_order_id, company_id, trade_price, quantity)
                VALUES (m.buy_id, m.sell_id, p_company_id, v_trade_price, v_trade_qty);

                -- 5. Обновление ордеров
                UPDATE orders SET remaining_qty = remaining_qty - v_trade_qty,
                    status = CASE WHEN remaining_qty - v_trade_qty = 0 THEN 'FILLED' ELSE 'PARTIAL' END
                WHERE order_id = m.buy_id;

                UPDATE orders SET remaining_qty = remaining_qty - v_trade_qty,
                    status = CASE WHEN remaining_qty - v_trade_qty = 0 THEN 'FILLED' ELSE 'PARTIAL' END
                WHERE order_id = m.sell_id;

                -- 6. Деньги
                UPDATE users SET balance = balance + (v_trade_qty * v_trade_price) WHERE user_id = m.seller_id;
                
                IF v_trade_price < m.buy_limit THEN
                    v_refund := (m.buy_limit - v_trade_price) * v_trade_qty;
                    UPDATE users SET balance = balance + v_refund WHERE user_id = m.buyer_id;
                END IF;

                -- 7. Акции
                credit_stocks(m.buyer_id, p_company_id, v_trade_qty);

                -- 8. Цена и Логи
                UPDATE companies SET current_price = v_trade_price WHERE company_id = p_company_id;
                INSERT INTO price_log (company_id, price) VALUES (p_company_id, v_trade_price);
                stock_admin.pkg_market_dynamics.on_trade_executed(p_company_id);
                v_current_price := v_trade_price;

                -- 9. === ОТПРАВКА УВЕДОМЛЕНИЙ ===
                -- Рассчитываем, сколько ТЕПЕРЬ выполнено у каждого ордера
                v_buy_filled_total := m.buy_orig - (m.buy_qty - v_trade_qty);
                v_sell_filled_total := m.sell_orig - (m.sell_qty - v_trade_qty);

                notify_trade_participants(
                    p_buyer_id    => m.buyer_id,
                    p_seller_id   => m.seller_id,
                    p_company_id  => p_company_id,
                    p_qty         => v_trade_qty,
                    p_price       => v_trade_price,
                    p_buy_filled  => v_buy_filled_total,
                    p_buy_target  => m.buy_orig,
                    p_sell_filled => v_sell_filled_total,
                    p_sell_target => m.sell_orig
                );
                -- ==============================

            EXCEPTION
                WHEN OTHERS THEN
                    ROLLBACK TO sp_before_trade;
                    stock_admin.pkg_logger.log_error('pkg_trading_engine.match_loop', NULL, SQLCODE, SQLERRM);
            END;
        END LOOP;

    EXCEPTION
        WHEN OTHERS THEN
            stock_admin.pkg_logger.log_error('pkg_trading_engine.match_orders_global', NULL, SQLCODE, SQLERRM);
    END match_orders;

END pkg_trading_engine;
/