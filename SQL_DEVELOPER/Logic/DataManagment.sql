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

    -- =================================================================
    -- EXPORT
    -- =================================================================
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

    -- =================================================================
    -- IMPORT (With Embedded IPO Logic)
    -- =================================================================
    PROCEDURE import_market_data (
        p_json_clob IN  CLOB,
        o_status    OUT VARCHAR2,
        o_message   OUT VARCHAR2
    ) IS
        v_count          NUMBER;
        v_role_id        NUMBER;
        v_issuer_name    VARCHAR2(100);
        v_issuer_user_id NUMBER;
    BEGIN
        o_status := 'SUCCESS';
        o_message := 'Импорт рынка завершен';

        -- 1. СЕКТОРА (Простой Merge)
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

        -- 2. КОМПАНИИ (Цикл с логикой)
        FOR r IN (
            SELECT * FROM JSON_TABLE(p_json_clob, '$.companies[*]' 
                COLUMNS (
                    id NUMBER PATH '$.id', sid NUMBER PATH '$.sec_id', n VARCHAR2(100) PATH '$.name', 
                    tic VARCHAR2(10) PATH '$.ticker', d VARCHAR2(1000) PATH '$.desc',
                    p NUMBER PATH '$.price', v NUMBER PATH '$.vol', st VARCHAR2(20) PATH '$.stat', 
                    sh NUMBER PATH '$.shares', lt VARCHAR2(50) PATH '$.last_tr'
                )
            )
        ) LOOP
            -- Проверяем существование
            SELECT COUNT(*) INTO v_count FROM companies WHERE company_id = r.id;

            IF v_count > 0 THEN
                -- A. Если есть -> ОБНОВЛЯЕМ
                UPDATE companies
                SET sector_id = r.sid, name = r.n, ticker_symbol = r.tic, 
                    description = r.d, current_price = r.p, volatility_factor = r.v, 
                    status = r.st, total_shares = r.sh,
                    last_trade_at = TO_TIMESTAMP(r.lt, 'YYYY-MM-DD"T"HH24:MI:SS.FF')
                WHERE company_id = r.id;
            ELSE
                -- B. Если нет -> ВСТАВЛЯЕМ + IPO ЛОГИКА
                INSERT INTO companies (
                    company_id, sector_id, name, ticker_symbol, description, 
                    current_price, volatility_factor, status, total_shares, last_trade_at
                ) VALUES (
                    r.id, r.sid, r.n, r.tic, r.d, 
                    r.p, r.v, r.st, r.sh, TO_TIMESTAMP(r.lt, 'YYYY-MM-DD"T"HH24:MI:SS.FF')
                );

                -- === ВНУТРЕННЯЯ ЛОГИКА IPO (Изолированная) ===
                BEGIN
                    v_issuer_name := 'ISSUER_' || UPPER(r.tic);
                    
                    -- Получаем ID роли (с фоллбэком)
                    BEGIN
                        SELECT role_id INTO v_role_id FROM roles WHERE name = 'User' FETCH FIRST 1 ROWS ONLY;
                    EXCEPTION WHEN NO_DATA_FOUND THEN
                        SELECT role_id INTO v_role_id FROM roles FETCH FIRST 1 ROWS ONLY;
                    END;

                    -- 1. Создаем/Ищем Эмитента
                    -- (Используем MERGE или BEGIN-EXCEPTION на случай, если юзер остался от старых тестов)
                    BEGIN
                        INSERT INTO users (role_id, username, email, password_hash, balance, is_banned) 
                        VALUES (v_role_id, v_issuer_name, v_issuer_name || '@stocklab.internal', 'LOCKED', 0, 1)
                        RETURNING user_id INTO v_issuer_user_id;
                    EXCEPTION WHEN DUP_VAL_ON_INDEX THEN
                        -- Если эмитент уже есть, берем его ID
                        SELECT user_id INTO v_issuer_user_id FROM users WHERE username = v_issuer_name;
                    END;

                    -- 2. Начисляем акции (Портфель)
                    MERGE INTO portfolios p
                    USING dual ON (p.user_id = v_issuer_user_id AND p.company_id = r.id)
                    WHEN MATCHED THEN UPDATE SET quantity_owned = r.sh
                    WHEN NOT MATCHED THEN INSERT (user_id, company_id, quantity_owned) VALUES (v_issuer_user_id, r.id, r.sh);

                    -- 3. Выставляем Ордер на продажу
                    -- (Удаляем старые открытые ордера этого эмитента по этой компании, чтобы не дублировать)
                    DELETE FROM orders WHERE user_id = v_issuer_user_id AND company_id = r.id AND status = 'OPEN';
                    
                    INSERT INTO orders (
                        user_id, company_id, type, status, limit_price, original_qty, remaining_qty
                    ) VALUES (
                        v_issuer_user_id, r.id, 'SELL', 'OPEN', r.p, r.sh, r.sh
                    );

                EXCEPTION WHEN OTHERS THEN
                    -- Если IPO провалилось, логируем, но не роняем весь импорт
                    stock_admin.pkg_logger.log_error('pkg_data_management.internal_ipo', NULL, SQLCODE, 'IPO failed for ' || r.tic || ': ' || SQLERRM);
                END;
                -- === КОНЕЦ ВНУТРЕННЕЙ ЛОГИКИ ===
            END IF;
        END LOOP;

        -- 3. ИСТОРИЯ ЦЕН (Merge)
        MERGE INTO price_log t USING (
            SELECT * FROM JSON_TABLE(p_json_clob, '$.price_logs[*]' 
                COLUMNS (
                    id NUMBER PATH '$.id', cid NUMBER PATH '$.cid', pr NUMBER PATH '$.pr', tm VARCHAR2(50) PATH '$.tm'
                )
            )
        ) s ON (t.log_id = s.id)
        WHEN NOT MATCHED THEN 
            INSERT (log_id, company_id, price, log_time) 
            VALUES (s.id, s.cid, s.pr, TO_TIMESTAMP(s.tm, 'YYYY-MM-DD"T"HH24:MI:SS.FF'));

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