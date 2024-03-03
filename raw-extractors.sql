DELIMITER $$
CREATE PROCEDURE `EXTRACT_raw` (INOUT `str` TEXT, OUT `cat` BIGINT UNSIGNED)  
BEGIN
	DECLARE firstChar CHAR(1);
	DECLARE catcher TEXT;
	SET str=ltrm(str);
	SET firstChar = LEFT(str,1);
	CASE firstChar
		WHEN "t" THEN
			CALL EXTRACT_rawBool(str,catcher); 
		WHEN "f" THEN 
			CALL EXTRACT_rawBool(str,catcher);
		WHEN "{" THEN
			CALL EXTRACT_rawObject(str,catcher);
		WHEN "[" THEN
			CALL EXTRACT_rawArray(str,catcher);
		WHEN "\"" THEN
			CALL EXTRACT_rawString(str,catcher);
		WHEN "n" THEN
			CALL EXTRACT_rawNull(str,catcher);
		ELSE
			IF firstChar IN('0','1','2','3','4','5','6','7','8','9','.','+','-') THEN
				CALL EXTRACT_rawNumber(str,catcher);
			ELSE 
				CALL JSON_ERROR_EXTRACT_RAW_FAILURE;
			END IF;
	END CASE;

	INSERT INTO vals (type, val)
		VALUES       ("raw", catcher);
	SET cat = LAST_INSERT_ID();

END$$

CREATE PROCEDURE `EXTRACT_rawArray` (INOUT `str` TEXT, OUT `cat` TEXT)  
BEGIN
	DECLARE cont TINYINT(1) UNSIGNED;
	DECLARE counter INT UNSIGNED;
	DECLARE insideStr TINYINT(1) UNSIGNED;
	DECLARE escp TINYINT(1) UNSIGNED;
	DECLARE extraOpenings INT UNSIGNED;
	DECLARE firstChar CHAR(1);
	SET cont = 1;
	SET counter = 2;
	SET insideStr=0;
	SET escp=0;
	SET extraOpenings=0;
	IF LEFT(str,1)="[" THEN
		WHILE str IS NOT NULL AND cont=1 AND counter <= CHAR_LENGTH(str) DO
			SET firstChar = SUBSTRING(str,counter,1);
			IF firstChar = "\"" THEN
				IF insideStr AND NOT escp THEN
					SET insideStr= 0;
				ELSEIF NOT insideStr THEN
					SET insideStr=1;
				END IF;
				SET escp = 0;
			ELSEIF firstChar = "\\" THEN
				IF escp = 1 THEN 
					SET escp = 0;
				ELSEIF insideStr = 1 THEN 
					SET escp = 1;
				END IF;
			ELSEIF firstChar = "[" THEN
				IF NOT insideStr THEN
					SET extraOpenings= extraOpenings+1;
				ELSE
					SET escp = 0;
				END IF;
         
			ELSEIF firstChar = "]" THEN
				IF NOT insideStr THEN
					IF extraOpenings = 0 THEN 
						SET cont = 0;
						SET cat = LEFT(str,counter);
						SET str = SUBSTRING(str, counter+1);
					ELSE 
						SET extraOpenings = extraOpenings - 1;
					END IF;
				ELSE
					SET escp = 0;
				END IF;   
			ELSE
				SET escp = 0;
			END IF;
			SET counter=counter+1;
		END WHILE;
		IF cont = 1 THEN 
			CALL JSON_ERROR_ARRAY_NOT_CLOSED; 
		END IF;
	ELSE
		CALL JSON_ERROR_EXPECTED_RAW_ARRAY;
	END IF;
END$$

CREATE PROCEDURE `EXTRACT_rawBool` (INOUT `str` TEXT, OUT `cat` TEXT)  
BEGIN
	IF LEFT(str, 4) = "true" THEN
		SET cat = LEFT(str,4);
		SET str= SUBSTRING(str,5);
	ELSEIF LEFT(str, 5) = "false" THEN
		SET cat = LEFT(str,5);
		SET str= SUBSTRING(str,6);
   
	ELSE
		CALL JSON_ERROR_rawBool;
	END IF;
END$$

CREATE PROCEDURE `EXTRACT_rawNull` (INOUT `str` TEXT, OUT `cat` TEXT)  
BEGIN
	IF LEFT(str,4) = "null" THEN
		SET str = SUBSTRING(str,5);
		SET cat = "null";
	ELSE
		CALL JSON_ERROR_EXPECTED_RAWNULL;
	END IF;
END$$

CREATE PROCEDURE `EXTRACT_rawNumber` (INOUT `str` TEXT, OUT `cat` TEXT)  
BEGIN
	DECLARE counter INT UNSIGNED;
	DECLARE cont TINYINT(1) UNSIGNED;
	DECLARE deci TINYINT(1) UNSIGNED;


	SET counter = 0;
	SET cont =1;
	SET deci=0;
	IF LEFT(str, 1) NOT IN("+","-","0","1","2","3","4","5","6","7","8","9",".") THEN
		CALL JSON_ERROR_EXPECTING_NUMBER;
	END IF;
	WHILE cont =1 AND counter <= CHAR_LENGTH(str) DO
		SET counter = counter+1;
		IF counter = 1 THEN 
			IF SUBSTRING(str,counter,1)="." THEN
				IF deci=1 THEN
					CALL JSON_ERROR_TWO_DECIMALS;
				END IF;
				SET deci=1;
			ELSEIF SUBSTRING(str,counter,1) NOT IN("+","-","0","1","2","3","4","5","6","7","8","9") THEN
				CALL JSON_ERROR_EXPECTING_NUMBER;
			END IF;
		ELSE 
			IF SUBSTRING(str,counter,1)="." THEN
				IF deci = 1 THEN
					CALL JSON_ERROR_TWO_DECIMALS;
				END IF;
				SET deci=1;
			ELSEIF SUBSTRING(str,counter,1) NOT IN("0","1","2","3","4","5","6","7","8","9") THEN
				SET cont=0; SET counter = counter-1;
			END IF;
		END IF;
	END WHILE;
	SET cat = SUBSTRING(str,1,counter);
	SET str = SUBSTRING(str,counter+1);
END$$

CREATE PROCEDURE `EXTRACT_rawObject` (INOUT `str` TEXT, OUT `cat` TEXT)  
BEGIN
	DECLARE cont TINYINT(1) UNSIGNED;
	DECLARE counter INT UNSIGNED;
	DECLARE insideStr TINYINT(1) UNSIGNED;
	DECLARE escp TINYINT(1) UNSIGNED;
	DECLARE extraOpenings INT UNSIGNED;
	DECLARE firstChar CHAR(1);
	SET cont = 1;
	SET counter = 2;
	SET insideStr=0;
	SET escp=0;
	SET extraOpenings=0;
	IF LEFT(str,1)="{" THEN
		WHILE str IS NOT NULL AND cont=1 AND counter <= CHAR_LENGTH(str) DO
			SET firstChar = SUBSTRING(str,counter,1);
			IF firstChar = "\"" THEN
				IF insideStr AND NOT escp THEN
					SET insideStr= 0;
				ELSEIF NOT insideStr THEN
					SET insideStr=1;
				END IF;
				SET escp = 0;
			ELSEIF firstChar = "\\" THEN
				IF escp = 1 THEN 
					SET escp = 0;
				ELSEIF insideStr = 1 THEN 
					SET escp = 1;
				END IF;
			ELSEIF firstChar = "{" THEN
				IF NOT insideStr THEN
					SET extraOpenings= extraOpenings+1;
				ELSE
					SET escp = 0;
				END IF;
         
			ELSEIF firstChar = "}" THEN
				IF NOT insideStr THEN
					IF extraOpenings = 0 THEN 
						SET cont = 0;
						SET cat = LEFT(str,counter);
						SET str = SUBSTRING(str, counter+1);
					ELSE 
						SET extraOpenings = extraOpenings - 1;
					END IF;
				ELSE
					SET escp = 0;
				END IF;
			ELSE
				SET escp = 0;
			END IF;
			SET counter=counter+1;
		END WHILE;
		IF cont = 1 THEN 
			CALL JSON_ERROR_OBJECT_NOT_CLOSED; 
		END IF;
	ELSE
		CALL JSON_ERROR_EXPECTED_RAW_OBJECT;
	END IF;
END$$

CREATE  PROCEDURE `EXTRACT_rawString` (INOUT `str` TEXT, OUT `cat` TEXT)  
BEGIN
	DECLARE counter INT UNSIGNED;
	DECLARE clength INT UNSIGNED;
	DECLARE escp TINYINT(1) UNSIGNED;
	DECLARE cont TINYINT(1) UNSIGNED;
	DECLARE nextChar CHAR(1);
   
	IF LEFT(str,1) = "\"" THEN
		SET counter=2; SET cont=1;
		SET clength = CHAR_LENGTH(str);
		SET escp=0;
		WHILE cont =1 AND counter <= clength DO
			SET nextChar=SUBSTRING(str,counter,1);
			IF nextChar = "\"" AND escp=0 THEN
				SET cat = LEFT(str,counter);
				SET str=SUBSTRING(str,counter+1);
				SET cont=0;
			ELSEIF nextChar = "\\" AND escp=0 THEN
				SET escp=1;  
			ELSE 
				SET escp=0;
			END IF;
			SET counter = counter +1;
		END WHILE;
		IF cont=1 THEN 
			CALL JSON_ERROR_STRING_NOT_CLOSED;
		END IF;
	ELSE 
		CALL JSON_ERROR_EXPECTING_KEY;
	END IF;
END$$
