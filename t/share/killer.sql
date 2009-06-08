-- Correct for the total lack of indexes in the MW 1.13 SQLite schema
--
-- Unique indexes need to be handled with INSERT SELECT since just running
-- the CREATE INDEX statement will fail if there are duplicate values.
--
-- Ignore duplicates, several tables will have them (e.g. bug 16966) but in 
-- most cases it's harmless to discard them. We'll keep the old tables with 
-- duplicates in so that the user can recover them in case of disaster.

--------------------------------------------------------------------------------
-- Drop temporary tables from aborted runs
--------------------------------------------------------------------------------

DROP TABLE IF EXISTS /*_*/user_tmp;
DROP TABLE IF EXISTS /*_*/user_groups_tmp;
DROP TABLE IF EXISTS /*_*/page_tmp;
DROP TABLE IF EXISTS /*_*/revision_tmp;
DROP TABLE IF EXISTS /*_*/pagelinks_tmp;
DROP TABLE IF EXISTS /*_*/templatelinks_tmp;
DROP TABLE IF EXISTS /*_*/imagelinks_tmp;
DROP TABLE IF EXISTS /*_*/categorylinks_tmp;
DROP TABLE IF EXISTS /*_*/category_tmp;
DROP TABLE IF EXISTS /*_*/langlinks_tmp;
DROP TABLE IF EXISTS /*_*/site_stats_tmp;
DROP TABLE IF EXISTS /*_*/ipblocks_tmp;
DROP TABLE IF EXISTS /*_*/watchlist_tmp;
DROP TABLE IF EXISTS /*_*/math_tmp;
DROP TABLE IF EXISTS /*_*/interwiki_tmp;
DROP TABLE IF EXISTS /*_*/page_restrictions_tmp;
DROP TABLE IF EXISTS /*_*/protected_titles_tmp;
DROP TABLE IF EXISTS /*_*/page_props_tmp;

--------------------------------------------------------------------------------
-- Create new tables
--------------------------------------------------------------------------------

CREATE TABLE /*_*/user_tmp (
  user_id int unsigned NOT NULL PRIMARY KEY ,
  user_name varchar(255)  NOT NULL default '',
  user_real_name varchar(255)  NOT NULL default '',
  user_password varchar NOT NULL,
  user_newpassword varchar NOT NULL,
  user_newpass_time varchar(14),
  user_email varchar NOT NULL,
  user_options blob NOT NULL,
  user_touched varchar(14) NOT NULL default '',
  user_token varchar(32) NOT NULL default '',
  user_email_authenticated varchar(14),
  user_email_token varchar(32),
  user_email_token_expires varchar(14),
  user_registration varchar(14),
  user_editcount int
);
CREATE UNIQUE INDEX /*i*/user_name ON /*_*/user_tmp (user_name);
CREATE INDEX /*i*/user_email_token ON /*_*/user_tmp (user_email_token);


CREATE TABLE /*_*/user_groups_tmp (
  ug_user int unsigned NOT NULL default 0,
  ug_group varchar(16) NOT NULL default ''
);

CREATE UNIQUE INDEX /*i*/ug_user_group ON /*_*/user_groups_tmp (ug_user,ug_group);
CREATE INDEX /*i*/ug_group ON /*_*/user_groups_tmp (ug_group);

CREATE TABLE /*_*/page_tmp (
  page_id int unsigned NOT NULL PRIMARY KEY ,
  page_namespace int NOT NULL,
  page_title varchar(255)  NOT NULL,
  page_restrictions tinyblob NOT NULL,
  page_counter bigint unsigned NOT NULL default 0,
  page_is_redirect tinyint unsigned NOT NULL default 0,
  page_is_new tinyint unsigned NOT NULL default 0,
  page_random real unsigned NOT NULL,
  page_touched varchar(14) NOT NULL default '',
  page_latest int unsigned NOT NULL,
  page_len int unsigned NOT NULL
);

CREATE UNIQUE INDEX /*i*/name_title ON /*_*/page_tmp (page_namespace,page_title);
CREATE INDEX /*i*/page_random ON /*_*/page_tmp (page_random);
CREATE INDEX /*i*/page_len ON /*_*/page_tmp (page_len);


CREATE TABLE /*_*/revision_tmp (
  rev_id int unsigned NOT NULL PRIMARY KEY ,
  rev_page int unsigned NOT NULL,
  rev_text_id int unsigned NOT NULL,
  rev_comment tinyblob NOT NULL,
  rev_user int unsigned NOT NULL default 0,
  rev_user_text varchar(255)  NOT NULL default '',
  rev_timestamp varchar(14) NOT NULL default '',
  rev_minor_edit tinyint unsigned NOT NULL default 0,
  rev_deleted tinyint unsigned NOT NULL default 0,
  rev_len int unsigned,
  rev_parent_id int unsigned default NULL
);
CREATE UNIQUE INDEX /*i*/rev_page_id ON /*_*/revision_tmp (rev_page, rev_id);
CREATE INDEX /*i*/rev_timestamp ON /*_*/revision_tmp (rev_timestamp);
CREATE INDEX /*i*/page_timestamp ON /*_*/revision_tmp (rev_page,rev_timestamp);
CREATE INDEX /*i*/user_timestamp ON /*_*/revision_tmp (rev_user,rev_timestamp);
CREATE INDEX /*i*/usertext_timestamp ON /*_*/revision_tmp (rev_user_text,rev_timestamp);

CREATE TABLE /*_*/pagelinks_tmp (
  pl_from int unsigned NOT NULL default 0,
  pl_namespace int NOT NULL default 0,
  pl_title varchar(255)  NOT NULL default ''
);

CREATE UNIQUE INDEX /*i*/pl_from ON /*_*/pagelinks_tmp (pl_from,pl_namespace,pl_title);
CREATE INDEX /*i*/pl_namespace_title ON /*_*/pagelinks_tmp (pl_namespace,pl_title,pl_from);


CREATE TABLE /*_*/templatelinks_tmp (
  tl_from int unsigned NOT NULL default 0,
  tl_namespace int NOT NULL default 0,
  tl_title varchar(255)  NOT NULL default ''
);

CREATE UNIQUE INDEX /*i*/tl_from ON /*_*/templatelinks_tmp (tl_from,tl_namespace,tl_title);
CREATE INDEX /*i*/tl_namespace_title ON /*_*/templatelinks_tmp (tl_namespace,tl_title,tl_from);


CREATE TABLE /*_*/imagelinks_tmp (
  il_from int unsigned NOT NULL default 0,
  il_to varchar(255)  NOT NULL default ''
) /*$wgDBTableOptions*/;
CREATE UNIQUE INDEX /*i*/il_from ON /*_*/imagelinks_tmp (il_from,il_to);
CREATE INDEX /*i*/il_to ON /*_*/imagelinks_tmp (il_to,il_from);


CREATE TABLE /*_*/categorylinks_tmp (
  cl_from int unsigned NOT NULL default 0,
  cl_to varchar(255)  NOT NULL default '',
  cl_sortkey varchar(70)  NOT NULL default '',
  cl_timestamp timestamp NOT NULL
);
CREATE UNIQUE INDEX /*i*/cl_from ON /*_*/categorylinks_tmp (cl_from,cl_to);
CREATE INDEX /*i*/cl_sortkey ON /*_*/categorylinks_tmp (cl_to,cl_sortkey,cl_from);
CREATE INDEX /*i*/cl_timestamp ON /*_*/categorylinks_tmp (cl_to,cl_timestamp);


CREATE TABLE /*_*/category_tmp (
  cat_id int unsigned NOT NULL PRIMARY KEY ,
  cat_title varchar(255)  NOT NULL,
  cat_pages int signed NOT NULL default 0,
  cat_subcats int signed NOT NULL default 0,
  cat_files int signed NOT NULL default 0,
  cat_hidden tinyint unsigned NOT NULL default 0
);
CREATE UNIQUE INDEX /*i*/cat_title ON /*_*/category_tmp (cat_title);
CREATE INDEX /*i*/cat_pages ON /*_*/category_tmp (cat_pages);

CREATE TABLE /*_*/langlinks_tmp (
  ll_from int unsigned NOT NULL default 0,
  ll_lang varchar(20) NOT NULL default '',
  ll_title varchar(255)  NOT NULL default ''
);

CREATE UNIQUE INDEX /*i*/ll_from ON /*_*/langlinks_tmp (ll_from, ll_lang);
CREATE INDEX /*i*/ll_lang_title ON /*_*/langlinks_tmp (ll_lang, ll_title);


CREATE TABLE /*_*/site_stats_tmp (
  ss_row_id int unsigned NOT NULL,
  ss_total_views bigint unsigned default 0,
  ss_total_edits bigint unsigned default 0,
  ss_good_articles bigint unsigned default 0,
  ss_total_pages bigint default '-1',
  ss_users bigint default '-1',
  ss_active_users bigint default '-1',
  ss_admins int default '-1',
  ss_images int default 0
);
CREATE UNIQUE INDEX /*i*/ss_row_id ON /*_*/site_stats_tmp (ss_row_id);


CREATE TABLE /*_*/ipblocks_tmp (
  ipb_id int NOT NULL PRIMARY KEY ,
  ipb_address tinyblob NOT NULL,
  ipb_user int unsigned NOT NULL default 0,
  ipb_by int unsigned NOT NULL default 0,
  ipb_by_text varchar(255) NOT NULL default '',
  ipb_reason tinyblob NOT NULL,
  ipb_timestamp varchar(14) NOT NULL default '',
  ipb_auto bool NOT NULL default 0,

  -- If set to 1, block applies only to logged-out users
  ipb_anon_only bool NOT NULL default 0,
  ipb_create_account bool NOT NULL default 1,
  ipb_enable_autoblock bool NOT NULL default '1',
  ipb_expiry varchar(14) NOT NULL default '',
  ipb_range_start tinyblob NOT NULL,
  ipb_range_end tinyblob NOT NULL,
  ipb_deleted bool NOT NULL default 0,
  ipb_block_email bool NOT NULL default 0,
  ipb_allow_usertalk bool NOT NULL default 0
);


CREATE TABLE /*_*/watchlist_tmp (
  wl_user int unsigned NOT NULL,
  wl_namespace int NOT NULL default 0,
  wl_title varchar(255)  NOT NULL default '',
  wl_notificationtimestamp varchar(14)
);

CREATE UNIQUE INDEX /*i*/wl_user_namespace_title ON /*_*/watchlist_tmp (wl_user, wl_namespace, wl_title);
CREATE INDEX /*i*/namespace_title ON /*_*/watchlist_tmp (wl_namespace, wl_title);


CREATE TABLE /*_*/math_tmp (
  math_inputhash varchar(16) NOT NULL,
  math_outputhash varchar(16) NOT NULL,
  math_html_conservativeness tinyint NOT NULL,
  math_html text,
  math_mathml text  
);

CREATE UNIQUE INDEX /*i*/math_inputhash ON /*_*/math_tmp (math_inputhash);


CREATE TABLE /*_*/interwiki_tmp (
  iw_prefix varchar(32) NOT NULL,
  iw_url blob NOT NULL,
  iw_local bool NOT NULL,
  iw_trans tinyint NOT NULL default 0
);

CREATE UNIQUE INDEX /*i*/iw_prefix ON /*_*/interwiki_tmp (iw_prefix);


CREATE TABLE /*_*/page_restrictions_tmp (
  pr_page int NOT NULL,
  pr_type varchar(60) NOT NULL,
  pr_level varchar(60) NOT NULL,
  pr_cascade tinyint NOT NULL,
  pr_user int NULL,
  pr_expiry varchar(14) NULL,
  pr_id int unsigned NOT NULL PRIMARY KEY 
);

CREATE UNIQUE INDEX /*i*/pr_pagetype ON /*_*/page_restrictions_tmp (pr_page,pr_type);
CREATE UNIQUE INDEX /*i*/pr_typelevel ON /*_*/page_restrictions_tmp (pr_type,pr_level);
CREATE UNIQUE INDEX /*i*/pr_level ON /*_*/page_restrictions_tmp (pr_level);
CREATE UNIQUE INDEX /*i*/pr_cascade ON /*_*/page_restrictions_tmp (pr_cascade);

CREATE TABLE /*_*/protected_titles_tmp (
  pt_namespace int NOT NULL,
  pt_title varchar(255)  NOT NULL,
  pt_user int unsigned NOT NULL,
  pt_reason tinyblob,
  pt_timestamp varchar(14) NOT NULL,
  pt_expiry varchar(14) NOT NULL default '',
  pt_create_perm varchar(60) NOT NULL
);
CREATE UNIQUE INDEX /*i*/pt_namespace_title ON /*_*/protected_titles_tmp (pt_namespace,pt_title);
CREATE INDEX /*i*/pt_timestamp ON /*_*/protected_titles_tmp (pt_timestamp);

CREATE TABLE /*_*/page_props_tmp (
  pp_page int NOT NULL,
  pp_propname varchar(60) NOT NULL,
  pp_value blob NOT NULL
);
CREATE UNIQUE INDEX /*i*/pp_page_propname ON /*_*/page_props_tmp (pp_page,pp_propname);



DROP TABLE IF EXISTS /*_*/searchindex;
CREATE TABLE /*_*/searchindex (
  si_page int unsigned NOT NULL,
  si_title varchar(255) NOT NULL default '',
  si_text mediumtext NOT NULL
);
CREATE UNIQUE INDEX /*i*/si_page ON /*_*/searchindex (si_page);
CREATE INDEX /*i*/si_title ON /*_*/searchindex (si_title);
CREATE INDEX /*i*/si_text ON /*_*/searchindex (si_text);

DROP TABLE IF EXISTS /*_*/transcache;
CREATE TABLE /*_*/transcache (
  tc_url varchar(255) NOT NULL,
  tc_contents text,
  tc_time int NOT NULL
) /*$wgDBTableOptions*/;
CREATE UNIQUE INDEX /*i*/tc_url_idx ON /*_*/transcache (tc_url);

DROP TABLE IF EXISTS /*_*/querycache_info;
CREATE TABLE /*_*/querycache_info (
  qci_type varchar(32) NOT NULL default '',
  qci_timestamp varchar(14) NOT NULL default '19700101000000'
) /*$wgDBTableOptions*/;
CREATE UNIQUE INDEX /*i*/qci_type ON /*_*/querycache_info (qci_type);

