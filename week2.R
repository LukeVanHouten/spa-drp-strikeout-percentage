# Week 2 starter code and sample exercises
# For help with SQL check out this resource: 
#   https://www.sqltutorial.org/wp-content/uploads/2016/04/SQL-cheat-sheet.pdf

# Load the packages
require(DBI)
require(dplyr)

# Create a connection to the SQL database
# driver <- dbDriver("SQLite")
conn <- dbConnect(RSQLite::SQLite(),  dbname = "data/lahman_1871-2021.sqlite")

# Some examples
## List tables
dbListTables(conn)

## List the fields in a table
table_name <- 'AllstarFull'
dbListFields(conn, table_name)

## Let's get the full batting table
query <- '
SELECT * FROM Batting
'
df <- dbGetQuery(conn, query)
View(df)

## That's a lot of data! Let's just pull some batting data for Mariners in 2021
query <- '
SELECT playerID, teamID, R, H, "2B", "3B", HR
FROM Batting
WHERE yearID = "2021" AND teamID = "SEA"
'
df <- dbGetQuery(conn, query)

## Sweet! Now let's merge on the Players table to get the actual names of our players
## Notice that when the columns appxear in both tables you have to prefix the desired
## column with "table.col_name"
query <- '
SELECT Batting.playerID, teamID, R, H, "2B", "3B", HR, nameGiven, nameLast, AB
FROM Batting
JOIN People ON Batting.playerID = People.playerID
WHERE yearID = "2021" AND teamID = "SEA"
'
df <- dbGetQuery(conn, query)
View(df)

## Here's an example of grouping and summarizing to compute a metric using SQL
## instead of first reading the table and then manipulating the df to calculate the metric
## Here we calculate team avg BA by year for every year from 2011-2021
## Notice I've also used the "AS" command to shorten "Batting" to "b"
query <- '
SELECT b.teamId, yearId, avg(H) / avg(AB) AS AVE_BA
FROM BATTING AS b
WHERE b.AB > 0 AND
  b.yearID > 2010
GROUP BY b.teamId, b.yearId
ORDER BY AVE_BA DESC
'
df1 <- dbGetQuery(conn, query)
View(df1)

## OBP data
query <- '
SELECT b.teamId, b.yearId, (avg(H) + avg(BB) + avg(HBP)) / (avg(AB) + avg(BB) + avg(HBP) + avg(SF)) AS OBP 
FROM BATTING AS b
WHERE b.AB > 0 AND
  b.yearID = 2015
GROUP BY b.teamId, b.yearId
ORDER BY OBP DESC
'

df <- dbGetQuery(conn, query)
View(df)

## Dope. Now here are some queries you can try to work out:

## From the Salaries table, find the total salary by team for the year 2016 vs 2006
## Hint: group by team and year
query <- '
SELECT s.yearID, teamID, SUM(salary) AS salarTotal
FROM SALARIES AS s
WHERE S.yearID = 2006 OR
  s.yearID = 2016
GROUP BY s.teamID, s.yearID
'

df <- dbGetQuery(conn, query)
View(df)

## Using the batting table, find the stealing success rate for the 2021 Mariners
## for all batters with more than 25 at-bats 
## Hint: SUM(?? + ??)*1.0/AB AS steal_attempts_per_AB
query <- '
SELECT b.teamID, yearID, sum((1.0*(SB + CS) / AB)) AS steal_attempts_per_AB
FROM BATTING AS b
JOIN People ON b.playerID = People.playerID
WHERE yearID = "2021" AND
  teamID = "SEA" AND
  AB > 25
'

df <- dbGetQuery(conn, query)
View(df)

## Create a query that calculates the number of all stars on the WS winning
## team by year where the columns are year, team, num_all_stars
## Hint: Join the tables SeriesPost and AllstarFull
query <- '
SELECT sp.yearID AS year, teamIDwinner, COUNT(a.playerID) AS num_all_stars
FROM SeriesPost as sp
JOIN ALLstarFull as a
ON sp.yearID = a.yearID AND
  sp.teamIDwinner = a.teamID
WHERE sp.round = "WS"
GROUP BY year
ORDER BY num_all_Stars DESC
'
df <- dbGetQuery(conn, query)
View(df)