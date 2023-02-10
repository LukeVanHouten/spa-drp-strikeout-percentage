library(DBI)
library(RPostgres)

conn <- DBI::dbConnect(RPostgres::Postgres(), dbname = "drpstatcast",
                       host = "localhost", port = 5432, user = "postgres",
                       password = "drppassword")

dbListFields(conn, "statcast")

query <- "
SELECT * FROM statcast
"

sql_df <- dbGetQuery(conn, query)
View(sql_df)