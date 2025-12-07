alter session  set container = STOCKLABDB;
show con_name;
CREATE TABLESPACE stocklab_data
    DATAFILE '/opt/oracle/oradata/FREE/stocklabdb/stocklab_data01.dbf'
    SIZE 200M
    AUTOEXTEND ON NEXT 50M
    MAXSIZE UNLIMITED
    SEGMENT SPACE MANAGEMENT AUTO;

CREATE TABLESPACE stocklab_index
    DATAFILE '/opt/oracle/oradata/FREE/stocklabdb/stocklab_index01.dbf'
    SIZE 100M
    AUTOEXTEND ON NEXT 50M
    MAXSIZE UNLIMITED
    SEGMENT SPACE MANAGEMENT AUTO;

CREATE TEMPORARY TABLESPACE stocklab_temp
    TEMPFILE '/opt/oracle/oradata/FREE/stocklabdb/stocklab_temp01.dbf'
    SIZE 100M
    AUTOEXTEND ON NEXT 50M
    MAXSIZE UNLIMITED;
