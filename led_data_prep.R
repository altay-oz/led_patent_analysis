library(RPostgreSQL)
library(stargazer)
library(dplyr)
library(magrittr)
library(lubridate)
library(countrycode)
library(rworldmap)

rm(list=ls())

drv <- dbDriver("PostgreSQL")
con <- dbConnect(drv, dbname="patstat")
dbListConnections(drv)
dbGetInfo(drv)
summary(con)

######################################################
## main data.frame all will be left_join
led.db <- dbGetQuery(con,"select * from led_t211")
names(led.db)

unique(led.db$publn_auth)

led.db %<>% select(appln_id, pat_publn_id, litigated, publn_date, publn_claims)

names(led.db)

######################################################
## appln_date
led.appln.date <- dbGetQuery(con,"SELECT t211.appln_id, t201.appln_filing_date
                                  FROM led_t211 t211, led_t201 t201
                                  WHERE t211.appln_id = t201.appln_id")

names(led.appln.date)


## join appln.date to led.db
led.db <- left_join(led.db, led.appln.date)

led.db[is.na(led.db$appln_filing_date), ] ## all filing date is OK

led.db %<>% select(appln_id, pat_publn_id, litigated, appln_filing_date, publn_date, publn_claims)

names(led.db)
nrow(led.db) ## 22 705

## min/max publication dates of ligigated patents
led.db %>% filter(litigated == 0) %>% summary

## min/max publication dates of ligigated patents
led.db %>% filter(litigated == 1) %>% summary


######################################################
## fwd_citation table limit with...
led.fwd <- dbGetQuery(con,"select * from led_fwd_citation")
names(led.fwd)

max(led.fwd$citing_appln_filing_date)
min(led.fwd$citing_appln_filing_date)

max(led.fwd$cited_appln_filing_date)
min(led.fwd$cited_appln_filing_date)

led.fwd %>% filter(citing_appln_filing_date == '9999-12-31') %>% nrow ## 7
## deleting the 7 rows.
led.fwd %<>% filter(citing_appln_filing_date != '9999-12-31')

names(led.fwd)

led.fwd$difftime <- as.numeric(difftime(led.fwd$citing_appln_filing_date,
                                        led.fwd$cited_appln_filing_date,
                                        units = "days"))

head(led.fwd)

## 5 years difference
5*365

nrow(led.fwd)

## five year span
led.fwd %<>% filter(difftime < 1830) %>% select(citing_publn_id, cited_pat_publn_id)
nrow(led.fwd) ## 55 829


head(led.fwd)

## number of fwd citation of the cited_pat_publn_id 
led.fwd %<>% group_by(cited_pat_publn_id) %>% count

names(led.fwd) <- c("pat_publn_id", "fwd.cit")

######################################################
##  backward citation
led.bckwd <- dbGetQuery(con,"select * from led_backward_citation")
names(led.bckwd)[2] <- "bck.cit"

######################################################
##  scientific citation
led.sci.cit <- dbGetQuery(con,"select * from led_sci_citation")
names(led.sci.cit)[2] <- "sci.cit"

######################################################
##  ipc count
led.ipc.count <- dbGetQuery(con,"select * from led_ipc_count")
names(led.ipc.count)[2] <- "ipc"

######################################################
##  patentees count
led.patentees <- dbGetQuery(con,"select * from led_patentees")
names(led.patentees)[2] <- "patentees"

######################################################
##  inventors count
led.inventors <- dbGetQuery(con,"select * from led_inventors")
names(led.inventors)[2] <- "inventors"

######################################################
##  legal status
led.legal <- dbGetQuery(con,"select * from led_legal")

######################################################
##  family size
led.family.size <- dbGetQuery(con,"select * from led_docdb_family")


names(led.legal)

led.legal.impact <- led.legal %>% select(appln_id, impact_num) %>%
    group_by(appln_id) %>% summarise(legal.sum.impact = sum(impact_num))

## check if it is OK 
led.legal.impact %>% filter(legal.sum.impact==max(legal.sum.impact))
led.legal %>% filter(appln_id == 48498237)
## it is OK

names(led.legal.impact)

led.analysis.db <- left_join(led.db, led.fwd) %>% left_join(., led.bckwd) %>%
    left_join(., led.sci.cit) %>% left_join(., led.ipc.count) %>%
    left_join(., led.patentees) %>% left_join(., led.inventors) %>%
    left_join(., led.family.size) %>% left_join(., led.legal.impact)


led.analysis.db[is.na(led.analysis.db)] <- 0

names(led.analysis.db)

led.analysis.db$litigated <- factor(led.analysis.db$litigated)

str(led.analysis.db)

saveRDS(led.analysis.db, "led_analysis_db_5_year.rds")

#########################################################

#####################################################################
#####################################################################
# publn_nr v. year, graph
drv <- dbDriver("PostgreSQL")
con <- dbConnect(drv, dbname="patstat")
dbListConnections(drv)
dbGetInfo(drv)
summary(con)

yearly.data <- dbGetQuery(con,
                       " SELECT date_Part('year', publn_date) as year,
                                count(publn_nr), publn_auth
                         FROM led_t211_complete
                         GROUP BY 1, 3 ORDER BY 1")

names(yearly.data)

unique(yearly.data$publn_auth)

yearly.data %<>% filter(publn_auth %in% c("CN", "TW", "JP", "EP", "KR", "US")
                        & year < 2014 & year > 1980) 

yearly.patent <- ggplot(yearly.data,
                        aes(x=year, y=count, group=publn_auth, linetype=publn_auth
                            )) +
    geom_line() +
    ylab("Number of first granted patents") +
    xlab("Year") +
    ggtitle("Yearly Published LED patents in top 6 patent offices") +
    theme(legend.title=element_blank())  + theme_bw()
yearly.patent

ggsave(filename="yearly_publsh_led_patent.pdf")

############################################################
############################################################
### country_code change it to continent
led.countries <- readRDS('./led_patentee_country.rds')
head(led.countries)

led.countries$continent <- countrycode(led.countries$person_ctry_code, 'iso2c', 'continent')

### a worldmap out of country code.
country.freq <- as.data.frame(table(led.countries$person_ctry_code) )

names(country.freq) <- c("country", "freq")

wmap <- joinCountryData2Map(country.freq, joinCode = "ISO2", nameJoinColumn = "country")

mapDevice("x11")
par(mai=c(0,0,1,0),xaxs="i",yaxs="i")
##png(filename="./breach_worldmap.pdf")

mapCountryData(wmap, nameColumnToPlot="freq", catMethod="pretty", addLegend = TRUE,
               colourPalette="white2Black", mapTitle="Number of patentee by country")

help(mapCountryData)

help(addMapLegendBoxes)

help(addMapLegend)

dev.print(pdf, 'led_worldmap.pdf')
odev.off()

help(dev.print)

str(country.freq)

arrange(country.freq, desc(freq)) %>% head

########################################################
########################################################
### joining and starting the analysis.

led.wo.continent <- readRDS('./led_analysis_db_5_year.rds')
led.cont <- led.countries %>% select(pat_publn_id, continent) %>% unique

nrow(led.wo.continent) ## 22 705
names(led.wo.continent)

nrow(led.cont) ## 23 404
length(unique(led.cont$pat_publn_id)) ## 22 615

led.cont.table <- as.data.frame(table(led.cont$pat_publn_id))

names(led.cont.table) <- c("pat_publn_id", "freq")

str(led.cont.table)

led.cont.table$pat_publn_id <- as.character(led.cont.table$pat_publn_id)
led.cont.table$pat_publn_id <- as.integer(led.cont.table$pat_publn_id)

## joined so that cross-continent patents are named 
led.continent <- left_join(led.cont, led.cont.table)

names(led.continent)

nrow(led.continent) ## 23 404 because some patents have multiple pantees from different continents. 

led.continent %>% filter(freq > 1) ## 1550 

## create a second colum to change multi-continent.
led.continent <- mutate(led.continent, continent.2 = ifelse(freq > 1, "multi-continent", continent))

led.continent %>% filter(continent.2 == "multi-continent")

table(led.continent$continent.2, useNA="ifany")

## group Africa, Oceania NA as others.
led.continent %<>% mutate(., continent.3 = ifelse(continent.2 == "Africa" |
                                        continent.2 == "Oceania" | is.na(continent.2) , "other",
                                        continent.2))

table(led.continent$continent.3, useNA="ifany")

nrow(led.continent) ## 23 404

led.continent %>% filter(freq > 1) %>% head ## 1550 

head(led.continent)

led.publnid.continent <- led.continent %>% select(pat_publn_id, continent.3) %>% unique

nrow(led.publnid.continent) ## 22 615

length(unique(led.publnid.continent$pat_publn_id)) ## 22 615

## led.countries to led.db 
names(led.wo.continent)
names(led.publnid.continent)

led.db <- left_join(led.wo.continent, led.publnid.continent)
nrow(led.db) ## 22 705

str(led.db)

names(led.db)[names(led.db) == 'continent.3'] <- 'continent'

table(led.db$continent, useNA="ifany")

led.db %<>% mutate(., continent = ifelse(continent == "Africa" |
                                        continent == "Oceania" | is.na(continent) , "other",
                                        continent))

table(led.db$continent)


led.db$continent <- factor(led.db$continent)
table(led.db$continent)

led.db$continent <- relevel(led.db$continent, "other")

## ok our db is done.
saveRDS(led.db, './led_db.rds')

##########################################################
#########################   END
##########################################################
##########################################################

