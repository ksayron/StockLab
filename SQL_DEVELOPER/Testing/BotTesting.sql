select * from error_log
select * from users
select * from companies
select * from trades order by executed_at desc
select * from price_log order by log_time des

BEGIN
    stock_admin.pkg_market_bots.cleanup_simulation;
    DBMS_OUTPUT.PUT_LINE('Тестовые данные удалены.');
END;
/