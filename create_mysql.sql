create database if not exists videos;
connect videos;
create table if not exists marker (
  marker int(11) unsigned not null default 0
) ENGINE = InnoDB DEFAULT CHARSET = utf8 COLLATE = utf8_bin;
CREATE TABLE if not exists program (
  id int(11) unsigned NOT NULL AUTO_INCREMENT, 
  name varchar(32) COLLATE utf8_bin DEFAULT '', 
  PRIMARY KEY (id), 
  UNIQUE KEY program (name)
) ENGINE = InnoDB DEFAULT CHARSET = utf8 COLLATE = utf8_bin;
-- Create syntax for TABLE 'series'
CREATE TABLE if not exists series (
  id int(11) unsigned NOT NULL AUTO_INCREMENT, 
  program_id int(10) unsigned NOT NULL, 
  series_number int(3) unsigned NOT NULL, 
  max_episodes int(3) DEFAULT NULL, 
  priority int(1) NOT NULL DEFAULT 0, 
  PRIMARY KEY (id), 
  UNIQUE KEY program_id (program_id, series_number), 
  CONSTRAINT fk_program FOREIGN KEY (program_id) REFERENCES program (id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8 COLLATE = utf8_bin;

-- Create syntax for TABLE 'episode'
CREATE TABLE if not exists episode (
  id int(11) unsigned NOT NULL AUTO_INCREMENT, 
  series_id int(11) unsigned NOT NULL, 
  episode_number int(3) unsigned NOT NULL, 
  status int(2) default 0,
  host varchar(32)
  PRIMARY KEY (id), 
  UNIQUE KEY series_id (series_id, episode_number), 
  CONSTRAINT episode_ibfk_1 FOREIGN KEY (series_id) REFERENCES series (id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8 COLLATE = utf8_bin;
-- Create syntax for TABLE 'raw_file'
CREATE TABLE if not exists raw_file (
  id int(11) unsigned NOT NULL AUTO_INCREMENT, 
  name varchar(32) COLLATE utf8_bin NOT NULL, 
  k1 varchar(32) COLLATE utf8_bin NOT NULL, 
  k2 int(3) NOT NULL, 
  video_length time(3) NOT NULL, 
  last_updated datetime NOT NULL default current_timestamp(), 
  status int(2) NOT NULL, 
  PRIMARY KEY (id), 
  UNIQUE KEY name (name)
) ENGINE = InnoDB DEFAULT CHARSET = utf8 COLLATE = utf8_bin;
-- Create syntax for TABLE 'section'
CREATE TABLE if not exists section (
  id int(11) unsigned NOT NULL AUTO_INCREMENT, 
  episode_id int(11) unsigned NOT NULL, 
  section_number int(3) unsigned NOT NULL, 
  start_time time(3) NOT NULL, 
  end_time time(3) NOT NULL, 
  raw_file_id int(11) unsigned DEFAULT NULL, 
  last_updated datetime DEFAULT current_timestamp(), 
  status int(2) NOT NULL DEFAULT 0, 
  PRIMARY KEY (id), 
  UNIQUE KEY episode_id (episode_id, section_number), 
  KEY raw_file_id (raw_file_id), 
  CONSTRAINT section_ibfk_1 FOREIGN KEY (raw_file_id) REFERENCES raw_file (id)  on delete cascade,
  CONSTRAINT section_ibfk_2 FOREIGN KEY (episode_id) REFERENCES episode (id) on delete cascade
) ENGINE = InnoDB DEFAULT CHARSET = utf8 COLLATE = utf8_bin;
drop view if exists videos;
create view videos as 
select 
  a.id program_id, 
  a.name program_name, 
  b.id series_id, 
  b.series_number, 
  b.max_episodes, 
  c.id episode_id, 
  c.episode_number,
  c.status episode_status,
  d.id section_id, 
  d.section_number, 
  d.start_time, 
  d.end_time, 
  d.last_updated, 
  e.name file_name, 
  e.video_length, 
  e.status raw_status, 
  e.k1, 
  e.k2
from 
  program a 
  left outer join series b on b.program_id = a.id 
  left outer join episode c on c.series_id = b.id 
  left outer join section d on d.episode_id = c.id 
  left outer join raw_file e on e.id = d.raw_file_id;
drop view if exists segments;
create view segments as
select 
  a.name program_name, 
  b.series_number, 
  c.id episode_id, 
  c.episode_number,
  d.section_number, 
  d.start_time, 
  d.end_time,
  convert(time_to_sec(d.start_time)*1000,UNSIGNED) seg_start_ms, 
  convert(time_to_sec(d.end_time)*1000,UNSIGNED) seg_end_ms,
  e.video_length,
  convert(time_to_sec(e.video_length)*1000,UNSIGNED) raw_ms 
 from 
  program a 
  left outer join series b on b.program_id = a.id 
  left outer join episode c on c.series_id = b.id 
  left outer join section d on d.episode_id = c.id 
  left outer join raw_file e on e.id = d.raw_file_id;




drop view if exists summary;
create view summary as 
select a.name program_name, b.series_number, c.episode_number, sum(d.end_time-d.start_time) duration
 from program a
  left outer join series b on b.program_id = a.id 
  left outer join episode c on c.series_id = b.id 
  left outer join section d on d.episode_id = c.id 
group by a.name,b.series_number,c.episode_number;

drop view if exists missing;
create view missing as
select a.name program_name, b.series_number, c.seq episode_number,d.id
 from program a
  left outer join series b on b.program_id = a.id 
  left outer join seq_1_to_1000 c on 1 = 1 
  left outer join episode d on d.series_id = b.id and d.episode_number=c.seq
  where c.seq <= b.max_episodes
  and d.id is null;

drop view if exists orphan_mp4;
create view orphan_mp4 as 
select 
  a.* 
from 
  raw_file a 
  left outer join section b on a.id = b.raw_file_id 
where 
  b.raw_file_id is null;
drop view if exists durations;
create view durations as 
select 
  a.name program_name, 
  b.series_number, 
  c.episode_number,
  sum(time_to_sec(d.end_time)-time_to_sec(d.start_time)) duration
from 
  program a 
  left outer join series b on b.program_id = a.id 
  left outer join episode c on c.series_id = b.id 
  left outer join section d on d.episode_id = c.id 
  group by program_name,series_number,c.episode_number;
drop view if exists orphan_mp4;
create view orphan_mp4 as 
select 
  a.* 
from 
  raw_file a 
  left outer join section b on a.id = b.raw_file_id 
where 
  b.raw_file_id is null;

commit;
drop view if exists outliers;
create view outliers as
SELECT t1.program_name ,t1.series_number,t1.episode_number,t1.duration outlier,
       t2.valAvg  average
FROM durations t1
INNER JOIN
(
    SELECT program_name, AVG(duration) valAvg, STDDEV(duration) valStd
    FROM durations
    GROUP BY program_name
) t2
    ON t1.program_name = t2.program_name
WHERE ABS(t1.duration - t2.valAvg) > t2.valStd
and t1.program_name in (select program_name from videos where episode_status=0)
;

drop view if exists episode_status;
create view episode_status as
SELECT t1.program_name ,t1.series_number,t1.episode_number,t1.duration,
       if((ABS(t1.duration - t2.valAvg)-t2.valStd)>0,'Outlier',
        if(isnull(t1.duration),'Outlier','')) outlier
FROM durations t1
INNER JOIN
(
    SELECT program_name, AVG(duration) valAvg, STDDEV(duration) valStd
    FROM durations
    GROUP BY program_name
) t2
    ON t1.program_name = t2.program_name
WHERE  
t1.program_name in (select program_name from videos where episode_status=0)
;

DELIMITER //
create or replace trigger ai_section 
  after insert on section
  for each row
begin
  if NEW.status = 0 then
    update episode set status=0 where id=NEW.episode_id;
  end if;
end; //
DELIMITER ;

DELIMITER //
create or replace trigger au_section 
  after update on section
  for each row
begin
  if new.status = 0 then
    update episode set status=0 where id=new.episode_id;
  end if;
end; //
DELIMITER ;
DELIMITER //
create trigger bd_section
  before delete on section
  for each row
  update episode set status=0 where id=old.episode_id;
//
DELIMITER ;

