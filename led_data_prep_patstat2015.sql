\d led_litigated

drop table led_litigated_t211;
select t.* 
into led_litigated_t211
from led_litigated l, led_t211 t
where l.appln_id = t.appln_id;

select min(publn_year) from led_litigated;
-- 1989

select max(publn_year) from led_litigated;
-- 2011

select count(*) from led_litigated_t211;
--98
\d led_litigated_t211

-- find sub ipc of H01L 33/**
\d tls209_appln_ipc

SELECT distinct ipc_class_symbol
FROM tls209_appln_ipc
WHERE ipc_class_symbol like 'H01L% 33/%'
ORDER by 1;

-- 33 IPC in LED

SELECT *
INTO led_t209
FROM tls209_appln_ipc 
WHERE  ipc_class_symbol like 'H01L% 33/%';
-- 366 006

-- selecting all other ipc that h01l33 patents are in.
SELECT *
INTO led_t209_whole
FROM tls209_appln_ipc 
WHERE  appln_id in (select appln_id from led_t209); 
-- 778 179

-- selecting only patent of inventions
SELECT *
INTO led_t201
FROM tls201_appln
WHERE ipr_type = 'PI'
and appln_id in (SELECT distinct(appln_id) FROM led_t209);

select count(*) from led_t201;
-- 167 627

CREATE UNIQUE index t201_appln_id_indx on led_t201(appln_id);

drop table led_t211;
SELECT *
INTO led_t211
FROM tls211_pat_publn
WHERE appln_id in (SELECT distinct(appln_id) FROM led_t201)
and publn_auth in ('US', 'JP', 'EP')
and publn_first_grant = 1;

CREATE UNIQUE index t211_appln_id_indx on led_t211(appln_id);

drop table led_t211_complete;
SELECT *
INTO led_t211_complete
FROM tls211_pat_publn
WHERE appln_id in (SELECT distinct(appln_id) FROM led_t201)
and publn_first_grant = 1;

CREATE UNIQUE index t211_appln_id_comp_indx on led_t211_complete(appln_id);

SELECT count(*) FROM led_t211;
-- 42 351

SELECT count(*) FROM led_t211 WHERE publn_auth = 'US';
--  22 705
SELECT count(*) FROM led_t211 WHERE publn_auth = 'JP';
--  17 163
SELECT count(*) FROM led_t211 WHERE publn_auth = 'EP';
-- 2 483

-- keeping only US.
delete from led_t211 where publn_auth <> 'US';

SELECT count(*) FROM led_t211;
-- 22 705

SELECT count(*) FROM led_t211_complete;
-- 70 838

-- backwd citation table
drop table led_t212_bckwd;
SELECT *
into led_t212_bckwd
FROM tls212_citation
WHERE pat_publn_id in (SELECT distinct(pat_publn_id) FROM led_t211);
--   567 965

-- forward citation table
drop table led_t212_fwd;
SELECT *
into led_t212_fwd
FROM tls212_citation
WHERE cited_pat_publn_id in (SELECT distinct(pat_publn_id) FROM led_t211);
-- 276 364


SELECT count(distinct(publn_nr)) 
FROM led_t211 
WHERE publn_auth = 'US';
-- 22 705

SELECT count(distinct(publn_nr)) 
FROM led_t211 
WHERE publn_auth = 'US' 
and publn_date > '2000-01-01';
-- 19 389

SELECT min(publn_date) FROM led_t211;
-- 1954-07-13

SELECT max(publn_date) FROM led_t211;
--  2015-07-28

drop table led_t227;
SELECT *
into led_t227
FROM tls227_pers_publn 
WHERE pat_publn_id in (SELECT distinct(pat_publn_id) FROM led_t211);
--  89 617

drop table led_t906;
SELECT *
into led_t906
FROM tls906_person
WHERE person_id in (select distinct(person_id) from led_t227);
-- 34 957

-- creating a new field in led_t211 which designates litigated patent.
alter table led_t211 add litigated smallint;

update led_t211 set litigated = 1
where appln_id in (select appln_id from led_litigated_t211); 

update led_t211 set litigated = 0 where litigated is null;


select count(*) from led_t211;
-- 22 705

-- fwd citation
\d led_t212_fwd

-- cited_appln_id is wrong WRONG!
select count(*) from tls212_citation where cited_appln_id = 0;
-- 194 699 446

drop table fwd_citation;
SELECT ltf212.pat_publn_id as citing_publn_id, t211.appln_id as citing_appln_id,
       ltf212.cited_pat_publn_id 
       INTO temp fwd_citation
FROM led_t212_fwd ltf212, tls211_pat_publn t211
WHERE ltf212.pat_publn_id = t211.pat_publn_id;
-- 276 364

SELECT f.*, t.appln_id as cited_pat_appln_id
INTO temp fwd_citation_2
FROM fwd_citation f, tls211_pat_publn t
WHERE f.cited_pat_publn_id = t.pat_publn_id;
-- 276 364

\d fwd_citation_2

drop table fwd_citation_3;
select f.*, t.appln_filing_date as citing_appln_filing_date
INTO temp fwd_citation_3
FROM fwd_citation_2 f, tls201_appln t
WHERE f.citing_appln_id = t.appln_id;

drop table led_fwd_citation;
select f.*, t.appln_filing_date as cited_appln_filing_date
INTO led_fwd_citation
FROM fwd_citation_3 f, tls201_appln t
WHERE f.cited_pat_appln_id = t.appln_id;

-- backwd citation
drop table led_backward_citation;
SELECT pat_publn_id, count(distinct(cited_pat_publn_id))
into led_backward_citation
FROM led_t212_bckwd
GROUP by pat_publn_id;

-- non-pat lit citaion (sci work citation)
drop table led_sci_citation;
SELECT pat_publn_id, count(distinct(npl_publn_id))
into led_sci_citation
FROM led_t212_bckwd
WHERE npl_citn_seq_nr <> 0
GROUP by pat_publn_id;

-- pat_citation_backward
drop table led_pat_citation_bckwd;
SELECT pat_publn_id, count(distinct(cited_pat_publn_id))
into led_pat_citation_bckwd
FROM led_t212_bckwd
WHERE pat_citn_seq_nr <> 0
GROUP by pat_publn_id;

-- ipc_count
drop table led_ipc_count;
SELECT appln_id, count(ipc_class_symbol)
INTO led_ipc_count
FROM led_t209_whole
GROUP by appln_id;

-- number of inventors
drop table led_inventors;
select pat_publn_id, count(person_id)
into led_inventors
from led_t227
where invt_seq_nr <> 0
group by pat_publn_id;

-- number of patentee
drop table led_patentees;
select pat_publn_id, count(person_id)
into led_patentees
from led_t227
where applt_seq_nr <> 0
group by pat_publn_id;

---------------------------------------
-- searching nakamura patent
select * from tls211_pat_publn
where publn_nr like '%5578839%';

\d tls211_pat_publn

select * from tls227_pers_publn
where pat_publn_id = 300748022;

select * from tls906_person
where person_id in (select person_id from tls227_pers_publn
where pat_publn_id = 300748022);

-- family size of the patent
drop table led_docdb_family;
select pat_publn_id, docdb_family_size
into led_docdb_family
from led_t201 t201, led_t211 t211
where t201.appln_id = t211.appln_id; 

-- patentee country
drop table led_patentee_ctry;
select distinct l.pat_publn_id, t906.person_ctry_code
into led_patentee_ctry
from tls906_person t906, led_t227 l
where t906.person_id = l.person_id
and l.applt_seq_nr <> 0
order by 1, 2;

drop table led_ctry_count;
select pat_publn_id, count(person_ctry_code) as count_ctry
into led_ctry_count
from led_patentee_ctry
group by 1;


-- =======================

drop table led_t221;
SELECT *
into led_t221
FROM tls221_inpadoc_prs t221
WHERE appln_id in (SELECT distinct(appln_id) FROM led_t211);
-- 62 036

drop table led_t802;
SELECT *
into led_t802
FROM tls802_legal_event_code
WHERE lec_id in (SELECT distinct(lec_id) FROM led_t221);


drop table led_legal;
select t211.pat_publn_id, t211.appln_id, t802.*
into led_legal
from led_t211 t211, led_t221 t221, led_t802 t802
where t211.appln_id = t221.appln_id
and t221.lec_id = t802.lec_id;
-- 68 240

\d led_legal

select distinct impact from led_legal;

alter table led_legal add impact_num smallint;

update led_legal
set impact_num = 1
where impact = '+';

update led_legal
set impact_num = 0
where impact = ' ';

update led_legal
set impact_num = -1
where impact = '-';


\d

-- check an example https://patents.google.com/patent/US7479448?oq=7479448

select * from led_t212_bckwd where pat_publn_id = 55766519;

select * from led_t227 where pat_publn_id = 55766519;

select * from led_t906 where person_id = 5217703;

select * from led_t906 where person_id = 6449517;
