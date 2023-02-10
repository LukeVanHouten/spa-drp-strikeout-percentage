library(DBI)
library(RPostgres)
library(tidyverse)

conn <- DBI::dbConnect(RPostgres::Postgres(), dbname = "drpstatcast",
                       host = "localhost", port = 5432, user = "postgres",
                       password = "drppassword")

sql_df <- dbGetQuery(conn, statement = read_file("week5.sql"))
View(sql_df)