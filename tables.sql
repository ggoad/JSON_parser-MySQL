CREATE DATABASE `json`;
USE `json`;

CREATE TABLE `kv` (
	`pk` bigint(20) UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
	`o` bigint(20) UNSIGNED NOT NULL,
	`k` varchar(100) NOT NULL,
	`v` bigint(20) UNSIGNED NOT NULL,
	UNIQUE KEY (`o`,`k`),
	FOREIGN KEY (`o`) REFRENCES `objects`(`pk`),
	FOREIGN KEY (`v`) REFRENCES `vals`(`pk`)
);



CREATE TABLE `objects` (
	`pk` bigint(20) UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT
);


CREATE TABLE `vals` (
	`pk` bigint(20) UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
	`type` enum('number','string','boolean','object','array','null','raw') NOT NULL,
	`val` text NOT NULL
);

