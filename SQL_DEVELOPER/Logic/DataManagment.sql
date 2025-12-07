CREATE OR REPLACE PACKAGE pkg_data_management AS

    -- Полный экспорт БД (включая пароли и историю)
    PROCEDURE export_database_json (
        o_json_clob OUT CLOB,
        o_status    OUT VARCHAR2,
        o_message   OUT VARCHAR2
    );

    -- Полный импорт
    PROCEDURE import_database_json (
        p_json_clob IN  CLOB,
        o_status    OUT VARCHAR2,
        o_message   OUT VARCHAR2
    );

END pkg_data_management;
/

CREATE OR REPLACE PACKAGE BODY pkg_data_management AS

    PROCEDURE export_database_json (
        o_json_clob OUT CLOB,
        o_status    OUT VARCHAR2,
        o_message   OUT VARCHAR2
    ) IS
    BEGIN
        o_status := 'SUCCESS';
        o_message := 'Полный экспорт сформирован';

        SELECT JSON_OBJECT(
            -- 2. Сектора
            'sectors' VALUE (
                SELECT JSON_ARRAYAGG(
                    JSON_OBJECT('id' VALUE sector_id, 'name' VALUE name, 'desc' VALUE description)
                    RETURNING CLOB
                ) FROM sectors
            ),
            -- 3. Компании
            'companies' VALUE (
                SELECT JSON_ARRAYAGG(
                    JSON_OBJECT(
                        'id' VALUE company_id, 'sec_id' VALUE sector_id, 'name' VALUE name,
                        'ticker' VALUE ticker_symbol, 'desc' VALUE description,
                        'price' VALUE current_price, 'vol' VALUE volatility_factor,
                        'stat' VALUE status, 'shares' VALUE total_shares,
                        'last_tr' VALUE TO_CHAR(last_trade_at, 'YYYY-MM-DD"T"HH24:MI:SS.FF')
                    ) RETURNING CLOB
                ) FROM companies
            ),
            -- 4. Пользователи (С ПАРОЛЯМИ!)
            'users' VALUE (
                SELECT JSON_ARRAYAGG(
                    JSON_OBJECT(
                        'id' VALUE user_id, 'rid' VALUE role_id, 'name' VALUE username,
                        'email' VALUE email, 'pass' VALUE password_hash, -- <--- Пароль
                        'bal' VALUE balance, 'ban' VALUE is_banned,
                        'cr_at' VALUE TO_CHAR(created_at, 'YYYY-MM-DD"T"HH24:MI:SS.FF')
                    ) RETURNING CLOB
                ) FROM users
            ),
            -- 5. Портфели
            'portfolios' VALUE (
                SELECT JSON_ARRAYAGG(
                    JSON_OBJECT('uid' VALUE user_id, 'cid' VALUE company_id, 'qty' VALUE quantity_owned)
                    RETURNING CLOB
                ) FROM portfolios
            ),
            -- 6. Ордера
            'orders' VALUE (
                SELECT JSON_ARRAYAGG(
                    JSON_OBJECT(
                        'id' VALUE order_id, 'uid' VALUE user_id, 'cid' VALUE company_id,
                        'type' VALUE type, 'stat' VALUE status, 'lim' VALUE limit_price,
                        'o_qty' VALUE original_qty, 'r_qty' VALUE remaining_qty,
                        'cr_at' VALUE TO_CHAR(created_at, 'YYYY-MM-DD"T"HH24:MI:SS.FF')
                    ) RETURNING CLOB
                ) FROM orders
            ),
            -- 7. Сделки
            'trades' VALUE (
                SELECT JSON_ARRAYAGG(
                    JSON_OBJECT(
                        'id' VALUE trade_id, 'bid' VALUE buyer_order_id, 'sid' VALUE seller_order_id,
                        'cid' VALUE company_id, 'pr' VALUE trade_price, 'qty' VALUE quantity,
                        'ex_at' VALUE TO_CHAR(executed_at, 'YYYY-MM-DD"T"HH24:MI:SS.FF')
                    ) RETURNING CLOB
                ) FROM trades
            ),
            -- 8. История цен
            'price_logs' VALUE (
                SELECT JSON_ARRAYAGG(
                    JSON_OBJECT(
                        'id' VALUE log_id, 'cid' VALUE company_id, 'pr' VALUE price,
                        'tm' VALUE TO_CHAR(log_time, 'YYYY-MM-DD"T"HH24:MI:SS.FF')
                    ) RETURNING CLOB
                ) FROM price_log
            ),
            -- 9. Уведомления
            'notifs' VALUE (
                SELECT JSON_ARRAYAGG(
                    JSON_OBJECT(
                        'id' VALUE notification_id, 'ti' VALUE title, 'msg' VALUE message,
                        'tp' VALUE type, 'cr_at' VALUE TO_CHAR(created_at, 'YYYY-MM-DD"T"HH24:MI:SS.FF')
                    ) RETURNING CLOB
                ) FROM notifications
            ),
            'user_notifs' VALUE (
                SELECT JSON_ARRAYAGG(
                    JSON_OBJECT(
                        'uid' VALUE user_id, 'nid' VALUE notification_id, 'read' VALUE is_read
                    ) RETURNING CLOB
                ) FROM stock_admin.user_notifications
            )
            RETURNING CLOB
        ) INTO o_json_clob FROM DUAL;

    EXCEPTION
        WHEN OTHERS THEN
            stock_admin.pkg_logger.log_error('pkg_data_management.export', NULL, SQLCODE, SQLERRM);
            o_status := 'ERROR';
            o_message := 'Ошибка экспорта';
            o_json_clob := '{}';
    END export_database_json;

    PROCEDURE import_database_json (
        p_json_clob IN  CLOB,
        o_status    OUT VARCHAR2,
        o_message   OUT VARCHAR2
    ) IS
    BEGIN
        o_status := 'SUCCESS';
        o_message := 'Полный импорт завершен';

        -- 2. Sectors
        MERGE INTO sectors t USING (
            SELECT * FROM JSON_TABLE(p_json_clob, '$.sectors[*]' COLUMNS (id NUMBER PATH '$.id', n VARCHAR2(100) PATH '$.name', d VARCHAR2(500) PATH '$.desc'))
        ) s ON (t.sector_id = s.id)
        WHEN MATCHED THEN UPDATE SET t.name = s.n, t.description = s.d
        WHEN NOT MATCHED THEN INSERT (sector_id, name, description) VALUES (s.id, s.n, s.d);

        -- 3. Companies
        MERGE INTO companies t USING (
            SELECT * FROM JSON_TABLE(p_json_clob, '$.companies[*]' COLUMNS (
                id NUMBER PATH '$.id', sid NUMBER PATH '$.sec_id', n VARCHAR2(100) PATH '$.name', 
                tic VARCHAR2(10) PATH '$.ticker', d VARCHAR2(1000) PATH '$.desc',
                p NUMBER PATH '$.price', v NUMBER PATH '$.vol', st VARCHAR2(20) PATH '$.stat', 
                sh NUMBER PATH '$.shares', lt VARCHAR2(50) PATH '$.last_tr'
            ))
        ) s ON (t.company_id = s.id)
        WHEN MATCHED THEN UPDATE SET t.current_price = s.p, t.status = s.st, t.last_trade_at = TO_TIMESTAMP(s.lt, 'YYYY-MM-DD"T"HH24:MI:SS.FF')
        WHEN NOT MATCHED THEN INSERT (company_id, sector_id, name, ticker_symbol, description, current_price, volatility_factor, status, total_shares, last_trade_at)
            VALUES (s.id, s.sid, s.n, s.tic, s.d, s.p, s.v, s.st, s.sh, TO_TIMESTAMP(s.lt, 'YYYY-MM-DD"T"HH24:MI:SS.FF'));

        -- 4. Users (WITH PASSWORDS)
        MERGE INTO users t USING (
            SELECT * FROM JSON_TABLE(p_json_clob, '$.users[*]' COLUMNS (
                id NUMBER PATH '$.id', rid NUMBER PATH '$.rid', un VARCHAR2(50) PATH '$.name', 
                em VARCHAR2(100) PATH '$.email', h VARCHAR2(255) PATH '$.pass', 
                bal NUMBER PATH '$.bal', ban NUMBER PATH '$.ban', cr VARCHAR2(50) PATH '$.cr_at'
            ))
        ) s ON (t.user_id = s.id)
        WHEN MATCHED THEN UPDATE SET t.balance = s.bal, t.password_hash = s.h, t.is_banned = s.ban
        WHEN NOT MATCHED THEN INSERT (user_id, role_id, username, email, password_hash, balance, is_banned, created_at)
            VALUES (s.id, s.rid, s.un, s.em, s.h, s.bal, s.ban, TO_TIMESTAMP(s.cr, 'YYYY-MM-DD"T"HH24:MI:SS.FF'));

        -- 5. Portfolios
        MERGE INTO portfolios t USING (
            SELECT * FROM JSON_TABLE(p_json_clob, '$.portfolios[*]' COLUMNS (uid NUMBER PATH '$.uid', cid NUMBER PATH '$.cid', q NUMBER PATH '$.qty'))
        ) s ON (t.user_id = s.uid AND t.company_id = s.cid)
        WHEN MATCHED THEN UPDATE SET t.quantity_owned = s.q
        WHEN NOT MATCHED THEN INSERT (user_id, company_id, quantity_owned) VALUES (s.uid, s.cid, s.q);

        -- 6. Orders
        MERGE INTO orders t USING (
            SELECT * FROM JSON_TABLE(p_json_clob, '$.orders[*]' COLUMNS (
                id NUMBER PATH '$.id', uid NUMBER PATH '$.uid', cid NUMBER PATH '$.cid', 
                tp VARCHAR2(10) PATH '$.type', st VARCHAR2(10) PATH '$.stat', 
                lim NUMBER PATH '$.lim', oq NUMBER PATH '$.o_qty', rq NUMBER PATH '$.r_qty', 
                cr VARCHAR2(50) PATH '$.cr_at'
            ))
        ) s ON (t.order_id = s.id)
        WHEN MATCHED THEN UPDATE SET t.status = s.st, t.remaining_qty = s.rq
        WHEN NOT MATCHED THEN INSERT (order_id, user_id, company_id, type, status, limit_price, original_qty, remaining_qty, created_at)
            VALUES (s.id, s.uid, s.cid, s.tp, s.st, s.lim, s.oq, s.rq, TO_TIMESTAMP(s.cr, 'YYYY-MM-DD"T"HH24:MI:SS.FF'));

        -- 7. Trades
        MERGE INTO trades t USING (
            SELECT * FROM JSON_TABLE(p_json_clob, '$.trades[*]' COLUMNS (
                id NUMBER PATH '$.id', bid NUMBER PATH '$.bid', sid NUMBER PATH '$.sid', 
                cid NUMBER PATH '$.cid', pr NUMBER PATH '$.pr', qty NUMBER PATH '$.qty', 
                ex VARCHAR2(50) PATH '$.ex_at'
            ))
        ) s ON (t.trade_id = s.id)
        WHEN NOT MATCHED THEN INSERT (trade_id, buyer_order_id, seller_order_id, company_id, trade_price, quantity, executed_at)
            VALUES (s.id, s.bid, s.sid, s.cid, s.pr, s.qty, TO_TIMESTAMP(s.ex, 'YYYY-MM-DD"T"HH24:MI:SS.FF'));

        -- 8. Price Logs
        MERGE INTO price_log t USING (
            SELECT * FROM JSON_TABLE(p_json_clob, '$.price_logs[*]' COLUMNS (
                id NUMBER PATH '$.id', cid NUMBER PATH '$.cid', pr NUMBER PATH '$.pr', tm VARCHAR2(50) PATH '$.tm'
            ))
        ) s ON (t.log_id = s.id)
        WHEN NOT MATCHED THEN INSERT (log_id, company_id, price, log_time) 
            VALUES (s.id, s.cid, s.pr, TO_TIMESTAMP(s.tm, 'YYYY-MM-DD"T"HH24:MI:SS.FF'));

        -- 9. Notifications
        MERGE INTO notifications t USING (
            SELECT * FROM JSON_TABLE(p_json_clob, '$.notifs[*]' COLUMNS (
                id NUMBER PATH '$.id', ti VARCHAR2(200) PATH '$.ti', msg VARCHAR2(1000) PATH '$.msg', 
                tp VARCHAR2(20) PATH '$.tp', cr VARCHAR2(50) PATH '$.cr_at'
            ))
        ) s ON (t.notification_id = s.id)
        WHEN NOT MATCHED THEN INSERT (notification_id, title, message, type, created_at)
            VALUES (s.id, s.ti, s.msg, s.tp, TO_TIMESTAMP(s.cr, 'YYYY-MM-DD"T"HH24:MI:SS.FF'));

        -- 10. User Notifications
        MERGE INTO user_notifications t USING (
            SELECT * FROM JSON_TABLE(p_json_clob, '$.user_notifs[*]' COLUMNS (
                uid NUMBER PATH '$.uid', nid NUMBER PATH '$.nid', r NUMBER PATH '$.read'
            ))
        ) s ON (t.user_id = s.uid AND t.notification_id = s.nid)
        WHEN MATCHED THEN UPDATE SET t.is_read = s.r
        WHEN NOT MATCHED THEN INSERT (user_id, notification_id, is_read) VALUES (s.uid, s.nid, s.r);

        COMMIT;

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            stock_admin.pkg_logger.log_error('pkg_data_management.import', NULL, SQLCODE, SQLERRM);
            o_status := 'ERROR';
            o_message := 'Ошибка импорта данных (см. логи): ' || SQLERRM;
    END import_database_json;

END pkg_data_management;
/
