CREATE OR REPLACE PACKAGE pkg_users AS

  -- Retrieve all users
    PROCEDURE get_users(p_cursor OUT SYS_REFCURSOR);

  -- Retrieve one user
    PROCEDURE get_user_by_id(p_id IN NUMBER, p_cursor OUT SYS_REFCURSOR);
  
    PROCEDURE get_user_by_username(p_username IN VARCHAR2, p_cursor OUT SYS_REFCURSOR);

  -- Add user (registration)
    PROCEDURE add_user(
        p_username      IN VARCHAR2,
        p_password_hash IN VARCHAR2,
        p_email         IN VARCHAR2,
        p_role_id       IN NUMBER,
        p_balance       IN NUMBER DEFAULT 0
    );

  -- Update user info
    PROCEDURE update_user(
        p_id         IN NUMBER,
        p_username   IN VARCHAR2,
        p_email      IN VARCHAR2,
        p_balance    IN NUMBER
    );

  -- Delete user
    PROCEDURE delete_user(p_id IN NUMBER);

  -- Authentication
    FUNCTION validate_login(
        p_username      IN VARCHAR2,
        p_password_hash IN VARCHAR2
      ) RETURN NUMBER;

  -- Existence check
    FUNCTION check_user_exists(
        p_username IN VARCHAR2,
        p_email    IN VARCHAR2
    ) RETURN BOOLEAN;

  -- Stats
    FUNCTION get_trade_count(p_user_id IN NUMBER) RETURN NUMBER;
    FUNCTION get_portfolio_value(p_user_id IN NUMBER) RETURN NUMBER;

  -- Admin utilities
    PROCEDURE ban_user(p_user_id IN NUMBER);
    PROCEDURE unban_user(p_user_id IN NUMBER);
    PROCEDURE update_role(p_user_id IN NUMBER, p_new_role_id IN NUMBER);

END pkg_users;
/
CREATE OR REPLACE PACKAGE BODY pkg_users AS

  --------------------------------------------------------------------
  PROCEDURE get_users(p_cursor OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_cursor FOR
      SELECT id, username, email, role_id, balance, trade_count, is_bot, is_banned
      FROM users;
  END get_users;

  --------------------------------------------------------------------
  PROCEDURE get_user_by_id(p_id IN NUMBER, p_cursor OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_cursor FOR
      SELECT id, username, email, role_id, balance, trade_count, is_bot, is_banned
      FROM users
      WHERE id = p_id;
  END get_user_by_id;
 --------------------------------------------------------------------
  PROCEDURE get_user_by_username(p_username IN VARCHAR2, p_cursor OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_cursor FOR
      SELECT id, username, password_hash, email, role_id, balance
      FROM users
      WHERE username = p_username;
  END get_user_by_username;
  --------------------------------------------------------------------
  PROCEDURE add_user(
    p_username      IN VARCHAR2,
    p_password_hash IN VARCHAR2,
    p_email         IN VARCHAR2,
    p_role_id       IN NUMBER,
    p_balance       IN NUMBER DEFAULT 0
  ) IS
  BEGIN
    INSERT INTO users(username, password_hash, email, role_id, balance, trade_count, is_bot, is_banned, created_at)
    VALUES (p_username, p_password_hash, p_email, p_role_id, p_balance, 0, 'N', 'N', SYSDATE);
    COMMIT;
  END add_user;

  --------------------------------------------------------------------
  PROCEDURE update_user(
    p_id         IN NUMBER,
    p_username   IN VARCHAR2,
    p_email      IN VARCHAR2,
    p_balance    IN NUMBER
  ) IS
  BEGIN
    UPDATE users
       SET username = p_username,
           email = p_email,
           balance = p_balance
     WHERE id = p_id;
    COMMIT;
  END update_user;

  --------------------------------------------------------------------
  PROCEDURE delete_user(p_id IN NUMBER) IS
  BEGIN
    DELETE FROM users WHERE id = p_id;
    COMMIT;
  END delete_user;

  --------------------------------------------------------------------
  FUNCTION validate_login(
    p_username      IN VARCHAR2,
    p_password_hash IN VARCHAR2
  ) RETURN NUMBER IS
    v_id NUMBER;
  BEGIN
    SELECT id INTO v_id
    FROM users
    WHERE username = p_username
      AND password_hash = p_password_hash
      AND is_banned = 'N';
    RETURN v_id;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN NULL;
  END validate_login;

  --------------------------------------------------------------------
  FUNCTION check_user_exists(
    p_username IN VARCHAR2,
    p_email    IN VARCHAR2
  ) RETURN BOOLEAN IS
    v_count NUMBER;
  BEGIN
    SELECT COUNT(*) INTO v_count
    FROM users
    WHERE username = p_username OR email = p_email;
    RETURN (v_count > 0);
  END check_user_exists;

  --------------------------------------------------------------------
  FUNCTION get_trade_count(p_user_id IN NUMBER) RETURN NUMBER IS
    v_count NUMBER;
  BEGIN
    SELECT trade_count INTO v_count FROM users WHERE id = p_user_id;
    RETURN v_count;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN 0;
  END get_trade_count;

  --------------------------------------------------------------------
  FUNCTION get_portfolio_value(p_user_id IN NUMBER) RETURN NUMBER IS
    v_value NUMBER;
  BEGIN
    SELECT NVL(SUM(s.purchase_price), 0)
    INTO v_value
    FROM stocks s
    WHERE s.portfolio_id = p_user_id;
    RETURN v_value;
  END get_portfolio_value;

  --------------------------------------------------------------------
  PROCEDURE ban_user(p_user_id IN NUMBER) IS
  BEGIN
    UPDATE users SET is_banned = 'Y' WHERE id = p_user_id;
    COMMIT;
  END ban_user;

  --------------------------------------------------------------------
  PROCEDURE unban_user(p_user_id IN NUMBER) IS
  BEGIN
    UPDATE users SET is_banned = 'N' WHERE id = p_user_id;
    COMMIT;
  END unban_user;

  --------------------------------------------------------------------
  PROCEDURE update_role(p_user_id IN NUMBER, p_new_role_id IN NUMBER) IS
  BEGIN
    UPDATE users SET role_id = p_new_role_id WHERE id = p_user_id;
    COMMIT;
  END update_role;

END pkg_users;
/