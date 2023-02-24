library(DBI)
library(RPostgres)
library(tidyverse)
library(baseballr)
library(xgboost)
library(shapr)

conn <- DBI::dbConnect(RPostgres::Postgres(), dbname = "drpstatcast",
                       host = "localhost", port = 5432, user = "postgres",
                       password = "drppassword")

connn <- dbConnect(RSQLite::SQLite(),  dbname = "data/lahman_1871-2021.sqlite")

sql_df <- dbGetQuery(conn, read_file("week5.sql"))

platoon_s_k_query <- "
SELECT game_date, pitcher, events, type, game_year, stand, p_throws, at_bat_number
FROM statcast
WHERE game_date NOT BETWEEN '2021-03-01' AND '2021-03-31'
    AND game_date NOT BETWEEN '2015-03-28' AND '2015-04-04'
   	AND game_date NOT BETWEEN '2016-03-28' AND '2016-04-02'
   	AND game_date NOT BETWEEN '2017-03-28' AND '2017-04-01'
"

platoon_s_k_df <- dbGetQuery(conn, platoon_s_k_query)

strike_platoon_df <- platoon_s_k_df %>%
    select(pitcher, game_year, stand, p_throws, type) %>%
    group_by(pitcher, game_year) %>% 
    summarize(platoon_advantage = sum(stand == p_throws) / n(),
              strike_percentage = sum(type != "B") / n())

strikeout_df <- platoon_s_k_df %>%
    select(game_date, pitcher, events, game_year, at_bat_number) %>%
    filter(events != "") %>%
    group_by(pitcher, game_year, game_date, at_bat_number) %>%
    summarize(strikeouts = sum(events == "strikeout")) %>%
    summarize(strikeouts_game = sum(strikeouts),
              at_bats_game = n_distinct(at_bat_number)) %>%
    group_by(pitcher, game_year) %>%
    summarize(strikeout_percentage = sum(strikeouts_game) / sum(at_bats_game))

sql_platoon_s_k_df <- merge(merge(strike_platoon_df, strikeout_df, 
                              by = c("pitcher", "game_year"), all.x = TRUE), 
                        sql_df, by = c("pitcher", "game_year"), all.x = TRUE)

names_df <- read.csv("players.csv")

joined_df <- merge(sql_platoon_s_k_df, names_df, by.x='pitcher', by.y='key_mlbam',
                   all.x = TRUE)

df_train_features <- joined_df %>% 
    subset(game_year != 2021) %>%
    select(-pitcher, -game_year, -name, -strikeout_percentage)
df_train_labels <- joined_df %>% 
    subset(game_year != 2021) %>%
    select(strikeout_percentage)
df_test_features <- joined_df %>% 
    subset(game_year == 2021) %>%
    select(-pitcher, -game_year, -name, -strikeout_percentage)
df_test_labels <- joined_df %>% 
    subset(game_year == 2021) %>%
    select(strikeout_percentage)

train_features <- data.matrix(df_train_features)
train_labels <- data.matrix(df_train_labels)
test_features <- data.matrix(df_test_features)
test_labels <- data.matrix(df_test_labels)

model <- xgboost(
    data = train_features,
    label = train_labels,
    eta = 0.05,
    max_depth = 10,
    nrounds = 100,
    colsample_bytree = 0.8,
    verbose = TRUE
)

plot(model$evaluation_log$iter, model$evaluation_log$train_rmse)

pred <- predict(model, test_features)

xgboost_mae <- mean(abs(pred - df_test_labels$strikeout_percentage))