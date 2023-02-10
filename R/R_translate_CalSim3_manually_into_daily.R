# Identify your working directory for saving outputs of interest
root <- "~/GitHub/WRCML_LTO_ROC"
setwd(root)

code_root <- file.path(root,"R")
output_root <- file.path(root,"Hydro model output")

library(tidyverse)
library(stringr)
library(lubridate)
library(rJava)


#############
#Read csv file
NAA_data<-read.csv(file.path(output_root,"NAA_CalSim3_data.csv")) %>% mutate(Date=as.Date(Date))
str(NAA_data)

############
#Convert data from monthly to daily based on monthly averages

#Create a vector of dates
datelist <- seq(as.Date("1921-11-01"), as.Date("2021-09-30"), by = "day")

#Create function to convert
month_to_daily<- function(data_in=NAA_data){
  data_in<-data_in %>% mutate(Year=year(Date),Month=month(Date))
  newdata<-data.frame(Date=datelist,Month=month(datelist),Year=year(datelist)) %>%
    left_join(data_in %>% select(-Date))
  return(newdata)
}

daily_NAA<-month_to_daily()
