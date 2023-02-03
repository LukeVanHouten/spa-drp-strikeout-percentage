library(DBI)
library(RPostgres)

conn <- DBI::dbConnect(RPostgres::Postgres(), dbname = "drpstatcast",
                       host = "localhost", port = 5432, user = "postgres",
                       password = "drppassword")

dbListFields(conn, "statcast")

query <- "
SELECT st.pitch_type, game_date, release_speed, player_name, stand, p_throws, type, pfx_x, pfx_z, effective_speed
FROM statcast as st
WHERE game_date
NOT BETWEEN '2021-03-01' AND '2021-03-27'
"

sql_df <- dbGetQuery(conn, query)
View(sql_df)