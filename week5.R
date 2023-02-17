library(DBI)
library(RPostgres)
library(tidyverse)
library(baseballr)

conn <- DBI::dbConnect(RPostgres::Postgres(), dbname = "drpstatcast",
                       host = "localhost", port = 5432, user = "postgres",
                       password = "drppassword")

sql_df <- dbGetQuery(conn, statement = read_file("week5.sql"))
View(sql_df)

player_ids <- read.csv("player_ids.csv")

mlb_ids <- player_ids %>%
    select(PLAYERNAME, MLBID)
View(mlb_ids)

left_join_df <- merge(sql_df, mlb_ids, by.x='pitcher', by.y='MLBID', all.x = TRUE)
View(left_join_df)