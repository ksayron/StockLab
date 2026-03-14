SET SERVEROUTPUT ON;

DECLARE
    v_sector_id     NUMBER;
    v_status        VARCHAR2(50);
    v_message       VARCHAR2(4000);
    v_cursor        SYS_REFCURSOR;
    
    v_test_name     VARCHAR2(100) := 'Test_IT_Sector_' || TO_CHAR(SYSDATE, 'HH24MISS'); -- Уникальное имя
    v_update_name   VARCHAR2(100) := 'Test_IT_Updated_' || TO_CHAR(SYSDATE, 'HH24MISS');
    v_desc          VARCHAR2(200) := 'Temporary sector for unit testing';
    
    rec_id          NUMBER;
    rec_name        VARCHAR2(100);
    rec_desc        VARCHAR2(200);

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
    DBMS_OUTPUT.PUT_LINE('=== НАЧАЛО ТЕСТИРОВАНИЯ ===');


    pkg_market_view.get_all_sectors(
        o_cursor  => v_cursor,
        o_status  => v_status,
        o_message => v_message
    );
    
    IF v_status = 'SUCCESS' THEN
        print_test('1. Get All Sectors (Status)', 'SUCCESS', v_status);
        -- Проверка что курсор открыт (просто фетчим первую строку, если есть)
        FETCH v_cursor INTO rec_id, rec_name, rec_desc;
        CLOSE v_cursor; 
    ELSE
        print_test('1. Get All Sectors', 'SUCCESS', v_status, v_message);
    END IF;
    
    pkg_market_admin.add_sector(
        p_name        => v_test_name,
        p_description => v_desc,
        o_sector_id   => v_sector_id,
        o_status      => v_status,
        o_message     => v_message
    );
    
    print_test('2. Add New Sector', 'SUCCESS', v_status, 'ID: ' || v_sector_id);

    DECLARE
        v_dup_id NUMBER;
        v_dup_status VARCHAR2(50);
        v_dup_msg VARCHAR2(4000);
    BEGIN
        pkg_market_admin.add_sector(
            p_name        => v_test_name, -- То же имя
            p_description => 'Duplicate',
            o_sector_id   => v_dup_id,
            o_status      => v_dup_status,
            o_message     => v_dup_msg
        );
        print_test('3. Add Duplicate Sector', 'ERROR', v_dup_status, v_dup_msg);
    END;


    pkg_market_view.get_sector_by_id(
        p_sector_id => v_sector_id,
        o_cursor    => v_cursor,
        o_status    => v_status,
        o_message   => v_message
    );
    
    FETCH v_cursor INTO rec_id, rec_name, rec_desc;
    CLOSE v_cursor;
    
    IF rec_name = v_test_name THEN
         print_test('4. Verify Created Data', 'MATCH', 'MATCH');
    ELSE
         print_test('4. Verify Created Data', v_test_name, rec_name, 'Name mismatch');
    END IF;

    pkg_market_admin.update_sector(
        p_sector_id   => v_sector_id,
        p_name        => v_update_name,
        p_description => 'Updated Description',
        o_status      => v_status,
        o_message     => v_message
    );
    print_test('5. Update Sector', 'SUCCESS', v_status);

    pkg_market_admin.update_sector(
        p_sector_id   => -999,
        p_name        => 'Ghost',
        p_description => 'Ghost',
        o_status      => v_status,
        o_message     => v_message
    );
    print_test('6. Update Non-existent', 'ERROR', v_status, v_message);

    pkg_market_admin.delete_sector(
        p_sector_id => v_sector_id,
        o_status    => v_status,
        o_message   => v_message
    );
    print_test('7. Delete Sector', 'SUCCESS', v_status);

    pkg_market_admin.delete_sector(
        p_sector_id => v_sector_id,
        o_status    => v_status,
        o_message   => v_message
    );
    print_test('8. Delete Deleted Sector', 'ERROR', v_status, v_message);

    pkg_market_view.get_sector_by_id(
        p_sector_id => v_sector_id,
        o_cursor    => v_cursor,
        o_status    => v_status,
        o_message   => v_message
    );
    
    FETCH v_cursor INTO rec_id, rec_name, rec_desc;
    IF v_cursor%NOTFOUND THEN
        print_test('9. Verify Deletion', 'EMPTY', 'EMPTY');
    ELSE
        print_test('9. Verify Deletion', 'EMPTY', 'FOUND', 'Row still exists');
    END IF;
    CLOSE v_cursor;

    DBMS_OUTPUT.PUT_LINE('=== ТЕСТИРОВАНИЕ ЗАВЕРШЕНО ===');

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('CRITICAL SCRIPT ERROR: ' || SQLERRM);
END;
/