-- phpMyAdmin SQL Dump
-- version 5.1.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Mar 01, 2024 at 09:11 PM
-- Server version: 10.4.20-MariaDB
-- PHP Version: 8.0.9

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `json3`
--
CREATE DATABASE IF NOT EXISTS `json` DEFAULT CHARACTER SET latin1 COLLATE latin1_swedish_ci;
USE `json`;

DELIMITER $$
--
-- Procedures
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `EXTRACT_array` (INOUT `str` TEXT, OUT `cat` BIGINT UNSIGNED, IN `depthLimit` INT)  BEGIN
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
               VALUES        (mainOb,counter ,textCatcher);
            END IF;
            SET str = ltrm(str);
            IF LEFT(str,1) = "," THEN
               SET str=ltrm(SUBSTRING(str,2));
            END IF;
         END IF;
         SET counter =counter +1;
      END WHILE;
      INSERT INTO vals (type   , val)
      VALUES           ("array",mainOb);
      SET cat = LAST_INSERT_ID();
   ELSE
      CALL JSON_ERROR_EXPECTING_ARRAY;
   END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `EXTRACT_bool` (INOUT `str` TEXT, OUT `cat` BIGINT UNSIGNED)  BEGIN
   DECLARE catcher TEXT;
   CALL EXTRACT_rawBool(str, catcher);
   INSERT INTO vals (type, val)
   VALUES          ("boolean", catcher);
   SET cat = LAST_INSERT_ID();
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `EXTRACT_key` (INOUT `str` TEXT, OUT `cat` TEXT)  BEGIN
   DECLARE catcher TEXT;
   CALL EXTRACT_rawString(str, catcher);
   SET cat = SUBSTRING(catcher, 2, CHAR_LENGTH(catcher)-2);
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `EXTRACT_null` (INOUT `str` TEXT, OUT `cat` BIGINT UNSIGNED)  BEGIN
   DECLARE catcher TEXT;
   CALL EXTRACT_rawNull(str, catcher);
   INSERT INTO vals (type  ,val)
   VALUES           ("null",catcher);
   SET cat = LAST_INSERT_ID();
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `EXTRACT_number` (INOUT `str` TEXT, OUT `cat` BIGINT UNSIGNED)  BEGIN
   DECLARE catcher TEXT;
   CALL EXTRACT_rawNumber(str, catcher);
   INSERT INTO vals (type, val)
   VALUES          ("number",catcher);
   SET cat = LAST_INSERT_ID();
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `EXTRACT_object` (INOUT `str` TEXT, OUT `cat` BIGINT UNSIGNED, IN `depthLimit` INT)  BEGIN
DECLARE kk TEXT; DECLARE vv BIGINT UNSIGNED;
DECLARE o BIGINT UNSIGNED;
DECLARE cont INT;
DECLARE catcher TEXT;
   IF LEFT(str,1) = "{" THEN
      	SET str = SUBSTRING(str,2);
        SET o=GET_object();
        
        INSERT INTO vals (type  ,val)
        VALUES           ("object",o);
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
                  VALUES         (o,kk,vv);
               ELSE 
                  CALL EXTRACT_raw(str, catcher);
                  INSERT INTO kv (o,k,v)
                  VALUES         (o,kk,catcher);
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

CREATE DEFINER=`root`@`localhost` PROCEDURE `EXTRACT_raw` (INOUT `str` TEXT, OUT `cat` BIGINT UNSIGNED)  BEGIN
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
VALUES          ("raw", catcher);
SET cat = LAST_INSERT_ID();

END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `EXTRACT_rawArray` (INOUT `str` TEXT, OUT `cat` TEXT)  BEGIN
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
   IF cont = 1 THEN CALL JSON_ERROR_ARRAY_NOT_CLOSED; END IF;
   ELSE
      CALL JSON_ERROR_EXPECTED_RAW_ARRAY;
   END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `EXTRACT_rawBool` (INOUT `str` TEXT, OUT `cat` TEXT)  BEGIN
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

CREATE DEFINER=`root`@`localhost` PROCEDURE `EXTRACT_rawNull` (INOUT `str` TEXT, OUT `cat` TEXT)  BEGIN
    IF LEFT(str,4) = "null" THEN
      	SET str = SUBSTRING(str,5);
        SET cat = "null";
   ELSE
      CALL JSON_ERROR_EXPECTED_RAWNULL;
   END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `EXTRACT_rawNumber` (INOUT `str` TEXT, OUT `cat` TEXT)  BEGIN
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

CREATE DEFINER=`root`@`localhost` PROCEDURE `EXTRACT_rawObject` (INOUT `str` TEXT, OUT `cat` TEXT)  BEGIN
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
   IF cont = 1 THEN CALL JSON_ERROR_OBJECT_NOT_CLOSED; END IF;
   ELSE
      CALL JSON_ERROR_EXPECTED_RAW_OBJECT;
   END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `EXTRACT_rawString` (INOUT `str` TEXT, OUT `cat` TEXT)  BEGIN
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

CREATE DEFINER=`root`@`localhost` PROCEDURE `EXTRACT_string` (INOUT `str` TEXT, OUT `cat` BIGINT UNSIGNED)  BEGIN
   DECLARE catcher TEXT;
   CALL EXTRACT_key(str, catcher);
   INSERT INTO vals (type, val)
   VALUES           ("string",catcher);
   SET cat = LAST_INSERT_ID();
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `GET_realValAndType` (IN `p` BIGINT UNSIGNED, OUT `rv` TEXT, OUT `t` TEXT)  BEGIN 
   SELECT type, val INTO t,rv FROM vals WHERE pk=p LIMIT 1;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `GET_serValAndType` (IN `pk` BIGINT UNSIGNED, OUT `sv` TEXT, OUT `t` TEXT)  BEGIN
   CALL SERIALIZE(pk, sv);
   SELECT type INTO t FROM vals WHERE pk = pk; 
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `PARSE` (INOUT `op` TEXT, OUT `val` BIGINT UNSIGNED, IN `depthLimit` INT)  BEGIN 

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

CREATE DEFINER=`root`@`localhost` PROCEDURE `RELEASE_val` (IN `p` BIGINT UNSIGNED)  BEGIN
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

CREATE DEFINER=`root`@`localhost` PROCEDURE `SERIALIZE` (IN `p` BIGINT UNSIGNED, OUT `ser` TEXT)  BEGIN

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

--
-- Functions
--
CREATE DEFINER=`root`@`localhost` FUNCTION `GET_memVal` (`o` BIGINT UNSIGNED, `k` TEXT) RETURNS BIGINT(20) UNSIGNED BEGIN 
    DECLARE ret BIGINT UNSIGNED;
    SELECT l.v INTO ret FROM kv l WHERE l.o= o AND l.k = k LIMIT 1;
    RETURN ret;
END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `GET_object` () RETURNS BIGINT(20) UNSIGNED BEGIN 
 INSERT INTO objects (pk)
 VALUES           (NULL);
RETURN LAST_INSERT_ID();
END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `GET_realMemVal` (`ob` BIGINT UNSIGNED, `mem` TEXT) RETURNS TEXT CHARSET latin1 BEGIN 
   DECLARE ii BIGINT UNSIGNED;
   SET ii= GET_memVal(ob, mem);
   RETURN GET_realVal(ii);
END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `GET_realVal` (`v` BIGINT UNSIGNED) RETURNS TEXT CHARSET latin1 BEGIN 
   DECLARE ret TEXT;
   SELECT val INTO ret FROM vals WHERE pk = v LIMIT 1;
   RETURN ret;
END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `GET_serMemVal` (`ob` BIGINT UNSIGNED, `mem` TEXT) RETURNS TEXT CHARSET latin1 BEGIN 
   DECLARE ii BIGINT UNSIGNED;
   SET ii=GET_memVal(ob,mem);
   RETURN GET_serVal(ii);
END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `GET_serVal` (`p` BIGINT UNSIGNED) RETURNS TEXT CHARSET latin1 BEGIN 
   DECLARE ret TEXT;
   CALL SERIALIZE(p, ret);
   RETURN ret;
END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `IS_key` (`o` BIGINT UNSIGNED, `mem` TEXT) RETURNS TINYINT(3) UNSIGNED BEGIN
DECLARE c BIGINT UNSIGNED;
SELECT COUNT(l.pk) INTO c FROM kv l WHERE l.o=o AND l.k=mem;
IF c=0 THEN RETURN 0; ELSE RETURN 1; END IF;
END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `IS_whitespace` (`operand` CHAR(1)) RETURNS TINYINT(1) UNSIGNED BEGIN
  RETURN (operand IN (' ','\r','\n','\t'));
END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `ltrm` (`t` TEXT) RETURNS TEXT CHARSET latin1 BEGIN
WHILE t IS NOT NULL AND LENGTH(t) > 0 AND IS_whitespace(LEFT(t,1)) DO
SET t= SUBSTRING(t,2);
END WHILE;
RETURN t;
END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `ObjectFromJson` (`jsn` TEXT) RETURNS BIGINT(20) UNSIGNED BEGIN 
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

CREATE DEFINER=`root`@`localhost` FUNCTION `SET_memVal` (`ob` BIGINT UNSIGNED, `mem` TEXT, `val` TEXT, `tp` TEXT) RETURNS TINYINT(3) UNSIGNED BEGIN 

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

DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `kv`
--

CREATE TABLE `kv` (
  `pk` bigint(20) UNSIGNED NOT NULL,
  `o` bigint(20) UNSIGNED NOT NULL,
  `k` varchar(100) NOT NULL,
  `v` bigint(20) UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `objects`
--

CREATE TABLE `objects` (
  `pk` bigint(20) UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `vals`
--

CREATE TABLE `vals` (
  `pk` bigint(20) UNSIGNED NOT NULL,
  `type` enum('number','string','boolean','object','array','null','raw') NOT NULL,
  `val` text NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `kv`
--
ALTER TABLE `kv`
  ADD PRIMARY KEY (`pk`),
  ADD UNIQUE KEY `o` (`o`,`k`),
  ADD KEY `v` (`v`);

--
-- Indexes for table `objects`
--
ALTER TABLE `objects`
  ADD PRIMARY KEY (`pk`);

--
-- Indexes for table `vals`
--
ALTER TABLE `vals`
  ADD PRIMARY KEY (`pk`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `kv`
--
ALTER TABLE `kv`
  MODIFY `pk` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `objects`
--
ALTER TABLE `objects`
  MODIFY `pk` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `vals`
--
ALTER TABLE `vals`
  MODIFY `pk` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `kv`
--
ALTER TABLE `kv`
  ADD CONSTRAINT `kv_ibfk_1` FOREIGN KEY (`o`) REFERENCES `objects` (`pk`),
  ADD CONSTRAINT `kv_ibfk_2` FOREIGN KEY (`v`) REFERENCES `vals` (`pk`);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;

