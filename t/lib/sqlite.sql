-- 
-- Created by SQL::Translator::Producer::SQLite
-- Created on Fri Mar 24 07:13:26 2006
-- 
BEGIN TRANSACTION;

--
-- Table: serialized
--
CREATE TABLE serialized (
  id INTEGER PRIMARY KEY NOT NULL,
  serialized text NOT NULL
);

--
-- Table: employees_adjacencylist
--
CREATE TABLE employees_adjacencylist (
  employee_id INTEGER PRIMARY KEY NOT NULL,
  parent_id integer NOT NULL,
  position integer,
  name varchar(100)
);

--
-- Table: liner_notes
--
CREATE TABLE liner_notes (
  liner_id INTEGER PRIMARY KEY NOT NULL,
  notes varchar(100) NOT NULL
);

--
-- Table: cd_to_producer
--
CREATE TABLE cd_to_producer (
  cd integer NOT NULL,
  producer integer NOT NULL,
  PRIMARY KEY (cd, producer)
);

--
-- Table: artist
--
CREATE TABLE artist (
  artistid INTEGER PRIMARY KEY NOT NULL,
  name varchar(100)
);

--
-- Table: self_ref_alias
--
CREATE TABLE self_ref_alias (
  self_ref integer NOT NULL,
  alias integer NOT NULL,
  PRIMARY KEY (self_ref, alias)
);

--
-- Table: cd
--
CREATE TABLE cd (
  cdid INTEGER PRIMARY KEY NOT NULL,
  artist integer NOT NULL,
  title varchar(100) NOT NULL,
  year varchar(100) NOT NULL
);

--
-- Table: track
--
CREATE TABLE track (
  trackid INTEGER PRIMARY KEY NOT NULL,
  cd integer NOT NULL,
  position integer NOT NULL,
  title varchar(100) NOT NULL
);

--
-- Table: self_ref
--
CREATE TABLE self_ref (
  id INTEGER PRIMARY KEY NOT NULL,
  name varchar(100) NOT NULL
);

--
-- Table: tags
--
CREATE TABLE tags (
  tagid INTEGER PRIMARY KEY NOT NULL,
  cd integer NOT NULL,
  tag varchar(100) NOT NULL
);

--
-- Table: treelike
--
CREATE TABLE treelike (
  id INTEGER PRIMARY KEY NOT NULL,
  parent integer NOT NULL,
  name varchar(100) NOT NULL
);

--
-- Table: twokeys
--
CREATE TABLE twokeys (
  artist integer NOT NULL,
  cd integer NOT NULL,
  PRIMARY KEY (artist, cd)
);

--
-- Table: employees_positional
--
CREATE TABLE employees_positional (
  employee_id INTEGER PRIMARY KEY NOT NULL,
  position integer NOT NULL,
  group_id integer,
  name varchar(100)
);

--
-- Table: fourkeys
--
CREATE TABLE fourkeys (
  foo integer NOT NULL,
  bar integer NOT NULL,
  hello integer NOT NULL,
  goodbye integer NOT NULL,
  PRIMARY KEY (foo, bar, hello, goodbye)
);

--
-- Table: artist_undirected_map
--
CREATE TABLE artist_undirected_map (
  id1 integer NOT NULL,
  id2 integer NOT NULL,
  PRIMARY KEY (id1, id2)
);

--
-- Table: producer
--
CREATE TABLE producer (
  producerid INTEGER PRIMARY KEY NOT NULL,
  name varchar(100) NOT NULL
);

--
-- Table: onekey
--
CREATE TABLE onekey (
  id INTEGER PRIMARY KEY NOT NULL,
  artist integer NOT NULL,
  cd integer NOT NULL
);

COMMIT;
