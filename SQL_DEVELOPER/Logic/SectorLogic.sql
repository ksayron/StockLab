CREATE OR REPLACE PACKAGE pkg_market_view AS
    
    -- 1. Получить все сектора
    PROCEDURE get_all_sectors (
        o_cursor  OUT SYS_REFCURSOR,
        o_status  OUT VARCHAR2,
        o_message OUT VARCHAR2
    );

    -- 2. Получить сектор по ID
    PROCEDURE get_sector_by_id (
        p_sector_id IN  NUMBER,
        o_cursor    OUT SYS_REFCURSOR,
        o_status    OUT VARCHAR2,
        o_message   OUT VARCHAR2
    );

END pkg_market_view;
/

CREATE OR REPLACE PACKAGE BODY pkg_market_view AS

    PROCEDURE get_all_sectors (
        o_cursor  OUT SYS_REFCURSOR,
        o_status  OUT VARCHAR2,
        o_message OUT VARCHAR2
    ) IS
    BEGIN
        o_status := 'SUCCESS';
        o_message := 'OK';

        OPEN o_cursor FOR
            SELECT sector_id, name, description 
            FROM sectors 
            ORDER BY name;
            
    EXCEPTION
        WHEN OTHERS THEN
            stock_admin.pkg_logger.log_error('pkg_market_view.get_all_sectors', NULL, SQLCODE, SQLERRM);
            o_status := 'ERROR';
            o_message := 'Internal System Error';
    END get_all_sectors;

    PROCEDURE get_sector_by_id (
        p_sector_id IN  NUMBER,
        o_cursor    OUT SYS_REFCURSOR,
        o_status    OUT VARCHAR2,
        o_message   OUT VARCHAR2
    ) IS
    BEGIN
        o_status := 'SUCCESS';
        o_message := 'OK';

        OPEN o_cursor FOR
            SELECT sector_id, name, description 
            FROM sectors 
            WHERE sector_id = p_sector_id;
            
    EXCEPTION
        WHEN OTHERS THEN
            stock_admin.pkg_logger.log_error('pkg_market_view.get_sector_by_id', NULL, SQLCODE, SQLERRM);
            o_status := 'ERROR';
            o_message := 'Internal System Error';
    END get_sector_by_id;

END pkg_market_view;
/

CREATE OR REPLACE PACKAGE pkg_market_admin AS

    -- CRUD операции
    PROCEDURE add_sector (
        p_name        IN  VARCHAR2,
        p_description IN  VARCHAR2,
        o_sector_id   OUT NUMBER,
        o_status      OUT VARCHAR2,
        o_message     OUT VARCHAR2
    );

    PROCEDURE update_sector (
        p_sector_id   IN  NUMBER,
        p_name        IN  VARCHAR2,
        p_description IN  VARCHAR2,
        o_status      OUT VARCHAR2,
        o_message     OUT VARCHAR2
    );

    PROCEDURE delete_sector (
        p_sector_id   IN  NUMBER,
        o_status      OUT VARCHAR2,
        o_message     OUT VARCHAR2
    );

END pkg_market_admin;
/
CREATE OR REPLACE PACKAGE BODY pkg_market_admin AS

    -- ADD
    PROCEDURE add_sector (
        p_name        IN  VARCHAR2,
        p_description IN  VARCHAR2,
        o_sector_id   OUT NUMBER,
        o_status      OUT VARCHAR2,
        o_message     OUT VARCHAR2
    ) IS
    BEGIN
        o_status := 'SUCCESS';
        o_message := 'Сектор создан';

        INSERT INTO sectors (name, description)
        VALUES (p_name, p_description)
        RETURNING sector_id INTO o_sector_id;
        
        COMMIT;
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            ROLLBACK;
            o_status := 'ERROR';
            o_message := 'Имя сектора уже занято';
        WHEN OTHERS THEN
            ROLLBACK;
            stock_admin.pkg_logger.log_error('pkg_market_admin.add_sector', NULL, SQLCODE, SQLERRM);
            o_status := 'ERROR';
            o_message := 'Internal System Error';
    END add_sector;

    -- UPDATE
    PROCEDURE update_sector (
        p_sector_id   IN  NUMBER,
        p_name        IN  VARCHAR2,
        p_description IN  VARCHAR2,
        o_status      OUT VARCHAR2,
        o_message     OUT VARCHAR2
    ) IS
    BEGIN
        o_status := 'SUCCESS';
        o_message := 'Сектор обновлен';

        UPDATE sectors
        SET name = p_name,
            description = p_description
        WHERE sector_id = p_sector_id;

        IF SQL%ROWCOUNT = 0 THEN
            ROLLBACK;
            o_status := 'ERROR';
            o_message := 'Сектор не найден';
            RETURN;
        END IF;
        
        COMMIT;
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            ROLLBACK;
            o_status := 'ERROR';
            o_message := 'Имя сектора уже занято';
        WHEN OTHERS THEN
            ROLLBACK;
            stock_admin.pkg_logger.log_error('pkg_market_admin.update_sector', NULL, SQLCODE, SQLERRM);
            o_status := 'ERROR';
            o_message := 'Internal System Error';
    END update_sector;

    -- DELETE
    PROCEDURE delete_sector (
        p_sector_id IN  NUMBER,
        o_status    OUT VARCHAR2,
        o_message   OUT VARCHAR2
    ) IS
        e_child_records EXCEPTION;
        PRAGMA EXCEPTION_INIT(e_child_records, -02292);
    BEGIN
        o_status := 'SUCCESS';
        o_message := 'Сектор удален';

        DELETE FROM sectors WHERE sector_id = p_sector_id;

        IF SQL%ROWCOUNT = 0 THEN
            ROLLBACK;
            o_status := 'ERROR';
            o_message := 'Секктор не найден';
            RETURN;
        END IF;

        COMMIT;
    EXCEPTION
        WHEN e_child_records THEN
            ROLLBACK;
            o_status := 'ERROR';
            o_message := 'Невозможно удалить,так как данный сервер уже используется';
        WHEN OTHERS THEN
            ROLLBACK;
            stock_admin.pkg_logger.log_error('pkg_market_admin.delete_sector', NULL, SQLCODE, SQLERRM);
            o_status := 'ERROR';
            o_message := 'Internal System Error';
    END delete_sector;

END pkg_market_admin;
/


CREATE OR REPLACE PUBLIC SYNONYM pkg_market_view FOR pkg_market_view;
CREATE OR REPLACE PUBLIC SYNONYM pkg_market_admin FOR pkg_market_admin;

GRANT EXECUTE ON pkg_market_view TO stock_user;
GRANT EXECUTE ON pkg_market_view TO stock_guest;
GRANT EXECUTE ON pkg_market_view TO stock_admin;


GRANT EXECUTE ON pkg_market_admin TO stock_admin;