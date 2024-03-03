DELIMITER $$
CREATE PROCEDURE `EXTRACT_array` (INOUT `str` TEXT, OUT `cat` BIGINT UNSIGNED, IN `depthLimit` INT)  
BEGIN
	DECLARE counter INT;
	DECLARE currentKV BIGINT UNSIGNED;
	DECLARE textCatcher TEXT;
	DECLARE mainOb BIGINT UNSIGNED;
	DECLARE cont TINYINT(1) UNSIGNED;
	SET cont = 1;
	SET counter = 0;
	IF LEFT(str, 1) = "[" THEN 
		SET str = SUBSTRING(str, 2);
		SET mainOb=GET_object();
		SET cont=1;
		WHILE cont=1 DO
			SET str = ltrm(str);
			IF CHAR_LENGTH(str) =0 THEN
				CALL JSON_ERROR_ARRAY_NOT_CLOSED;
			ELSEIF LEFT(str,1) = "]" THEN
				SET cont = 0 ;
				SET str = SUBSTRING(str,2);
			ELSE 
				IF depthLimit=0 OR @jsonCurrentParseDepth < depthLimit THEN
					CALL PARSE(str, currentKV, depthLimit);
					INSERT INTO kv (o,k,v)
					VALUES        (mainOb,counter ,currentKV);
				ELSE 
					CALL EXTRACT_raw(str, textCatcher);
					INSERT INTO kv (o,k,v)
						VALUES     (mainOb,counter ,textCatcher);
				END IF;
				SET str = ltrm(str);
				IF LEFT(str,1) = "," THEN
					SET str=ltrm(SUBSTRING(str,2));
				END IF;
			END IF;
			SET counter =counter +1;
		END WHILE;
		INSERT INTO vals (type   , val)
			VALUES       ("array",mainOb);
		SET cat = LAST_INSERT_ID();
	ELSE
		CALL JSON_ERROR_EXPECTING_ARRAY;
	END IF;
END$$

CREATE PROCEDURE `EXTRACT_bool` (INOUT `str` TEXT, OUT `cat` BIGINT UNSIGNED)  
BEGIN
	DECLARE catcher TEXT;
	CALL EXTRACT_rawBool(str, catcher);
	INSERT INTO vals (type, val)
		VALUES       ("boolean", catcher);
	SET cat = LAST_INSERT_ID();
END$$

CREATE PROCEDURE `EXTRACT_key` (INOUT `str` TEXT, OUT `cat` TEXT)  
BEGIN
	DECLARE catcher TEXT;
	CALL EXTRACT_rawString(str, catcher);
	SET cat = SUBSTRING(catcher, 2, CHAR_LENGTH(catcher)-2);
END$$

CREATE PROCEDURE `EXTRACT_string` (INOUT `str` TEXT, OUT `cat` BIGINT UNSIGNED)  
BEGIN
	DECLARE catcher TEXT;
	CALL EXTRACT_key(str, catcher);
	INSERT INTO vals (type, val)
		VALUES     ("string",catcher);
	SET cat = LAST_INSERT_ID();
END$$

CREATE PROCEDURE `EXTRACT_null` (INOUT `str` TEXT, OUT `cat` BIGINT UNSIGNED)  
BEGIN
	DECLARE catcher TEXT;
	CALL EXTRACT_rawNull(str, catcher);
	INSERT INTO vals (type  ,val)
		VALUES      ("null",catcher);
	SET cat = LAST_INSERT_ID();
END$$

CREATE PROCEDURE `EXTRACT_number` (INOUT `str` TEXT, OUT `cat` BIGINT UNSIGNED)  
BEGIN
	DECLARE catcher TEXT;
	CALL EXTRACT_rawNumber(str, catcher);
	INSERT INTO vals (type, val)
		VALUES      ("number",catcher);
	SET cat = LAST_INSERT_ID();
END$$

CREATE PROCEDURE `EXTRACT_object` (INOUT `str` TEXT, OUT `cat` BIGINT UNSIGNED, IN `depthLimit` INT)  
BEGIN
	DECLARE kk TEXT; 
	DECLARE vv BIGINT UNSIGNED;
	DECLARE o BIGINT UNSIGNED;
	DECLARE cont INT;
	DECLARE catcher TEXT;
	IF LEFT(str,1) = "{" THEN
		SET str = SUBSTRING(str,2);
		SET o=GET_object();
        
		INSERT INTO vals (type  ,val)
			VALUES      ("object",o);
		SET cat = LAST_INSERT_ID();
		
		SET cont=1;
		WHILE cont=1 DO
			SET str = ltrm(str);
			IF LEFT(str,1) = "}" THEN
				SET cont=0;
				SET str = SUBSTRING(str,2);
			ELSE
				CALL EXTRACT_key(str,kk);
				SET str = ltrm(str);
				IF LEFT(str,1)= ":" THEN
					SET str = ltrm(SUBSTRING(str,2));
					IF depthLimit=0 OR @jsonCurrentParseDepth < depthLimit THEN
						CALL PARSE(str,vv, depthLimit);
						INSERT INTO kv (o,k,v)
							VALUES    (o,kk,vv);
					ELSE 
						CALL EXTRACT_raw(str, catcher);
						INSERT INTO kv (o,k,v)
							VALUES    (o,kk,catcher);
					END IF;
					SET str = ltrm(str);
					IF LEFT(str, 1) = "," THEN
						SET str = SUBSTRING(str,2);
					END IF;
				ELSE
					CALL JSON_ERROR_EXPECTING_SEMI;
				END IF;
			END IF;
		END WHILE;

        
	ELSE
		CALL JSON_ERROR_EXPECTED_OBJECT;
	END IF;
END$$
