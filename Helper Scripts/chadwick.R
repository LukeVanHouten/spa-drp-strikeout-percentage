library(tidyverse)
library(baseballr)

chadwick0 <- read_csv("Data/chadwick/people-0.csv")
chadwick1 <- read_csv("Data/chadwick/people-1.csv")
chadwick2 <- read_csv("Data/chadwick/people-2.csv")
chadwick3 <- read_csv("Data/chadwick/people-3.csv")
chadwick4 <- read_csv("Data/chadwick/people-4.csv")
chadwick5 <- read_csv("Data/chadwick/people-5.csv")
chadwick6 <- read_csv("Data/chadwick/people-6.csv")
chadwick7 <- read_csv("Data/chadwick/people-7.csv")
chadwick8 <- read_csv("Data/chadwick/people-8.csv")
chadwick9 <- read_csv("Data/chadwick/people-9.csv")
chadwicka <- read_csv("Data/chadwick/people-a.csv")
chadwickb <- read_csv("Data/chadwick/people-b.csv")
chadwickc <- read_csv("Data/chadwick/people-c.csv")
chadwickd <- read_csv("Data/chadwick/people-d.csv")
chadwicke <- read_csv("Data/chadwick/people-e.csv")
chadwickf <- read_csv("Data/chadwick/people-f.csv")

people <- rbind(chadwick0, chadwick1, chadwick2, chadwick3, chadwick4, 
                chadwick5, chadwick6, chadwick7, chadwick8, chadwick9, 
                chadwicka, chadwickb, chadwickc, chadwickd, chadwicke, 
                chadwickf) %>%
    select(key_mlbam, key_bbref, key_fangraphs, name_last, name_first, 
           mlb_played_last) %>%
    filter(mlb_played_last %in% seq(2015, 2022)) %>%
    mutate(name = paste(name_first, name_last)) %>%
    select(name, key_mlbam, key_bbref, key_fangraphs)

write.csv(people, "Data/players_pos.csv", row.names=FALSE)