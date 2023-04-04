library(DBI)
library(RPostgres)
library(RSQLite)
library(tidyverse)
library(xgboost)

conn <- dbConnect(Postgres(), dbname = "drpstatcast", host = "localhost",
                  port = 5432, user = "postgres", password = "drppassword")

connn <- dbConnect(SQLite(),  dbname = "Data/lahman_1871-2021.sqlite")

sql_df <- dbGetQuery(conn, read_file("Data/pitches_query.sql"))

id_df <- read.csv("Data/players_pos.csv")

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

colnames(names_df) <- c("POS", "name", "pitcher", "key_fangraphs")

more_stats_query <- "
SELECT game_date, pitcher, events, type, game_year, stand, p_throws, 
   at_bat_number, release_speed, pfx_x, pfx_z
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

clusters_df <- read.csv("Data/clustered_pitches.csv")

joined_df <- merge(merge(merge(merge(first_batter_platoon_df,
                                     strikes_pitches_games_df,
                                     by=c("pitcher", "game_year"),
                                     all.x=TRUE), strikeout_df,
                               by = c("pitcher", "game_year"), all.x=TRUE),
                         sql_df, by = c("pitcher", "game_year"), all.x=TRUE),
                   clusters_df, by = c("pitcher", "game_year"), all.x=TRUE)

named_joined_df <- right_join(joined_df, names_df, by="pitcher") %>%
    select(-POS) %>%
    filter(pitch_count < 1000, games >= 4, pitches_per_game < 45)

li_df <- read.csv("Data/li.csv")

all_features_df <- merge(named_joined_df, li_df, 
                         by.x=c("key_fangraphs", "game_year"), 
                         by.y=c("playerid", "season"), all.x=TRUE) %>%
    select(-key_fangraphs) %>%
    na.omit() %>%
    filter(mean_gmLI != 0)

less_features_df <- all_features_df %>%
    select(-release_spin_rate_range, -vertical_release_range,
           -vertical_release_iqr, -horizontal_release_max,
           -horizontal_release_range, -horizontal_release_iqr,
           -vertical_movement_range, -horizontal_movement_range,
           -max_inLI, -mean_inLI, -vertical_release_max)

df_train_features <- less_features_df %>% 
    subset(game_year != 2021) %>%
    select(-pitcher, -name, -pitch_count, -games, -pitches_per_game, -p_throws,
           -strikeout_percentage, -game_year)
df_train_label <- less_features_df %>%
    subset(game_year != 2021) %>%
    select(strikeout_percentage)
df_test_features <- less_features_df %>% 
    subset(game_year == 2021) %>%
    select(-pitcher, -name, -pitch_count, -games, -pitches_per_game, -p_throws,
           -strikeout_percentage, -game_year)
test_label <- less_features_df %>% 
    subset(game_year == 2021) %>%
    select(name, p_throws, game_year, pitch_count, games, strikeout_percentage)

train_features <- data.matrix(df_train_features)
train_label <- data.matrix(df_train_label)
test_features <- data.matrix(df_test_features)

etas <- c(0.05, 0.1, 0.15, 0.2)
nroundss <- c(50, 100, 200, 250)
max_depths <- c(2, 4, 6)
colsample_bytrees <- c(0.5, 0.7, 0.8, 1)
lambdas <- c(0.001, 0.1, 0.5, 0.9)

params <- expand.grid(list(eta = etas, nrounds = nroundss, 
                           max_depth = max_depths, 
                           colsample_bytree = colsample_bytrees,
                           lambda = lambdas)) %>%
    mutate(mae = NA)

best_mae <- 1

for (row in 1:nrow(params)){
    this_eta <- params[row, "eta"]
    this_nrounds <- params[row, "nrounds"]
    this_max_depth <- params[row, "max_depth"]
    this_colsample_bytree <- params[row, "colsample_bytree"]
    this_lambda <- params[row, "lambda"]
    model <- xgboost(
        data = train_features,
        label = train_label,
        eta = this_eta,
        nrounds = this_nrounds,
        max_depth = this_max_depth,
        colsample_bytree = this_colsample_bytree,
        lambda = this_lambda,
        verbose = FALSE
    )
    pred <- predict(model, test_features)
    mae <- mean(abs(pred - test_label$strikeout_percentage))
    params[row, "mae"] <- mae
    if (mae < best_mae){
        best_mae <- mae
        best_param_row <- params[row, ]
        best_pred <- pred
        best_model <- model
    }
}

print(best_param_row)

prediction_vs_actual_df <- test_label %>%
    mutate(strikeout_percentage_pred = best_pred) %>%
    mutate(absolute_error = abs(strikeout_percentage - 
                                strikeout_percentage_pred)) %>%
    arrange(absolute_error)

error_plot <- ggplot(prediction_vs_actual_df, aes(x=1:length(absolute_error), 
                                                  y=absolute_error)) +
    geom_line() +
    labs(title="Arranged Absolute Error For Test Pitchers", 
         y="Absolute Error") +
    theme(axis.title.x = element_blank())

importance_df <- as.data.frame(xgb.importance(colnames(df_train_features), 
                                              model = best_model)) %>%
    select(Feature, Gain) %>%
    arrange(Gain)
importance_df$Feature <- factor(importance_df$Feature, 
                                levels = importance_df$Feature)

importance_plot <- ggplot(tail(importance_df, 10), aes(Gain, Feature)) +
    geom_point() +
    scale_x_continuous(breaks = seq(0, 0.2, 0.01)) +
    labs(title="XGBoost Model Feature Importance (Top 10)", 
         x = "Feature Importance (Gain)")