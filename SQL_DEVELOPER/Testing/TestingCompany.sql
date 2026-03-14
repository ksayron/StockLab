SET SERVEROUTPUT ON;

DECLARE
    -- Переменные для результатов
    v_company_id    NUMBER;
    v_sector_id     NUMBER;
    v_status        VARCHAR2(50);
    v_message       VARCHAR2(4000);
    v_cursor        SYS_REFCURSOR;
    
    -- Тестовые данные (генерируем уникальные, чтобы можно было запускать скрипт многократно)
    v_timestamp     VARCHAR2(20) := TO_CHAR(SYSDATE, 'HH24MISS');
    v_name          VARCHAR2(100) := 'TestCorp_' || v_timestamp;
    v_ticker        VARCHAR2(10)  := 'T' || SUBSTR(v_timestamp, -4); -- Тикер макс 5-10 символов
    v_desc          VARCHAR2(200) := 'IPO Test Description';
    v_init_price    NUMBER := 150.00;
    v_volatility    NUMBER := 0.15;
    v_shares        NUMBER := 1000000;
    
    -- Переменные для обновления
    v_new_name      VARCHAR2(100) := 'TestCorp_Updated_' || v_timestamp;
    
    -- Переменные для выборки из курсора
    rec_id          NUMBER;
    rec_name        VARCHAR2(100);
    rec_ticker      VARCHAR2(50);
    rec_desc        VARCHAR2(200);
    rec_price       NUMBER;
    rec_sect_id     NUMBER;
    rec_sect_name   VARCHAR2(100);
    rec_vol         NUMBER;
    
    -- Для прямой проверки в БД (Bypass View)
    v_db_status     VARCHAR2(20);
    v_db_price      NUMBER;

    -- Хелпер для вывода
    PROCEDURE print_test(p_test_name VARCHAR2, p_expected VARCHAR2, p_actual VARCHAR2, p_msg VARCHAR2 DEFAULT NULL) IS
    BEGIN
        DBMS_OUTPUT.PUT(RPAD(p_test_name, 50, '.') || ' ');
        IF p_expected = p_actual THEN
            DBMS_OUTPUT.PUT_LINE('[ OK ]');
        ELSE
            DBMS_OUTPUT.PUT_LINE('[ FAIL ] Expected: ' || p_expected || ', Got: ' || p_actual || '. Msg: ' || p_msg);
        END IF;
    END;

BEGIN
    DBMS_OUTPUT.PUT_LINE('=== ЗАПУСК ТЕСТА: IPO & DELISTING ===');

    -- 0. Подготовка: Берем любой существующий сектор
    BEGIN
        SELECT sector_id INTO v_sector_id FROM sectors FETCH FIRST 1 ROWS ONLY;
    EXCEPTION WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('CRITICAL: В базе нет секторов. Сначала создайте сектор.');
        RETURN;
    END;

    -- ====================================================
    -- 1. ТЕСТ: Успешное IPO (Add Company)
    -- ====================================================
    pkg_companies_admin.add_company(
        p_sector_id    => v_sector_id,
        p_name         => v_name,
        p_ticker       => v_ticker,
        p_description  => v_desc,
        p_init_price   => v_init_price,
        p_volatility   => v_volatility,
        p_total_shares => v_shares,
        o_company_id   => v_company_id,
        o_status       => v_status,
        o_message      => v_message
    );
    
    print_test('1. IPO Creation', 'SUCCESS', v_status, 'ID: ' || v_company_id || ' Msg: ' || v_message);

    -- Проверка: Создался ли Эмитент и ордер (косвенно, если статус SUCCESS, значит транзакция прошла)
    IF v_status = 'SUCCESS' THEN
        -- ====================================================
        -- 2. ТЕСТ: Проверка видимости через VIEW (Get By ID)
        -- ====================================================
        pkg_companies_view.get_company_by_id(
            p_company_id => v_company_id,
            o_cursor     => v_cursor,
            o_status     => v_status,
            o_message    => v_message
        );
        
        FETCH v_cursor INTO rec_id, rec_name, rec_ticker, rec_desc, rec_price, rec_sect_id, rec_sect_name, rec_vol;
        
        IF v_cursor%FOUND AND rec_name = v_name THEN
             print_test('2. Verify View Data', 'MATCH', 'MATCH');
        ELSE
             print_test('2. Verify View Data', v_name, rec_name, 'Name mismatch or not found');
        END IF;
        CLOSE v_cursor;

        -- ====================================================
        -- 3. ТЕСТ: Обновление компании (Update)
        -- ====================================================
        pkg_companies_admin.update_company(
            p_company_id  => v_company_id,
            p_sector_id   => v_sector_id, -- Тот же сектор
            p_name        => v_new_name,
            p_description => 'Updated Description',
            p_volatility  => 0.25,
            o_status      => v_status,
            o_message     => v_message
        );
        
        print_test('3. Update Company', 'SUCCESS', v_status);
        
        -- Проверка обновления
        pkg_companies_view.get_company_by_id(v_company_id, v_cursor, v_status, v_message);
        FETCH v_cursor INTO rec_id, rec_name, rec_ticker, rec_desc, rec_price, rec_sect_id, rec_sect_name, rec_vol;
        CLOSE v_cursor;
        
        IF rec_name = v_new_name THEN
            print_test('4. Verify Update', 'MATCH', 'MATCH');
        ELSE
            print_test('4. Verify Update', v_new_name, rec_name, 'Name did not update');
        END IF;

        -- ====================================================
        -- 5. ТЕСТ: Делистинг (Delist)
        -- ====================================================
        pkg_companies_admin.delist_company(
            p_company_id => v_company_id,
            o_status     => v_status,
            o_message    => v_message
        );
        
        print_test('5. Delist Action', 'SUCCESS', v_status, v_message);

        -- ====================================================
        -- 6. ТЕСТ: Проверка отсутствия в публичном VIEW
        -- ====================================================
        -- Пакет pkg_companies_view фильтрует по status='ACTIVE'. 
        -- После делистинга мы НЕ должны получить данные.
        pkg_companies_view.get_company_by_id(
            p_company_id => v_company_id,
            o_cursor     => v_cursor,
            o_status     => v_status,
            o_message    => v_message
        );
        
        FETCH v_cursor INTO rec_id, rec_name, rec_ticker, rec_desc, rec_price, rec_sect_id, rec_sect_name, rec_vol;
        
        IF v_cursor%NOTFOUND THEN
             print_test('6. Verify Hidden in View', 'HIDDEN', 'HIDDEN');
        ELSE
             print_test('6. Verify Hidden in View', 'HIDDEN', 'VISIBLE', 'Company still visible in public API!');
        END IF;
        CLOSE v_cursor;

        -- ====================================================
        -- 7. ТЕСТ: Прямая проверка в БД (Физическое наличие)
        -- ====================================================
        -- Мы должны убедиться, что строка НЕ удалена, а просто обновлена.
        BEGIN
            SELECT status, current_price 
            INTO v_db_status, v_db_price
            FROM companies 
            WHERE company_id = v_company_id;
            
            IF v_db_status = 'DELISTED' AND v_db_price = 0 THEN
                print_test('7. Verify DB State (Delisted)', 'OK', 'OK', 'Status=DELISTED, Price=0');
            ELSE
                print_test('7. Verify DB State (Delisted)', 'DELISTED/0', v_db_status||'/'||v_db_price);
            END IF;
        EXCEPTION WHEN NO_DATA_FOUND THEN
            print_test('7. Verify DB State (Delisted)', 'EXIST', 'DELETED', 'Row was physically deleted!');
        END;

    ELSE
        DBMS_OUTPUT.PUT_LINE('CRITICAL: IPO Failed. ' || v_message);
    END IF;

    DBMS_OUTPUT.PUT_LINE('=== ТЕСТ ЗАВЕРШЕН ===');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('SCRIPT ERROR: ' || SQLERRM);
END;
/