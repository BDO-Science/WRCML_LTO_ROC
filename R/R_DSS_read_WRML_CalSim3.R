# Identify your working directory for saving outputs of interest
root <- "~/GitHub/WRCML_LTO_ROC"
setwd(root)

code_root <- file.path(root,"R")
output_root <- file.path(root,"Hydro model output")

# The following libraries need to be installed and loaded
# NOTE: You also need to have HEC-DSSVue installed on your computer
# See: https://www.hec.usace.army.mil/software/hec-dssvue/downloads.aspx

library(tidyverse)
library(stringr)
library(lubridate)
library(rJava)


#############
#Read DSS file

# The following function for is used for turning CalSim time stamps into R dates. 

from_time_stamp <- function(x) {
  day_ref <- as.Date("1899-12-30")
  return(day_ref+x/1440)
}



# Run this workaround if your R session crashes when running .jinit() - below
# This issue occurs in base R versions 4.2 and later
# In lieu of this workaround, you can also install a patched R version 
# E.g., https://cran.r-project.org/bin/windows/base/rpatched.html

replacement <- function(category = "LC_ALL") {
  
  if (identical(category, "LC_MESSAGES"))
    return("")
  
  category <- match(category, .LC.categories)
  if (is.na(category)) 
    stop("invalid 'category' argument")
  .Internal(Sys.getlocale(category))
  
}
base <- asNamespace("base")
environment(replacement) <- base
unlockBinding("Sys.getlocale", base)
assign("Sys.getlocale", replacement, envir = base)
lockBinding("Sys.getlocale", base)


# This code establishes your java connection with HEC-DSSVue

# Specify your own location for 'HEC-DSSVue'
dss_location <- "C:\\Program Files\\HEC\\HEC-DSSVue\\" 

# Specify your own location for the 'jar' sub-folder
# This identifies all possible java executables that meet be needed
jars <- c(list.files("C:\\Program Files\\HEC\\HEC-DSSVue\\jar")) 

jars <- paste0(dss_location, "jar/", jars)

# Specify your own location for the 'lib' sub-folder
libs <- "-Djava.library.path=C:\\Program Files\\HEC\\HEC-DSSVue\\lib\\"

.jinit(classpath = jars, parameters = libs)

##########
# Function to assemble the dataset

# Identify the DSS file you want to access with dss_input

dss_data_pull_WRML<-function(dss_input="D:\\2023-01-06 - CalSim3 example file for ReROC\\CalSim3_2040MED_120722_DRAFT_wDWRv705update_wCCdraftBC\\DSS\\output\\CS3_L2020_DV_2021_ext_2040MED"){
  # Open the DSS file through rJava
  dssFile <- .jcall("hec/heclib/dss/HecDss", "Lhec/heclib/dss/HecDss;",   method="open", dss_input)
  #Sacramento River flow at Freeport (SAC Dayflow)
  java.SAC <- dssFile$get("/CALSIM/C_SAC049/CHANNEL//1MON/L2020A/") 
  SAC=data.frame(Date=java.SAC$times %>% from_time_stamp,SAC=java.SAC$values)
  #San Joaquin River flow at Vernalis (SJR Dayflow)
  java.SJR <- dssFile$get("/CALSIM/C_SJR070/CHANNEL//1MON/L2020A/") 
  SJR=data.frame(Date=java.SJR$times %>% from_time_stamp,SJR=java.SJR$values)
  #Yolo Bypass flow (YOLO Dayflow)
  java.YOLO <- dssFile$get("/CALSIM/C_YBP020/CHANNEL//1MON/L2020A/") 
  YOLO=data.frame(Date=java.YOLO$times %>% from_time_stamp,YOLO=java.YOLO$values)
  #Export values from Delta Export Facilities (EXPORT Dayflow)
  java.EXPORT1 <- dssFile$get("/CALSIM/D_OMR028_DMC000/DIVERSION//1MON/L2020A/") 
  java.EXPORT2 <- dssFile$get("/CALSIM/D_OMR027_CAA000/DIVERSION//1MON/L2020A/") 
  EXPORT=data.frame(Date=java.EXPORT1$times %>% from_time_stamp,EXPORT=java.EXPORT1$values+java.EXPORT2$values)
  #Bend Bridge flow (RBDD Flow from BND station)
  java.BND <- dssFile$get("/CALSIM/C_SAC257/CHANNEL//1MON/L2020A/") 
  BND=data.frame(Date=java.BND$times %>% from_time_stamp,BND_flow=java.BND$values)
  #Delta Cross Channel ops
  java.DCC <- dssFile$get("/CALSIM/DXC/GATE-DAYS-OPEN//1MON/L2020A/") 
  DCC=data.frame(Date=java.DCC$times %>% from_time_stamp,DCC=java.DCC$values)
  
  final_data_frame= SAC %>% left_join(SJR) %>% left_join(YOLO) %>% left_join(EXPORT) %>% left_join(BND) %>% left_join(DCC)
  return(final_data_frame)
}

#Use the function to create data frame
NAA_data <- dss_data_pull_WRML()
#D1641_data <- dss_data_pull_WRML(dss_input="")

#Export DSS output files for WRML model input
write.csv(NAA_data,file.path(output_root,"NAA_CalSim3_data.csv"),row.names=F)

