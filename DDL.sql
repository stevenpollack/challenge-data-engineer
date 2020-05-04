drop database if exists iplytics;
create database iplytics;
use iplytics;

######### Patents & Patent Authors: ##############

drop table if exists patents;
CREATE TABLE patents (
    title VARCHAR(200) NOT NULL,
    publication_nr VARCHAR(40) NOT NULL,
    family_id VARCHAR(40),
    applicant VARCHAR(40) NOT NULL,
    patent_office VARCHAR(20) NOT NULL,
    publication_date DATE NOT NULL,
    kind_type VARCHAR(20),
    granted BOOLEAN,
    lapsed BOOLEAN,
    family_size INT,
    market_coverage FLOAT,
    technical_relevance FLOAT,
    PRIMARY KEY (publication_nr),
    INDEX (applicant)
)  ENGINE=INNODB;

#create index applicant on patents (applicant);
CREATE TABLE prior_art (
  patent_nr VARCHAR(40) NOT NULL,
  cited_patent_nr VARCHAR(40) NOT NULL,
  INDEX (patent_nr),
  FOREIGN KEY (cited_patent_nr)
    REFERENCES patents (publication_nr)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=INNODB;

drop table if exists patent_inventors;
CREATE TABLE patent_inventors (
    publication_nr VARCHAR(40) NOT NULL,
    inventor VARCHAR(100) NOT NULL,
    FOREIGN KEY (publication_nr)
        REFERENCES patents (publication_nr)
        ON DELETE CASCADE ON UPDATE CASCADE
)  ENGINE=INNODB;


insert into patents
values ("SIGNAL INDICATION FOR FLEXIBLE NEW RADIO (NR) LONG TERM EVOLUTION (LTE) COEXISTENCE | INDICATION DE SIGNAL POUR COEXISTENCE SOUPLE NOUVELLE RADIO (NR) / ÉVOLUTION À LONG TERME (LTE)",
"WO2018127074A1","20180705US20180192404A1","Huawei Technologies Co. Ltd.", "WO",DATE("2018-07-12"),
"Patent Application",FALSE,FALSE,NULL,2,1.0648804,0),
 ("METHOD, DEVICE AND SYSTEM FOR REGRESSING TO LONG TERM EVOLUTION (LTE) NETWORK | PROCÉDÉ, DISPOSITIF ET SYSTÈME DE RÉGRESSION À UN RÉSEAU D'ÉVOLUTION À LONG TERME (LTE)",
"WO2014067166A1","20140508WO2014067166A1","Huawei Technologies Co., Ltd.","WO",DATE("2014-05-08"),"
Patent Application",FALSE,FALSE,NULL,2,1.3537302,0);

INSERT INTO iplytics.patent_inventors
 VALUES ("WO2018127074A1", "MAAREF", "Amine"),
 ("WO2018127074A1", "Au", "Kelvin Kar Kin"),
 ("WO2018127074A1", UPPER("Ma"), UPPER("Jianglei")),
 ("WO2014067166A1", "SHU", "Lin"),
 ("WO2014067166A1",  "WU", "Xiaobo")
 ;
 
 # test join
 
SELECT patents.publication_nr, family_id, inventors, publication_date
FROM patents INNER JOIN
    (SELECT publication_nr,
            GROUP_CONCAT(inventor
                ORDER BY inventor ASC
                SEPARATOR ' | ') AS inventors
    FROM
        (SELECT publication_nr,
            UPPER(CONCAT(last_name, ', ', first_name)) AS inventor
		 FROM patent_inventors) AS t1
    GROUP BY publication_nr) AS t2
ON (patents.publication_nr = t2.publication_nr);
 
 ########### Standards & Standard Authors: ################
 
 drop table if exists standards;
 CREATE TABLE standards (
    title VARCHAR(1000) NOT NULL,
    std_doc_id VARCHAR(100) NOT NULL,
    tech_gen VARCHAR(40),
    publication_date DATE NOT NULL,
    sso VARCHAR(40) NOT NULL,
    std_proj VARCHAR(40) NOT NULL,
    version_hist VARCHAR(40) NOT NULL,
    original_doc VARCHAR(256) NOT NULL,
    PRIMARY KEY (std_doc_id),
    INDEX (std_proj)
)  ENGINE=INNODB;

drop table if exists standard_authors;
CREATE TABLE standard_authors (
    std_doc_id VARCHAR(100) NOT NULL,
    author VARCHAR(100) NOT NULL,
    FOREIGN KEY (std_doc_id)
        REFERENCES standards (std_doc_id)
        ON UPDATE CASCADE ON DELETE CASCADE
)  ENGINE=INNODB;

insert into standards values
("LTE; General Packet Radio Service (GPRS) enhancements for Evolved Universal Terrestrial Radio Access Network (E-UTRAN) access (3GPP TS 23.401 version 8.18.0 Release 8) General Packet Radio Service (GPRS) enhancements for Evolved Universal Terrestrial Radio Access Netw",
"TS 23.401 v8.18.0","4G",DATE("2013-04-05"),"ETSI",
"3GPP 3GPP-Release-8 3GPP-SA","8.18.0",
"https://www.etsi.org/deliver/etsi_ts/123400_123499/123401/08.18.00_60/ts_123401v081800p.pdf"),
("Digital cellular telecommunications system (Phase 2+) (GSM); Universal Mobile Telecommunications System (UMTS); LTE; Circuit Switched (CS) fallback in Evolved Packet System (EPS); Stage 2 (3GPP TS 23.272 version 15.0.0 Release 15) Circuit Switched (CS) fallback in Evolved Packet System (EPS); Stage 2",
"TS 23.272 v15.0.0", "4G, 3G, 2G", DATE("2018-07-26"),"ETSI",
"3GPP 3GPP-Release-15 3GPP-SA","15.0.0", 
"https://www.etsi.org/deliver/etsi_ts/123200_123299/123272/15.00.00_60/ts_123272v150000p.pdf");

# test join
SELECT GROUP_CONCAT(author SEPARATOR ' | ') AS authors, t1.*
FROM
    (SELECT 
        UPPER(CONCAT(last_name, ', ', first_name)) AS author, stds.*
    FROM
        standards AS stds
    INNER JOIN standard_authors AS authors
    ON (stds.std_doc_id = authors.std_doc_id)) AS t1
GROUP BY std_doc_id;

####### Declarations: ###############
drop table if exists declarations;
CREATE TABLE declarations (
    declaring_company VARCHAR(100) NOT NULL,
    declaration_date DATE NOT NULL,
    std_proj VARCHAR(100) NOT NULL,
    std_doc_id VARCHAR(100) NOT NULL,
    tech_gen VARCHAR(100) NOT NULL,
    releases VARCHAR(1000) NOT NULL,
    publication_nr VARCHAR(40) NOT NULL,
    application_nr VARCHAR(40) NOT NULL,
    PRIMARY KEY (declaration_date, std_doc_id, std_proj, publication_nr),
    CONSTRAINT FK_STD_DOC_ID FOREIGN KEY (std_doc_id)
        REFERENCES standards (std_doc_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT FK_STD_PROJ FOREIGN KEY (std_proj)
        REFERENCES standards (std_proj)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT FK_APPLICANT FOREIGN KEY (declaring_company)
        REFERENCES patents (applicant)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT FK_PUB_NR FOREIGN KEY (publication_nr)
        REFERENCES patents (publication_nr)
        ON UPDATE CASCADE ON DELETE CASCADE
)  ENGINE=INNODB;


# turn off foreign key checks for the purpose of DDL
set foreign_key_checks = 0;
set autocommit = 1;

insert into declarations values
("Apple Inc.",DATE("2017-11-03"),"3GPP","TS 36.300 v8.12.0","4G","Release 8 | Release 13 | Release 12 | Release 9 | Release 11 | Release 10 | Release 16 | Release 15 | Release 14","US8199719B2","US2009400834A"),
("Apple Inc.",DATE("2016-11-28"),"3GPP","TS 36.300 v8.12.0","4G","Release 8 | Release 13 | Release 12 | Release 9 | Release 11 | Release 10 | Release 16 | Release 15 | Release 14","US8199719B2","US2009400834A");

