library(data.table)
library(magrittr)
setwd("~/IPlytics/challenge-data-engineer/")

standards <-
  data.table::fread("dumps/standards.csv",
                    sep = ",",
                    sep2 = " | ")


# figure out primary keys of standards
all.equal(unique(standards), standards)
standards[, nrow(.SD),
          by = c("Version History")
          ][,
            all(V1 == 1)]


head(standards)
standards$`Original Document` %>% unique %>% length %>% `==`(., nrow(standards))

nrow(standards)

# unique titles:
standards$Title %>% unique %>% lapply(FUN = function(title){
  standards[title, on="Title"]
})

standards[, .(length(unique(`Title`)), length(unique(`Version History`))), by="Technology Generation"]

count <- function(x) {
  return(length(unique(x))) 
}

standards[, count(`Title`), by="Technology Generation"]
standards[, count(`Technology Generation`), by="Title"]
standards[, count(`Standard Project`), by="Author"]
standards[Author == "Maurice Pope | Sabine Demel", unique(`Standard Project`)]

##########
declarations <-
  data.table::fread("dumps/declarations.csv",
                    sep = ",",
                    sep2 = " | ") # there are duplicate rows in this csv

# figure out the compount primary key of declarations:
unique(declarations)[, nrow(.SD),
             by = c(
               "Standard Project",
               "Publication Nr.",
               "Declaration Date",
               "Standard Document ID"
             )][, all(V1 == 1)]

declarations[, list(unique(`Standard Document ID`)), by=`Standard Project`]

declarations[, count(`Standard Project`), by="Application Nr."]

declarations[standards, on=c(`Standard Document ID`="Standard Document Id"), nomatch=NULL]

###
patents <-
  data.table::fread("dumps/patents.csv",
                    sep=",",
                    sep2=" | ")

# check that publication nr. can be a primary key
patents[, nrow(.SD), by="Publication Nr."][, all(V1 == 1)] # check

patents[, nrow(.SD), by="INPADOC Family ID"] # families can include multiple applications to the same country.

tripleInner <-
  patents[declarations,
          on = "Publication Nr.", nomatch = NULL][
            standards, on = c(`Standard Document ID` = "Standard Document Id"),
            nomatch = NULL]


