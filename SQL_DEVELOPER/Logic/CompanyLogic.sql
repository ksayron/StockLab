CREATE OR REPLACE PACKAGE pkg_companies_view AS
    
    -- Единая процедура для получения списка компаний
    -- Поддерживает: Фильтрацию по сектору, Поиск, Сортировку
    PROCEDURE get_companies (
        p_search_query  IN  VARCHAR2 DEFAULT NULL, -- Поиск по имени/тикеру
        p_sector_id     IN  NUMBER   DEFAULT NULL, -- Фильтр по сектору
        p_sort_by       IN  VARCHAR2 DEFAULT 'NAME', -- 'NAME', 'PRICE', 'VOLATILITY'
        p_sort_dir      IN  VARCHAR2 DEFAULT 'ASC',  -- 'ASC', 'DESC'
        o_cursor        OUT SYS_REFCURSOR,
        o_status        OUT VARCHAR2,
        o_message       OUT VARCHAR2
    );

    -- Получение одной компании остается отдельным, так как это детальный вид
    PROCEDURE get_company_by_id (
        p_company_id IN  NUMBER,
        o_cursor     OUT SYS_REFCURSOR,
        o_status     OUT VARCHAR2,
        o_message    OUT VARCHAR2
    );
    
    PROCEDURE get_price_history (
        p_company_id IN  NUMBER,
        p_hours_back IN  NUMBER DEFAULT 24, -- За сколько часов
        o_cursor     OUT SYS_REFCURSOR,
        o_status     OUT VARCHAR2,
        o_message    OUT VARCHAR2
    );

END pkg_companies_view;
/

CREATE OR REPLACE PACKAGE BODY pkg_companies_view AS

    PROCEDURE get_companies (
        p_search_query  IN  VARCHAR2 DEFAULT NULL,
        p_sector_id     IN  NUMBER   DEFAULT NULL,
        p_sort_by       IN  VARCHAR2 DEFAULT 'NAME',
        p_sort_dir      IN  VARCHAR2 DEFAULT 'ASC',
        o_cursor        OUT SYS_REFCURSOR,
        o_status        OUT VARCHAR2,
        o_message       OUT VARCHAR2
    ) IS
        v_search_term VARCHAR2(100);
    BEGIN
        o_status := 'SUCCESS';
        o_message := 'ОК';

        -- Подготовка строки поиска (если она есть)
        IF p_search_query IS NOT NULL THEN
            v_search_term := '%' || LOWER(p_search_query) || '%';
        END IF;

        OPEN o_cursor FOR
            SELECT c.company_id, c.name, c.ticker_symbol, c.current_price, 
                   s.name as sector_name, c.volatility_factor, c.status
            FROM companies c
            JOIN sectors s ON c.sector_id = s.sector_id
            WHERE c.status = 'ACTIVE'
              -- 1. Фильтр по сектору (если p_sector_id NULL, условие игнорируется)
              AND (p_sector_id IS NULL OR c.sector_id = p_sector_id)
              -- 2. Поиск (если v_search_term NULL, условие игнорируется)
              AND (v_search_term IS NULL OR 
                   LOWER(c.name) LIKE v_search_term OR 
                   LOWER(c.ticker_symbol) LIKE v_search_term)
            ORDER BY 
                -- 3. Динамическая сортировка
                CASE WHEN p_sort_dir = 'ASC' THEN
                    CASE 
                        WHEN p_sort_by = 'PRICE' THEN c.current_price
                        WHEN p_sort_by = 'VOLATILITY' THEN c.volatility_factor
                    END
                END ASC,
                CASE WHEN p_sort_dir = 'DESC' THEN
                    CASE 
                        WHEN p_sort_by = 'PRICE' THEN c.current_price
                        WHEN p_sort_by = 'VOLATILITY' THEN c.volatility_factor
                    END
                END DESC,
                -- Сортировка по имени (всегда как вторичная или основная)
                CASE WHEN p_sort_by = 'NAME' AND p_sort_dir = 'ASC' THEN c.name END ASC,
                CASE WHEN p_sort_by = 'NAME' AND p_sort_dir = 'DESC' THEN c.name END DESC;

    EXCEPTION
        WHEN OTHERS THEN
            stock_admin.pkg_logger.log_error('pkg_companies_view.get_companies', NULL, SQLCODE, SQLERRM);
            o_status := 'ERROR';
            o_message := 'Internal Server Error';
    END get_companies;

    PROCEDURE get_company_by_id (
        p_company_id IN  NUMBER,
        o_cursor     OUT SYS_REFCURSOR,
        o_status     OUT VARCHAR2,
        o_message    OUT VARCHAR2
    ) IS
    BEGIN
        o_status := 'SUCCESS';
        o_message := 'ОК';

        OPEN o_cursor FOR
            SELECT c.company_id, c.name, c.ticker_symbol, c.description, 
                   c.current_price, c.sector_id, s.name as sector_name,
                   c.volatility_factor
            FROM companies c
            JOIN sectors s ON c.sector_id = s.sector_id
            WHERE c.company_id = p_company_id AND c.status = 'ACTIVE';
            
    EXCEPTION
        WHEN OTHERS THEN
            stock_admin.pkg_logger.log_error('pkg_companies_view.get_company_by_id', NULL, SQLCODE, SQLERRM);
            o_status := 'ERROR';
            o_message := 'Internal Server Error';
    END get_company_by_id;
    
    PROCEDURE get_price_history (
        p_company_id IN  NUMBER,
        p_hours_back IN  NUMBER DEFAULT 24,
        o_cursor     OUT SYS_REFCURSOR,
        o_status     OUT VARCHAR2,
        o_message    OUT VARCHAR2
    ) IS
    BEGIN
        o_status := 'SUCCESS';
        o_message := 'ОК';

        OPEN o_cursor FOR
            SELECT price, log_time
            FROM price_log
            WHERE company_id = p_company_id
              AND log_time >= SYSTIMESTAMP - NUMTODSINTERVAL(p_hours_back, 'HOUR')
            ORDER BY log_time ASC;
    EXCEPTION
        WHEN OTHERS THEN
            stock_admin.pkg_logger.log_error('pkg_companies_view.get_price_history', NULL, SQLCODE, SQLERRM);
            o_status := 'ERROR';
            o_message := 'Внутренняя ошибка сервера';
    END get_price_history;

END pkg_companies_view;
/

-- логика
CREATE OR REPLACE PACKAGE pkg_companies_admin AS

    -- 1. Добавить компанию (IPO)
    PROCEDURE add_company (
        p_sector_id    IN NUMBER,
        p_name         IN VARCHAR2,
        p_ticker       IN VARCHAR2,
        p_description  IN VARCHAR2,
        p_init_price   IN NUMBER,
        p_volatility   IN NUMBER,
        p_total_shares IN NUMBER,
        o_company_id   OUT NUMBER,
        o_status       OUT VARCHAR2,
        o_message      OUT VARCHAR2
    );

    -- 2. Обновить
    PROCEDURE update_company (
        p_company_id  IN NUMBER,
        p_sector_id   IN NUMBER,
        p_name        IN VARCHAR2,
        p_description IN VARCHAR2,
        p_volatility  IN NUMBER,
        o_status      OUT VARCHAR2,
        o_message     OUT VARCHAR2
    );

    -- 3. Делистинг
    PROCEDURE delist_company (
        p_company_id IN NUMBER,
        o_status     OUT VARCHAR2,
        o_message    OUT VARCHAR2
    );

END pkg_companies_admin;
/

CREATE OR REPLACE PACKAGE BODY pkg_companies_admin AS

    PROCEDURE add_company (
        p_sector_id    IN NUMBER,
        p_name         IN VARCHAR2,
        p_ticker       IN VARCHAR2,
        p_description  IN VARCHAR2,
        p_init_price   IN NUMBER,
        p_volatility   IN NUMBER,
        p_total_shares IN NUMBER,
        o_company_id   OUT NUMBER,
        o_status       OUT VARCHAR2,
        o_message      OUT VARCHAR2
    ) IS
        v_issuer_user_id NUMBER;
        v_role_id        NUMBER;
        v_issuer_name    VARCHAR2(100);
    BEGIN
        o_status := 'SUCCESS';
        o_message := 'Компания создана, IPO запущено';

        -- 1. Создаем Компанию
        INSERT INTO companies (
            sector_id, name, ticker_symbol, description, current_price, volatility_factor, status, total_shares
        ) VALUES (
            p_sector_id, p_name, UPPER(p_ticker), p_description, p_init_price, p_volatility, 'ACTIVE', p_total_shares
        ) RETURNING company_id INTO o_company_id;
        
        -- 2. Логика Эмитента (Refactored)
        v_issuer_name := 'ISSUER_' || UPPER(p_ticker);
        
        BEGIN
            -- Ищем роль ISSUER
            SELECT role_id INTO v_role_id FROM roles WHERE name = 'Issuer' FETCH FIRST 1 ROWS ONLY;
        EXCEPTION WHEN NO_DATA_FOUND THEN
            -- Fallback на USER, если роль Issuer не создана
            BEGIN
                SELECT role_id INTO v_role_id FROM roles WHERE name = 'User' FETCH FIRST 1 ROWS ONLY;
            EXCEPTION WHEN NO_DATA_FOUND THEN
                 -- Fallback на любую роль (крайний случай)
                 SELECT role_id INTO v_role_id FROM roles FETCH FIRST 1 ROWS ONLY;
            END;
        END;
        
        INSERT INTO users (
            role_id, username, email, password_hash, balance, is_banned
        ) VALUES (
            v_role_id, v_issuer_name, v_issuer_name || '@stocklab.internal', 
            'SYSTEM_ACCOUNT_LOCKED', 0, 1
        ) RETURNING user_id INTO v_issuer_user_id;
        
        -- 3. Ордер и Портфель
        INSERT INTO portfolios (user_id, company_id, quantity_owned) 
        VALUES (v_issuer_user_id, o_company_id, p_total_shares);

        INSERT INTO orders (
            user_id, company_id, type, status, limit_price, original_qty, remaining_qty
        ) VALUES (
            v_issuer_user_id, o_company_id, 'SELL', 'OPEN', p_init_price, p_total_shares, p_total_shares
        );

        COMMIT;

    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            ROLLBACK;
            o_status := 'ERROR';
            o_message := 'Имя компании, Тикер или Имя эмитента уже заняты';
        
        WHEN OTHERS THEN
            ROLLBACK;
            IF SQLCODE = -2291 THEN
                o_status := 'ERROR';
                o_message := 'Указан неверный ID сектора';
            ELSE
                stock_admin.pkg_logger.log_error('pkg_companies_admin.add_company', NULL, SQLCODE, SQLERRM);
                o_status := 'ERROR';
                o_message := 'Internal Server Error: ' || SQLERRM;
            END IF;
    END add_company;
    
    PROCEDURE update_company (
        p_company_id  IN NUMBER,
        p_sector_id   IN NUMBER,
        p_name        IN VARCHAR2,
        p_description IN VARCHAR2,
        p_volatility  IN NUMBER,
        o_status      OUT VARCHAR2,
        o_message     OUT VARCHAR2
    ) IS
    BEGIN
        o_status := 'SUCCESS';
        o_message := 'Компания обновлена';

        UPDATE companies
        SET sector_id = p_sector_id,
            name = p_name,
            description = p_description,
            volatility_factor = p_volatility
        WHERE company_id = p_company_id;

        IF SQL%ROWCOUNT = 0 THEN
            ROLLBACK;
            o_status := 'ERROR';
            o_message := 'Компания не найдена';
            RETURN;
        END IF;

        COMMIT;
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            ROLLBACK;
            o_status := 'ERROR';
            o_message := 'Имя компании уже занято';
        WHEN OTHERS THEN
            ROLLBACK;
            IF SQLCODE = -2291 THEN
                o_status := 'ERROR';
                o_message := 'Указан неверный ID сектора';
            ELSE
                stock_admin.pkg_logger.log_error('pkg_companies_admin.update_company', NULL, SQLCODE, SQLERRM);
                o_status := 'ERROR';
                o_message := 'Internal Server Error';
            END IF;
    END update_company;

    PROCEDURE delist_company (
        p_company_id IN NUMBER,
        o_status     OUT VARCHAR2,
        o_message    OUT VARCHAR2
    ) IS
    BEGIN
        o_status := 'SUCCESS';
        o_message := 'Компания делистингована';

        UPDATE companies
        SET status = 'DELISTED', current_price = 0
        WHERE company_id = p_company_id;
        
        IF SQL%ROWCOUNT = 0 THEN
            ROLLBACK;
            o_status := 'ERROR';
            o_message := 'Компания не найдена';
            RETURN;
        END IF;

        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            stock_admin.pkg_logger.log_error('pkg_companies_admin.delist_company', NULL, SQLCODE, SQLERRM);
            o_status := 'ERROR';
            o_message := 'Internal Server Error';
    END delist_company;

END pkg_companies_admin;
/
CREATE OR REPLACE PUBLIC SYNONYM pkg_companies_view FOR pkg_companies_view;
CREATE OR REPLACE PUBLIC SYNONYM pkg_companies_admin FOR pkg_companies_admin;

GRANT EXECUTE ON pkg_companies_view TO stock_user;
GRANT EXECUTE ON pkg_companies_view TO stock_guest;
GRANT EXECUTE ON pkg_companies_view TO stock_admin;

GRANT EXECUTE ON pkg_market_admin TO stock_admin;