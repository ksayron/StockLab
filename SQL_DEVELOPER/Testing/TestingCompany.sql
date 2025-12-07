select * from companies;
SET SERVEROUTPUT ON;

DECLARE
    -- ID для секторов
    v_sec_tech_id    NUMBER;
    v_sec_energy_id  NUMBER;
    v_sec_finance_id NUMBER;

    -- ID для компаний
    v_comp1_id NUMBER; -- Tech (Apple-like)
    v_comp2_id NUMBER; -- Tech (Volatile startup)
    v_comp3_id NUMBER; -- Energy (Stable)
    v_comp4_id NUMBER; -- Finance (Bank)
    v_comp5_id NUMBER; -- To be Delisted

    -- Переменные для чтения курсоров
    c_cursor     SYS_REFCURSOR;
    r_id         NUMBER;
    r_name       VARCHAR2(100);
    r_ticker     VARCHAR2(10);
    r_price      NUMBER;
    r_sec_name   VARCHAR2(100);
    r_volatility NUMBER;
    r_status     VARCHAR2(20);

BEGIN
    DBMS_OUTPUT.PUT_LINE('=== НАЧАЛО ТЕСТИРОВАНИЯ COMPANIES PACKAGES ===');

    -- ====================================================
    -- 1. ПОДГОТОВКА (Создаем Сектора)
    -- ====================================================
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- 1. Создание тестовых секторов ---');
    
    -- Используем существующий пакет секторов
    stock_admin.pkg_market_admin.add_sector('Test Tech', 'High growth', v_sec_tech_id);
    stock_admin.pkg_market_admin.add_sector('Test Energy', 'Stable income', v_sec_energy_id);
    stock_admin.pkg_market_admin.add_sector('Test Finance', 'Money movers', v_sec_finance_id);
    
    DBMS_OUTPUT.PUT_LINE('Сектора созданы: Tech='||v_sec_tech_id||', Energy='||v_sec_energy_id||', Finance='||v_sec_finance_id);

    -- ====================================================
    -- 2. НАПОЛНЕНИЕ (Создаем 5 Компаний)
    -- ====================================================
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- 2. Создание 5 компаний ---');

    -- 1. Alpha Tech (Expensive, Low Volatility)
    stock_admin.pkg_companies_admin.add_company(
        p_sector_id => v_sec_tech_id, p_name => 'Alpha Tech', p_ticker => 'ALPH', 
        p_description => 'Big Tech', p_init_price => 150.00, p_volatility => 0.05, 
        o_company_id => v_comp1_id
    );

    -- 2. Beta Startup (Cheap, High Volatility)
    stock_admin.pkg_companies_admin.add_company(
        p_sector_id => v_sec_tech_id, p_name => 'Beta Startup', p_ticker => 'BETA', 
        p_description => 'Risky stuff', p_init_price => 10.00, p_volatility => 0.25, 
        o_company_id => v_comp2_id
    );

    -- 3. Gamma Energy (Mid Price, Low Volatility)
    stock_admin.pkg_companies_admin.add_company(
        p_sector_id => v_sec_energy_id, p_name => 'Gamma Oil', p_ticker => 'GAMM', 
        p_description => 'Oil & Gas', p_init_price => 80.00, p_volatility => 0.03, 
        o_company_id => v_comp3_id
    );

    -- 4. Delta Bank (Mid Price)
    stock_admin.pkg_companies_admin.add_company(
        p_sector_id => v_sec_finance_id, p_name => 'Delta Bank', p_ticker => 'DELT', 
        p_description => 'Global Bank', p_init_price => 50.00, p_volatility => 0.08, 
        o_company_id => v_comp4_id
    );

    -- 5. Epsilon Scam (To be deleted)
    stock_admin.pkg_companies_admin.add_company(
        p_sector_id => v_sec_finance_id, p_name => 'Epsilon Scam', p_ticker => 'SCAM', 
        p_description => 'Bad company', p_init_price => 100.00, p_volatility => 0.50, 
        o_company_id => v_comp5_id
    );

    DBMS_OUTPUT.PUT_LINE('Компании созданы успешно.');

    -- ====================================================
    -- 3. ТЕСТ СОРТИРОВКИ (View)
    -- ====================================================
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- 3. Тест Сортировки: По ЦЕНЕ (DESC) ---');
    DBMS_OUTPUT.PUT_LINE('Ожидаем: Alpha(150) -> Epsilon(100) -> Gamma(80)...');

    stock_admin.pkg_companies_view.get_all_companies(
        p_sort_by  => 'PRICE',
        p_sort_dir => 'DESC',
        o_cursor   => c_cursor
    );

    LOOP
        FETCH c_cursor INTO r_id, r_name, r_ticker, r_price, r_sec_name, r_volatility, r_status;
        EXIT WHEN c_cursor%NOTFOUND;
        -- Фильтруем вывод только для наших тестовых компаний
        IF r_name IN ('Alpha Tech', 'Beta Startup', 'Gamma Oil', 'Delta Bank', 'Epsilon Scam') THEN
            DBMS_OUTPUT.PUT_LINE('   > ' || r_name || ' ($' || r_price || ')');
        END IF;
    END LOOP;
    CLOSE c_cursor;

    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- 3.1. Тест Сортировки: По ВОЛАТИЛЬНОСТИ (ASC) ---');
    stock_admin.pkg_companies_view.get_all_companies('VOLATILITY', 'ASC', c_cursor);
    LOOP
        FETCH c_cursor INTO r_id, r_name, r_ticker, r_price, r_sec_name, r_volatility, r_status;
        EXIT WHEN c_cursor%NOTFOUND;
        IF r_name IN ('Alpha Tech', 'Beta Startup', 'Gamma Oil', 'Delta Bank', 'Epsilon Scam') THEN
            DBMS_OUTPUT.PUT_LINE('   > ' || r_name || ' (Vol: ' || r_volatility || ')');
        END IF;
    END LOOP;
    CLOSE c_cursor;

    -- ====================================================
    -- 4. ТЕСТ ФИЛЬТРАЦИИ ПО СЕКТОРУ
    -- ====================================================
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- 4. Тест Фильтра: Только Tech Сектор ---');
    
    stock_admin.pkg_companies_view.get_companies_by_sector(v_sec_tech_id, c_cursor);
    LOOP
        FETCH c_cursor INTO r_id, r_name, r_ticker, r_price;
        EXIT WHEN c_cursor%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE('   > Найдено: ' || r_name || ' (' || r_ticker || ')');
    END LOOP;
    CLOSE c_cursor;

    -- ====================================================
    -- 5. ТЕСТ ПОИСКА (SEARCH)
    -- ====================================================
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- 5. Тест Поиска: запрос "elt" (должен найти D(elt)a) ---');
    
    stock_admin.pkg_companies_view.search_companies('elt', c_cursor);
    LOOP
        FETCH c_cursor INTO r_id, r_name, r_ticker, r_price, r_sec_name;
        EXIT WHEN c_cursor%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE('   > Результат поиска: ' || r_name);
    END LOOP;
    CLOSE c_cursor;

    -- ====================================================
    -- 6. ТЕСТ ОБНОВЛЕНИЯ
    -- ====================================================
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- 6. Тест Update: Delta Bank -> Giga Bank ---');
    
    stock_admin.pkg_companies_admin.update_company(
        p_company_id => v_comp4_id,
        p_sector_id  => v_sec_finance_id,
        p_name       => 'Giga Bank', -- New Name
        p_description=> 'Rebranded',
        p_volatility => 0.10
    );
    
    -- Проверяем
    stock_admin.pkg_companies_view.get_company_by_id(v_comp4_id, c_cursor);
    FETCH c_cursor INTO r_id, r_name, r_ticker, r_name, r_price, r_id, r_sec_name, r_volatility;
    CLOSE c_cursor;
    DBMS_OUTPUT.PUT_LINE('   > Новое имя: ' || r_name);

    -- ====================================================
    -- 7. ТЕСТ DELIST (Мягкое удаление + Обнуление цены)
    -- ====================================================
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- 7. Тест Delist: Epsilon Scam ---');
    
    stock_admin.pkg_companies_admin.delist_company(v_comp5_id);
    
    -- 1. Проверяем, что цена стала 0 (прямой select для проверки)
    DECLARE
        v_check_price NUMBER;
        v_check_status VARCHAR2(20);
    BEGIN
        SELECT current_price, status INTO v_check_price, v_check_status 
        FROM stock_admin.companies WHERE company_id = v_comp5_id;
        
        DBMS_OUTPUT.PUT_LINE('   > Статус: ' || v_check_status);
        DBMS_OUTPUT.PUT_LINE('   > Цена: $' || v_check_price);
        
        IF v_check_status = 'DELISTED' AND v_check_price = 0 THEN
            DBMS_OUTPUT.PUT_LINE('   >> УСПЕХ: Компания делистингована и цена обнулена.');
        ELSE
            DBMS_OUTPUT.PUT_LINE('   >> ОШИБКА: Неверный статус или цена.');
        END IF;
    END;

    -- 2. Проверяем, что она пропала из общего списка (ACTIVE only)
    DBMS_OUTPUT.PUT_LINE('   > Проверка списка ACTIVE (Epsilon не должно быть):');
    stock_admin.pkg_companies_view.get_all_companies(o_cursor => c_cursor);
    DBMS_OUTPUT.PUT_LINE(c_cursor%ROWCOUNT);
    LOOP
        FETCH c_cursor INTO r_id, r_name, r_ticker, r_price, r_sec_name, r_volatility, r_status;
        DBMS_OUTPUT.PUT_LINE('   > ' || r_name || ' ($' || r_price || ')');
        EXIT WHEN c_cursor%NOTFOUND;
        IF r_name = 'Epsilon Scam' THEN
            DBMS_OUTPUT.PUT_LINE('   >> ОШИБКА: Epsilon все еще в списке!');
        END IF;
    END LOOP;
    CLOSE c_cursor;

    -- ====================================================
    -- 8. ОЧИСТКА (CLEANUP)
    -- ====================================================
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- 8. Очистка данных ---');
    
    -- Удаляем компании
    --DELETE FROM stock_admin.companies WHERE company_id IN (v_comp1_id, v_comp2_id, v_comp3_id, v_comp4_id, v_comp5_id);
    -- Удаляем сектора
    --DELETE FROM stock_admin.sectors WHERE sector_id IN (v_sec_tech_id, v_sec_energy_id, v_sec_finance_id);
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('   >> Тестовые данные удалены.');

    DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== ТЕСТЫ ЗАВЕРШЕНЫ ===');
END;
/
DELETE FROM stock_admin.companies;
DELETE FROM stock_admin.sectors;

