library(baseballr)
library(tidyverse)
library(DBI)
library(RPostgres)
library(RPostgreSQL)

annual_statcast_query <- function(season) {
    
    data_base_column_types <- read_csv("https://app.box.com/shared/static/q326nuker938n2nduy81au67s2pf9a3j.csv")
    
    dates <- seq.Date(as.Date(paste0(season, '-03-28')),
                      as.Date(paste0(season, '-11-05')), by = '4 days')
    
    date_grid <- tibble::tibble(start_date = dates, 
                                end_date = dates + 3)
    
    safe_savant <- purrr::safely(scrape_statcast_savant)
    
    payload <- purrr::map(.x = seq_along(date_grid$start_date), 
                          ~{message(paste0('\nScraping week of ', date_grid$start_date[.x], '...\n'))
                              
                              payload <- safe_savant(start_date = date_grid$start_date[.x], 
                                                     end_date = date_grid$end_date[.x], type = 'pitcher')
                              
                              return(payload)
                          })
    
    payload_df <- purrr::map(payload, 'result')
    
    number_rows <- purrr::map_df(.x = seq_along(payload_df), 
                                 ~{number_rows <- tibble::tibble(week = .x, 
                                                                 number_rows = length(payload_df[[.x]]$game_date))}) %>%
        dplyr::filter(number_rows > 0) %>%
        dplyr::pull(week)
    
    payload_df_reduced <- payload_df[number_rows]
    
    payload_df_reduced_formatted <- purrr::map(.x = seq_along(payload_df_reduced), 
                                               ~{cols_to_transform <- c("fielder_2", "pitcher_1", "fielder_2_1", "fielder_3",
                                                                        "fielder_4", "fielder_5", "fielder_6", "fielder_7",
                                                                        "fielder_8", "fielder_9")
                                               
                                               df <- purrr::pluck(payload_df_reduced, .x) %>%
                                                   dplyr::mutate_at(.vars = cols_to_transform, as.numeric) %>%
                                                   dplyr::mutate_at(.vars = cols_to_transform, function(x) {
                                                       ifelse(is.na(x), 999999999, x)
                                                   })
                                               
                                               character_columns <- data_base_column_types %>%
                                                   dplyr::filter(class == "character") %>%
                                                   dplyr::pull(variable)
                                               
                                               numeric_columns <- data_base_column_types %>%
                                                   dplyr::filter(class == "numeric") %>%
                                                   dplyr::pull(variable)
                                               
                                               integer_columns <- data_base_column_types %>%
                                                   dplyr::filter(class == "integer") %>%
                                                   dplyr::pull(variable)
                                               
                                               df <- df %>%
                                                   dplyr::mutate_if(names(df) %in% character_columns, as.character) %>%
                                                   dplyr::mutate_if(names(df) %in% numeric_columns, as.numeric) %>%
                                                   dplyr::mutate_if(names(df) %in% integer_columns, as.integer)
                                               
                                               return(df)
                                               })
    
    combined <- payload_df_reduced_formatted %>%
        dplyr::bind_rows()
    
    combined
}


format_append_statcast <- function(df) {
    
    # function for appending new variables to the data set
    
    additional_info <- function(df) {
        
        # apply additional coding for custom variables
        
        df$hit_type <- with(df, ifelse(type == "X" & events == "single", 1,
                                       ifelse(type == "X" & events == "double", 2,
                                              ifelse(type == "X" & events == "triple", 3, 
                                                     ifelse(type == "X" & events == "home_run", 4, NA)))))
        
        df$hit <- with(df, ifelse(type == "X" & events == "single", 1,
                                  ifelse(type == "X" & events == "double", 1,
                                         ifelse(type == "X" & events == "triple", 1, 
                                                ifelse(type == "X" & events == "home_run", 1, NA)))))
        
        df$fielding_team <- with(df, ifelse(inning_topbot == "Bot", away_team, home_team))
        
        df$batting_team <- with(df, ifelse(inning_topbot == "Bot", home_team, away_team))
        
        df <- df %>%
            dplyr::mutate(barrel = ifelse(launch_angle <= 50 & launch_speed >= 98 & launch_speed * 1.5 - launch_angle >= 117 & launch_speed + launch_angle >= 124, 1, 0))
        
        df <- df %>%
            dplyr::mutate(spray_angle = round(
                (atan(
                    (hc_x-125.42)/(198.27-hc_y)
                )*180/pi*.75)
                ,1)
            )
        
        df <- df %>%
            dplyr::filter(!is.na(game_year))
        
        return(df)
    }
    
    df <- df %>%
        additional_info()
    
    df$game_date <- as.character(df$game_date)
    
    df <- df %>%
        dplyr::arrange(game_date)
    
    df <- df %>%
        dplyr::filter(!is.na(game_date))
    
    df <- df %>%
        dplyr::ungroup()
    
    df <- df %>%
        dplyr::select(setdiff(names(.), c("error")))
    
    return(df)
}

delete_and_upload <- function(df, 
                              year,
                              dbname, 
                              user,
                              password, 
                              host = 'local_host', 
                              port = 5432) {
    
    pg <- RPostgres::Postgres()
    
    statcast_db <- dbConnect(pg, 
                             dbname = dbname, 
                             user = user, 
                             password = password,
                             host = host, 
                             port = port)
    
    query <- paste0('DELETE from statcast where game_year = ', year)
    
    dbGetQuery(statcast_db, query)
    
    dbWriteTable(statcast_db, "statcast", as.data.frame(df), append = TRUE)
    
    dbDisconnect(statcast_db)
    rm(statcast_db)
}

# payload_statcast <- annual_statcast_query(2021)
# 
# df <- format_append_statcast(df = payload_statcast)
# 
# statcast_db <- DBI::dbConnect(RPostgres::Postgres(), dbname = "drpstatcast",
#                               host = "localhost", 
#                               port = 5432,
#                               user = "postgres",
#                               password = "drppassword")
# 
# dbWriteTable(statcast_db, "statcast", as.data.frame(df), overwrite = TRUE)
# 
# DBI::dbDisconnect(statcast_db)
# 
# rm(df)
# gc()

map(.x = seq(2015, 2019, 1), 
    ~{payload_statcast <- annual_statcast_query(season = .x)
    
    message(paste0('Formatting payload for ', .x, '...'))
    
    df <- format_append_statcast(df = payload_statcast)
    
    message(paste0('Deleting and uploading ', .x, ' data to database...'))
    
    delete_and_upload(df, 
                      year = .x, 
                      dbname = 'drpstatcast', 
                      user = 'postgres', 
                      password = 'drppassword', 
                      host = 'localhost', 
                      port = 5432)
    
    statcast_db <- DBI::dbConnect(RPostgres::Postgres(), dbname = "drpstatcast",
                                  host = "localhost", 
                                  port = 5432,
                                  user = "postgres",
                                  password = "drppassword")
    
    dbGetQuery(statcast_db, 'select game_year, count(game_year) from statcast group by game_year')
    
    DBI::dbDisconnect(statcast_db)
    
    message('Sleeping and collecting garbage...')
    
    Sys.sleep(5*60)
    
    gc()
    
    })