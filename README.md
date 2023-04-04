# Predicting Strikeout Percentage for Relief Pitchers Based on MLB Pitch Data


### Luke VanHouten
### Baseball Analytics DRP 
### Winter 2023

## Context and Setup
This project is to predict the strikeout percentage of pitchers given information about the pitches they throw as well as the contexts of when they are thrown. The primary source for the data used is a PostrgreSQL database of MLB Statcast pitch data scraped from BaseballSavant. There is a helper R script to build this database included called `database.R`, which is borrowed from a [tutorial created by Bill Petti](https://billpetti.github.io/2021-04-02-build-statcast-database-rstats-version-3.0/). The database should be created with the following fields:

```bash
user = 'postgres',
password = 'drppassword',
host = 'localhost',
port = 5432
```

The data should be between 2015 and 2021. I ommitted 2020 data in my original analysis, but this is not necessary. As a result, any predictions made may be different than the ones I made. In order to create this database, simply hit the source button in RStudio to run `database.R`. Next, for the prediciton script the libraries `DBI`, `RPostgres`, `RSQLite`, `tidyverse`, and `xgboost` will need to be installed with the `install.packages()` function. The `baseballr` library will need to be installed for numerous helper scripts, as well as the `RPostgreSQL` and `mclust` libraries for `database.R` and `clustering.R`, respectively.

## Running the Model

Simply hit the source button in RStudio to run `final.R` for the model. It will create numerous dataframes for the different subsets of data used, the model with the lowest mean absolute error as well as relevant information for it, and dataframes and a chart detailing feature importance. To plot the distribution of the number of pitch clusters between starters and relievers, run the `clusters_plot.R` file. The rest of the helper scripts provide .csv files that have already been created, and thus do not need to be ran.

## Article

I wrote a lengthy article about this project on Medium. The article can be found [here](https://medium.com/).

## To-Do

- Add 2020 and 2022 years

- Fix position players pitching

- Improve pitch clustering
