-- Create the raw input table.
CREATE TABLE IF NOT EXISTS public.gen_dep (
report_year DATE,
country_sender VARCHAR(80),
main_assignment SMALLINT,
title SMALLINT,
gender SMALLINT,
receiver_country VARCHAR(80),
country_code_sender INT,
alpha3_code_sender VARCHAR(3),
cow_code_sender INT,
sender_region INT,
gme_code_sender INT,
female_parliament_share NUMERIC(5,2),
feminist_foreign_policy_sender INT,
country_code_receiver INT,
alpha3_code_receiver VARCHAR(3),
cow_code_receiver INT,
receiver_region INT,
GME_receiver INT,
feminist_foreign_policy_receiver INT
);

-- Validate the raw input table.
SELECT *
FROM public.gen_dep
LIMIT 10;

-- Create a cleaned table without duplicate records.
DROP TABLE IF EXISTS public.gen_dep_clean;

CREATE TABLE public.gen_dep_clean AS
SELECT DISTINCT *
FROM public.gen_dep;

-- Compare the number of records before and after duplicate removal.
SELECT COUNT(*) AS raw_record_count
FROM public.gen_dep;

SELECT COUNT(*) AS clean_record_count
FROM public.gen_dep_clean;

-- Replace the raw table with the cleaned table used in the analysis.
DROP TABLE public.gen_dep;
ALTER TABLE public.gen_dep_clean RENAME TO gen_dip;

-- Use a numeric code for unknown gender values so they are preserved in joins.
UPDATE public.gen_dip
SET gender = 99
WHERE gender IS NULL;

-- Create support tables to improve readability.

-- Gender lookup table.
DROP TABLE IF EXISTS public.gender_type;

CREATE TABLE public.gender_type (
code SMALLINT PRIMARY KEY,
genderlabel VARCHAR(20) NOT NULL
);

INSERT INTO public.gender_type (code, genderlabel)
VALUES
(1, 'Female'),
(0, 'Male'),
(99, 'Unknown');

-- Region lookup table.
DROP TABLE IF EXISTS public.region_code;

CREATE TABLE public.region_code (
code SMALLINT PRIMARY KEY,
region_name VARCHAR(80) NOT NULL
);

INSERT INTO public.region_code (code, region_name)
VALUES
(0, 'Africa'),
(1, 'Asia'),
(2, 'Central and North America'),
(3, 'Europe'),
(4, 'Middle East'),
(5, 'Nordic countries'),
(6, 'Oceania'),
(7, 'South America');

-- Diplomatic title lookup table.
DROP TABLE IF EXISTS public.title_legend;

CREATE TABLE public.title_legend (
title_code SMALLINT PRIMARY KEY,
diplomatic_title VARCHAR(80) NOT NULL
);

INSERT INTO public.title_legend (title_code, diplomatic_title)
VALUES
(1, 'chargé d’affaires'),
(2, 'minister, internuncios'),
(3, 'ambassador'),
(96, 'acting chargé d’affaires'),
(97, 'acting ambassador'),
(98, 'other');

-- 1) TEMPORAL ANALYSIS

-- Analyze the trend in diplomatic appointments over time by gender.
SELECT
gd.report_year,
gt.genderlabel,
COUNT(*) AS total
FROM public.gen_dip AS gd
INNER JOIN public.gender_type AS gt
ON COALESCE(gd.gender, 99) = gt.code
GROUP BY gd.report_year, gt.genderlabel
ORDER BY gd.report_year, gt.genderlabel;

-- Show the percentage trend of male and female appointments over time.
SELECT
gd.report_year,
ROUND(SUM(CASE WHEN gt.genderlabel = 'Female' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 2) AS percent_female,
ROUND(SUM(CASE WHEN gt.genderlabel = 'Male' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 2) AS percent_male
FROM public.gen_dip AS gd
INNER JOIN public.gender_type AS gt
ON COALESCE(gd.gender, 99) = gt.code
GROUP BY gd.report_year
ORDER BY gd.report_year;

-- Show the total number and percentage of diplomats by gender over time.
SELECT
gd.report_year,
gt.genderlabel,
COUNT(*) AS total,
ROUND(COUNT(*) * 100.0 / NULLIF(SUM(COUNT(*)) OVER (PARTITION BY gd.report_year), 0), 2) AS gender_percentage
FROM public.gen_dip AS gd
INNER JOIN public.gender_type AS gt
ON COALESCE(gd.gender, 99) = gt.code
GROUP BY gd.report_year, gt.genderlabel
ORDER BY gd.report_year, gt.genderlabel;

-- Compare gender percentages per year using a window function.
SELECT
gd.report_year,
gt.genderlabel,
COUNT(*) AS total_diplomats,
ROUND(COUNT(*) * 100.0 / NULLIF(SUM(COUNT(*)) OVER (PARTITION BY gd.report_year), 0), 2) AS gender_percentage
FROM public.gen_dip AS gd
INNER JOIN public.gender_type AS gt
ON COALESCE(gd.gender, 99) = gt.code
GROUP BY gd.report_year, gt.genderlabel
ORDER BY gd.report_year, gt.genderlabel;

-- Find the year with the highest percentage of female main assignments.
SELECT
gd.report_year,
ROUND(SUM(CASE WHEN gt.genderlabel = 'Female' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 2) AS percent_female
FROM public.gen_dip AS gd
INNER JOIN public.gender_type AS gt
ON COALESCE(gd.gender, 99) = gt.code
WHERE gd.main_assignment = 1
GROUP BY gd.report_year
ORDER BY percent_female DESC
LIMIT 1;

-- Show the evolution of feminist foreign policy over time.
SELECT
report_year,
ROUND(SUM(CASE WHEN feminist_foreign_policy_sender = 1 THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 2) AS percent_sender_ffp,
ROUND(SUM(CASE WHEN feminist_foreign_policy_receiver = 1 THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 2) AS percent_receiver_ffp
FROM public.gen_dip
GROUP BY report_year
ORDER BY report_year;

-- Show the percentage of female diplomats sent by FFP and non-FFP countries.
SELECT
gd.feminist_foreign_policy_sender,
ROUND(SUM(CASE WHEN gt.genderlabel = 'Female' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 2) AS percent_female_diplomats
FROM public.gen_dip AS gd
INNER JOIN public.gender_type AS gt
ON COALESCE(gd.gender, 99) = gt.code
GROUP BY gd.feminist_foreign_policy_sender
ORDER BY gd.feminist_foreign_policy_sender;

-- Show the percentage of female diplomats received by FFP and non-FFP countries.
SELECT
gd.feminist_foreign_policy_receiver,
ROUND(SUM(CASE WHEN gt.genderlabel = 'Female' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 2) AS percent_female_diplomats
FROM public.gen_dip AS gd
INNER JOIN public.gender_type AS gt
ON COALESCE(gd.gender, 99) = gt.code
GROUP BY gd.feminist_foreign_policy_receiver
ORDER BY gd.feminist_foreign_policy_receiver;

-- Measure the gender gap in diplomacy over time.
SELECT
gd.report_year,
ROUND(SUM(1) FILTER (WHERE gt.genderlabel = 'Female') * 100.0 / NULLIF(COUNT(*), 0), 2) AS percent_female,
ROUND(SUM(1) FILTER (WHERE gt.genderlabel = 'Male') * 100.0 / NULLIF(COUNT(*), 0), 2) AS percent_male,
ROUND(
(SUM(1) FILTER (WHERE gt.genderlabel = 'Male') * 100.0 / NULLIF(COUNT(*), 0)) -
(SUM(1) FILTER (WHERE gt.genderlabel = 'Female') * 100.0 / NULLIF(COUNT(*), 0)),
2
) AS gender_gap
FROM public.gen_dip AS gd
INNER JOIN public.gender_type AS gt
ON COALESCE(gd.gender, 99) = gt.code
GROUP BY gd.report_year
ORDER BY gd.report_year;

-- Show the yearly change in the gender gap.
WITH gap AS (
SELECT
gd.report_year,
ROUND(
SUM(1) FILTER (WHERE gt.genderlabel = 'Male') * 100.0 / NULLIF(COUNT(*), 0) -
SUM(1) FILTER (WHERE gt.genderlabel = 'Female') * 100.0 / NULLIF(COUNT(*), 0),
2
) AS gender_gap
FROM public.gen_dip AS gd
INNER JOIN public.gender_type AS gt
ON COALESCE(gd.gender, 99) = gt.code
GROUP BY gd.report_year
)
SELECT
report_year,
gender_gap,
gender_gap - LAG(gender_gap) OVER (ORDER BY report_year) AS gender_gap_change
FROM gap
ORDER BY report_year;

-- 2) GEOGRAPHICAL ANALYSIS

-- REGION

-- Show the percentage of female diplomats by sending geographic area.
SELECT
rc.region_name AS sender_region,
ROUND(SUM(CASE WHEN gd.gender = 1 THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 2) AS percent_female
FROM public.region_code AS rc
INNER JOIN public.gen_dip AS gd
ON rc.code = gd.sender_region
GROUP BY rc.region_name
ORDER BY percent_female DESC;

-- Show the percentage of female and male diplomats by sending geographic area over time.
SELECT
gd.report_year,
rc.region_name AS sender_region,
ROUND(SUM(CASE WHEN gt.genderlabel = 'Female' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 2) AS percent_female,
ROUND(SUM(CASE WHEN gt.genderlabel = 'Male' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 2) AS percent_male
FROM public.gen_dip AS gd
INNER JOIN public.gender_type AS gt
ON COALESCE(gd.gender, 99) = gt.code
INNER JOIN public.region_code AS rc
ON gd.sender_region = rc.code
GROUP BY gd.report_year, rc.region_name
ORDER BY gd.report_year, percent_female DESC;

-- Show the percentage of female diplomats by receiving geographic area.
SELECT
rc.region_name AS receiver_region,
ROUND(SUM(CASE WHEN gd.gender = 1 THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 2) AS percent_female
FROM public.region_code AS rc
INNER JOIN public.gen_dip AS gd
ON rc.code = gd.receiver_region
GROUP BY rc.region_name
ORDER BY percent_female DESC;

-- Show the percentage of female and male diplomats by receiving geographic area over time.
SELECT
gd.report_year,
rc.region_name AS receiver_region,
ROUND(SUM(CASE WHEN gt.genderlabel = 'Female' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 2) AS percent_female,
ROUND(SUM(CASE WHEN gt.genderlabel = 'Male' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 2) AS percent_male
FROM public.gen_dip AS gd
INNER JOIN public.gender_type AS gt
ON COALESCE(gd.gender, 99) = gt.code
INNER JOIN public.region_code AS rc
ON gd.receiver_region = rc.code
GROUP BY gd.report_year, rc.region_name
ORDER BY gd.report_year, percent_female DESC;

-- Show the gender gap across sending geographic areas.
SELECT
rc.region_name AS sender_region,
ROUND(SUM(CASE WHEN gd.gender = 1 THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 2) AS percent_female,
ROUND(SUM(CASE WHEN gd.gender = 0 THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 2) AS percent_male,
ROUND(
(SUM(CASE WHEN gd.gender = 0 THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0)) -
(SUM(CASE WHEN gd.gender = 1 THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0)),
2
) AS gender_gap
FROM public.gen_dip AS gd
INNER JOIN public.region_code AS rc
ON gd.sender_region = rc.code
GROUP BY rc.region_name
ORDER BY percent_female DESC;

-- Show the gender gap across receiving geographic areas.
SELECT
rc.region_name AS receiver_region,
ROUND(SUM(CASE WHEN gd.gender = 1 THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 2) AS percent_female,
ROUND(SUM(CASE WHEN gd.gender = 0 THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 2) AS percent_male,
ROUND(
(SUM(CASE WHEN gd.gender = 0 THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0)) -
(SUM(CASE WHEN gd.gender = 1 THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0)),
2
) AS gender_gap
FROM public.gen_dip AS gd
INNER JOIN public.region_code AS rc
ON gd.receiver_region = rc.code
GROUP BY rc.region_name
ORDER BY percent_female DESC;

-- Compare female diplomats in sending geographic areas by FFP status.
SELECT
CASE WHEN gd.feminist_foreign_policy_sender = 1 THEN 'FFP' ELSE 'Non-FFP' END AS ffp_sender_status,
rc_sender.region_name AS sender_region,
ROUND(SUM(CASE WHEN gt.genderlabel = 'Female' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 2) AS percent_female_sent
FROM public.gen_dip AS gd
INNER JOIN public.gender_type AS gt
ON COALESCE(gd.gender, 99) = gt.code
INNER JOIN public.region_code AS rc_sender
ON gd.sender_region = rc_sender.code
GROUP BY gd.feminist_foreign_policy_sender, rc_sender.region_name
ORDER BY ffp_sender_status, percent_female_sent DESC;

-- Compare female diplomats in receiving geographic areas by FFP status.
SELECT
CASE WHEN gd.feminist_foreign_policy_receiver = 1 THEN 'FFP' ELSE 'Non-FFP' END AS ffp_receiver_status,
rc_receiver.region_name AS receiver_region,
ROUND(SUM(CASE WHEN gt.genderlabel = 'Female' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 2) AS percent_female_received
FROM public.gen_dip AS gd
INNER JOIN public.gender_type AS gt
ON COALESCE(gd.gender, 99) = gt.code
INNER JOIN public.region_code AS rc_receiver
ON gd.receiver_region = rc_receiver.code
GROUP BY gd.feminist_foreign_policy_receiver, rc_receiver.region_name
ORDER BY ffp_receiver_status, percent_female_received DESC;

-- Analyze the Middle East over time, because it has low female representation among sending areas.
SELECT
rc.region_name AS sender_region,
gd.report_year,
ROUND(SUM(CASE WHEN gd.gender = 1 THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 2) AS percent_female,
ROUND(SUM(CASE WHEN gd.gender = 0 THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 2) AS percent_male,
ROUND(
(SUM(CASE WHEN gd.gender = 0 THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0)) -
(SUM(CASE WHEN gd.gender = 1 THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0)),
2
) AS gender_gap
FROM public.gen_dip AS gd
INNER JOIN public.region_code AS rc
ON gd.sender_region = rc.code
WHERE rc.region_name = 'Middle East'
GROUP BY rc.region_name, gd.report_year
ORDER BY gd.report_year ASC;

-- Analyze the Nordic countries over time, because they are a leading sending area for female diplomats.
SELECT
rc.region_name AS sender_region,
gd.report_year,
ROUND(SUM(CASE WHEN gd.gender = 1 THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 2) AS percent_female,
ROUND(SUM(CASE WHEN gd.gender = 0 THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 2) AS percent_male,
ROUND(
(SUM(CASE WHEN gd.gender = 0 THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0)) -
(SUM(CASE WHEN gd.gender = 1 THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0)),
2
) AS gender_gap
FROM public.gen_dip AS gd
INNER JOIN public.region_code AS rc
ON gd.sender_region = rc.code
WHERE rc.region_name = 'Nordic countries'
GROUP BY rc.region_name, gd.report_year
ORDER BY gd.report_year ASC;

-- COUNTRIES

-- Show the percentage of female diplomats by sending country.
SELECT
gd.country_sender,
ROUND(SUM(1) FILTER (WHERE gt.genderlabel = 'Female') * 100.0 / NULLIF(COUNT(*), 0), 2) AS percent_female_sender
FROM public.gen_dip AS gd
INNER JOIN public.gender_type AS gt
ON COALESCE(gd.gender, 99) = gt.code
GROUP BY gd.country_sender
ORDER BY percent_female_sender DESC;

-- Compare female diplomats in sending countries by FFP status.
SELECT
gd.country_sender,
CASE WHEN gd.feminist_foreign_policy_sender = 1 THEN 'FFP' ELSE 'Non-FFP' END AS ffp_status,
ROUND(SUM(CASE WHEN gt.genderlabel = 'Female' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 2) AS percent_female
FROM public.gen_dip AS gd
INNER JOIN public.gender_type AS gt
ON COALESCE(gd.gender, 99) = gt.code
GROUP BY gd.country_sender, gd.feminist_foreign_policy_sender
ORDER BY ffp_status, percent_female DESC;

-- Show the percentage of female diplomats by receiving country.
SELECT
gd.receiver_country,
ROUND(SUM(1) FILTER (WHERE gt.genderlabel = 'Female') * 100.0 / NULLIF(COUNT(*), 0), 2) AS percent_female_receiver
FROM public.gen_dip AS gd
INNER JOIN public.gender_type AS gt
ON COALESCE(gd.gender, 99) = gt.code
GROUP BY gd.receiver_country
ORDER BY percent_female_receiver DESC;

-- Compare female diplomats in receiving countries by FFP status.
SELECT
gd.receiver_country,
CASE WHEN gd.feminist_foreign_policy_receiver = 1 THEN 'FFP' ELSE 'Non-FFP' END AS ffp_status,
ROUND(SUM(CASE WHEN gt.genderlabel = 'Female' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 2) AS percent_female
FROM public.gen_dip AS gd
INNER JOIN public.gender_type AS gt
ON COALESCE(gd.gender, 99) = gt.code
GROUP BY gd.receiver_country, gd.feminist_foreign_policy_receiver
ORDER BY ffp_status, percent_female DESC;

-- Identify the sending countries with the highest percentage of female diplomats and their top receiving country.
WITH female_percentages AS (
SELECT
country_sender,
ROUND(COUNT(*) FILTER (WHERE gender = 1) * 100.0 / NULLIF(COUNT(*), 0), 2) AS percent_female
FROM public.gen_dip
GROUP BY country_sender
),
top_destinations AS (
SELECT
country_sender,
receiver_country,
COUNT(*) AS female_diplomats_sent,
ROW_NUMBER() OVER (
PARTITION BY country_sender
ORDER BY COUNT(*) DESC
) AS rn
FROM public.gen_dip
WHERE gender = 1
GROUP BY country_sender, receiver_country
)
SELECT
fp.country_sender,
fp.percent_female,
td.receiver_country AS top_receiver_country
FROM female_percentages AS fp
INNER JOIN top_destinations AS td
ON fp.country_sender = td.country_sender
WHERE td.rn = 1
ORDER BY fp.percent_female DESC
LIMIT 10;

-- Compare the percentage of female diplomats sent and received by the same country.
WITH sender AS (
SELECT
gd.country_sender,
ROUND(SUM(1) FILTER (WHERE gt.genderlabel = 'Female') * 100.0 / NULLIF(COUNT(*), 0), 2) AS percent_female_sender
FROM public.gen_dip AS gd
INNER JOIN public.gender_type AS gt
ON COALESCE(gd.gender, 99) = gt.code
GROUP BY gd.country_sender
),
receiver AS (
SELECT
gd.receiver_country,
ROUND(SUM(1) FILTER (WHERE gt.genderlabel = 'Female') * 100.0 / NULLIF(COUNT(*), 0), 2) AS percent_female_receiver
FROM public.gen_dip AS gd
INNER JOIN public.gender_type AS gt
ON COALESCE(gd.gender, 99) = gt.code
GROUP BY gd.receiver_country
)
SELECT
COALESCE(s.country_sender, r.receiver_country) AS country,
COALESCE(s.percent_female_sender, 0) AS percent_female_sender,
COALESCE(r.percent_female_receiver, 0) AS percent_female_receiver
FROM sender AS s
FULL JOIN receiver AS r
ON s.country_sender = r.receiver_country
ORDER BY percent_female_sender ASC, percent_female_receiver ASC;

-- The FULL JOIN keeps countries that appear only as senders or only as receivers.
-- Numeric COALESCE values are set to 0 so missing percentages remain numeric.

-- 3) DIPLOMATIC TITLES AND GENDER REPRESENTATION

-- Analyze male and female diplomatic appointments by title.
SELECT
tl.diplomatic_title AS title,
ROUND(SUM(CASE WHEN gt.genderlabel = 'Female' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 2) AS percent_female,
ROUND(SUM(CASE WHEN gt.genderlabel = 'Male' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 2) AS percent_male
FROM public.gen_dip AS gd
INNER JOIN public.gender_type AS gt
ON COALESCE(gd.gender, 99) = gt.code
INNER JOIN public.title_legend AS tl
ON gd.title = tl.title_code
GROUP BY tl.diplomatic_title
ORDER BY percent_female DESC;

-- Show female appointment percentages by diplomatic title over time.
SELECT
gd.report_year,
tl.diplomatic_title,
ROUND(SUM(CASE WHEN gt.genderlabel = 'Female' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 2) AS percent_female
FROM public.gen_dip AS gd
INNER JOIN public.gender_type AS gt
ON COALESCE(gd.gender, 99) = gt.code
INNER JOIN public.title_legend AS tl
ON gd.title = tl.title_code
GROUP BY gd.report_year, gd.title, tl.diplomatic_title
ORDER BY gd.report_year, percent_female DESC;

-- Show female appointment percentages by diplomatic title over time in tabular format.
SELECT
gd.report_year,
ROUND(SUM(1) FILTER (WHERE tl.diplomatic_title = 'ambassador' AND gt.genderlabel = 'Female') * 100.0 /
NULLIF(SUM(1) FILTER (WHERE tl.diplomatic_title = 'ambassador'), 0), 2) AS percent_female_ambassador,
ROUND(SUM(1) FILTER (WHERE tl.diplomatic_title = 'acting ambassador' AND gt.genderlabel = 'Female') * 100.0 /
NULLIF(SUM(1) FILTER (WHERE tl.diplomatic_title = 'acting ambassador'), 0), 2) AS percent_female_acting_ambassador,
ROUND(SUM(1) FILTER (WHERE tl.diplomatic_title = 'minister, internuncios' AND gt.genderlabel = 'Female') * 100.0 /
NULLIF(SUM(1) FILTER (WHERE tl.diplomatic_title = 'minister, internuncios'), 0), 2) AS percent_female_minister_internuncios,
ROUND(SUM(1) FILTER (WHERE tl.diplomatic_title = 'chargé d’affaires' AND gt.genderlabel = 'Female') * 100.0 /
NULLIF(SUM(1) FILTER (WHERE tl.diplomatic_title = 'chargé d’affaires'), 0), 2) AS percent_female_charge_d_affaires,
ROUND(SUM(1) FILTER (WHERE tl.diplomatic_title = 'acting chargé d’affaires' AND gt.genderlabel = 'Female') * 100.0 /
NULLIF(SUM(1) FILTER (WHERE tl.diplomatic_title = 'acting chargé d’affaires'), 0), 2) AS percent_female_acting_charge_d_affaires
FROM public.gen_dip AS gd
INNER JOIN public.gender_type AS gt
ON COALESCE(gd.gender, 99) = gt.code
INNER JOIN public.title_legend AS tl
ON gd.title = tl.title_code
GROUP BY gd.report_year
ORDER BY gd.report_year;

-- Show the yearly growth in female main assignments.
SELECT
report_year,
percent_female,
percent_female - LAG(percent_female) OVER (ORDER BY report_year) AS growth
FROM (
SELECT
gd.report_year,
ROUND(SUM(CASE WHEN gt.genderlabel = 'Female' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 2) AS percent_female
FROM public.gen_dip AS gd
INNER JOIN public.gender_type AS gt
ON COALESCE(gd.gender, 99) = gt.code
WHERE gd.main_assignment = 1
GROUP BY gd.report_year
) AS yearly_percentages
ORDER BY report_year;

-- Show the percentage of female ambassador appointments over time.
SELECT
gd.report_year,
tl.diplomatic_title,
ROUND(SUM(CASE WHEN gt.genderlabel = 'Female' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 2) AS percent_female
FROM public.gen_dip AS gd
INNER JOIN public.gender_type AS gt
ON COALESCE(gd.gender, 99) = gt.code
INNER JOIN public.title_legend AS tl
ON gd.title = tl.title_code
WHERE tl.diplomatic_title = 'ambassador'
GROUP BY gd.report_year, gd.title, tl.diplomatic_title
ORDER BY gd.report_year, gd.title;

-- Show the percentage of female acting ambassador appointments over time.
SELECT
gd.report_year,
tl.diplomatic_title,
ROUND(SUM(CASE WHEN gt.genderlabel = 'Female' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 2) AS percent_female
FROM public.gen_dip AS gd
INNER JOIN public.gender_type AS gt
ON COALESCE(gd.gender, 99) = gt.code
INNER JOIN public.title_legend AS tl
ON gd.title = tl.title_code
WHERE tl.diplomatic_title = 'acting ambassador'
GROUP BY gd.report_year, gd.title, tl.diplomatic_title
ORDER BY gd.report_year, gd.title;

-- Show the percentage of female minister and internuncio appointments over time.
SELECT
gd.report_year,
tl.diplomatic_title,
ROUND(SUM(CASE WHEN gt.genderlabel = 'Female' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 2) AS percent_female
FROM public.gen_dip AS gd
INNER JOIN public.gender_type AS gt
ON COALESCE(gd.gender, 99) = gt.code
INNER JOIN public.title_legend AS tl
ON gd.title = tl.title_code
WHERE tl.diplomatic_title = 'minister, internuncios'
GROUP BY gd.report_year, gd.title, tl.diplomatic_title
ORDER BY gd.report_year, gd.title;

-- Show the percentage of female chargé d’affaires appointments over time.
SELECT
gd.report_year,
tl.diplomatic_title,
ROUND(SUM(CASE WHEN gt.genderlabel = 'Female' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 2) AS percent_female
FROM public.gen_dip AS gd
INNER JOIN public.gender_type AS gt
ON COALESCE(gd.gender, 99) = gt.code
INNER JOIN public.title_legend AS tl
ON gd.title = tl.title_code
WHERE tl.diplomatic_title = 'chargé d’affaires'
GROUP BY gd.report_year, gd.title, tl.diplomatic_title
ORDER BY gd.report_year, gd.title;

-- Show the average percentage of women in parliament by sender FFP status.
SELECT
feminist_foreign_policy_sender AS ffp,
ROUND(AVG(female_parliament_share), 2) AS avg_women_parliament
FROM public.gen_dip
GROUP BY feminist_foreign_policy_sender
ORDER BY feminist_foreign_policy_sender;

-- Show the percentage of female main assignments by year.
SELECT
gd.report_year,
ROUND(SUM(CASE WHEN gt.genderlabel = 'Female' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 2) AS percent_female_main_assignment
FROM public.gen_dip AS gd
INNER JOIN public.gender_type AS gt
ON COALESCE(gd.gender, 99) = gt.code
WHERE gd.main_assignment = 1
GROUP BY gd.report_year
ORDER BY gd.report_year;

-- Find the most frequent diplomatic title in each sending region.
SELECT DISTINCT ON (region_name)
region_name,
diplomatic_title
FROM (
SELECT
rc.region_name,
tl.diplomatic_title,
COUNT(*) AS frequency
FROM public.gen_dip AS gd
INNER JOIN public.region_code AS rc
ON gd.sender_region = rc.code
INNER JOIN public.title_legend AS tl
ON gd.title = tl.title_code
GROUP BY rc.region_name, tl.diplomatic_title
) AS title_frequency
ORDER BY region_name, frequency DESC;

-- Show relationships between sending and receiving geographic areas for female diplomats.
SELECT
rc_sender.region_name AS sender_region,
rc_receiver.region_name AS receiver_region,
tl.diplomatic_title,
COUNT(*) AS female_diplomats_sent
FROM public.gen_dip AS gd
INNER JOIN public.gender_type AS gt
ON COALESCE(gd.gender, 99) = gt.code
INNER JOIN public.region_code AS rc_sender
ON gd.sender_region = rc_sender.code
INNER JOIN public.region_code AS rc_receiver
ON gd.receiver_region = rc_receiver.code
INNER JOIN public.title_legend AS tl
ON gd.title = tl.title_code
WHERE gt.genderlabel = 'Female'
GROUP BY rc_sender.region_name, rc_receiver.region_name, tl.diplomatic_title
ORDER BY rc_sender.region_name, female_diplomats_sent DESC;
