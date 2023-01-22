library("tidyverse")
library("baseballr")

my_pitching <- function(name, stat, start, end){
 dates <- seq.Date(as.Date(start), as.Date(end), by = 7)
 date_grid <- tibble(start_date = dates, end_date = dates + 6)
 pitcher_data <- purrr::map2_df(.x = date_grid$start_date,
                                .y = date_grid$end_date,
                                ~bref_daily_pitcher(.x, .y))
#   pitcher_data <- bref_daily_pitcher(start, end)
#   stat_df <- filter(pitcher_data, Name == name)
#   return(select(stat_df, stat)[[1]])
}

my_pitching("Max Scherzer", "WHIP", "2021-06-01", "2021-06-30")

my_pitching2 <- function(name, stat, start, end){
  pitcher_data <- bref_daily_pitcher(start, end)
  stat_df <- filter(pitcher_data, Name == name)
  return(suppressWarnings(select(stat_df, stat)[[1]]))
}

my_pitching2("Max Scherzer", "WHIP", "2021-06-01", "2021-06-30")

my_statcast <- function(first, last, start, end){
  player_id <- playerid_lookup(last, first) %>%
    pull(mlbam_id)
  statcast_search_pitchers(start, end, player_id)
}

statcast_data <- my_statcast("Paul", "Sewald", "2021-06-01", "2021-06-30")
View(statcast_data)

plot_df <- statcast_data %>%
  map_df(rev) %>%
  mutate(Pitches = factor(row_number()))

my_colors = c("ball" = "springgreen3", "blocked_ball" = "springgreen3", 
              "hit_by_pitch" = "springgreen3", "called_strike" = "red2", 
              "swinging_strike" = "red2", "foul" = "red2", "foul_tip" = "red2",
              "swinging_strike_blocked" = "red2", "hit_into_play" = "blue")

all_pitches <- unique(plot_df$pitch_type)
all_fastballs <- c("FF", "FC", "FA", "FT", "SI", "FS")
fast_fastballs <- c("FF", "FA", "FT")
slow_fastballs <- c("FC", "FS", "SI")
all_off_speed <- c("SL", "CU", "CB", "KC", "SC", "KU", "KN", "CH", "EP")
standard_off_speed <- c("SL", "CU", "CB", "CH")
uncommon_off_speed <- c("KC", "SC", "KU", "KN", "EP")  # "Junk"

all_outcomes <- unique(plot_df$description)
balls <- c("ball", "blocked_ball", "hit_by_pitch")
strikes <- c("called_strike", "swinging_strike", "foul", "foul_tip",
             "swinging_strike_blocked")
BIP <- "hit_into_play"
swing <- c("swinging_strike", "foul", "foul_tip", "swinging_strike_blocked",
           BIP)
no_swing <- c("ball", "blocked_ball", "hit_by_pitch", "called_strike")
in_the_dirt <- c("blocked_ball", "swinging_strike_blocked")
may_increase_obp <- c("ball", "blocked_ball", "hit_by_pitch", BIP)

pitch_speed <- function(pitch, outcome){
  pitch_df <- filter(plot_df, pitch_type %in% pitch, description %in% outcome)
  ggplot(pitch_df, aes(as.numeric(as.character(Pitches)), release_speed, 
                       color=description)) +
    geom_point() +
    scale_color_manual(name = "Pitch\nResult", values = my_colors, 
                       breaks = c("ball", "called_strike", "hit_into_play"),
                       labels = c("Balls", "Strikes", "BIP")) +
    theme(axis.title.y = element_blank(), axis.text.x = element_blank(),
          axis.ticks.x = element_blank()) +
    xlab("Pitches (Sequential Across Date Range)") +
    ggtitle("Pitch Release Speed in MPH (Balls, Strikes, BIP)") +
    scale_y_continuous(breaks = seq(floor(min(pitch_df$release_speed)),
                                    ceiling(max(pitch_df$release_speed)),
                                    by = 1))
}

# pitch_speed(all_pitches, may_increase_obp)

pitch_location <- function(pitch, outcome){
  pitch_df <- filter(plot_df, pitch_type %in% pitch, description %in% outcome)
  plt <- ggplot(pitch_df, aes(plate_x, plate_z, color = description)) +
    geom_point() +
    xlim(-6.5, 6.5) +
    ylim(-1, 5) +
    scale_color_manual(name = "Pitch\nResult", values = my_colors, 
                       breaks = c("ball", "called_strike", "hit_into_play"),
                       labels = c("Balls", "Strikes", "BIP")) +
    theme(axis.title.y = element_blank(), axis.title.x = element_blank()) +
    ggtitle("Pitch Location from Batter's Perspective (Balls, Strikes, BIP)")
  suppressWarnings(print(plt))
}

pitch_location(all_pitches, all_outcomes)

pitch_location_speed <- function(pitch, outcome){
  pitch_df <- filter(plot_df, pitch_type %in% pitch, description %in% outcome)
  plt <- ggplot(pitch_df, aes(plate_x, plate_z, color = release_speed)) +
    geom_point() +
    xlim(-6.5, 6.5) +
    ylim(-1, 5) +
    scale_color_gradient(name = "Pitch\nSpeed", low = "lightgoldenrodyellow",
                         high = "orangered3", breaks =
                         seq(70, ceiling(max(pitch_df$release_speed)), 
                             by = 5)) +
    theme(axis.title.y = element_blank(), axis.title.x = element_blank()) +
    ggtitle("Pitch Location from Batter's Perspective (Speed in MPH)")
  suppressWarnings(print(plt))
}


# pitch_location_speed(all_pitches, balls)