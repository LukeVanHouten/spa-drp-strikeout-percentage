library(DBI)
library(RPostgres)
library(tidyverse)
library(mclust)

conn <- dbConnect(Postgres(), dbname = "drpstatcast", host = "localhost",
                  port = 5432, user = "postgres", password = "drppassword")

pitch_data_query <- "
SELECT game_year, pitcher, release_speed, pfx_x, pfx_z
FROM statcast
WHERE game_date NOT BETWEEN '2021-03-01' AND '2021-03-31'
AND game_date NOT BETWEEN '2015-03-28' AND '2015-04-04'
AND game_date NOT BETWEEN '2016-03-28' AND '2016-04-02'
AND game_date NOT BETWEEN '2017-03-28' AND '2017-04-01'
"

pitch_data_df <- dbGetQuery(conn, pitch_data_query) %>%
    na.omit()

standardize <- function(x){
    (x - min(x)) / diff(range(x))
}

standardized_df <- cbind(select(pitch_data_df, pitcher, game_year), 
                         data.frame(lapply(select(pitch_data_df, -pitcher, 
                                                  -game_year), standardize)))

clustered_df <- standardized_df %>%
    group_by(pitcher, game_year) %>%
    summarize(clusters = n_distinct(Mclust(as.data.frame(release_speed, pfx_x, 
                                                         pfx_z))$classification))

write.csv(clustered_df, "clustered_pitches.csv", row.names=FALSE)