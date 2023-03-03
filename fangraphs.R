library(tidyverse)
library(baseballr)

id_df <- read.csv("players_pos.csv")
pitchers_df <- read.csv("relief_pitchers.csv")

pitcher_ids_df <- merge(id_df, pitchers_df, by.x="key_mlbam", by.y="pitcher") %>%
    mutate(id_year = paste0(game_year, "_", key_fangraphs)) %>%
    select(key_mlbam, key_fangraphs, game_year, id_year)

pitchers_2021_df <- pitcher_ids_df %>%
    filter(game_year == 2021) %>%
    select(-id_year)

pitchers_train_df <- pitcher_ids_df %>%
    filter(game_year != 2021)

li_2021_df <- map_df(.x = pitchers_2021_df$key_fangraphs,
                     ~{fg_pitcher_game_logs(.x, 2021) %>% 
                       select(playerid, season, pLI, inLI, gmLI) %>%
                       group_by(playerid, season) %>%
                       summarize(mean_pLI = mean(pLI), mean_inLI = mean(inLI),
                                 mean_gmLI = mean(gmLI), max_pLI = max(pLI),
                                 max_inLI = max(inLI), max_gmLI = max(gmLI))
                       })

li_train_df <- map_df(.x = pitchers_train_df$id_year,
                      ~{fg_pitcher_game_logs(as.numeric(str_sub(.x, 6, -1)), 
                                             as.numeric(str_sub(.x, 1, 4))) %>% 
                              select(playerid, season, pLI, inLI, gmLI) %>%
                              group_by(playerid, season) %>%
                              summarize(mean_pLI = mean(pLI), 
                                        mean_inLI = mean(inLI),
                                        mean_gmLI = mean(gmLI),
                                        max_pLI = max(pLI),
                                        max_inLI = max(inLI), 
                                        max_gmLI = max(gmLI))
                        })

li_df <- rbind(li_train_df, li_2021_df)

write.csv(li_df, "li.csv", row.names=FALSE)