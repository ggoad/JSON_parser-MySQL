DELIMITER $$
CREATE PROCEDURE `PARSE` (INOUT `op` TEXT, OUT `val` BIGINT UNSIGNED, IN `depthLimit` INT)  
BEGIN 

	DECLARE firstChar CHAR(1);
	SET max_sp_recursion_depth = 15;
	IF op IS NULL THEN 
		SET @jsonCurrentParseDepth = NULL;
		CALL ERROR_op_is_null;
	END IF;
	SET @jsonCurrentParseDepth = IFNULL(@jsonCurrentParseDepth  +1,1);
	SET op = ltrm(op);
	CASE LEFT(op,1)
		WHEN "t" THEN 
			CALL EXTRACT_bool(op,val);
		WHEN "f" THEN 
			CALL EXTRACT_bool(op,val);
		WHEN "{" THEN
			CALL EXTRACT_object(op,val,depthLimit);
		WHEN "[" THEN
			CALL EXTRACT_array(op,val,depthLimit);
		WHEN """" THEN
			CALL EXTRACT_string(op,val);
		WHEN "n" THEN
			CALL EXTRACT_null(op,val);
		ELSE 
			IF LEFT(op,1) IN('0','1','2','3','4','5','6','7','8','9','.','+','-') THEN
				CALL EXTRACT_number(op,val);     
			ELSE 
				CALL JSON_ERROR_PARSE_FAIL;
			END IF;
	END CASE;



	SET @jsonCurrentParseDepth  = @jsonCurrentParseDepth -1;
	IF @jsonCurrentParseDepth  < 0 THEN
		SET @jsonCurrentParseDepth  = NULL;
	END IF;
END$$

CREATE PROCEDURE `RELEASE_val` (IN `p` BIGINT UNSIGNED)  
BEGIN
	DECLARE t TEXT;
	DECLARE o BIGINT UNSIGNED;
	DECLARE gc TEXT;
	DECLARE comInd INT UNSIGNED;
	DECLARE pk TEXT;

	SELECT type INTO t FROM vals WHERE pk = p;

	IF t = "object" OR t = "array" THEN

		SELECT val INTO o FROM vals WHERE pk=p;

		SELECT GROUP_CONCAT(v SEPARATOR ",") INTO gc
			FROM kv
			WHERE o = o;

		WHILE CHARACTER_LENGTH(gc) > 0 DO
			SET comInd = LOCATE(gc, ",");
			IF comInd < 0 THEN 
				SET pk=LEFT(gc, comInd-1);
				SET gc = SUBSTRING(gc, comInd+1);
			ELSE 
				SET pk = gc;
				SET gc="";
			END IF;
			SET pk=LEFT(gc, comInd-1);
			SET gc = SUBSTRING(gc, comInd+1);
      
			CALL RELEASE_val(pk);

		END WHILE;

		DELETE FROM kv WHERE o=o;   
		DELETE FROM objects WHERE pk=o;
		DELETE FROM vals WHERE pk=p;
	ELSE
		DELETE FROM vals WHERE pk=p;
	END IF;
END$$

CREATE PROCEDURE `SERIALIZE` (IN `p` BIGINT UNSIGNED, OUT `ser` TEXT)  
BEGIN

	DECLARE t TEXT;
	DECLARE memv TEXT;
	DECLARE gc TEXT;
	DECLARE comInd INT UNSIGNED;
	DECLARE pk BIGINT UNSIGNED;
	DECLARE memValCatcher BIGINT UNSIGNED;
	DECLARE memValSer TEXT;
	DECLARE memKeyCatcher TEXT;

	IF p IS NULL THEN
		CALL JSON_ERROR_NO_P_PROVIDED;
	ELSE
		CALL  GET_realValAndType(p, memv,t);

		IF t IS NULL THEN 
			SET @nomatter=_err.E(CONCAT("No Existing val ",p));
			# CALL JSON_ERROR_NO_EXISTING_VAL_SERIALIZE ;
		END IF;

		IF t IN('number','boolean','null','raw') THEN
			SET ser = memv;
		ELSEIF  t='string' THEN 
			SET ser = CONCAT('"',memv,'"');
		ELSEIF  t='object' THEN 
			SET ser = "{";
			SELECT GROUP_CONCAT(kk.pk SEPARATOR ",")
				INTO gc
				FROM kv kk
				WHERE kk.o=memv;

			WHILE CHAR_LENGTH(gc) > 0 DO
				SET comInd= LOCATE(",",gc);
				IF comInd = 0 THEN 
					SET pk = gc;
					SET gc = "";
				ELSE
					SET pk = LEFT(gc, comInd-1);
					SET gc = SUBSTRING(gc, comInd+1);
				END IF;
			 
				SELECT l.k ,l.v INTO memKeyCatcher, memValCatcher
					FROM kv l WHERE l.pk=pk LIMIT 1;

				CALL SERIALIZE(memValCatcher,memValSer);
				SET ser = CONCAT(ser,'"',memKeyCatcher,'":',memValSer);

				IF comInd > 0 THEN 
					SET ser = CONCAT(ser,  ",");
				END IF;
			END WHILE;
			SET ser = CONCAT(ser, "}");
		ELSEIF  t='array' THEN 
			SET ser= "[";
			SELECT GROUP_CONCAT(kk.pk SEPARATOR ",")
				INTO gc
				FROM kv kk
				WHERE o=memv
				ORDER BY k;
			WHILE CHAR_LENGTH(gc) > 0 DO
				SET comInd= LOCATE(",",gc);
				IF comInd = 0 THEN 
					SET pk = gc;
					SET gc = "";
				ELSE
					SET pk = LEFT(gc, comInd-1);
					SET gc = SUBSTRING(gc, comInd+1);
				END IF;
			 
				SELECT l.v INTO memValCatcher
					FROM kv l WHERE l.pk=pk;

				CALL SERIALIZE(memValCatcher,memValSer);
				SET ser = CONCAT(ser,memValSer);

				IF comInd > 0 THEN 
					SET ser = CONCAT(ser,  ",");
				END IF;
			 
			END WHILE;
		ELSE 
			SET ser=CONCAT( "ERROR: ",p);
			#CALL JSON_ERROR_SERIALIZE_INVALID_TYPE;
		END IF;

	END IF;
END$$


CREATE FUNCTION `ObjectFromJson` (`jsn` TEXT) RETURNS BIGINT(20) UNSIGNED 
BEGIN 
	DECLARE val BIGINT UNSIGNED;
	DECLARE obj BIGINT UNSIGNED;
	DECLARE tp TEXT;
    CALL PARSE(jsn, val, 0);
    CALL GET_realValAndType(val, obj, tp);
    IF tp = "null" THEN 
    	RETURN NULL;
    ELSEIF tp = 'object' THEN
    	RETURN obj;
    ELSE 
    	CALL ERROR_expectedAnObject();
    END IF;
END$$

CREATE FUNCTION `SET_memVal` (`ob` BIGINT UNSIGNED, `mem` TEXT, `val` TEXT, `tp` TEXT) RETURNS TINYINT(3) UNSIGNED 
BEGIN 

	DECLARE cnt INT;
	DECLARE insId BIGINT UNSIGNED;
	DECLARE hostKv BIGINT UNSIGNED;

	INSERT INTO vals (type, val) VALUES (tp, val);
	SET insid= LAST_INSERT_ID();
	SELECT COUNT(pk) INTO cnt FROM kv WHERE o=ob AND k=mem LIMIT 1;

	IF cnt > 0 THEN 
		UPDATE kv SET v= insid WHERE o=ob AND k=mem;
	ELSE 
		INSERT INTO kv (k,o,v) VALUES (mem, ob, insid);
	END IF;

	RETURN 1;

END$$

CREATE FUNCTION `GET_memVal` (`o` BIGINT UNSIGNED, `k` TEXT) RETURNS BIGINT(20) UNSIGNED 
BEGIN 
	DECLARE ret BIGINT UNSIGNED;
	SELECT l.v INTO ret FROM kv l WHERE l.o= o AND l.k = k LIMIT 1;
	RETURN ret;
END$$

CREATE FUNCTION `GET_object` () RETURNS BIGINT(20) UNSIGNED 
BEGIN 
	INSERT INTO objects (pk)
	VALUES           (NULL);
	RETURN LAST_INSERT_ID();
END$$

CREATE FUNCTION `GET_realMemVal` (`ob` BIGINT UNSIGNED, `mem` TEXT) RETURNS TEXT CHARSET latin1 
BEGIN 
	DECLARE ii BIGINT UNSIGNED;
	SET ii= GET_memVal(ob, mem);
	RETURN GET_realVal(ii);
END$$

CREATE FUNCTION `GET_realVal` (`v` BIGINT UNSIGNED) RETURNS TEXT CHARSET latin1 
BEGIN 
	DECLARE ret TEXT;
	SELECT val INTO ret FROM vals WHERE pk = v LIMIT 1;
	RETURN ret;
END$$

CREATE FUNCTION `GET_serMemVal` (`ob` BIGINT UNSIGNED, `mem` TEXT) RETURNS TEXT CHARSET latin1 
BEGIN 
	DECLARE ii BIGINT UNSIGNED;
	SET ii=GET_memVal(ob,mem);
	RETURN GET_serVal(ii);
END$$

CREATE FUNCTION `GET_serVal` (`p` BIGINT UNSIGNED) RETURNS TEXT CHARSET latin1 
BEGIN 
	DECLARE ret TEXT;
	CALL SERIALIZE(p, ret);
	RETURN ret;
END$$

CREATE FUNCTION `IS_key` (`o` BIGINT UNSIGNED, `mem` TEXT) RETURNS TINYINT(3) UNSIGNED 
BEGIN
	DECLARE c BIGINT UNSIGNED;
	SELECT COUNT(l.pk) INTO c FROM kv l WHERE l.o=o AND l.k=mem;
	IF c=0 THEN 
		RETURN 0; 
	ELSE 
		RETURN 1; 
	END IF;
END$$