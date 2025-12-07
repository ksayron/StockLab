CREATE OR REPLACE PACKAGE pkg_portfolio AS

    -- Константа
    c_calc_interval CONSTANT INTERVAL DAY TO SECOND := INTERVAL '15' MINUTE;

    -- Получить общую сводку
    PROCEDURE get_portfolio_summary (
        p_user_id       IN  NUMBER,
        o_cash_balance  OUT NUMBER,
        o_stocks_value  OUT NUMBER,
        o_total_equity  OUT NUMBER,
        o_change_abs    OUT NUMBER,
        o_change_pct    OUT NUMBER,
        o_status        OUT VARCHAR2,
        o_message       OUT VARCHAR2
    );

    -- Получить список активов
    PROCEDURE get_portfolio_items (
        p_user_id IN  NUMBER,
        o_cursor  OUT SYS_REFCURSOR,
        o_status  OUT VARCHAR2,
        o_message OUT VARCHAR2
    );

END pkg_portfolio;
/

CREATE OR REPLACE PACKAGE BODY pkg_portfolio AS

    -- Вспомогательная функция (без изменений)
    FUNCTION get_historical_price(p_company_id NUMBER) RETURN NUMBER IS
        v_price NUMBER;
    BEGIN
        SELECT price INTO v_price
        FROM price_log
        WHERE company_id = p_company_id
          AND log_time <= SYSTIMESTAMP - c_calc_interval
        ORDER BY log_time DESC
        FETCH FIRST 1 ROW ONLY;
        RETURN v_price;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            SELECT current_price INTO v_price FROM companies WHERE company_id = p_company_id;
            RETURN v_price;
    END;

    -- SUMMARY
    PROCEDURE get_portfolio_summary (
        p_user_id       IN  NUMBER,
        o_cash_balance  OUT NUMBER,
        o_stocks_value  OUT NUMBER,
        o_total_equity  OUT NUMBER,
        o_change_abs    OUT NUMBER,
        o_change_pct    OUT NUMBER,
        o_status        OUT VARCHAR2,
        o_message       OUT VARCHAR2
    ) IS
        v_current_stock_sum NUMBER := 0;
        v_old_stock_sum     NUMBER := 0;
    BEGIN
        o_status := 'SUCCESS';
        o_message := 'ОК';

        -- Проверка существования пользователя
        BEGIN
            SELECT balance INTO o_cash_balance FROM users WHERE user_id = p_user_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                o_status := 'ERROR';
                o_message := 'Пользователь не найден';
                RETURN;
        END;

        -- Считаем стоимость акций
        FOR r IN (SELECT company_id, quantity_owned FROM portfolios WHERE user_id = p_user_id) LOOP
            DECLARE
                v_cur_price NUMBER;
                v_old_price NUMBER;
            BEGIN
                SELECT current_price INTO v_cur_price FROM companies WHERE company_id = r.company_id;
                v_old_price := get_historical_price(r.company_id);

                v_current_stock_sum := v_current_stock_sum + (r.quantity_owned * v_cur_price);
                v_old_stock_sum     := v_old_stock_sum     + (r.quantity_owned * v_old_price);
            END;
        END LOOP;

        o_stocks_value := v_current_stock_sum;
        o_total_equity := o_cash_balance + o_stocks_value;
        
        o_change_abs := v_current_stock_sum - v_old_stock_sum;
        
        IF v_old_stock_sum > 0 THEN
            o_change_pct := (o_change_abs / v_old_stock_sum) * 100;
        ELSE
            o_change_pct := 0;
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            stock_admin.pkg_logger.log_error('pkg_portfolio.get_portfolio_summary', p_user_id, SQLCODE, SQLERRM);
            o_status := 'ERROR';
            o_message := 'Internal Server Error';
    END get_portfolio_summary;

    -- ITEMS
    PROCEDURE get_portfolio_items (
        p_user_id IN  NUMBER,
        o_cursor  OUT SYS_REFCURSOR,
        o_status  OUT VARCHAR2,
        o_message OUT VARCHAR2
    ) IS
    BEGIN
        o_status := 'SUCCESS';
        o_message := 'ОК';

        OPEN o_cursor FOR
            SELECT 
                c.company_id,
                c.ticker_symbol,
                c.name,
                p.quantity_owned,
                c.current_price,
                (p.quantity_owned * c.current_price) AS current_value,
                ROUND(c.current_price - COALESCE(
                    (SELECT price FROM price_log pl 
                     WHERE pl.company_id = c.company_id 
                       AND pl.log_time <= SYSTIMESTAMP - c_calc_interval 
                     ORDER BY pl.log_time DESC FETCH FIRST 1 ROW ONLY),
                    c.current_price
                ), 2) AS price_change_abs,
                ROUND(
                    CASE WHEN c.current_price = 0 THEN 0 ELSE
                    ((c.current_price - COALESCE(
                        (SELECT price FROM price_log pl 
                         WHERE pl.company_id = c.company_id 
                           AND pl.log_time <= SYSTIMESTAMP - c_calc_interval 
                         ORDER BY pl.log_time DESC FETCH FIRST 1 ROW ONLY),
                        c.current_price
                    )) / NULLIF(c.current_price,0)) * 100
                    END
                , 2) AS price_change_pct
            FROM portfolios p
            JOIN companies c ON p.company_id = c.company_id
            WHERE p.user_id = p_user_id
            ORDER BY (p.quantity_owned * c.current_price) DESC;
            
    EXCEPTION
        WHEN OTHERS THEN
            stock_admin.pkg_logger.log_error('pkg_portfolio.get_portfolio_items', p_user_id, SQLCODE, SQLERRM);
            o_status := 'ERROR';
            o_message := 'Internal Server Error';
    END get_portfolio_items;

END pkg_portfolio;
/
CREATE OR REPLACE PUBLIC SYNONYM pkg_portfolio FOR pkg_portfolio;
GRANT EXECUTE ON pkg_portfolio TO stock_user;
GRANT EXECUTE ON pkg_portfolio TO stock_admin;