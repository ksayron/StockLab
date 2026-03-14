CREATE OR REPLACE PACKAGE BODY pkg_olap_analytics AS

    -- статусы симуляции
    STATUS_PLANNED  CONSTANT NUMBER := 0;
    STATUS_ACTIVE   CONSTANT NUMBER := 1;
    STATUS_PAUSED   CONSTANT NUMBER := 2;
    STATUS_FINISHED CONSTANT NUMBER := 3;

    PROCEDURE get_windrose_data(
        p_cursor  OUT t_cursor,
        p_status  OUT VARCHAR2,
        p_message OUT VARCHAR2
    ) IS
        v_tourn_id    NUMBER;
        v_bot_role_id NUMBER;
    BEGIN
        BEGIN
            SELECT role_id INTO v_bot_role_id FROM roles WHERE name = 'Bot';
        EXCEPTION WHEN NO_DATA_FOUND THEN
            p_status := 'WARNING';
            p_message := 'Роль ''Bot'' не найдена.';
            RETURN;
        END;
        
        BEGIN
            SELECT tournament_id INTO v_tourn_id 
            FROM tournaments
            WHERE status_id IN (STATUS_ACTIVE, STATUS_PAUSED)
            ORDER BY tournament_id DESC 
            FETCH FIRST 1 ROW ONLY;
        EXCEPTION WHEN NO_DATA_FOUND THEN
            p_status := 'WARNING';
            p_message := 'Рынок закрыт (нет активного турнира).';
            RETURN;
        END;

        OPEN p_cursor FOR
            WITH LiveNetworth AS (
                SELECT 
                    u.user_id,
                    (u.balance + COALESCE((
                        SELECT SUM(pf.quantity_owned * comp.current_price)
                        FROM portfolios pf
                        JOIN companies comp ON pf.company_id = comp.company_id
                        WHERE pf.user_id = u.user_id
                    ), 0)) AS current_nw,
                    ns.start_networth
                FROM users u
                JOIN networth_snapshots ns ON u.user_id = ns.user_id
                WHERE ns.tournament_id = v_tourn_id
                  AND u.role_id = v_bot_role_id
            ),
            BotStats AS (
                SELECT 
                    user_id,
                    (current_nw - start_networth) / GREATEST(start_networth, 1) * 100 AS roi,
                    NTILE(10) OVER (ORDER BY (current_nw - start_networth) DESC) AS tile
                FROM LiveNetworth
            )
            SELECT 
                CASE 
                    WHEN tile = 1 THEN 'Winners (Top 10%)'
                    WHEN tile = 10 THEN 'Losers (Bottom 10%)'
                    ELSE 'Average Mass' 
                END AS category,
                ROUND(AVG(bc.greed_factor), 2) AS avg_greed,
                ROUND(AVG(bc.panic_level), 2)  AS avg_panic,
                ROUND(AVG(bc.memory_span), 1)  AS avg_memory,
                ROUND(AVG(bc.bet_size), 2)     AS avg_bet_size,
                ROUND(AVG(bs.roi), 2)          AS avg_roi_percent
            FROM BotStats bs
            JOIN bot_configs bc ON bs.user_id = bc.user_id
            GROUP BY 
                CASE 
                    WHEN tile = 1 THEN 'Winners (Top 10%)'
                    WHEN tile = 10 THEN 'Losers (Bottom 10%)'
                    ELSE 'Average Mass' 
                END
            ORDER BY avg_roi_percent DESC;

        p_status := 'SUCCESS';
        p_message := 'Роза ветров посчитана.';
    EXCEPTION WHEN OTHERS THEN
        pkg_logger.log_error('get_windrose_data', NULL, SQLCODE, SQLERRM);
        p_status := 'ERROR';
        p_message := 'Internal error: ' || SQLERRM;
    END get_windrose_data;

    PROCEDURE get_market_heatmap(
        p_cursor  OUT t_cursor,
        p_status  OUT VARCHAR2,
        p_message OUT VARCHAR2
    ) IS
        v_start_time TIMESTAMP;
    BEGIN
        BEGIN
            SELECT start_time INTO v_start_time 
            FROM tournaments 
            WHERE status_id IN (STATUS_ACTIVE, STATUS_PAUSED)
            ORDER BY tournament_id DESC FETCH FIRST 1 ROW ONLY;
        EXCEPTION WHEN NO_DATA_FOUND THEN
            v_start_time := SYSTIMESTAMP - INTERVAL '1' HOUR; -- Fallback
        END;

        OPEN p_cursor FOR
        WITH 
        StartPrices AS (
            SELECT pl.company_id,
                   MAX(pl.price) KEEP (DENSE_RANK FIRST ORDER BY pl.log_time DESC) AS start_price
            FROM price_log pl
            WHERE pl.log_time <= v_start_time
            GROUP BY pl.company_id
        ),
        TradeAgg AS (
            SELECT t.company_id, SUM(t.quantity) AS vol
            FROM trades t
            WHERE t.executed_at >= v_start_time
            GROUP BY t.company_id
        )
        SELECT 
            NVL(s.name, 'GLOBAL_INDEX') AS hierarchy_level_1,
            NVL(c.name, c.name) AS hierarchy_level_2,
            NVL(SUM(ta.vol), 0) AS total_volume,
            ROUND(
                NVL(
                    SUM(
                        ((c.current_price - NVL(sp.start_price, c.current_price)) 
                         / NULLIF(NVL(sp.start_price, c.current_price), 0) * 100) 
                        * NVL(ta.vol, 0)
                    ) / NULLIF(SUM(NVL(ta.vol, 0)), 0)
                , 0)
            , 2) AS weighted_change,
            CASE 
                WHEN NVL(
                    SUM(
                        ((c.current_price - NVL(sp.start_price, c.current_price)) 
                         / NULLIF(NVL(sp.start_price, c.current_price), 0) * 100) 
                        * NVL(ta.vol, 0)
                    ) / NULLIF(SUM(NVL(ta.vol, 0)), 0)
                , 0) > 0 THEN 'BULLISH' 
                ELSE 'BEARISH' 
            END AS status
        FROM companies c
        LEFT JOIN sectors s ON c.sector_id = s.sector_id
        LEFT JOIN TradeAgg ta ON c.company_id = ta.company_id
        LEFT JOIN StartPrices sp ON c.company_id = sp.company_id
        GROUP BY ROLLUP (s.name, c.name)
        ORDER BY total_volume DESC;

        p_status := 'SUCCESS';
        p_message := 'Heatmap высчитан.';
    EXCEPTION WHEN OTHERS THEN
        pkg_logger.log_error('get_market_heatmap', NULL, SQLCODE, SQLERRM);
        p_status := 'ERROR';
        p_message := 'Internal error: ' || SQLERRM;
    END get_market_heatmap;

    PROCEDURE get_top_active_companies(
        p_cursor  OUT t_cursor,
        p_status  OUT VARCHAR2,
        p_message OUT VARCHAR2
    ) IS
        v_start_time TIMESTAMP;
    BEGIN
        BEGIN
            SELECT start_time INTO v_start_time 
            FROM tournaments 
            WHERE status_id IN (STATUS_ACTIVE, STATUS_PAUSED)
            ORDER BY tournament_id DESC FETCH FIRST 1 ROW ONLY;
        EXCEPTION WHEN NO_DATA_FOUND THEN
            v_start_time := SYSTIMESTAMP - INTERVAL '1' HOUR;
        END;

        OPEN p_cursor FOR
            SELECT * FROM (
                SELECT 
                    c.name AS company_name,
                    c.ticker_symbol,       
                    SUM(t.quantity) AS total_shares,
                    COUNT(t.trade_id) AS trade_count
                FROM trades t
                JOIN companies c ON t.company_id = c.company_id
                WHERE t.executed_at >= v_start_time
                GROUP BY c.company_id, c.name, c.ticker_symbol
                ORDER BY SUM(t.quantity) DESC
            ) WHERE ROWNUM <= 5;

        p_status := 'SUCCESS';
        p_message := 'Топ 5 компаний высчитаны.';
    EXCEPTION WHEN OTHERS THEN
        pkg_logger.log_error('get_top_active_companies', NULL, SQLCODE, SQLERRM);
        p_status := 'ERROR';
        p_message := 'Internal error: ' || SQLERRM;
    END get_top_active_companies;

END pkg_olap_analytics;
/
CREATE OR REPLACE PACKAGE pkg_olap_analytics AS
    TYPE t_cursor IS REF CURSOR;

    -- Роза ветров
    PROCEDURE get_windrose_data(
        p_cursor  OUT t_cursor,
        p_status  OUT VARCHAR2,
        p_message OUT VARCHAR2
    );

    -- Heatmap
    PROCEDURE get_market_heatmap(
        p_cursor  OUT t_cursor,
        p_status  OUT VARCHAR2,
        p_message OUT VARCHAR2
    );

    -- Топ Активных
    PROCEDURE get_top_active_companies(
        p_cursor  OUT t_cursor,
        p_status  OUT VARCHAR2,
        p_message OUT VARCHAR2
    );
END pkg_olap_analytics;
/
