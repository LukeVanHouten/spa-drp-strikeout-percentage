library("tidyverse")
library("baseballr")

granular_data <- function(first, last, data_year){
    player_id <- playerid_lookup(last, first)
    statcast_data <- 
        statcast_search_pitchers(paste0(as.character(data_year), "-03-28"),
                                 paste0(as.character(data_year), "-11-30"),
                                 player_id$mlbam_id[[1]]) %>%
        select(game_date, release_speed, player_name, events, stand, p_throws, 
               type, pfx_x, pfx_z, effective_speed, at_bat_number, 
               pitch_number) %>%
        mutate(total_pitches = 1:n()) %>%
        arrange(desc(total_pitches)) %>%
        group_by(game_date) %>%
        mutate(total_game_pitches = 1:n()) %>%
        ungroup() %>%
        mutate(total_pitches = 1:n()) %>%
        relocate(total_pitches, .after=total_game_pitches)
    fangraphs_data <- fg_pitcher_game_logs(player_id$fangraphs_id[[1]], 
                                           year=data_year) %>%
        select(Date, Pitches, pLI, inLI, gmLI, exLI) %>%
        arrange(Date) %>%
        uncount(Pitches) %>%
        select(-Date) %>%
        mutate(total_pitches = 1:n())
    joined_data <- left_join(statcast_data, fangraphs_data, 
                             by="total_pitches")
    View(joined_data)
    return(joined_data)
}

granular_data("Paul", "Sewald", 2021) 

# To do: create S% and SO% using the type and events columns, respectively.
# Calculate by creating running total using at_bat_number? Maybe change this
# column to be 1, 2, etc.
