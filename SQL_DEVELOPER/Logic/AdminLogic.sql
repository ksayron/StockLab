CREATE OR REPLACE PACKAGE pkg_admin_tools AS

    -- 1. Блокировка / Разблокировка
    PROCEDURE set_user_ban_status (
        p_admin_id       IN  NUMBER,
        p_target_user_id IN  NUMBER,
        p_is_banned      IN  NUMBER,
        o_status         OUT VARCHAR2,
        o_message        OUT VARCHAR2
    );

    -- 2. Создание нового Админа (Вместо promote)
    PROCEDURE create_new_admin (
        p_username      IN  VARCHAR2,
        p_password_hash IN  VARCHAR2,
        o_admin_id      OUT NUMBER,
        o_status        OUT VARCHAR2,
        o_message       OUT VARCHAR2
    );

    -- 3. Ручное изменение баланса
    PROCEDURE adjust_user_balance (
        p_target_user_id IN  NUMBER,
        p_new_balance    IN  NUMBER,
        o_status         OUT VARCHAR2,
        o_message        OUT VARCHAR2
    );

    -- 4. Получение данных
    PROCEDURE get_user_full_details (
        p_target_user_id IN  NUMBER,
        o_cursor         OUT SYS_REFCURSOR,
        o_status         OUT VARCHAR2,
        o_message        OUT VARCHAR2
    );

    -- 5. Ордера компании
    PROCEDURE get_company_orders_admin (
        p_company_id IN  NUMBER,
        o_cursor     OUT SYS_REFCURSOR,
        o_status     OUT VARCHAR2,
        o_message    OUT VARCHAR2
    );

    -- 6. Сделки компании
    PROCEDURE get_company_trades_admin (
        p_company_id IN  NUMBER,
        o_cursor     OUT SYS_REFCURSOR,
        o_status     OUT VARCHAR2,
        o_message    OUT VARCHAR2
    );
    
    -- 7. Просмотр системных логов ошибок
    PROCEDURE get_system_error_logs (
        p_minutes_back IN  NUMBER DEFAULT NULL,
        o_cursor       OUT SYS_REFCURSOR,
        o_status       OUT VARCHAR2,
        o_message      OUT VARCHAR2
    );
    
    PROCEDURE get_all_users (
    o_cursor  OUT SYS_REFCURSOR,
    o_status  OUT VARCHAR2,
    o_message OUT VARCHAR2
    );

END pkg_admin_tools;
/

CREATE OR REPLACE PACKAGE BODY pkg_admin_tools AS

    -- 1. SET BAN
    PROCEDURE set_user_ban_status (
        p_admin_id       IN  NUMBER,
        p_target_user_id IN  NUMBER,
        p_is_banned      IN  NUMBER,
        o_status         OUT VARCHAR2,
        o_message        OUT VARCHAR2
    ) IS
    BEGIN
        o_status := 'SUCCESS';
        o_message := 'Статус блокировки изменен';

        IF p_admin_id = p_target_user_id THEN
            o_status := 'ERROR';
            o_message := 'Нельзя заблокировать самого себя';
            RETURN;
        END IF;

        UPDATE users 
        SET is_banned = p_is_banned 
        WHERE user_id = p_target_user_id;

        IF SQL%ROWCOUNT = 0 THEN
            o_status := 'ERROR';
            o_message := 'Пользователь не найден';
            RETURN;
        END IF;
        
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            stock_admin.pkg_logger.log_error('pkg_admin_tools.set_user_ban_status', p_admin_id, SQLCODE, SQLERRM);
            o_status := 'ERROR';
            o_message := 'Internal Server Error';
    END set_user_ban_status;

    -- 2. CREATE NEW ADMIN
    PROCEDURE create_new_admin (
        p_username      IN  VARCHAR2,
        p_password_hash IN  VARCHAR2,
        o_admin_id      OUT NUMBER,
        o_status        OUT VARCHAR2,
        o_message       OUT VARCHAR2
    ) IS
        v_admin_role_id NUMBER;
        v_email         VARCHAR2(100);
    BEGIN
        o_status := 'SUCCESS';
        o_message := 'Администратор создан';

        -- Генерация системной почты
        v_email := p_username || '@stocklab.internal';

        SELECT role_id INTO v_admin_role_id FROM roles WHERE name = 'Admin';

        INSERT INTO users (role_id, username, email, password_hash, balance) 
        VALUES (v_admin_role_id, p_username, v_email, p_password_hash, 0)
        RETURNING user_id INTO o_admin_id;

        COMMIT;

    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            ROLLBACK;
            o_status := 'ERROR';
            o_message := 'Имя пользователя уже занято';
        WHEN OTHERS THEN
            ROLLBACK;
            stock_admin.pkg_logger.log_error('pkg_admin_tools.create_new_admin', NULL, SQLCODE, SQLERRM);
            o_status := 'ERROR';
            o_message := 'Internal Server Error';
    END create_new_admin;

    -- 3. ADJUST BALANCE
    PROCEDURE adjust_user_balance (
        p_target_user_id IN  NUMBER,
        p_new_balance    IN  NUMBER,
        o_status         OUT VARCHAR2,
        o_message        OUT VARCHAR2
    ) IS
    BEGIN
        o_status := 'SUCCESS';
        o_message := 'Баланс обновлен';

        UPDATE users 
        SET balance = p_new_balance 
        WHERE user_id = p_target_user_id;
        
        IF SQL%ROWCOUNT = 0 THEN
            o_status := 'ERROR';
            o_message := 'Пользователь не найден';
            RETURN;
        END IF;
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            stock_admin.pkg_logger.log_error('pkg_admin_tools.adjust_user_balance', NULL, SQLCODE, SQLERRM);
            o_status := 'ERROR';
            o_message := 'Internal Server Error';
    END adjust_user_balance;

    -- 4. GET USER DETAILS
    PROCEDURE get_user_full_details (
        p_target_user_id IN  NUMBER,
        o_cursor         OUT SYS_REFCURSOR,
        o_status         OUT VARCHAR2,
        o_message        OUT VARCHAR2
    ) IS
    BEGIN
        o_status := 'SUCCESS';
        o_message := 'ОК';

        OPEN o_cursor FOR
            SELECT u.user_id, u.username, u.email, u.balance, u.is_banned, 
                   r.name as role_name, u.created_at,
                   (SELECT COUNT(*) FROM orders o WHERE o.user_id = u.user_id) as total_orders,
                   (SELECT COUNT(*) FROM trades t 
                    JOIN orders o ON t.buyer_order_id = o.order_id OR t.seller_order_id = o.order_id 
                    WHERE o.user_id = u.user_id) as total_trades
            FROM users u
            JOIN roles r ON u.role_id = r.role_id
            WHERE u.user_id = p_target_user_id;
    EXCEPTION
        WHEN OTHERS THEN
            stock_admin.pkg_logger.log_error('pkg_admin_tools.get_user_full_details', p_target_user_id, SQLCODE, SQLERRM);
            o_status := 'ERROR';
            o_message := 'Internal Server Error';
    END get_user_full_details;

    -- 5. GET COMPANY ORDERS
    PROCEDURE get_company_orders_admin (
        p_company_id IN  NUMBER,
        o_cursor     OUT SYS_REFCURSOR,
        o_status     OUT VARCHAR2,
        o_message    OUT VARCHAR2
    ) IS
    BEGIN
        o_status := 'SUCCESS';
        o_message := 'ОК';

        OPEN o_cursor FOR
            SELECT o.order_id, u.username, o.type, o.status, 
                   o.limit_price, o.original_qty, o.remaining_qty, o.created_at
            FROM orders o
            JOIN users u ON o.user_id = u.user_id
            WHERE o.company_id = p_company_id
            ORDER BY o.created_at DESC;
    EXCEPTION
        WHEN OTHERS THEN
            stock_admin.pkg_logger.log_error('pkg_admin_tools.get_company_orders_admin', NULL, SQLCODE, SQLERRM);
            o_status := 'ERROR';
            o_message := 'Internal Server Error';
    END get_company_orders_admin;

    -- 6. GET COMPANY TRADES
    PROCEDURE get_company_trades_admin (
        p_company_id IN  NUMBER,
        o_cursor     OUT SYS_REFCURSOR,
        o_status     OUT VARCHAR2,
        o_message    OUT VARCHAR2
    ) IS
    BEGIN
        o_status := 'SUCCESS';
        o_message := 'ОК';

        OPEN o_cursor FOR
            SELECT t.trade_id, 
                   u_buy.username as buyer, 
                   u_sell.username as seller,
                   t.trade_price, t.quantity, t.executed_at
            FROM trades t
            JOIN orders o_buy ON t.buyer_order_id = o_buy.order_id
            JOIN users u_buy ON o_buy.user_id = u_buy.user_id
            JOIN orders o_sell ON t.seller_order_id = o_sell.order_id
            JOIN users u_sell ON o_sell.user_id = u_sell.user_id
            WHERE t.company_id = p_company_id
            ORDER BY t.executed_at DESC;
    EXCEPTION
        WHEN OTHERS THEN
            stock_admin.pkg_logger.log_error('pkg_admin_tools.get_company_trades_admin', NULL, SQLCODE, SQLERRM);
            o_status := 'ERROR';
            o_message := 'Internal Server Error';
    END get_company_trades_admin;
    
    PROCEDURE get_system_error_logs (
        p_minutes_back IN  NUMBER DEFAULT NULL,
        o_cursor       OUT SYS_REFCURSOR,
        o_status       OUT VARCHAR2,
        o_message      OUT VARCHAR2
    ) IS
    BEGIN
        o_status := 'SUCCESS';
        o_message := 'ОК';

        OPEN o_cursor FOR
            SELECT log_id, proc_name, user_id, error_code, error_msg, created_at
            FROM error_log
            WHERE p_minutes_back IS NULL 
               OR created_at >= SYSTIMESTAMP - NUMTODSINTERVAL(p_minutes_back, 'MINUTE')
            ORDER BY created_at DESC
            FETCH FIRST 1000 ROWS ONLY; -- Защита от перегрузки, если фильтр не задан

    EXCEPTION
        WHEN OTHERS THEN
            -- Если даже чтение логов упало, пишем в лог (рекурсия, но безопасная из-за автономности pkg_logger)
            stock_admin.pkg_logger.log_error('pkg_admin_tools.get_system_logs', NULL, SQLCODE, SQLERRM);
            o_status := 'ERROR';
            o_message := 'Не удалось прочитать логи';
    END get_system_error_logs;
    
    PROCEDURE get_all_users (
    o_cursor  OUT SYS_REFCURSOR,
    o_status  OUT VARCHAR2,
    o_message OUT VARCHAR2
    ) IS
    BEGIN
        o_status := 'SUCCESS';
        o_message := 'ОК';
        
        OPEN o_cursor FOR
            SELECT u.user_id, u.username, u.email, u.balance, u.is_banned, 
                r.name as role_name, u.created_at
            FROM users u
            JOIN roles r ON u.role_id = r.role_id
            WHERE u.role_id = 1 or u.role_id = 2
            ORDER BY u.created_at DESC;
    EXCEPTION
        WHEN OTHERS THEN
            stock_admin.pkg_logger.log_error('pkg_admin_tools.get_all_users', NULL, SQLCODE, SQLERRM);
            o_status := 'ERROR';
            o_message := 'Внутренняя ошибка сервера';
    END get_all_users;

END pkg_admin_tools;
/