library(DBI)
library(RPostgres)
library(RSQLite)
library(tidyverse)
library(baseballr)
library(xgboost)

conn <- dbConnect(Postgres(), dbname = "drpstatcast", host = "localhost",
                  port = 5432, user = "postgres", password = "drppassword")

connn <- dbConnect(SQLite(),  dbname = "data/lahman_1871-2021.sqlite")

sql_df <- dbGetQuery(conn, read_file("week5.sql"))

id_df <- read.csv("player_ids.csv")

positions_query <- "
SELECT playerID, yearID, POS
FROM Fielding
WHERE yearID BETWEEN 2015 AND 2019 OR
yearID == 2021
GROUP BY playerID, POS
"

fielding_df <- dbGetQuery(connn, positions_query)

bbref_query <- "
SELECT playerID, bbrefID
FROM People
"

bbref_df <- dbGetQuery(connn, bbref_query)

positions_df <- merge(fielding_df, bbref_df, by.x="playerID",
                      by.y="playerID") %>%
    select(bbrefID, POS)

names_df <- merge(positions_df, id_df, by.x="bbrefID", by.y="key_bbref") %>%
    select(-bbrefID) %>%
    filter(POS == "P")

colnames(names_df) <- c("POS", "name", "pitcher")

more_stats_query <- "
SELECT game_date, pitcher, events, type, game_year, stand, p_throws, at_bat_number
FROM statcast
WHERE game_date NOT BETWEEN '2021-03-01' AND '2021-03-31'
AND game_date NOT BETWEEN '2015-03-28' AND '2015-04-04'
AND game_date NOT BETWEEN '2016-03-28' AND '2016-04-02'
AND game_date NOT BETWEEN '2017-03-28' AND '2017-04-01'
"

more_stats_df <- dbGetQuery(conn, more_stats_query)

first_batter_platoon_df <- more_stats_df %>%
    select(game_date, pitcher, game_year, stand, p_throws, at_bat_number) %>%
    group_by(game_date, pitcher, game_year) %>%
    slice_min(at_bat_number) %>%
    slice_head(n = 1) %>%
    group_by(pitcher, game_year) %>%
    summarize(first_batter_platoon_advantage = sum(stand == p_throws) / n())
View(first_batter_platoon_df)

strikeout_df <- more_stats_df %>%
    select(game_date, pitcher, events, game_year, at_bat_number) %>%
    filter(events != "") %>%
    group_by(pitcher, game_year, game_date, at_bat_number) %>%
    summarize(strikeouts = sum(events == "strikeout")) %>%
    summarize(strikeouts_game = sum(strikeouts),
              at_bats_game = n_distinct(at_bat_number)) %>%
    group_by(pitcher, game_year) %>%
    summarize(strikeout_percentage = sum(strikeouts_game) / sum(at_bats_game))

strikes_pitches_games_df <- more_stats_df %>%
    select(game_date, pitcher, game_year, p_throws, type) %>%
    group_by(pitcher, game_year, p_throws) %>%
    summarize(pitch_count = n(), games = n_distinct(game_date), 
              pitches_per_game = pitch_count / games,
              strike_percentage = sum(type != "B") / n())

joined_df <- merge(merge(merge(first_batter_platoon_df, 
                               strikes_pitches_games_df,
                               by = c("pitcher", "game_year"), all.x = TRUE),
                         strikeout_df, by = c("pitcher", "game_year"),
                         all.x = TRUE), sql_df, by = c("pitcher", "game_year"),
                   all.x = TRUE)

named_joined_df <- right_join(joined_df, names_df, by="pitcher") %>%
    select(-POS) %>%
    filter(pitch_count < 1000, games > 3, pitches_per_game < 45)

df_train_features <- named_joined_df %>% 
    subset(game_year != 2021) %>%
    select(-pitcher, -game_year, -name, -strikeout_percentage, -pitch_count, 
           -games, -pitches_per_game, -p_throws)
df_train_labels <- named_joined_df %>% 
    subset(game_year != 2021) %>%
    select(strikeout_percentage)
df_test_features <- named_joined_df %>% 
    subset(game_year == 2021) %>%
    select(-pitcher, -game_year, -name, -strikeout_percentage, -pitch_count, 
           -games, -pitches_per_game, -p_throws)
df_test_labels <- named_joined_df %>% 
    subset(game_year == 2021) %>%
    select(strikeout_percentage)

train_features <- data.matrix(df_train_features)
train_labels <- data.matrix(df_train_labels)
test_features <- data.matrix(df_test_features)
test_labels <- data.matrix(df_test_labels)

etas <- c(0.05, 0.1, 0.15, 0.2)
nroundss <- c(50, 100, 200, 250)
max_depths <- c(2, 4, 6, 10)
colsample_bytrees <- c(0.5, 0.7, 0.8, 1)


params <- expand.grid(list(eta = etas, nrounds = nroundss, max_depth = 
                           max_depths, colsample_bytree = colsample_bytrees))
best_mae <- 10

for (row in 1:nrow(params)){
    this_eta <- params[row, "eta"]
    this_nrounds <- params[row, "nrounds"]
    this_max_depth <- params[row, "max_depth"]
    this_colsample_bytree <- params[row, "colsample_bytree"]
    this_model <- xgboost(
        data = train_features,
        label = train_labels,
        eta = this_eta,
        nrounds = this_nrounds,
        max_depth = this_max_depth,
        colsample_bytree = this_colsample_bytree,
        verbose = FALSE
    )
    pred <- predict(this_model, test_features)
    mae <- mean(abs(pred - df_test_labels$strikeout_percentage))
    if (mae < best_mae){
        best_mae <- mae
        best_param_row <- row
    }
}

print(best_mae)
print(params[best_param_row, ])