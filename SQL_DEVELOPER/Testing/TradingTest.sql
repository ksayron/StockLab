SET SERVEROUTPUT ON;
select * from users;
DECLARE
    v_user_id       NUMBER :=1;
    v_start_balance NUMBER := 25000;
    
    v_cursor        SYS_REFCURSOR;
    v_company_id    NUMBER;
    v_current_price NUMBER;
    v_ticker        VARCHAR2(50);
    
    v_buy_order_id  NUMBER;
    v_sell_order_id NUMBER;

    v_status        VARCHAR2(50);
    v_message       VARCHAR2(4000);
    
    v_balance_after_buy     NUMBER;
    v_balance_after_cancel  NUMBER;
    v_shares_after_sell     NUMBER;
    v_shares_after_cancel   NUMBER;
    v_order_status          VARCHAR2(20);
    
    PROCEDURE print_test(p_test_name VARCHAR2, p_expected VARCHAR2, p_actual VARCHAR2, p_msg VARCHAR2 DEFAULT NULL) IS
    BEGIN
        DBMS_OUTPUT.PUT(RPAD(p_test_name, 50, '.') || ' ');
        IF p_expected = p_actual THEN
            DBMS_OUTPUT.PUT_LINE('[ OK ]');
        ELSE
            DBMS_OUTPUT.PUT_LINE('[ FAIL ] Expected: ' || p_expected || ', Got: ' || p_actual || '. Msg: ' || p_msg);
        END IF;
    END;
    
    FUNCTION get_or_create_user RETURN NUMBER IS
        l_uid NUMBER;
        l_role VARCHAR2(50);
        l_stat VARCHAR2(50);
        l_msg  VARCHAR2(4000);
    BEGIN
        -- Пробуем найти тестового юзера
        BEGIN
            -- Создаем
            pkg_users.register_user('TraderBot_Test1', 'bot@test.com', 'Pass12345!', l_uid, l_role, l_stat, l_msg);
            IF l_stat = 'SUCCESS' THEN RETURN l_uid; ELSE RAISE_APPLICATION_ERROR(-20001, 'User create failed: '||l_msg); END IF;
        END;
    END;

BEGIN
   
    stock_admin.pkg_companies_view.get_companies(
        o_cursor  => v_cursor,
        o_status  => v_status,
        o_message => v_message
    );

    IF v_company_id IS NULL THEN
        DBMS_OUTPUT.PUT_LINE('CRITICAL: Нет активных компаний для теста. Скрипт остановлен.');
        RETURN;
    END IF;
    
    print_test('0. Setup', 'READY', 'READY', 'User: '||v_user_id||', Comp: '||v_ticker||' @ '||v_current_price);


    stock_admin.pkg_trading_user.place_order(
        p_user_id     => v_user_id,
        p_company_id  => v_company_id,
        p_type        => 'BUY',
        p_qty         => 10,
        p_limit_price => 10.0,
        o_order_id    => v_buy_order_id,
        o_status      => v_status,
        o_message     => v_message
    );
    
    print_test('1. Place BUY Order', 'SUCCESS', v_status, 'ID: ' || v_buy_order_id);


    stock_admin.pkg_trading_user.cancel_order(
        p_user_id  => v_user_id,
        p_order_id => v_buy_order_id,
        o_status   => v_status,
        o_message  => v_message
    );
    
    print_test('3. Cancel BUY Order', 'SUCCESS', v_status);

    stock_admin.pkg_trading_user.place_order(
        p_user_id     => v_user_id,
        p_company_id  => v_company_id,
        p_type        => 'SELL',
        p_qty         => 20,
        p_limit_price => 9999.0,
        o_order_id    => v_sell_order_id,
        o_status      => v_status,
        o_message     => v_message
    );
    
    print_test('6. Place SELL Order', 'SUCCESS', v_status, 'ID: ' || v_sell_order_id);

    stock_admin.pkg_trading_user.cancel_order(
        p_user_id  => v_user_id,
        p_order_id => v_sell_order_id,
        o_status   => v_status,
        o_message  => v_message
    );
    
    print_test('8. Cancel SELL Order', 'SUCCESS', v_status);

    DBMS_OUTPUT.PUT_LINE('=== ТОРГОВЫЙ СЦЕНАРИЙ ЗАВЕРШЕН ===');

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('SCRIPT ERROR: ' || SQLERRM);
END;
/