library(tidyverse)

all_pitchers <- read.csv("Data/clustered_pitches.csv")

relief_pitchers <- read.csv("Data/relief_pitchers.csv")

starting_pitchers <- setdiff(select(all_pitchers, -clusters), relief_pitchers)

reliever_clusters <- reliever_clusters <- merge(all_pitchers, relief_pitchers, 
                                                by = c("pitcher", "game_year"), 
                                                all.x = FALSE, all.y = TRUE)

starter_clusters <- anti_join(all_pitchers, reliever_clusters,
                              by = c("pitcher", "game_year"))

starter_counts <- starter_clusters %>%
    group_by(clusters) %>%
    summarize(num_pitchers = n_distinct(pitcher) / nrow(starter_clusters)) %>%
    complete(clusters = 0:9, fill = list(num_pitchers = 0))

reliever_counts <- reliever_clusters %>%
    group_by(clusters) %>%
    summarize(num_pitchers = n_distinct(pitcher) / nrow(reliever_clusters)) %>%
    complete(clusters = 0:9, fill = list(num_pitchers = 0))

counts <- rbind(starter_counts, reliever_counts)
counts$group <- rep(c("Starters", "Relievers"), each = 10)

ggplot(counts, aes(x = as.factor(clusters), y = num_pitchers, fill = group)) +
    geom_bar(stat = "identity", position = position_dodge()) +
    geom_line(aes(group = group, linetype = group), position = position_dodge(width = 0.9)) +
    scale_fill_manual(values = c("green3", "red"), name = "") +
    scale_linetype_manual(values = c("dashed", "solid"), name = "") +
    xlab("Clusters") +
    ylab("Percentage of Pitchers per Cluster") +
    ggtitle("Comparison of Clusters between Starters and Relievers") +
    theme(plot.title = element_text(hjust = 0.5))