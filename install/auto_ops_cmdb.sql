/*
 Navicat Premium Data Transfer

 Source Server         : 10.0.0.63
 Source Server Type    : MySQL
 Source Server Version : 50734
 Source Host           : 10.0.0.63:3306
 Source Schema         : auto_ops_cmdb

 Target Server Type    : MySQL
 Target Server Version : 50734
 File Encoding         : 65001

 Date: 29/12/2021 16:18:57
*/

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ----------------------------
-- Table structure for alarm
-- ----------------------------
DROP TABLE IF EXISTS `alarm`;
CREATE TABLE `alarm`  (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `content` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `date` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `is_send` tinyint(1) NOT NULL,
  `send_role` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL,
  `is_log` tinyint(1) NULL DEFAULT NULL,
  PRIMARY KEY (`ID`) USING BTREE,
  INDEX `ID`(`ID`) USING BTREE,
  INDEX `is_send`(`date`, `is_send`) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 1 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Records of alarm
-- ----------------------------

-- ----------------------------
-- Table structure for alarm_legacy
-- ----------------------------
DROP TABLE IF EXISTS `alarm_legacy`;
CREATE TABLE `alarm_legacy`  (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `host` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `keyword` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `qun` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT 'legacy',
  PRIMARY KEY (`ID`) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 1 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Records of alarm_legacy
-- ----------------------------

-- ----------------------------
-- Table structure for assets_area
-- ----------------------------
DROP TABLE IF EXISTS `assets_area`;
CREATE TABLE `assets_area`  (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `subnet` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL,
  `bandwidth` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL,
  `contact` varchar(16) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL,
  `phone` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL,
  `address` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL,
  `contract_date` varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `describe` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL,
  `needed_cabinet` tinyint(1) NOT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `name`(`name`) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 2 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Records of assets_area
-- ----------------------------
INSERT INTO `assets_area` VALUES (1, '演示办公', NULL, NULL, NULL, NULL, NULL, '1', '', 1);

-- ----------------------------
-- Table structure for assets_asset
-- ----------------------------
DROP TABLE IF EXISTS `assets_asset`;
CREATE TABLE `assets_asset`  (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `ip_url` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `ipadd` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL,
  `sn` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL,
  `asset_type` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `status` smallint(6) NOT NULL,
  `cpu` varchar(60) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL,
  `disk` varchar(60) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL,
  `memory` varchar(60) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL,
  `cabinet` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL,
  `uhight` int(11) NULL DEFAULT NULL,
  `railnum` int(11) NULL DEFAULT NULL,
  `put_shelf_time` date NOT NULL,
  `ctime` datetime(6) NULL DEFAULT NULL,
  `utime` datetime(6) NULL DEFAULT NULL,
  `comment` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `area_id` int(11) NULL DEFAULT NULL,
  `manufacturer_id` int(11) NULL DEFAULT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `hostname`(`ip_url`) USING BTREE,
  UNIQUE INDEX `ipadd`(`ipadd`) USING BTREE,
  UNIQUE INDEX `sn`(`sn`) USING BTREE,
  INDEX `assets_asset_area_id_779a1370_fk_assets_area_id`(`area_id`) USING BTREE,
  INDEX `assets_asset_manufacturer_id_30ff9133_fk_assets_manufacturer_id`(`manufacturer_id`) USING BTREE,
  CONSTRAINT `assets_asset_area_id_779a1370_fk_assets_area_id` FOREIGN KEY (`area_id`) REFERENCES `assets_area` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `assets_asset_manufacturer_id_30ff9133_fk_assets_manufacturer_id` FOREIGN KEY (`manufacturer_id`) REFERENCES `assets_manufacturer` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE = InnoDB AUTO_INCREMENT = 2 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Records of assets_asset
-- ----------------------------

-- ----------------------------
-- Table structure for assets_manufacturer
-- ----------------------------
DROP TABLE IF EXISTS `assets_manufacturer`;
CREATE TABLE `assets_manufacturer`  (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `contact` varchar(16) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL,
  `phone` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL,
  `describe` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `name`(`name`) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 1 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Records of assets_manufacturer
-- ----------------------------

-- ----------------------------
-- Table structure for auth_group
-- ----------------------------
DROP TABLE IF EXISTS `auth_group`;
CREATE TABLE `auth_group`  (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `name`(`name`) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 1 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Records of auth_group
-- ----------------------------

-- ----------------------------
-- Table structure for auth_group_permissions
-- ----------------------------
DROP TABLE IF EXISTS `auth_group_permissions`;
CREATE TABLE `auth_group_permissions`  (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `group_id` int(11) NOT NULL,
  `permission_id` int(11) NOT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `auth_group_permissions_group_id_permission_id_0cd325b0_uniq`(`group_id`, `permission_id`) USING BTREE,
  INDEX `auth_group_permissio_permission_id_84c5c92e_fk_auth_perm`(`permission_id`) USING BTREE,
  CONSTRAINT `auth_group_permissio_permission_id_84c5c92e_fk_auth_perm` FOREIGN KEY (`permission_id`) REFERENCES `auth_permission` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `auth_group_permissions_group_id_b120cbf9_fk_auth_group_id` FOREIGN KEY (`group_id`) REFERENCES `auth_group` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE = InnoDB AUTO_INCREMENT = 1 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Records of auth_group_permissions
-- ----------------------------

-- ----------------------------
-- Table structure for auth_permission
-- ----------------------------
DROP TABLE IF EXISTS `auth_permission`;
CREATE TABLE `auth_permission`  (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `content_type_id` int(11) NOT NULL,
  `codename` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `auth_permission_content_type_id_codename_01ab375a_uniq`(`content_type_id`, `codename`) USING BTREE,
  CONSTRAINT `auth_permission_content_type_id_2f476e4b_fk_django_co` FOREIGN KEY (`content_type_id`) REFERENCES `django_content_type` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE = InnoDB AUTO_INCREMENT = 65 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Records of auth_permission
-- ----------------------------
INSERT INTO `auth_permission` VALUES (1, 'Can add log entry', 1, 'add_logentry');
INSERT INTO `auth_permission` VALUES (2, 'Can change log entry', 1, 'change_logentry');
INSERT INTO `auth_permission` VALUES (3, 'Can delete log entry', 1, 'delete_logentry');
INSERT INTO `auth_permission` VALUES (4, 'Can view log entry', 1, 'view_logentry');
INSERT INTO `auth_permission` VALUES (5, 'Can add permission', 2, 'add_permission');
INSERT INTO `auth_permission` VALUES (6, 'Can change permission', 2, 'change_permission');
INSERT INTO `auth_permission` VALUES (7, 'Can delete permission', 2, 'delete_permission');
INSERT INTO `auth_permission` VALUES (8, 'Can view permission', 2, 'view_permission');
INSERT INTO `auth_permission` VALUES (9, 'Can add group', 3, 'add_group');
INSERT INTO `auth_permission` VALUES (10, 'Can change group', 3, 'change_group');
INSERT INTO `auth_permission` VALUES (11, 'Can delete group', 3, 'delete_group');
INSERT INTO `auth_permission` VALUES (12, 'Can view group', 3, 'view_group');
INSERT INTO `auth_permission` VALUES (13, 'Can add user', 4, 'add_user');
INSERT INTO `auth_permission` VALUES (14, 'Can change user', 4, 'change_user');
INSERT INTO `auth_permission` VALUES (15, 'Can delete user', 4, 'delete_user');
INSERT INTO `auth_permission` VALUES (16, 'Can view user', 4, 'view_user');
INSERT INTO `auth_permission` VALUES (17, 'Can add content type', 5, 'add_contenttype');
INSERT INTO `auth_permission` VALUES (18, 'Can change content type', 5, 'change_contenttype');
INSERT INTO `auth_permission` VALUES (19, 'Can delete content type', 5, 'delete_contenttype');
INSERT INTO `auth_permission` VALUES (20, 'Can view content type', 5, 'view_contenttype');
INSERT INTO `auth_permission` VALUES (21, 'Can add session', 6, 'add_session');
INSERT INTO `auth_permission` VALUES (22, 'Can change session', 6, 'change_session');
INSERT INTO `auth_permission` VALUES (23, 'Can delete session', 6, 'delete_session');
INSERT INTO `auth_permission` VALUES (24, 'Can view session', 6, 'view_session');
INSERT INTO `auth_permission` VALUES (25, 'Can add area', 7, 'add_area');
INSERT INTO `auth_permission` VALUES (26, 'Can change area', 7, 'change_area');
INSERT INTO `auth_permission` VALUES (27, 'Can delete area', 7, 'delete_area');
INSERT INTO `auth_permission` VALUES (28, 'Can view area', 7, 'view_area');
INSERT INTO `auth_permission` VALUES (29, 'Can add manufacturer', 8, 'add_manufacturer');
INSERT INTO `auth_permission` VALUES (30, 'Can change manufacturer', 8, 'change_manufacturer');
INSERT INTO `auth_permission` VALUES (31, 'Can delete manufacturer', 8, 'delete_manufacturer');
INSERT INTO `auth_permission` VALUES (32, 'Can view manufacturer', 8, 'view_manufacturer');
INSERT INTO `auth_permission` VALUES (33, 'Can add asset', 9, 'add_asset');
INSERT INTO `auth_permission` VALUES (34, 'Can change asset', 9, 'change_asset');
INSERT INTO `auth_permission` VALUES (35, 'Can delete asset', 9, 'delete_asset');
INSERT INTO `auth_permission` VALUES (36, 'Can view asset', 9, 'view_asset');
INSERT INTO `auth_permission` VALUES (37, 'Can add main', 10, 'add_main');
INSERT INTO `auth_permission` VALUES (38, 'Can change main', 10, 'change_main');
INSERT INTO `auth_permission` VALUES (39, 'Can delete main', 10, 'delete_main');
INSERT INTO `auth_permission` VALUES (40, 'Can view main', 10, 'view_main');
INSERT INTO `auth_permission` VALUES (41, 'Can add domain', 11, 'add_domain');
INSERT INTO `auth_permission` VALUES (42, 'Can change domain', 11, 'change_domain');
INSERT INTO `auth_permission` VALUES (43, 'Can delete domain', 11, 'delete_domain');
INSERT INTO `auth_permission` VALUES (44, 'Can view domain', 11, 'view_domain');
INSERT INTO `auth_permission` VALUES (45, 'Can add log_alarm', 13, 'add_log_alarm');
INSERT INTO `auth_permission` VALUES (46, 'Can change log_alarm', 13, 'change_log_alarm');
INSERT INTO `auth_permission` VALUES (47, 'Can delete log_alarm', 13, 'delete_log_alarm');
INSERT INTO `auth_permission` VALUES (48, 'Can view log_alarm', 13, 'view_log_alarm');
INSERT INTO `auth_permission` VALUES (49, 'Can add alarm', 12, 'add_alarm');
INSERT INTO `auth_permission` VALUES (50, 'Can change alarm', 12, 'change_alarm');
INSERT INTO `auth_permission` VALUES (51, 'Can delete alarm', 12, 'delete_alarm');
INSERT INTO `auth_permission` VALUES (52, 'Can view alarm', 12, 'view_alarm');
INSERT INTO `auth_permission` VALUES (53, 'Can add alarm', 14, 'add_alarm');
INSERT INTO `auth_permission` VALUES (54, 'Can change alarm', 14, 'change_alarm');
INSERT INTO `auth_permission` VALUES (55, 'Can delete alarm', 14, 'delete_alarm');
INSERT INTO `auth_permission` VALUES (56, 'Can view alarm', 14, 'view_alarm');
INSERT INTO `auth_permission` VALUES (57, 'Can add ci_cd_info', 15, 'add_ci_cd_info');
INSERT INTO `auth_permission` VALUES (58, 'Can change ci_cd_info', 15, 'change_ci_cd_info');
INSERT INTO `auth_permission` VALUES (59, 'Can delete ci_cd_info', 15, 'delete_ci_cd_info');
INSERT INTO `auth_permission` VALUES (60, 'Can view ci_cd_info', 15, 'view_ci_cd_info');
INSERT INTO `auth_permission` VALUES (61, 'Can add info', 15, 'add_info');
INSERT INTO `auth_permission` VALUES (62, 'Can change info', 15, 'change_info');
INSERT INTO `auth_permission` VALUES (63, 'Can delete info', 15, 'delete_info');
INSERT INTO `auth_permission` VALUES (64, 'Can view info', 15, 'view_info');

-- ----------------------------
-- Table structure for auth_user
-- ----------------------------
DROP TABLE IF EXISTS `auth_user`;
CREATE TABLE `auth_user`  (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `password` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `last_login` datetime(6) NULL DEFAULT NULL,
  `is_superuser` tinyint(1) NOT NULL,
  `username` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `first_name` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `last_name` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `email` varchar(254) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `is_staff` tinyint(1) NOT NULL,
  `is_active` tinyint(1) NOT NULL,
  `date_joined` datetime(6) NOT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `username`(`username`) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 3 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Records of auth_user
-- ----------------------------
INSERT INTO `auth_user` VALUES (1, 'pbkdf2_sha256$260000$t52lop8mDywBYiGGv9x239$r4lMYwwH8cw0bh1JaUcIypTS1+0aY22QE59HsBOdl5w=', '2021-12-29 07:33:21.216046', 1, 'admin', '', '', 'admin@qq.com', 1, 1, '2021-05-24 08:55:18.947330');

-- ----------------------------
-- Table structure for auth_user_groups
-- ----------------------------
DROP TABLE IF EXISTS `auth_user_groups`;
CREATE TABLE `auth_user_groups`  (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `group_id` int(11) NOT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `auth_user_groups_user_id_group_id_94350c0c_uniq`(`user_id`, `group_id`) USING BTREE,
  INDEX `auth_user_groups_group_id_97559544_fk_auth_group_id`(`group_id`) USING BTREE,
  CONSTRAINT `auth_user_groups_group_id_97559544_fk_auth_group_id` FOREIGN KEY (`group_id`) REFERENCES `auth_group` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `auth_user_groups_user_id_6a12ed8b_fk_auth_user_id` FOREIGN KEY (`user_id`) REFERENCES `auth_user` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE = InnoDB AUTO_INCREMENT = 1 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Records of auth_user_groups
-- ----------------------------

-- ----------------------------
-- Table structure for auth_user_user_permissions
-- ----------------------------
DROP TABLE IF EXISTS `auth_user_user_permissions`;
CREATE TABLE `auth_user_user_permissions`  (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `permission_id` int(11) NOT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `auth_user_user_permissions_user_id_permission_id_14a6b632_uniq`(`user_id`, `permission_id`) USING BTREE,
  INDEX `auth_user_user_permi_permission_id_1fbb5f2c_fk_auth_perm`(`permission_id`) USING BTREE,
  CONSTRAINT `auth_user_user_permi_permission_id_1fbb5f2c_fk_auth_perm` FOREIGN KEY (`permission_id`) REFERENCES `auth_permission` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `auth_user_user_permissions_user_id_a95ead1b_fk_auth_user_id` FOREIGN KEY (`user_id`) REFERENCES `auth_user` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE = InnoDB AUTO_INCREMENT = 4 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Records of auth_user_user_permissions
-- ----------------------------

-- ----------------------------
-- Table structure for ci_cd_info
-- ----------------------------
DROP TABLE IF EXISTS `ci_cd_info`;
CREATE TABLE `ci_cd_info`  (
  `requestid` int(11) NOT NULL,
  `xiang_mu` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `date` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `jar_pack` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `jar_url` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `status` int(11) NOT NULL,
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (`ID`) USING BTREE,
  UNIQUE INDEX `ci_cd_info_requestid_4c6a2a61_uniq`(`requestid`, `jar_pack`) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 1 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Records of ci_cd_info
-- ----------------------------

-- ----------------------------
-- Table structure for django_admin_log
-- ----------------------------
DROP TABLE IF EXISTS `django_admin_log`;
CREATE TABLE `django_admin_log`  (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `action_time` datetime(6) NOT NULL,
  `object_id` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL,
  `object_repr` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `action_flag` smallint(5) UNSIGNED NOT NULL,
  `change_message` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `content_type_id` int(11) NULL DEFAULT NULL,
  `user_id` int(11) NOT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `django_admin_log_content_type_id_c4bce8eb_fk_django_co`(`content_type_id`) USING BTREE,
  INDEX `django_admin_log_user_id_c564eba6_fk_auth_user_id`(`user_id`) USING BTREE,
  CONSTRAINT `django_admin_log_content_type_id_c4bce8eb_fk_django_co` FOREIGN KEY (`content_type_id`) REFERENCES `django_content_type` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `django_admin_log_user_id_c564eba6_fk_auth_user_id` FOREIGN KEY (`user_id`) REFERENCES `auth_user` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE = InnoDB AUTO_INCREMENT = 1 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Records of django_admin_log
-- ----------------------------

-- ----------------------------
-- Table structure for django_content_type
-- ----------------------------
DROP TABLE IF EXISTS `django_content_type`;
CREATE TABLE `django_content_type`  (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `app_label` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `model` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `django_content_type_app_label_model_76bd3d3b_uniq`(`app_label`, `model`) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 17 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Records of django_content_type
-- ----------------------------
INSERT INTO `django_content_type` VALUES (1, 'admin', 'logentry');
INSERT INTO `django_content_type` VALUES (12, 'alarm', 'alarm');
INSERT INTO `django_content_type` VALUES (13, 'alarm', 'log_alarm');
INSERT INTO `django_content_type` VALUES (7, 'assets', 'area');
INSERT INTO `django_content_type` VALUES (9, 'assets', 'asset');
INSERT INTO `django_content_type` VALUES (8, 'assets', 'manufacturer');
INSERT INTO `django_content_type` VALUES (3, 'auth', 'group');
INSERT INTO `django_content_type` VALUES (2, 'auth', 'permission');
INSERT INTO `django_content_type` VALUES (4, 'auth', 'user');
INSERT INTO `django_content_type` VALUES (16, 'ci_cd', 'ci_cd_info');
INSERT INTO `django_content_type` VALUES (15, 'ci_cd', 'info');
INSERT INTO `django_content_type` VALUES (5, 'contenttypes', 'contenttype');
INSERT INTO `django_content_type` VALUES (11, 'dns', 'domain');
INSERT INTO `django_content_type` VALUES (10, 'dns', 'main');
INSERT INTO `django_content_type` VALUES (14, 'log', 'alarm');
INSERT INTO `django_content_type` VALUES (6, 'sessions', 'session');

-- ----------------------------
-- Table structure for django_migrations
-- ----------------------------
DROP TABLE IF EXISTS `django_migrations`;
CREATE TABLE `django_migrations`  (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `app` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `applied` datetime(6) NOT NULL,
  PRIMARY KEY (`id`) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 81 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Records of django_migrations
-- ----------------------------
INSERT INTO `django_migrations` VALUES (1, 'contenttypes', '0001_initial', '2021-05-24 08:54:54.491084');
INSERT INTO `django_migrations` VALUES (2, 'auth', '0001_initial', '2021-05-24 08:54:55.649411');
INSERT INTO `django_migrations` VALUES (3, 'admin', '0001_initial', '2021-05-24 08:54:55.878296');
INSERT INTO `django_migrations` VALUES (4, 'admin', '0002_logentry_remove_auto_add', '2021-05-24 08:54:55.895430');
INSERT INTO `django_migrations` VALUES (5, 'admin', '0003_logentry_add_action_flag_choices', '2021-05-24 08:54:55.911568');
INSERT INTO `django_migrations` VALUES (6, 'assets', '0001_initial', '2021-05-24 08:54:56.518505');
INSERT INTO `django_migrations` VALUES (7, 'assets', '0002_belong', '2021-05-24 08:54:56.591866');
INSERT INTO `django_migrations` VALUES (8, 'assets', '0003_asset_belong', '2021-05-24 08:54:56.669928');
INSERT INTO `django_migrations` VALUES (9, 'assets', '0004_remove_asset_belong', '2021-05-24 08:54:56.807572');
INSERT INTO `django_migrations` VALUES (10, 'assets', '0005_delete_belong', '2021-05-24 08:54:56.843522');
INSERT INTO `django_migrations` VALUES (11, 'contenttypes', '0002_remove_content_type_name', '2021-05-24 08:54:56.970360');
INSERT INTO `django_migrations` VALUES (12, 'auth', '0002_alter_permission_name_max_length', '2021-05-24 08:54:57.089410');
INSERT INTO `django_migrations` VALUES (13, 'auth', '0003_alter_user_email_max_length', '2021-05-24 08:54:57.118560');
INSERT INTO `django_migrations` VALUES (14, 'auth', '0004_alter_user_username_opts', '2021-05-24 08:54:57.138880');
INSERT INTO `django_migrations` VALUES (15, 'auth', '0005_alter_user_last_login_null', '2021-05-24 08:54:57.195871');
INSERT INTO `django_migrations` VALUES (16, 'auth', '0006_require_contenttypes_0002', '2021-05-24 08:54:57.210739');
INSERT INTO `django_migrations` VALUES (17, 'auth', '0007_alter_validators_add_error_messages', '2021-05-24 08:54:57.228729');
INSERT INTO `django_migrations` VALUES (18, 'auth', '0008_alter_user_username_max_length', '2021-05-24 08:54:57.312511');
INSERT INTO `django_migrations` VALUES (19, 'auth', '0009_alter_user_last_name_max_length', '2021-05-24 08:54:57.404523');
INSERT INTO `django_migrations` VALUES (20, 'auth', '0010_alter_group_name_max_length', '2021-05-24 08:54:57.445793');
INSERT INTO `django_migrations` VALUES (21, 'auth', '0011_update_proxy_permissions', '2021-05-24 08:54:57.490263');
INSERT INTO `django_migrations` VALUES (22, 'auth', '0012_alter_user_first_name_max_length', '2021-05-24 08:54:57.574456');
INSERT INTO `django_migrations` VALUES (23, 'dns', '0001_initial', '2021-05-24 08:54:57.811262');
INSERT INTO `django_migrations` VALUES (24, 'dns', '0002_auto_20191001_2333', '2021-05-24 08:54:57.862453');
INSERT INTO `django_migrations` VALUES (25, 'sessions', '0001_initial', '2021-05-24 08:54:57.964499');
INSERT INTO `django_migrations` VALUES (73, 'ci_cd', '0001_initial', '2021-07-20 06:00:40.185052');
INSERT INTO `django_migrations` VALUES (74, 'ci_cd', '0002_ci_cd_info_a_id', '2021-07-20 06:00:40.282328');
INSERT INTO `django_migrations` VALUES (75, 'ci_cd', '0003_auto_20210720_1145', '2021-07-20 06:00:40.464159');
INSERT INTO `django_migrations` VALUES (76, 'ci_cd', '0004_alter_ci_cd_info_id', '2021-07-20 06:00:40.474729');
INSERT INTO `django_migrations` VALUES (77, 'ci_cd', '0005_rename_ci_cd_info_info', '2021-07-20 06:00:40.508284');
INSERT INTO `django_migrations` VALUES (78, 'ci_cd', '0006_alter_info_id', '2021-07-20 06:00:40.582414');
INSERT INTO `django_migrations` VALUES (79, 'ci_cd', '0007_alter_info_requestid', '2021-07-20 06:00:40.605983');
INSERT INTO `django_migrations` VALUES (80, 'ci_cd', '0008_alter_info_requestid', '2021-07-20 06:00:40.615999');

-- ----------------------------
-- Table structure for django_session
-- ----------------------------
DROP TABLE IF EXISTS `django_session`;
CREATE TABLE `django_session`  (
  `session_key` varchar(40) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `session_data` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `expire_date` datetime(6) NOT NULL,
  PRIMARY KEY (`session_key`) USING BTREE,
  INDEX `django_session_expire_date_a5c62663`(`expire_date`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Records of django_session
-- ----------------------------
INSERT INTO `django_session` VALUES ('03d9p1jdrma03o3afq0z0byhpls4f42z', '.eJyNVMuSmzAQ_BUX57UR6AU-5pJTviDeco3QYNg14JJELlv-90jgBBbj9Z5aaIbunhlJH9ERelcde4vmWOtoHyXRy3xPQfGObQjoN2hP3a7oWmdqtQspu1vU7n51Gs8_brmfCCqwlf-bq0xzn54wSpHIlKSUcI2plEwkLJOEFSnmuchJTkErphmjHCFRRZYXIFggbbDtref6_XGI4HI5RPuNX1iLzh6iF79uocFx93DoM0_hgSFID1JBEoARMebWvpAxtwS7KWELpqjqPzhGm1CPDfEg9gUvKzHwCiLK8c_enOfG4gG-I4m1DsGEkPT6slmqipQRD7zgGIBSCCD1I1WD8ED0DK1uwLwvVemKKqdZGkAp8Z1aG2j7EgrXGzSPStbaoLVb1XV3Dtj19fNGMlr6P2vdNVC3K7MeGuGBEf31rMNqc7Pi4GSfT1upoe8l54uadWvjuaHJtljr5MzhPc_E8szqpCKX3eKLboU7uNIrIRn1kAtOhvqADVAkDyYWbvHWVjWe9dNuSZ5mw2Gl8p7tH9ny7Hib8bQ_1ZOvtHEu4L-wYI91tqWpw-O0pncyXX9ZCCZk2dFs6eBn7apeLQgr5y52H8en2iH697GJwbnwFJq4aLS6N6iCw9OMarKQXF-j61_fn7Up:1lw1bS:ud7vZp83M3P1Ejr0pP0yIoP3eXXMj26ngHWW-__E4_s', '2021-07-07 12:03:34.178455');
INSERT INTO `django_session` VALUES ('2muy2lgrcjuec8r9mnkkowdw4ubgllu8', '.eJxVjDsOwyAQBe9CHSE-i4GU6X0Ga2FXwUkEkrGrKHePLblI2jcz7y0m3NYybZ2XaSZxFVpcfreE-cn1APTAem8yt7ouc5KHIk_a5diIX7fT_Tso2MteuxTI7boGa1l5o4xVjth4D4OG4BVkwzEOUUWLlIAArGPUKYeYcQDx-QK9cjcK:1ll6Nc:HGlf8rfzE_LMs9NWIbfK3X6_ILwNTZUkyPZgSjARSRQ', '2021-06-07 08:56:08.803160');
INSERT INTO `django_session` VALUES ('3xpcou1qj2pvg2kmz7zgsy4jr4g4qzoc', '.eJyNVNuSoyAQ_ZWUz7koAuo87vt-wTqVaqCJ7nhJge7LVP59QTMVh2hNng50Q58-p8XP6AzjUJ1Hi-Zcq-gtItF-GRMgP7DzCfUXukt_lH03mFoc_ZHjPWuPv3uFza_72W8FKrCVu13EKsmVKjQSGmOilcwFCsJRqiImhLKUodQa0kIWXIJiUuYUsyLJgKeI0hdtsRutq_Xns4zgei2jt51bWIuDLaO9W3fQ4hwtyzFXlDqgCJmDTEDigcZ8Pls7IfNZDXan4QBGVvU_nLOt12N93pMFdQl3wEnq61KNvi6PuZ5vjqZZNnaa4BVKrJVPJnFMbvtdyMqdbQ6YZOigyLPCq-GIG6wGYYO0gU61YD5C1nSFlaU58SAEf0VrC92oQQ6jQbMlWSmD1h5E3z91QG_v3wPJ3NJj1g2YdmXUjFLwkxF8mkyW-h3jPJ_mL56c8KvdvaEBLvbHmS8JAuW-pdOisWe_azuESvnahBkyT6VV9gJj01_Oq6zr2h7UWWgyC012T3fFY57R1H95nMVTX0AnkMmGbP_4D7aqsVE_2psxkn89qadqX8VCG1ybp0f8oadY8XZJ4HYo6TbPQZva_9PW-C6mH68BYRKHjua39-j2H3dHpKs:1mzr2I:Rkb1JTF9FZWPrdz_mbbyUp7KoNuJkqZ4F93p7br_OF8', '2022-01-05 02:07:22.152096');
INSERT INTO `django_session` VALUES ('566svw611lsageafsixt11w409bxieiy', '.eJyNVMtyozAQ_BUXZz-E0ANy3Hu-IKRcIzQYNjxcEuwl5X9fCZyCYCj71JJm1N0zg_gOztB3xbm3aM6lDt6CMNjPzxRkX9j4gP4LzaU9Zm3TmVIdfcrxHrXH91Zj9eee-4ugAFu421zFmrv0kEUREkkJjQjXSKVkImSxJCyjmCQiIUkEWjHNWMQRQpXFSQaCedIam946ro_vNIDrNQ3edm5hLXY2DfZu3UCN42ma9rGjcMAQpAOpIPTAiBhzS1fImJuD3eVwAJMV5T8co7Wvx_q4F1vwUuFA0Mjzshw9ryAiH2_2ppobOw3wiiSW2gdDQuhtv1uqCsqIA55xdJDEMvHVCMQNVYOwIVpBo2swX0vVaEWVRzH1oJR4pdYamj6HrOsNmq2StTZo7UG17YMDdvv8fRCOlqZZV2DqlVFzxsBPRolhMjLyOy5EPMxfPXTCr3Z3Qx1c7NOZzwUWlXtLp5mxyb1YGyNH7vlyLV-grdrLeUb9rIBJWi47yZeddO9zpZFCssh_XoKTwRewAbJwY5r-hR9sUWKln_ZQchr_vJsHth-yZRuczdN0PtWTrPR2LuB2mLFtnUNuSv_jWtO7mLa_LgRDsuxofPsMbv8B2JmaMg:1lwfcE:xTyDkqvHzuoAu2vlf8-vBL5SMOCCgeOr5BC9in3SiJs', '2021-07-09 06:47:02.724499');
INSERT INTO `django_session` VALUES ('62plhdd09uuighvkdh57ap6fqcuspwkq', '.eJyNVMtyozAQ_BUXZz-E0ANy3Hu-IKRcIzQYNjxcEuwl5X9fCZyCYCj71JJm1N0zg_gOztB3xbm3aM6lDt6CMNjPzxRkX9j4gP4LzaU9Zm3TmVIdfcrxHrXH91Zj9eee-4ugAFu421zFmrv0kEUREkkJjQjXSKVkImSxJCyjmCQiIUkEWjHNWMQRQpXFSQaCedIam946ro_vNIDrNQ3edm5hLXY2DfZu3UCN42ma9rGjcMAQpAOpIPTAiBhzS1fImJuD3eVwAJMV5T8co7Wvx_q4F1vwUuFA0Mjzshw9ryAiH2_2ppobOw3wiiSW2gdDQuhtv1uqCsqIA55xdJDEMvHVCMQNVYOwIVpBo2swX0vVaEWVRzH1oJR4pdYamj6HrOsNmq2StTZo7UG17YMDdvv8fRCOlqZZV2DqlVFzxsBPRolhMjLyOy5EPMxfPXTCr3Z3Qx1c7NOZzwUWlXtLp5mxyb1YGyNH7vlyLV-grdrLeUb9rIBJWi47yZeddO9zpZFCssh_XoKTwRewAbJwY5r-hR9sUWKln_ZQchr_vJsHth-yZRuczdN0PtWTrPR2LuB2mLFtnUNuSv_jWtO7mLa_LgRDsuxofPsMbv8B2JmaMg:1m8CJh:MR5j6eU45NJ0Amj1n1_AQPp5Xz0ecuht4QB2mToaTwM', '2021-08-10 01:55:33.666091');
INSERT INTO `django_session` VALUES ('ecunvv1hn79b0e37azw7ec3gbqk6rwlv', '.eJxVjDsOwyAQBe9CHSE-i4GU6X0Ga2FXwUkEkrGrKHePLblI2jcz7y0m3NYybZ2XaSZxFVpcfreE-cn1APTAem8yt7ouc5KHIk_a5diIX7fT_Tso2MteuxTI7boGa1l5o4xVjth4D4OG4BVkwzEOUUWLlIAArGPUKYeYcQDx-QK9cjcK:1lnugO:u9bVbcmYpergiFiZRkyzzxuAXn3UbVArTP5vzJPYQDw', '2021-06-15 03:03:08.774157');
INSERT INTO `django_session` VALUES ('hll5cbq6l6ktv4huitdbb53d3cxaxdnm', '.eJylVMuSmzAQ_BUXZz-EnrDH3PMF8RY1SINNlodLgly2_O-RwBt7ZZx1KhdGaIbu6Wmh96SAcTgWo0Nb1CZ5SdJkfbtXgn7DLiTMT-gO_Vb33WDrchtKtpes237vDTbfLrWfAI7gjv5rUWZG-PKUM4ZEUUIZEQapUlymPFOEa4p5LnOSMzAlN5wzgZCWOss1SB5AW-xG57F-vO8TOJ32ycvKL5zDwe2TtV930OK8u9-PmYfwgSMoH1QJaQicyLm29kLm2grcqoINWH2sf-GcbYMeF_KBLMKl0gdJWcDlFQZcSWQ1fzna5rax3RSeocTahGRKCD2vVzGrpJz4ILRAH_JM5UGNRHzAahEekDbQmRbsW8zKFlgFy2gIZSmf0dpCN1agh9GifSTZGIvObcq-v-uAn18_b6RzS1evG7DtgtWCcwjOlHJyRrHwJqTMJv_Lu0mE1erS0AAH96XntwSR8tDS7qax-3nXboiVyiWHBYpAVRn1BGPTH4pF1mVtV2oVD1lEQ9Z1oc3CkCUj0x-EaKaTYcKbQML-f7ozlqI8--spmzrbTc-i7qr-Hwaex6qz-Gj5C2tJtOIs_G9SkMkN4FPQ6QPucOVt3LHGxnwpWwmafVwkd2gfYLH5vs3ddf-PnjRdOFG3BME4zR_zbCpbh5t8ie9g-_EUE9Jooik5vybn38qA7IU:1n2Tc9:5348vTkoivK5XrBpd1fDIkssrIMhcNWhqykCqnmIuMk', '2022-01-12 07:43:13.770587');
INSERT INTO `django_session` VALUES ('jzi84wbv2jjwaa3hmya6epq5r7i5axbo', '.eJyNVMtyozAQ_BUXZz-E3uS493xBSLkGNBg2BlwS7CXlf1_JOAsmsM6phWbU3TMj8Rkdoe_KY-_QHisTvURxtJ3uZZB_YBMC5jc0p3aft01nq2wfUvb3qNu_tgbPv-65DwQluNKfFpk2wqfHnDEkihLKiDBIleIy5loRnlNMEpmQhIHJuOGcCYQ4y3WSg-SBtMamd57r7TON4HJJo5eNXziHnUujrV83UOOwm6a99hQeOILyoDKIA3Aih9zKFzLkFuA2BezA5mX1B4doHepxIR7EZrxUepCUBV5eYOCVRBbDyd6ep8YON_iJJFYmBGNC6HW7matKyokHkQv0kGiVhGok4oqqRVgRPUNjarAfc1W2oCqYpgGyTP6k1hqavoC86y3atZKNsejcLmvbbw749f1xIx4s_Zu1aWuomoVZC2Zu06Vc_3_WYbW5W-ng5J5Oe8r8WLNp3GFqaLQtlzopTRicRAMLPCPLM6ujipp3S8y6Fd7gQq-k4ixcISnChdIZ8Bvk8crEwiveubLCs3naLSWo_nob39i-yOZ3x9s8jPtjPclCG6cC_gtzvq6zK2wVfk5Leifb9peZYEzmHdXX9-j6FzM_kJ8:1lwERk:p9hESrDV94n4qbIRgdObF-4CIHzBe1knkrrxa34Ird8', '2021-07-08 01:46:24.064246');
INSERT INTO `django_session` VALUES ('si52fli7bp7bxd8q8iug0jnm6jk14u7y', '.eJyNVMtyozAQ_BUXZz-E0ANy3Hu-IKRcIzQYNjxcEuwl5X9fCZyCYCj71JJm1N0zg_gOztB3xbm3aM6lDt6CMNjPzxRkX9j4gP4LzaU9Zm3TmVIdfcrxHrXH91Zj9eee-4ugAFu421zFmrv0kEUREkkJjQjXSKVkImSxJCyjmCQiIUkEWjHNWMQRQpXFSQaCedIam946ro_vNIDrNQ3edm5hLXY2DfZu3UCN42ma9rGjcMAQpAOpIPTAiBhzS1fImJuD3eVwAJMV5T8co7Wvx_q4F1vwUuFA0Mjzshw9ryAiH2_2ppobOw3wiiSW2gdDQuhtv1uqCsqIA55xdJDEMvHVCMQNVYOwIVpBo2swX0vVaEWVRzH1oJR4pdYamj6HrOsNmq2StTZo7UG17YMDdvv8fRCOlqZZV2DqlVFzxsBPRolhMjLyOy5EPMxfPXTCr3Z3Qx1c7NOZzwUWlXtLp5mxyb1YGyNH7vlyLV-grdrLeUb9rIBJWi47yZeddO9zpZFCssh_XoKTwRewAbJwY5r-hR9sUWKln_ZQchr_vJsHth-yZRuczdN0PtWTrPR2LuB2mLFtnUNuSv_jWtO7mLa_LgRDsuxofPsMbv8B2JmaMg:1lwhO2:lDFlHGs2ohiEoej7Y40rau2FCd7EZgDi9St_CvabCIg', '2021-07-09 08:40:30.515018');
INSERT INTO `django_session` VALUES ('w5ofo9ks54hm8t3u2jl84zr24edvunom', '.eJyNVMtyozAQ_BUXZz-E0ANy3Hu-IKRcIzQYNjxcEuwl5X9fCZyCYCj71JJm1N0zg_gOztB3xbm3aM6lDt6CMNjPzxRkX9j4gP4LzaU9Zm3TmVIdfcrxHrXH91Zj9eee-4ugAFu421zFmrv0kEUREkkJjQjXSKVkImSxJCyjmCQiIUkEWjHNWMQRQpXFSQaCedIam946ro_vNIDrNQ3edm5hLXY2DfZu3UCN42ma9rGjcMAQpAOpIPTAiBhzS1fImJuD3eVwAJMV5T8co7Wvx_q4F1vwUuFA0Mjzshw9ryAiH2_2ppobOw3wiiSW2gdDQuhtv1uqCsqIA55xdJDEMvHVCMQNVYOwIVpBo2swX0vVaEWVRzH1oJR4pdYamj6HrOsNmq2StTZo7UG17YMDdvv8fRCOlqZZV2DqlVFzxsBPRolhMjLyOy5EPMxfPXTCr3Z3Qx1c7NOZzwUWlXtLp5mxyb1YGyNH7vlyLV-grdrLeUb9rIBJWi47yZeddO9zpZFCssh_XoKTwRewAbJwY5r-hR9sUWKln_ZQchr_vJsHth-yZRuczdN0PtWTrPR2LuB2mLFtnUNuSv_jWtO7mLa_LgRDsuxofPsMbv8B2JmaMg:1lwh9j:hyJyqysfRodl9kAO7SZPWMoeIllHjnNgfaQBAu9AJ-E', '2021-07-09 08:25:43.868076');
INSERT INTO `django_session` VALUES ('yexwb7lr5pkg4zf876bh72faidso6jqk', '.eJyNVMtyozAQ_BUXZz-E0ANy3Hu-IKRcIzQYNjxcEuwl5X9fCZyCYCj71JJm1N0zg_gOztB3xbm3aM6lDt6CMNjPzxRkX9j4gP4LzaU9Zm3TmVIdfcrxHrXH91Zj9eee-4ugAFu421zFmrv0kEUREkkJjQjXSKVkImSxJCyjmCQiIUkEWjHNWMQRQpXFSQaCedIam946ro_vNIDrNQ3edm5hLXY2DfZu3UCN42ma9rGjcMAQpAOpIPTAiBhzS1fImJuD3eVwAJMV5T8co7Wvx_q4F1vwUuFA0Mjzshw9ryAiH2_2ppobOw3wiiSW2gdDQuhtv1uqCsqIA55xdJDEMvHVCMQNVYOwIVpBo2swX0vVaEWVRzH1oJR4pdYamj6HrOsNmq2StTZo7UG17YMDdvv8fRCOlqZZV2DqlVFzxsBPRolhMjLyOy5EPMxfPXTCr3Z3Qx1c7NOZzwUWlXtLp5mxyb1YGyNH7vlyLV-grdrLeUb9rIBJWi47yZeddO9zpZFCssh_XoKTwRewAbJwY5r-hR9sUWKln_ZQchr_vJsHth-yZRuczdN0PtWTrPR2LuB2mLFtnUNuSv_jWtO7mLa_LgRDsuxofPsMbv8B2JmaMg:1mZtuA:_gWSXMqUVX39ph3Bsn35BQ4JShsAdQByZqaL8rxGc0k', '2021-10-25 11:55:42.390871');
INSERT INTO `django_session` VALUES ('z692ye97uowzrl0lnr4o8zm6ncig3ng3', '.eJyNVMtyozAQ_BUXZz-E3uS493xBSLkGNBg2BlwS7CXlf1_JOAsmsM6phWbU3TMj8Rkdoe_KY-_QHisTvURxtJ3uZZB_YBMC5jc0p3aft01nq2wfUvb3qNu_tgbPv-65DwQluNKfFpk2wqfHnDEkihLKiDBIleIy5loRnlNMEpmQhIHJuOGcCYQ4y3WSg-SBtMamd57r7TON4HJJo5eNXziHnUujrV83UOOwm6a99hQeOILyoDKIA3Aih9zKFzLkFuA2BezA5mX1B4doHepxIR7EZrxUepCUBV5eYOCVRBbDyd6ep8YON_iJJFYmBGNC6HW7matKyokHkQv0kGiVhGok4oqqRVgRPUNjarAfc1W2oCqYpgGyTP6k1hqavoC86y3atZKNsejcLmvbbw749f1xIx4s_Zu1aWuomoVZC2Zu06Vc_3_WYbW5W-ng5J5Oe8r8WLNp3GFqaLQtlzopTRicRAMLPCPLM6ujipp3S8y6Fd7gQq-k4ixcISnChdIZ8Bvk8crEwiveubLCs3naLSWo_nob39i-yOZ3x9s8jPtjPclCG6cC_gtzvq6zK2wVfk5Leifb9peZYEzmHdXX9-j6FzM_kJ8:1lwF4L:F61qPJfTiRDNrqhyw4bf6S8-HoSFWonYAnqWBYk4Sug', '2021-07-08 02:26:17.983766');

-- ----------------------------
-- Table structure for dns_domain
-- ----------------------------
DROP TABLE IF EXISTS `dns_domain`;
CREATE TABLE `dns_domain`  (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `host_record` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `record_type` smallint(6) NOT NULL,
  `record_value` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL,
  `domain_describe` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL,
  `publish` datetime(6) NOT NULL,
  `mod_date` date NOT NULL,
  `domain_id` int(11) NULL DEFAULT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `dns_domain_domain_id_aab24eb8_fk_dns_main_id`(`domain_id`) USING BTREE,
  CONSTRAINT `dns_domain_domain_id_aab24eb8_fk_dns_main_id` FOREIGN KEY (`domain_id`) REFERENCES `dns_main` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE = InnoDB AUTO_INCREMENT = 1 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Records of dns_domain
-- ----------------------------

-- ----------------------------
-- Table structure for dns_main
-- ----------------------------
DROP TABLE IF EXISTS `dns_main`;
CREATE TABLE `dns_main`  (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `describe` varchar(60) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL,
  PRIMARY KEY (`id`) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 1 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Records of dns_main
-- ----------------------------

-- ----------------------------
-- Table structure for log_alarm
-- ----------------------------
DROP TABLE IF EXISTS `log_alarm`;
CREATE TABLE `log_alarm`  (
  `ID` int(11) NOT NULL,
  `log` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  INDEX `ID`(`ID`) USING BTREE,
  CONSTRAINT `ID` FOREIGN KEY (`ID`) REFERENCES `alarm` (`ID`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Records of log_alarm
-- ----------------------------

-- ----------------------------
-- Table structure for wechat_at
-- ----------------------------
DROP TABLE IF EXISTS `wechat_at`;
CREATE TABLE `wechat_at`  (
  `userid` int(11) NOT NULL AUTO_INCREMENT COMMENT '用户ID',
  `username` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL COMMENT '用户名',
  `groupid` int(11) NOT NULL COMMENT '组ID',
  `groupname` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL COMMENT '组名',
  `match_id` int(11) NOT NULL COMMENT '正则匹配ID,为wechat_at_match_varchar 的外键\r\n',
  PRIMARY KEY (`userid`) USING BTREE,
  INDEX `match_id`(`match_id`) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 1 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Records of wechat_at
-- ----------------------------

-- ----------------------------
-- Table structure for wechat_at_match_varchar
-- ----------------------------
DROP TABLE IF EXISTS `wechat_at_match_varchar`;
CREATE TABLE `wechat_at_match_varchar`  (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `match_id` int(11) NOT NULL,
  `match_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `match_varchar` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  PRIMARY KEY (`ID`) USING BTREE,
  INDEX `match_id`(`match_id`) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 1 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Records of wechat_at_match_varchar
-- ----------------------------

SET FOREIGN_KEY_CHECKS = 1;
