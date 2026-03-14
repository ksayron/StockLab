select * from error_log;
select * from users;
select * from companies;
select * from orders inner join users on orders.user_id=users.user_id where type='SELL' order by orders.created_at desc;

select * from trades  order by trades.executed_at desc;
select * from trades where company_id=61 order by trades.executed_at desc;
select count(*) from price_log order by log_time desc;
select * from orders where user_id=16408;
SELECT * FROM user_scheduler_jobs;
--299 1839
    SELECT *
                    FROM orders 
                    WHERE user_id = 1839 AND type = 'BUY' AND status = 'OPEN';
select * from companies;