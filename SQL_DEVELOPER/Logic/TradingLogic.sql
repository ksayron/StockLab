CREATE OR REPLACE PACKAGE pkg_trading_user AS

    -- Разместить ордер
    PROCEDURE place_order (
        p_user_id     IN  NUMBER,
        p_company_id  IN  NUMBER,
        p_type        IN  VARCHAR2, 
        p_qty         IN  NUMBER,
        p_limit_price IN  NUMBER,
        o_order_id    OUT NUMBER,
        o_status      OUT VARCHAR2,
        o_message     OUT VARCHAR2
    );

    -- Отменить ордер
    PROCEDURE cancel_order (
        p_user_id     IN  NUMBER,
        p_order_id    IN  NUMBER,
        o_status      OUT VARCHAR2,
        o_message     OUT VARCHAR2
    );
    
    -- Получить ордера
    PROCEDURE get_orders_by_user_id (
        p_user_id IN  NUMBER,
        o_cursor  OUT SYS_REFCURSOR,
        o_status  OUT VARCHAR2,
        o_message OUT VARCHAR2
    );

END pkg_trading_user;
/

CREATE OR REPLACE PACKAGE BODY pkg_trading_user AS

    -- PLACE ORDER
    PROCEDURE place_order (
        p_user_id     IN  NUMBER,
        p_company_id  IN  NUMBER,
        p_type        IN  VARCHAR2,
        p_qty         IN  NUMBER,
        p_limit_price IN  NUMBER,
        o_order_id    OUT NUMBER,
        o_status      OUT VARCHAR2,
        o_message     OUT VARCHAR2
    ) IS
        v_status VARCHAR2(20);
        v_total_cost NUMBER;
        v_current_balance NUMBER;
        v_stock_owned NUMBER;
    BEGIN
        -- Инициализация
        o_status := 'SUCCESS';
        o_message := 'Ордер размещен';

        -- 1. Валидация входных данных
        IF p_qty <= 0 OR p_limit_price <= 0 THEN
            o_status := 'ERROR';
            o_message := 'Количество и цена должны быть больше нуля.';
            RETURN;
        END IF;

        -- 2. Проверка: Открыта ли биржа?
        -- (Если есть пакет view, используем его, иначе можно опустить или читать таблицу напрямую)
        -- pkg_market_view.get_exchange_status(v_status);
        -- IF v_status = 'CLOSED' THEN ...

        -- 3. Логика ПОКУПКИ (BUY)
        IF p_type = 'BUY' THEN
            v_total_cost := p_qty * p_limit_price;

            SELECT balance INTO v_current_balance 
            FROM users WHERE user_id = p_user_id FOR UPDATE;

            IF v_current_balance < v_total_cost THEN
                o_status := 'ERROR';
                o_message := 'Недостаточно средств. Требуется: ' || v_total_cost || ', Доступно: ' || v_current_balance;
                RETURN;
            END IF;

            UPDATE users SET balance = balance - v_total_cost WHERE user_id = p_user_id;

        -- 4. Логика ПРОДАЖИ (SELL)
        ELSIF p_type = 'SELL' THEN
            BEGIN
                SELECT quantity_owned INTO v_stock_owned 
                FROM portfolios 
                WHERE user_id = p_user_id AND company_id = p_company_id 
                FOR UPDATE;
            EXCEPTION WHEN NO_DATA_FOUND THEN
                v_stock_owned := 0;
            END;

            IF v_stock_owned < p_qty THEN
                o_status := 'ERROR';
                o_message := 'Недостаточно акций. Требуется: ' || p_qty || ', Есть: ' || v_stock_owned;
                RETURN;
            END IF;

            UPDATE portfolios 
            SET quantity_owned = quantity_owned - p_qty 
            WHERE user_id = p_user_id AND company_id = p_company_id;

        ELSE
            o_status := 'ERROR';
            o_message := 'Неверный тип ордера. Используйте BUY или SELL.';
            RETURN;
        END IF;

        -- 5. Создаем ордер
        INSERT INTO orders (
            user_id, company_id, type, status, limit_price, original_qty, remaining_qty
        ) VALUES (
            p_user_id, p_company_id, p_type, 'OPEN', p_limit_price, p_qty, p_qty
        ) RETURNING order_id INTO o_order_id;
        
        -- 6. Запускаем Движок
        stock_admin.pkg_trading_engine.match_orders(p_company_id);

        COMMIT;

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            stock_admin.pkg_logger.log_error('pkg_trading_user.place_order', p_user_id, SQLCODE, SQLERRM);
            o_status := 'ERROR';
            o_message := 'Internal Server Error';
    END place_order;

    -- CANCEL ORDER
    PROCEDURE cancel_order (
        p_user_id  IN  NUMBER,
        p_order_id IN  NUMBER,
        o_status   OUT VARCHAR2,
        o_message  OUT VARCHAR2
    ) IS
        v_ord_type  VARCHAR2(10);
        v_rem_qty   NUMBER;
        v_price     NUMBER;
        v_comp_id   NUMBER;
    BEGIN
        o_status := 'SUCCESS';
        o_message := 'Ордер отменен';

        BEGIN
            -- Блокируем ордер
            SELECT type, remaining_qty, limit_price, company_id
            INTO v_ord_type, v_rem_qty, v_price, v_comp_id
            FROM orders
            WHERE order_id = p_order_id AND user_id = p_user_id AND status = 'OPEN'
            FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                o_status := 'ERROR';
                o_message := 'Ордер не найден или уже не активен.';
                RETURN;
        END;

        -- Меняем статус
        UPDATE orders SET status = 'CANCELLED' WHERE order_id = p_order_id;

        -- Возвращаем активы
        IF v_ord_type = 'BUY' THEN
            UPDATE users SET balance = balance + (v_rem_qty * v_price) WHERE user_id = p_user_id;
        ELSE 
            UPDATE portfolios 
            SET quantity_owned = quantity_owned + v_rem_qty 
            WHERE user_id = p_user_id AND company_id = v_comp_id;
        END IF;

        COMMIT;

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            stock_admin.pkg_logger.log_error('pkg_trading_user.cancel_order', p_user_id, SQLCODE, SQLERRM);
            o_status := 'ERROR';
            o_message := 'Internal Server Error';
    END cancel_order;
    
    -- GET ORDERS
    PROCEDURE get_orders_by_user_id (
        p_user_id IN  NUMBER,
        o_cursor  OUT SYS_REFCURSOR,
        o_status  OUT VARCHAR2,
        o_message OUT VARCHAR2
    ) IS
    BEGIN
        o_status := 'SUCCESS';
        o_message := 'ОК';

        OPEN o_cursor FOR
            SELECT o.order_id, 
                   c.ticker_symbol, 
                   o.type, 
                   o.status, 
                   o.limit_price, 
                   o.original_qty, 
                   o.remaining_qty, 
                   o.created_at
            FROM orders o
            JOIN companies c ON o.company_id = c.company_id
            WHERE o.user_id = p_user_id
            ORDER BY o.created_at DESC;
    EXCEPTION
        WHEN OTHERS THEN
            stock_admin.pkg_logger.log_error('pkg_trading_user.get_orders_by_user_id', p_user_id, SQLCODE, SQLERRM);
            o_status := 'ERROR';
            o_message := 'Internal Server Error';
    END get_orders_by_user_id;

END pkg_trading_user;
/
--CREATE OR REPLACE PUBLIC SYNONYM pkg_trading_user FOR pkg_trading_user;
-- OR REPLACE PUBLIC SYNONYM pkg_trading_engine FOR pkg_trading_engine;

-- 2. Права
-- USER имеет доступ только к "Фронт-офису"
GRANT EXECUTE ON pkg_trading_user TO stock_user;
GRANT EXECUTE ON pkg_trading_user TO stock_admin;

-- ДВИЖОК скрыт от обычных пользователей, но пакет pkg_trading_user должен иметь к нему доступ.
-- Так как оба пакета в одной схеме (stock_admin), это работает автоматически (Definer Rights).
-- Прямой вызов движка только админом (для тестов или ручного пуска).
GRANT EXECUTE ON pkg_trading_engine TO stock_admin;