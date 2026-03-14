CREATE OR REPLACE PACKAGE pkg_data_management AS

    -- Экспорт конфигурации рынка (Sectors, Companies, PriceLog)
    PROCEDURE export_market_data (
        o_json_clob OUT CLOB,
        o_status    OUT VARCHAR2,
        o_message   OUT VARCHAR2
    );

    -- Импорт с внутренней логикой генерации IPO для новых компаний
    PROCEDURE import_market_data (
        p_json_clob IN  CLOB,
        o_status    OUT VARCHAR2,
        o_message   OUT VARCHAR2
    );

END pkg_data_management;
/
CREATE OR REPLACE PACKAGE BODY pkg_data_management AS
    PROCEDURE export_market_data (
        o_json_clob OUT CLOB,
        o_status    OUT VARCHAR2,
        o_message   OUT VARCHAR2
    ) IS
    BEGIN
        o_status := 'SUCCESS';
        o_message := 'Экспорт рынка сформирован';

        SELECT JSON_OBJECT(
            -- 1. Сектора
            'sectors' VALUE (
                SELECT JSON_ARRAYAGG(
                    JSON_OBJECT(
                        'id' VALUE sector_id, 
                        'name' VALUE name, 
                        'desc' VALUE description
                    ) RETURNING CLOB
                ) FROM sectors
            ),
            -- 2. Компании (включая волатильность и статус)
            'companies' VALUE (
                SELECT JSON_ARRAYAGG(
                    JSON_OBJECT(
                        'id' VALUE company_id, 
                        'sec_id' VALUE sector_id, 
                        'name' VALUE name,
                        'ticker' VALUE ticker_symbol, 
                        'desc' VALUE description,
                        'price' VALUE current_price, 
                        'vol' VALUE volatility_factor,
                        'stat' VALUE status, 
                        'shares' VALUE total_shares,
                        'last_tr' VALUE TO_CHAR(last_trade_at, 'YYYY-MM-DD"T"HH24:MI:SS.FF')
                    ) RETURNING CLOB
                ) FROM companies
            ),
            -- 3. История цен
            'price_logs' VALUE (
                SELECT JSON_ARRAYAGG(
                    JSON_OBJECT(
                        'id' VALUE log_id, 
                        'cid' VALUE company_id, 
                        'pr' VALUE price,
                        'tm' VALUE TO_CHAR(log_time, 'YYYY-MM-DD"T"HH24:MI:SS.FF')
                    ) RETURNING CLOB
                ) FROM price_log
            )
            RETURNING CLOB
        ) INTO o_json_clob FROM DUAL;

    EXCEPTION
        WHEN OTHERS THEN
            stock_admin.pkg_logger.log_error('pkg_data_management.export', NULL, SQLCODE, SQLERRM);
            o_status := 'ERROR';
            o_message := 'Ошибка экспорта: ' || SQLERRM;
            o_json_clob := '{}';
    END export_market_data;

   PROCEDURE import_market_data (
        p_json_clob IN  CLOB,
        o_status    OUT VARCHAR2,
        o_message   OUT VARCHAR2
    ) IS
        v_role_id        NUMBER;
        v_issuer_name    VARCHAR2(100);
        v_issuer_user_id NUMBER;
    BEGIN
        o_status := 'SUCCESS';
        o_message := 'Импорт рынка завершен';

        -- Очистка данных
        DELETE FROM price_log;
        DELETE FROM trades;
        DELETE FROM orders;
        DELETE FROM portfolios;
        DELETE FROM companies;
    
        BEGIN
             DELETE FROM users WHERE role_id = (SELECT role_id FROM roles WHERE name = 'Issuer');
        EXCEPTION WHEN OTHERS THEN NULL; END;

        DELETE FROM sectors; 
    

        -- 2. СЕКТОРА
        MERGE INTO sectors t USING (
            SELECT * FROM JSON_TABLE(p_json_clob, '$.sectors[*]' 
                COLUMNS (
                    id NUMBER PATH '$.id', 
                    n VARCHAR2(100) PATH '$.name', 
                    d VARCHAR2(500) PATH '$.desc'
                )
            )
        ) s ON (t.sector_id = s.id)
        WHEN MATCHED THEN UPDATE SET t.name = s.n, t.description = s.d
        WHEN NOT MATCHED THEN INSERT (sector_id, name, description) VALUES (s.id, s.n, s.d);

        INSERT INTO companies (
            company_id, sector_id, name, ticker_symbol, description, 
            current_price, volatility_factor, status, total_shares, last_trade_at
        )
        SELECT 
            id, sid, n, tic, d, p, v, st, sh, 
            TO_TIMESTAMP(lt, 'YYYY-MM-DD"T"HH24:MI:SS.FF')
        FROM JSON_TABLE(p_json_clob, '$.companies[*]' 
            COLUMNS (
                id NUMBER PATH '$.id', 
                sid NUMBER PATH '$.sec_id', 
                n VARCHAR2(100) PATH '$.name', 
                tic VARCHAR2(20) PATH '$.ticker', 
                d VARCHAR2(1000) PATH '$.desc',
                p NUMBER PATH '$.price', 
                v NUMBER PATH '$.vol', 
                st VARCHAR2(20) PATH '$.stat', 
                sh NUMBER PATH '$.shares', 
                lt VARCHAR2(50) PATH '$.last_tr'
            )
        );

        INSERT INTO price_log (log_id, company_id, price, log_time)
        SELECT id, cid, pr, TO_TIMESTAMP(tm, 'YYYY-MM-DD"T"HH24:MI:SS.FF')
        FROM JSON_TABLE(p_json_clob, '$.price_logs[*]' 
            COLUMNS (
                id NUMBER PATH '$.id', 
                cid NUMBER PATH '$.cid', 
                pr NUMBER PATH '$.pr', 
                tm VARCHAR2(50) PATH '$.tm'
            )
        );

        -- IPO
        BEGIN
            SELECT role_id INTO v_role_id FROM roles WHERE name = 'Issuer' FETCH FIRST 1 ROWS ONLY;
        EXCEPTION WHEN NO_DATA_FOUND THEN
            SELECT role_id INTO v_role_id FROM roles WHERE name = 'User' FETCH FIRST 1 ROWS ONLY;
        END;

        FOR r IN (
            SELECT company_id, ticker_symbol, current_price, total_shares 
            FROM companies
        ) LOOP
            
            v_issuer_name := 'ISSUER_' || UPPER(r.ticker_symbol);

            -- 1. Создаем или находим Эмитента (Upsert логика через Exception)
            BEGIN
                INSERT INTO users (role_id, username, email, password_hash, balance, is_banned) 
                VALUES (v_role_id, v_issuer_name, v_issuer_name || '@stocklab.internal', 'LOCKED', 0, 1)
                RETURNING user_id INTO v_issuer_user_id;
            EXCEPTION WHEN DUP_VAL_ON_INDEX THEN
                -- Если юзер остался с прошлого раза (не удалился из-за FK где-то еще)
                SELECT user_id INTO v_issuer_user_id FROM users WHERE username = v_issuer_name;
                -- Обновляем роль на правильную, если она была другой
                UPDATE users SET role_id = v_role_id WHERE user_id = v_issuer_user_id;
            END;

            -- 2. Выдаем акции эмитенту
            INSERT INTO portfolios (user_id, company_id, quantity_owned) 
            VALUES (v_issuer_user_id, r.company_id, r.total_shares);

            -- 3. Выставляем IPO ордер
            INSERT INTO orders (
                user_id, company_id, type, status, limit_price, 
                original_qty, remaining_qty, created_at
            ) VALUES (
                v_issuer_user_id, r.company_id, 'SELL', 'OPEN', r.current_price, 
                r.total_shares, r.total_shares, SYSTIMESTAMP
            );

        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            stock_admin.pkg_logger.log_error('pkg_data_management.import', NULL, SQLCODE, SQLERRM);
            o_status := 'ERROR';
            IF SQLCODE = -2291 THEN
                o_message := 'Ошибка целостности: Компания ссылается на несуществующий сектор';
            ELSE
                o_message := 'Ошибка импорта: ' || SQLERRM;
            END IF;
    END import_market_data;

END pkg_data_management;
/