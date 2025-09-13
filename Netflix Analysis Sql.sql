CREATE DATABASE Netflix;
Use Netflix;
SELECT * From netflix;

SELECT show_id, COUNT(*) From netflix
GROUP BY show_id
having COUNT(*) > 1;

SELECT title, COUNT(*) From netflix
GROUP BY title having COUNT(*)>1;

SELECT * From netflix
WHERE concat(title, type) in (
SELECT concat(title, type) From netflix
GROUP BY title, type
HAVING COUNT(*)>1)
ORDER BY title;

SELECT title, type From netflix
GROUP BY title, type
having COUNT(*)>1;

# REMOVE DUPLICATES USING ROW NUMBER
WITH cte AS(
	SELECT *,
		ROW_NUMBER() OVER (PARTITION BY title, TYPE ORDER BY show_id) AS rn
From netflix
)
SELECT * FROM cte
WHERE rn = 1;

# CREATE HELPER NUMBER TABLE FOR SPLITTING COMMA SEPARATED FIELDS
CREATE TEMPORARY TABLE numbers (n INT);
INSERT INTO numbers VALUES (1), (2), (3), (4), (5), (6), (7), (8), (9), (10);

# SPLIT DIRECTOR INTO NETFLIX DIRECTORS
CREATE TABLE netflix_directors AS
SELECT
	show_id,
    TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(DIRECTOR, ',', n.n), ',', -1)) AS director
    FROM netflix
    JOIN numbers  n ON CHAR_LENGTH(director) - CHAR_LENGTH(REPLACE(director, ',', '')) >= n.n -1;
    
# SPLIT LIST INTO NETFLIX_GENRE
CREATE TABLE netflix_genre AS
SELECT
	show_id,
    TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(listed_in, ',', n.n), ',', -1)) AS genre
FROM netflix
JOIN numbers n ON CHAR_LENGTH(listed_in) - CHAR_LENGTH(REPLACE(listed_in, ',', '')) >= n.n - 1 ;

# SPLIT COUNTRY INTO NETFLIX COUNTRIES
CREATE TABLE netflix_countries AS
SELECT
	show_id, 
		TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(country, ',', n.n), ',', -1)) AS country
FROM netflix
JOIN numbers n ON CHAR_LENGTH(COUNTRY) - CHAR_LENGTH(REPLACE(country, ',', '')) >= n.n -1;

#SPLIT CAST INTO NETFLIX CAST
CREATE TABLE netflix_cast AS
SELECT
	show_id,
		TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX('CAST', ',', n.n), ',', -1)) AS cast_member
    FROM netflix
    JOIN numbers n ON CHAR_LENGTH('cast') - CHAR_LENGTH(REPLACE('cast', ',', '')) >= n.n -1;
    
# Convert date added into date type and remove duplicate
WITH cte AS (
	SELECT *,
		ROW_NUMBER() OVER (PARTITION BY title, type ORDER BY show_id) AS rn
FROM netflix
)
SELECT show_id, type, title,
	STR_TO_DATE(date_added, '%M %d, %Y') AS date_added,
    release_year, rating, duration, description
FROM cte
WHERE rn = 1;

# identify records with NULL country
SELECT * FROM netflix WHERE country IS NULL;

# identify records by specific director
SELECT * FROM netflix WHERE director = 'Ahishor Solomon';

#  MAP directors to country
SELECT nd.director, nc.country
FROM netflix_countries nc
JOIN netflix_directors nd ON nc.show_id = nd.show_id
GROUP BY nd.director, nc.country
ORDER BY nd.director;

# Populate missing countries in netflix_countries based on directors
## Not run Error ##############
INSERT INTO netflix_countries (show_id, country)
SELECT  n.show_id, m.country
FROM netflix n
JOIN (
	SELECT nd.director, nc.country
    FROM netflix_countries nc
    join netflix_directors nd ON nc.show_id = nd.show
    GROUP BY nd.director, nc.country
) m ON n.director = m.director
WHERE n.country IS NULL;
    
#  Identify records with NULL duration
SELECT  * FROM netflix WHERE duration IS NULL;

#. Final clean table with handled duration and date_added
WITH cte AS (
	SELECT *,
		ROW_NUMBER() OVER (PARTITION BY title, type ORDER BY show_id) AS rn
	FROM netflix
)
CREATE TABLE netflix_f AS
SELECT show_id, type, title, 
	STR_TO_DATE(DATE_ADDED, '%M %D, %Y') AS date_added,
	release_year, rating,
	CASE WHEN duration IS NULL THEN rating ELSE duration END AS duration, description
FROM cte
WHERE rn = 1;

##Analysis Queries
#Count movies and TV shows for directors with both
SELECT nd.director,
	COUNT(DISTINCT CASE WHEN nf.typr = 'Movie' THEN nf.show_id END) AS no_of_movies,
	COUNT(DISTINCT CASE WHEN nf.TYPE = 'TV SHOW' THEN nf.show_id END) AS no_of_tvshow
FROM netflix_directors nd
JOIN netflix_f nf ON nd.show_id = nf.show_id
GROUP BY nd.director
HAVING COUNT(DISTINCT nf.type) > 1;

# Country with highest comedy movies (use LIMIT 1
SELECT nc.country, COUNT(DISTINCT ng.show_id) AS no_of_movies
FROM netflix_genre ng
JOIN netflix_countries nc ON ng.show_id = nc.show_id
JOIN netflix_f n ON ng.show_id = n.show_id
WHERE ng.genre = 'Comedies' AND n.type = 'Movies'
GROUP BY nc.country
ORDER BY no_of_movies DESC
LIMIT 1;

# Director with max movies per year (by date_added)
WITH cte AS ( 
	SELECT nd.diector, YEAR(date_added) AS date_year, COUNT(n.show_id) AS no_of_movies
    FROM netflix_f n
    JOIN netflix_directors nd ON n.show_id = nd.show_id
    WHERE n.type = 'Movie'
    GROUP BY nd.director, YEAR(date_added)
),
cte2 AS (
	SELECT *,
		ROW_NUMBER() OVER (PARTITION BY date_year ORDER BY no_of_movies DESC, director) AS rn
	FROM cte
)
SELECT * FROM cte2 WHERE RN = 1;

# Average duration of movies per genre
SELECT ng.genere, AVG(CAST(REPLACE(duration, 'min', '') AS UNSIGNED)) AS avg_duration
FROM netflix_f n
JOIN netflix_genere ng ON n.show_id = ng.show_id
WHERE n.type = 'Movie'
GROUP BY ng.genre
ORDER BY avg_duration DESC;

# Directors with both horror and comedy movies and count of each
SELECT nd.director,
	COUNT(DISTINCT CASE WHEN ng.genre = 'Comedies' THEN n.show_id END) AS no_of_comedy,
    COUNT(DISTINCT CASE WHEN ng.genre = 'Horror Movies' then n.show_id END) AS  no_of_horror
FROM netflixf n
JOIN netflix_genre ng ON n.show_id =  ng.show_id
JOIN netflix_directors nd ON n.show_id = nd.show_id
WHERE n.type = 'Movies' AND ng.genre IN ('Comedies', 'Horror Movies')
GROUP BY nd.director
HAVING COUNT(DISTINCT ng.genre) = 2;
