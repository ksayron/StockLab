SET SERVEROUTPUT ON;

DECLARE
    -- Variables to hold data returned from procedures
    v_new_user_id   NUMBER;
    v_role_name     VARCHAR2(50);
    v_auth_id       NUMBER;
    v_auth_role     VARCHAR2(50);
    v_is_banned     NUMBER;
    
    -- Variables for testing inputs
    v_test_user     VARCHAR2(50) := 'TestTrader_01';
    v_test_email    VARCHAR2(100) := 'trader01@stocklab.com';
    v_test_pass     VARCHAR2(255) := 'hashed_secret_123';
    
    -- Cursor variables for reading user details
    c_user_details  SYS_REFCURSOR;
    -- Variables to hold fetched cursor rows
    r_id            NUMBER;
    r_username      VARCHAR2(50);
    r_email         VARCHAR2(100);
    r_balance       NUMBER;
    r_created       TIMESTAMP;
    r_role          VARCHAR2(50);

BEGIN
    DBMS_OUTPUT.PUT_LINE('--- STARTING PKG_USERS TESTS ---');

    -- =======================================
    -- 0. CLEANUP (So you can run this script multiple times)
    -- =======================================
    BEGIN
        DELETE FROM users WHERE username = v_test_user;
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('0. Cleanup: Deleted previous test user data.');
    EXCEPTION 
        WHEN OTHERS THEN NULL; -- Ignore if user didn't exist
    END;

    -- =======================================
    -- TEST 1: REGISTER USER
    -- =======================================
    DBMS_OUTPUT.PUT_LINE('1. Testing Register User...');
    
 stock_admin.pkg_users.register_user(
        p_username      => v_test_user,
        p_email         => v_test_email,
        p_password_hash => v_test_pass,
        o_user_id       => v_new_user_id,
        o_role_name     => v_role_name
    );
    
    DBMS_OUTPUT.PUT_LINE('   >> Success! User ID: ' || v_new_user_id || ' | Role: ' || v_role_name);

    -- =======================================
    -- TEST 2: AUTHENTICATE (LOGIN) - SUCCESS
    -- =======================================
    DBMS_OUTPUT.PUT_LINE('2. Testing Valid Login...');
    
    stock_admin.pkg_users.authenticate_user(
        p_username      => v_test_user,
        p_password_hash => v_test_pass,
        o_user_id       => v_auth_id,
        o_role_name     => v_auth_role,
        o_is_banned     => v_is_banned
    );
    
    DBMS_OUTPUT.PUT_LINE('   >> Login OK. ID: ' || v_auth_id || ' | Banned Status: ' || v_is_banned);

    -- =======================================
    -- TEST 3: AUTHENTICATE - FAILURE (Wrong Password)
    -- =======================================
    DBMS_OUTPUT.PUT_LINE('3. Testing Invalid Password...');
    
    BEGIN
        stock_admin.pkg_users.authenticate_user(
            p_username      => v_test_user,
            p_password_hash => 'WRONG_PASSWORD',
            o_user_id       => v_auth_id,
            o_role_name     => v_auth_role,
            o_is_banned     => v_is_banned
        );
        -- If we get here, the test FAILED because an error should have been raised
        DBMS_OUTPUT.PUT_LINE('   >> FAILURE: Expected an error but got none.');
    EXCEPTION
        WHEN OTHERS THEN
            -- We expect error -20002 (defined in package)
            IF SQLCODE = -20002 THEN
                DBMS_OUTPUT.PUT_LINE('   >> Success: Caught expected error: ' || SQLERRM);
            ELSE
                DBMS_OUTPUT.PUT_LINE('   >> FAILURE: Caught unexpected error: ' || SQLERRM);
            END IF;
    END;

    -- =======================================
    -- TEST 4: DEPOSIT CASH
    -- =======================================
    DBMS_OUTPUT.PUT_LINE('4. Testing Deposit Cash (Adding $500)...');
    
    stock_admin.pkg_users.deposit_cash(
        p_user_id => v_new_user_id,
        p_amount  => 500.00
    );
    DBMS_OUTPUT.PUT_LINE('   >> Deposit executed.');

    -- =======================================
    -- TEST 5: GET USER DETAILS (Check Balance)
    -- =======================================
    DBMS_OUTPUT.PUT_LINE('5. Testing Get User Details (Verifying Balance)...');
    
    stock_admin.pkg_users.get_user_details(
        p_user_id => v_new_user_id,
        o_cursor  => c_user_details
    );
    
    -- Loop through the cursor to fetch data
    LOOP
        FETCH c_user_details INTO r_id, r_username, r_email, r_balance, r_created, r_role;
        EXIT WHEN c_user_details%NOTFOUND;
        
        DBMS_OUTPUT.PUT_LINE('   >> User Found: ' || r_username);
        DBMS_OUTPUT.PUT_LINE('   >> Balance: $' || r_balance);
        DBMS_OUTPUT.PUT_LINE('   >> Role: ' || r_role);
        
        IF r_balance = 500 THEN
            DBMS_OUTPUT.PUT_LINE('   >> VERIFICATION: Balance is correct!');
        ELSE
            DBMS_OUTPUT.PUT_LINE('   >> VERIFICATION: Balance is WRONG.');
        END IF;
    END LOOP;
    CLOSE c_user_details;

    DBMS_OUTPUT.PUT_LINE('--- TESTS COMPLETED ---');

END;
/
-------------------------------------------------------------------------------
----Sectors
SET SERVEROUTPUT ON;

DECLARE
    -- Переменные для данных
    v_sector_id     NUMBER;
    v_sector_name   VARCHAR2(100) := 'AI & Robotics';
    v_sector_desc   VARCHAR2(500) := 'Future tech test sector';
    v_updated_name  VARCHAR2(100) := 'AI & Robotics (Updated)';
    
    v_status        VARCHAR2(20);
    
    -- Переменные для работы с курсором (чтение)
    c_cursor        SYS_REFCURSOR;
    r_id            NUMBER;
    r_name          VARCHAR2(100);
    r_desc          VARCHAR2(500);

BEGIN
    DBMS_OUTPUT.PUT_LINE('=== НАЧАЛО ТЕСТИРОВАНИЯ MARKET PACKAGES ===');

    -- ====================================================
    -- 1. ТЕСТ PKG_MARKET_ADMIN (Создание)
    -- ====================================================
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- Тест 1: Добавление сектора ---');
    
    -- Очистка от прошлых запусков (если есть права)
    BEGIN
        DELETE FROM stock_admin.sectors WHERE name LIKE 'AI & Robotics%';
        COMMIT;
    EXCEPTION WHEN OTHERS THEN NULL; END;

    stock_admin.pkg_market_admin.add_sector(
        p_name        => v_sector_name,
        p_description => v_sector_desc,
        o_sector_id   => v_sector_id
    );

    DBMS_OUTPUT.PUT_LINE('   >> Сектор создан. ID: ' || v_sector_id);

    -- ====================================================
    -- 2. ТЕСТ PKG_MARKET_VIEW (Чтение созданного)
    -- ====================================================
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- Тест 2: Чтение сектора по ID ---');

    stock_admin.pkg_market_view.get_sector_by_id(
        p_sector_id => v_sector_id,
        o_cursor    => c_cursor
    );

    LOOP
        FETCH c_cursor INTO r_id, r_name, r_desc;
        EXIT WHEN c_cursor%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE('   >> Прочитано: ID=' || r_id || ', Name=' || r_name);
    END LOOP;
    CLOSE c_cursor;

    -- ====================================================
    -- 3. ТЕСТ НА ОШИБКУ (Дубликат)
    -- ====================================================
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- Тест 3: Попытка создать дубликат (должна быть ошибка) ---');

    BEGIN
        stock_admin.pkg_market_admin.add_sector(v_sector_name, 'Duplicate desc', v_sector_id);
        DBMS_OUTPUT.PUT_LINE('   >> ОШИБКА: Дубликат был создан, хотя не должен!');
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -20010 THEN
                DBMS_OUTPUT.PUT_LINE('   >> УСПЕХ: Поймана ожидаемая ошибка -20010 (Sector exists).');
            ELSE
                DBMS_OUTPUT.PUT_LINE('   >> ПРОВАЛ: Неожиданная ошибка: ' || SQLERRM);
            END IF;
    END;

    -- ====================================================
    -- 4. ТЕСТ UPDATE
    -- ====================================================
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- Тест 4: Обновление сектора ---');

    stock_admin.pkg_market_admin.update_sector(
        p_sector_id   => v_sector_id,
        p_name        => v_updated_name,
        p_description => 'Updated desc'
    );
    DBMS_OUTPUT.PUT_LINE('   >> Update выполнен.');
    
    -- Проверяем результат через View
    stock_admin.pkg_market_view.get_sector_by_id(v_sector_id, c_cursor);
    FETCH c_cursor INTO r_id, r_name, r_desc;
    CLOSE c_cursor;
    
    IF r_name = v_updated_name THEN
        DBMS_OUTPUT.PUT_LINE('   >> УСПЕХ: Имя обновилось корректно.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('   >> ОШИБКА: Имя не совпадает. Ожидалось: ' || v_updated_name || ', получено: ' || r_name);
    END IF;

   
    -- ====================================================
    -- 6. ТЕСТ DELETE
    -- ====================================================
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- Тест 6: Удаление сектора ---');
    
    stock_admin.pkg_market_admin.delete_sector(v_sector_id);
    DBMS_OUTPUT.PUT_LINE('   >> Удаление выполнено.');
    
    -- Проверяем, что удалилось
    stock_admin.pkg_market_view.get_sector_by_id(v_sector_id, c_cursor);
    FETCH c_cursor INTO r_id, r_name, r_desc;
    
    IF c_cursor%NOTFOUND THEN
        DBMS_OUTPUT.PUT_LINE('   >> УСПЕХ: Курсор пуст, сектор не найден.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('   >> ОШИБКА: Сектор все еще существует!');
    END IF;
    CLOSE c_cursor;

    DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== ТЕСТЫ ЗАВЕРШЕНЫ УСПЕШНО ===');
END;
/