show con_name;
ALTER SYSTEM SET inmemory_size = 300M SCOPE=SPFILE; -- для CDB
alter session  set container = STOCKLABDB;
SHOW PARAMETER inmemory_size;
SHOW PARAMETER sga;
ALTER SYSTEM SET inmemory_size = 300M SCOPE=SPFILE; -- для PDB

ALTER TABLE users INMEMORY;
ALTER TABLE companies INMEMORY;
ALTER TABLE bot_configs INMEMORY;
ALTER TABLE sectors INMEMORY;
ALTER TABLE portfolios INMEMORY;
ALTER TABLE trades INMEMORY;
ALTER TABLE orders INMEMORY;
ALTER TABLE price_log INMEMORY;
ALTER TABLE bot_configs INMEMORY PRIORITY HIGH;
ALTER TABLE tournaments INMEMORY PRIORITY HIGH;
ALTER TABLE networth_snapshots INMEMORY PRIORITY HIGH;
ALTER TABLE tournament_history INMEMORY PRIORITY HIGH;

ALTER TABLE price_log
ADD CLUSTERING BY LINEAR ORDER (company_id, log_time)
YES ON LOAD YES ON DATA MOVEMENT;
ALTER TABLE price_log MOVE

ALTER TABLE trades ADD (total_volume AS (trade_price * quantity));
ALTER TABLE trades INMEMORY(total_volume);

SELECT segment_name, populate_status, bytes_not_populated 
FROM v$im_segments;

SELECT table_name, inmemory, inmemory_priority, inmemory_compression
FROM all_tables
WHERE owner = 'STOCK_ADMIN';








