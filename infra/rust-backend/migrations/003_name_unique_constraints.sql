-- UNIQUE 제약에 명시적 이름 부여 (에러 핸들링에서 constraint name으로 분기하기 위함)
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_nickname_key;
ALTER TABLE users ADD CONSTRAINT uq_users_nickname UNIQUE (nickname);
