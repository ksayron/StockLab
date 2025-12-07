alter session  set container = STOCKLABDB;
show con_name;
CREATE ROLE role_admin;
CREATE ROLE role_user;
CREATE ROLE role_guest;

-- full control
GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE SEQUENCE, CREATE PROCEDURE,
      CREATE TRIGGER, CREATE TYPE, CREATE SYNONYM, CREATE PUBLIC SYNONYM, CREATE MATERIALIZED VIEW,
      ALTER SESSION, SELECT ANY TABLE, INSERT ANY TABLE, UPDATE ANY TABLE, DELETE ANY TABLE
TO role_admin;
grant create public synonym to role_admin;
-- restricted DML, no DDL
GRANT CREATE SESSION, SELECT ANY TABLE, INSERT ANY TABLE, UPDATE ANY TABLE, DELETE ANY TABLE
TO role_user;

-- read-only
GRANT CREATE SESSION, SELECT ANY TABLE
TO role_guest;

alter USER stock_admin IDENTIFIED BY "admin123!"
    DEFAULT TABLESPACE stocklab_data
    TEMPORARY TABLESPACE stocklab_temp
    QUOTA UNLIMITED ON stocklab_data
    QUOTA UNLIMITED ON stocklab_index
    ACCOUNT UNLOCK;

CREATE USER stock_user IDENTIFIED BY "user123!"
    DEFAULT TABLESPACE stocklab_data
    TEMPORARY TABLESPACE stocklab_temp
    QUOTA 500M ON stocklab_data
    QUOTA 100M ON stocklab_index
    ACCOUNT UNLOCK;

CREATE USER stock_guest IDENTIFIED BY "guest123!"
    DEFAULT TABLESPACE stocklab_data
    TEMPORARY TABLESPACE stocklab_temp
    ACCOUNT UNLOCK;
--назначение ролей    
GRANT role_admin TO stock_admin;
GRANT role_user TO stock_user;
GRANT role_guest TO stock_guest;

-- убираем срок жизни парлоей
ALTER PROFILE DEFAULT LIMIT PASSWORD_LIFE_TIME UNLIMITED;

-- 7️⃣ Optional: make stock_admin schema owner
ALTER USER stock_admin DEFAULT ROLE ALL;
ALTER USER stock_admin QUOTA UNLIMITED ON stocklab_data;
ALTER USER stock_admin QUOTA UNLIMITED ON stocklab_index;

