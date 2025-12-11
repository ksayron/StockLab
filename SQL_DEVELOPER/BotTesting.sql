select * from error_log;
select * from users;
select * from companies;
select * from orders inner join users on orders.user_id=users.user_id order by orders.created_at desc;

select * from trades  order by trades.executed_at desc;
select * from trades where company_id=61 order by trades.executed_at desc;
select * from price_log order by log_time desc;
select * from orders where company_id=290;
SELECT * FROM user_scheduler_jobs;
--299 1839
    SELECT *
                    FROM orders 
                    WHERE user_id = 1839 AND type = 'BUY' AND status = 'OPEN';

BEGIN
    stock_admin.pkg_market_bots.cleanup_simulation;
    DBMS_OUTPUT.PUT_LINE('Тестовые данные удалены.');
END;
/
BEGIN
    DBMS_OUTPUT.PUT_LINE('Симуляция запущена.');    
    stock_admin.pkg_market_bots.setup_simulation_world;
END;
/