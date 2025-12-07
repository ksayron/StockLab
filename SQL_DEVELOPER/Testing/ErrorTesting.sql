SET SERVEROUTPUT ON;

DECLARE
    -- Переменные для ID
    v_sector_id    NUMBER;
    v_company_id   NUMBER;
    v_user_id      NUMBER;
    v_order_id     NUMBER;
    
    -- Переменные для OUT параметров (Soft Error)
    v_status       VARCHAR2(50);
    v_message      VARCHAR2(4000);
    v_role_name    VARCHAR2(50);
    
    -- Переменная для курсора
    c_cursor       SYS_REFCURSOR;

    -- Вспомогательная процедура для красивого вывода
    PROCEDURE print_test(p_name VARCHAR2, p_status VARCHAR2, p_msg VARCHAR2, p_expect_success BOOLEAN) IS
    BEGIN
        DBMS_OUTPUT.PUT('TEST: ' || RPAD(p_name, 40, '.') || ' ');
        
        IF (p_expect_success AND p_status = 'SUCCESS') OR (NOT p_expect_success AND p_status = 'ERROR') THEN
            DBMS_OUTPUT.PUT_LINE('[ OK ]');
            DBMS_OUTPUT.PUT_LINE('      Msg: ' || p_msg);
        ELSE
            DBMS_OUTPUT.PUT_LINE('[ FAIL ]');
            DBMS_OUTPUT.PUT_LINE('      Status: ' || p_status);
            DBMS_OUTPUT.PUT_LINE('      Msg:    ' || p_msg);
        END IF;
        DBMS_OUTPUT.PUT_LINE('----------------------------------------------------');
    END;

BEGIN
    DBMS_OUTPUT.PUT_LINE('=== ЗАПУСК ПОЛНОГО ТЕСТИРОВАНИЯ СИСТЕМЫ ===' || CHR(10));

    -- 0. ОЧИСТКА (Чтобы тест был воспроизводимым)
    BEGIN
        DELETE FROM stock_admin.error_log; -- Чистим логи для чистоты эксперимента
        DELETE FROM stock_admin.trades WHERE company_id IN (SELECT company_id FROM stock_admin.companies WHERE ticker_symbol = 'TEST_CRASH');
        DELETE FROM stock_admin.orders WHERE company_id IN (SELECT company_id FROM stock_admin.companies WHERE ticker_symbol = 'TEST_CRASH');
        DELETE FROM stock_admin.portfolios WHERE user_id IN (SELECT user_id FROM stock_admin.users WHERE username = 'TestUser_Fail');
        DELETE FROM stock_admin.users WHERE username = 'TestUser_Fail';
        DELETE FROM stock_admin.companies WHERE ticker_symbol = 'TEST_CRASH';
        DELETE FROM stock_admin.sectors WHERE name = 'Crash Sector';
        COMMIT;
    EXCEPTION WHEN OTHERS THEN NULL; END;

    -- ==========================================================
    -- ТЕСТ 1: УСПЕШНЫЙ ПУТЬ (HAPPY PATH)
    -- ==========================================================
    
    -- 1.1 Создание Сектора
    stock_admin.pkg_market_admin.add_sector(
        p_name => 'Crash Sector', p_description => 'Test', 
        o_sector_id => v_sector_id, o_status => v_status, o_message => v_message
    );
    print_test('1.1 Create Sector', v_status, v_message, TRUE);

    -- 1.2 Создание Компании (IPO)
    stock_admin.pkg_companies_admin.add_company(
        p_sector_id => v_sector_id, p_name => 'Crash Test Dummy', p_ticker => 'TEST_CRASH',
        p_description => 'Desc', p_init_price => 100, p_volatility => 0.1, p_total_shares => 1000,
        o_company_id => v_company_id, o_status => v_status, o_message => v_message
    );
    print_test('1.2 Create Company + IPO', v_status, v_message, TRUE);

    -- 1.3 Регистрация пользователя
    stock_admin.pkg_users.register_user(
        p_username => 'TestUser_Fail', p_email => 'fail@test.com', p_password_hash => '123',
        o_user_id => v_user_id, o_role_name => v_role_name, 
        o_status => v_status, o_message => v_message
    );
    print_test('1.3 Register User', v_status, v_message, TRUE);

    -- 1.4 Депозит ($1000)
    stock_admin.pkg_users.deposit_cash(
        p_user_id => v_user_id, p_amount => 1000, 
        o_status => v_status, o_message => v_message
    );
    print_test('1.4 Deposit $1000', v_status, v_message, TRUE);

    -- ==========================================================
    -- ТЕСТ 2: БИЗНЕС-ОШИБКА (Expected Soft Error)
    -- ==========================================================
    
    -- Попытка купить акций на $1,000,000 (у нас только $1,000)
    -- Ожидаем: Status = ERROR, Message = "Недостаточно средств..."
    -- Log: В system_logs ничего быть НЕ должно (это не сбой системы)
    
    stock_admin.pkg_trading_user.place_order(
        p_user_id => v_user_id, p_company_id => v_company_id, 
        p_type => 'BUY', p_qty => 10000, p_limit_price => 100,
        o_order_id => v_order_id, 
        o_status => v_status, o_message => v_message
    );
    print_test('2.1 Buy Too Much (Business Error)', v_status, v_message, FALSE);

    -- ==========================================================
    -- ТЕСТ 3: СИСТЕМНАЯ ОШИБКА (UNEXPECTED EXCEPTION)
    -- ==========================================================
    
    -- Мы попытаемся создать пользователя с NULL паролем.
    -- В таблице users поле password_hash NOT NULL.
    -- Это вызовет ORA-01400 (cannot insert NULL).
    -- Пакет pkg_users не обрабатывает эту ошибку явно, поэтому она попадет в WHEN OTHERS.
    -- Ожидаем: 
    --   1. Status = ERROR
    --   2. Message = "Internal System Error" (или Внутренняя ошибка)
    --   3. Запись в system_logs с реальным текстом ORA-01400
    
    stock_admin.pkg_users.register_user(
        p_username => 'SystemBreaker', 
        p_email => 'break@test.com', 
        p_password_hash => NULL, -- <-- ВОТ ДИВЕРСИЯ
        o_user_id => v_user_id, 
        o_role_name => v_role_name, 
        o_status => v_status, 
        o_message => v_message
    );
    print_test('3.1 Force Crash (NULL Password)', v_status, v_message, FALSE);

    -- ==========================================================
    -- ТЕСТ 4: ПРОВЕРКА ЛОГОВ
    -- ==========================================================
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== ПРОВЕРКА ТАБЛИЦЫ SYSTEM_LOGS ===');
    
    FOR r IN (SELECT log_id, proc_name, error_code, error_msg, created_at 
              FROM stock_admin.error_log 
              ORDER BY log_id DESC FETCH FIRST 5 ROWS ONLY) 
    LOOP
        DBMS_OUTPUT.PUT_LINE('LOG #' || r.log_id || ' | Proc: ' || r.proc_name);
        DBMS_OUTPUT.PUT_LINE('   Code: ' || r.error_code);
        DBMS_OUTPUT.PUT_LINE('   Msg:  ' || SUBSTR(r.error_msg, 1, 100)); -- Обрезаем для читаемости
        DBMS_OUTPUT.PUT_LINE('-----------------------------------');
    END LOOP;

    -- Проверка наличия записи о ORA-01400
    DECLARE
        v_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_count 
        FROM stock_admin.error_log 
        WHERE error_msg LIKE '%ORA-01400%' OR error_msg LIKE '%cannot insert NULL%';
        
        IF v_count > 0 THEN
            DBMS_OUTPUT.PUT_LINE('>> УСПЕХ: Системная ошибка была корректно перехвачена и записана в лог!');
        ELSE
            DBMS_OUTPUT.PUT_LINE('>> ПРОВАЛ: Лог пуст или ошибка не записалась.');
        END IF;
    END;

END;
/