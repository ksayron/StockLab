CREATE OR REPLACE PACKAGE pkg_users AS

    -- 1. Регистрация нового пользователя
    PROCEDURE register_user (
        p_username      IN  VARCHAR2,
        p_email         IN  VARCHAR2,
        p_password_hash IN  VARCHAR2,
        o_user_id       OUT NUMBER,
        o_role_name     OUT VARCHAR2,
        -- Soft Error Params
        o_status        OUT VARCHAR2, -- 'SUCCESS' / 'ERROR'
        o_message       OUT VARCHAR2
    );

    -- 2. Аутентификация
    PROCEDURE authenticate_user (
        p_username      IN  VARCHAR2,
        p_password_hash IN  VARCHAR2,
        o_user_id       OUT NUMBER,
        o_role_name     OUT VARCHAR2,
        o_is_banned     OUT NUMBER,
        o_status        OUT VARCHAR2,
        o_message       OUT VARCHAR2
    );

    -- 3. Получить данные по ID
    PROCEDURE get_user_details (
        p_user_id       IN  NUMBER,
        o_cursor        OUT SYS_REFCURSOR,
        o_status        OUT VARCHAR2,
        o_message       OUT VARCHAR2
    );

    -- 4. Добавить средства
    PROCEDURE deposit_cash (
        p_user_id       IN  NUMBER,
        p_amount        IN  NUMBER,
        o_status        OUT VARCHAR2,
        o_message       OUT VARCHAR2
    );

END pkg_users;
/

CREATE OR REPLACE PACKAGE BODY pkg_users AS

    -- =============================================
    -- 1. РЕГИСТРАЦИЯ
    -- =============================================
    PROCEDURE register_user (
        p_username      IN  VARCHAR2,
        p_email         IN  VARCHAR2,
        p_password_hash IN  VARCHAR2,
        o_user_id       OUT NUMBER,
        o_role_name     OUT VARCHAR2,
        o_status        OUT VARCHAR2,
        o_message       OUT VARCHAR2
    ) IS
        v_role_id NUMBER;
    BEGIN
        -- Инициализация
        o_status := 'SUCCESS';
        o_message := 'Пользователь зарегестрирован';

        -- Валидация имени
        IF UPPER(p_username) LIKE 'ISSUER_%' THEN
            o_status := 'ERROR';
            o_message := 'Используется зарезервированный системный префикс';
            RETURN; -- Выходим без ошибки
        END IF;

        -- Логика
        SELECT role_id, name INTO v_role_id, o_role_name
        FROM roles WHERE name = 'User';

        INSERT INTO users (role_id, username, email, password_hash, balance) 
        VALUES (v_role_id, p_username, p_email, p_password_hash, 0) 
        RETURNING user_id INTO o_user_id;

        COMMIT;

    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            ROLLBACK;
            o_status := 'ERROR';
            o_message := 'Имя пользователья или адрес эл. почты уже заняты';
            -- Не пишем в лог, так как это бизнес-ошибка, а не сбой системы
            
        WHEN OTHERS THEN
            ROLLBACK;
            -- Пишем в лог реальную ошибку
            stock_admin.pkg_logger.log_error('pkg_users.register_user', NULL, SQLCODE, SQLERRM);
            -- Возвращаем клиенту общее сообщение
            o_status := 'ERROR';
            o_message := 'Internal System Error';
    END register_user;

    -- =============================================
    -- 2. АУТЕНТИФИКАЦИЯ
    -- =============================================
    PROCEDURE authenticate_user (
        p_username      IN  VARCHAR2,
        p_password_hash IN  VARCHAR2,
        o_user_id       OUT NUMBER,
        o_role_name     OUT VARCHAR2,
        o_is_banned     OUT NUMBER,
        o_status        OUT VARCHAR2,
        o_message       OUT VARCHAR2
    ) IS
    BEGIN
        o_status := 'SUCCESS';
        o_message := 'Вход выполнен';

        BEGIN
            SELECT u.user_id, r.name, u.is_banned
            INTO o_user_id, o_role_name, o_is_banned
            FROM users u
            JOIN roles r ON u.role_id = r.role_id
            WHERE u.username = p_username 
              AND u.password_hash = p_password_hash;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                o_status := 'ERROR';
                o_message := 'Неподходящие логин и пароль';
                RETURN;
        END;

        IF o_is_banned = 1 THEN
            o_status := 'ERROR';
            o_message := 'Данный аккаунт заблокирован';
            RETURN;
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            stock_admin.pkg_logger.log_error('pkg_users.authenticate_user', NULL, SQLCODE, SQLERRM);
            o_status := 'ERROR';
            o_message := 'Internal System Error';
    END authenticate_user;

    -- =============================================
    -- 3. ПОЛУЧЕНИЕ ДАННЫХ
    -- =============================================
    PROCEDURE get_user_details (
        p_user_id IN  NUMBER,
        o_cursor  OUT SYS_REFCURSOR,
        o_status  OUT VARCHAR2,
        o_message OUT VARCHAR2
    ) IS
    BEGIN
        o_status := 'SUCCESS';
        o_message := 'OK';

        OPEN o_cursor FOR
            SELECT u.user_id, u.username, u.email, u.balance, u.created_at, r.name as role_name
            FROM users u
            JOIN roles r ON u.role_id = r.role_id
            WHERE u.user_id = p_user_id;
            
    EXCEPTION
        WHEN OTHERS THEN
            stock_admin.pkg_logger.log_error('pkg_users.get_user_details', p_user_id, SQLCODE, SQLERRM);
            o_status := 'ERROR';
            o_message := 'Internal System Error';
    END get_user_details;

    -- =============================================
    -- 4. ДЕПОЗИТ
    -- =============================================
    PROCEDURE deposit_cash (
        p_user_id IN NUMBER,
        p_amount  IN NUMBER,
        o_status  OUT VARCHAR2,
        o_message OUT VARCHAR2
    ) IS
    BEGIN
        o_status := 'SUCCESS';
        o_message := 'Пополнение успешно';

        IF p_amount <= 0 THEN
            o_status := 'ERROR';
            o_message := 'Сумма должна быть положительной';
            RETURN;
        END IF;

        UPDATE users
        SET balance = balance + p_amount
        WHERE user_id = p_user_id;

        IF SQL%ROWCOUNT = 0 THEN
            ROLLBACK;
            o_status := 'ERROR';
            o_message := 'Пользователь не найден';
            RETURN;
        END IF;

        COMMIT;

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            stock_admin.pkg_logger.log_error('pkg_users.deposit_cash', p_user_id, SQLCODE, SQLERRM);
            o_status := 'ERROR';
            o_message := 'Internal System Error';
    END deposit_cash;

END pkg_users;
/
CREATE OR REPLACE PUBLIC SYNONYM pkg_users FOR stock_admin.pkg_users;

GRANT EXECUTE ON pkg_users TO stock_guest;
GRANT EXECUTE ON pkg_users TO stock_user
GRANT EXECUTE ON pkg_users TO stock_admin;