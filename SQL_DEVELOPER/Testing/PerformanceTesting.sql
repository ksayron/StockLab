set autotrace on;
SELECT /*+ MONITOR INMEMORY */ company_id, AVG(price), COUNT(*) 
FROM price_log 
GROUP BY company_id;

SELECT segment_name, populate_status, bytes_not_populated 
FROM v$im_segments;

SET TIMING ON
SELECT /*+ INMEMORY MONITOR */ 
    company_id, 
    MAX(price), 
    MIN(price), 
    AVG(price) 
FROM stock_admin.price_log 
GROUP BY company_id;