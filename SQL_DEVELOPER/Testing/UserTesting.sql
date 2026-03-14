SET SERVEROUTPUT ON;

DECLARE
    -- Переменные для получения результатов
    v_user_id      NUMBER;
    v_role_name    VARCHAR2(50);
    v_status       VARCHAR2(50);
    v_message      VARCHAR2(4000);
    v_is_banned    NUMBER;
    v_cursor       SYS_REFCURSOR;
    
    -- Тестовые данные
    v_test_user    VARCHAR2(50) := 'TestUnitUser';
    v_test_email   VARCHAR2(100) := 'test.unit@example.com';
    v_test_pass    VARCHAR2(100) := 'StrongPass123';
    
    -- Переменные для выборки из курсора
    rec_user_id    NUMBER;
    rec_username   VARCHAR2(50);
    rec_email      VARCHAR2(100);
    rec_balance    NUMBER;
    rec_created    DATE;
    rec_role       VARCHAR2(50);

    -- Хелпер для вывода
    PROCEDURE print_test(p_test_name VARCHAR2, p_expected VARCHAR2, p_actual VARCHAR2, p_msg VARCHAR2 DEFAULT NULL) IS
    BEGIN
        DBMS_OUTPUT.PUT(RPAD(p_test_name, 40, '.') || ' ');
        IF p_expected = p_actual THEN
            DBMS_OUTPUT.PUT_LINE('[ OK ]');
        ELSE
            DBMS_OUTPUT.PUT_LINE('[ FAIL ] Expected: ' || p_expected || ', Got: ' || p_actual || '. Msg: ' || p_msg);
        END IF;
    END;

BEGIN
    DBMS_OUTPUT.PUT_LINE('=== ЗАПУСК ТЕСТОВ PKG_USERS ===');

    -- 0. Очистка (удаляем тестового пользователя, если он есть)
    --DELETE FROM users WHERE username = v_test_user;
    --COMMIT;

    -- ==========================================
    -- ТЕСТ 1: Валидация (Слишком короткое имя)
    -- ==========================================
    stock_admin.pkg_users.register_user(
        p_username      => 'Yo',
        p_email         => v_test_email,
        p_password_hash => v_test_pass,
        o_user_id       => v_user_id,
        o_role_name     => v_role_name,
        o_status        => v_status,
        o_message       => v_message
    );
    print_test('Register: Short Username', 'ERROR', v_status, v_message);

    -- ==========================================
    -- ТЕСТ 2: Валидация (Некорректный Email)
    -- ==========================================
    stock_admin.pkg_users.register_user(
        p_username      => v_test_user,
        p_email         => 'bad_email',
        p_password_hash => v_test_pass,
        o_user_id       => v_user_id,
        o_role_name     => v_role_name,
        o_status        => v_status,
        o_message       => v_message
    );
    print_test('Register: Bad Email', 'ERROR', v_status, v_message);

    -- ==========================================
    -- ТЕСТ 3: Успешная регистрация
    -- ==========================================
    stock_admin.pkg_users.register_user(
        p_username      => v_test_user,
        p_email         => v_test_email,
        p_password_hash => v_test_pass,
        o_user_id       => v_user_id,
        o_role_name     => v_role_name,
        o_status        => v_status,
        o_message       => v_message
    );
    print_test('Register: Success', 'SUCCESS', v_status, v_message);
    
    -- Сохраняем ID для следующих тестов
    IF v_status = 'SUCCESS' THEN
        -- ==========================================
        -- ТЕСТ 4: Аутентификация (Успех)
        -- ==========================================
        stock_admin.pkg_users.authenticate_user(
            p_username      => v_test_user,
            p_password_hash => v_test_pass,
            o_user_id       => v_user_id,
            o_role_name     => v_role_name,
            o_is_banned     => v_is_banned,
            o_status        => v_status,
            o_message       => v_message
        );
        print_test('Auth: Success', 'SUCCESS', v_status, v_message);

        -- ==========================================
        -- ТЕСТ 5: Аутентификация (Неверный пароль)
        -- ==========================================
        stock_admin.pkg_users.authenticate_user(
            p_username      => v_test_user,
            p_password_hash => 'WrongPass',
            o_user_id       => v_user_id,
            o_role_name     => v_role_name,
            o_is_banned     => v_is_banned,
            o_status        => v_status,
            o_message       => v_message
        );
        print_test('Auth: Wrong Password', 'ERROR', v_status, v_message);
    ELSE
        DBMS_OUTPUT.PUT_LINE('CRITICAL: Регистрация не прошла, остальные тесты пропущены.');
    END IF;

    -- Очистка после тестов
    --DELETE FROM users WHERE username = v_test_user;
    --COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('=== ТЕСТЫ ЗАВЕРШЕНЫ ===');
END;
/
select * from STOCK_ADMIN.users