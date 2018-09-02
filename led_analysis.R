library(glmx)
library(stargazer)
library(dplyr)
library(xtable)
library(RPostgreSQL)
library(ggplot2)
library(pscl)
library(magrittr)
library(psych)

rm(list=ls())

led.db <- readRDS('./led_db.rds')

min(led.db$publn_date) ## 1954-07-13
max(led.db$publn_date) ## 2015-07-28

min(led.db$appln_filing_date) ## 1951-12-27
max(led.db$appln_filing_date) ## 2014-12-30

led.db %>% filter(litigated==1) %>% filter(appln_filing_date == min(appln_filing_date))
## 1988-03-28

led.db %>% filter(litigated==1) %>% filter(appln_filing_date == max(appln_filing_date))
## 2010-06-09 | publn = 2011-04-19

nrow(led.db)
## remove patents before 1968. and publn_date after 2014-01-01
led.db %<>% filter(appln_filing_date > "1968-03-28") %>% filter(publn_date < "2014-01-01")
nrow(led.db) ### 17 769

## before 2000
led.db.b2005 <- led.db %>% filter(appln_filing_date < "2005-01-01")

## after 2000
led.db.a2005 <- led.db %>% filter(appln_filing_date > "2005-01-01") 

write.csv(led.db.a2005, "led_db_a2005.csv")
write.csv(led.db.b2005, "led_db_b2005.csv")
write.csv(led.db, "led_db.csv")


logit.model <- litigated ~ publn_claims + fwd.cit + bck.cit +
    sci.cit + ipc + patentees + inventors + docdb_family_size +
    continent

## logit.result <- hetglm(logit.model, data = led.db,
##                        family = binomial(link = "logit"))

## logit.result.b2005 <- hetglm(logit.model, data = led.db.b2005,
##                              family = binomial(link = "logit"))

## logit.result.a2005 <- hetglm(logit.model, data = led.db.a2005,
##                              family = binomial(link = "logit"))

## stargazer(logit.result.b2005, logit.result.a2005, logit.result, 
##           type="text")

##########################

logit.model <- litigated ~ publn_claims + fwd.cit + bck.cit +
    sci.cit + ipc + patentees + inventors + docdb_family_size +
    continent

logit.result.b2005 <- glm(logit.model, data = led.db.b2005,
                             family = binomial(link = "logit"))

logit.result.a2005 <- glm(logit.model, data = led.db.a2005,
                             family = binomial(link = "logit"))

logit.result <- glm(logit.model, data = led.db,
                       family = binomial(link = "logit"))


summary(logit.result.b2005)
summary(logit.result.a2005)
summary(logit.result)

## wald test for the overall effect of the continent.
library(aod)

wald.test(b=coef(logit.result.b2005), Sigma=vcov(logit.result.b2005), Terms=10:13)

wald.test(b=coef(logit.result.a2005), Sigma=vcov(logit.result.a2005), Terms=10:13)

wald.test(b=coef(logit.result), Sigma=vcov(logit.result), Terms=10:13)

stargazer(list(logit.result.b2005, logit.result.a2005, logit.result), 
          type="text")

stargazer(list(logit.result.b2005, logit.result.a2005, logit.result), 
          type="html", out="/tmp/logit_final.html")

## mac faden R2
pR2(logit.result.b2005)
pR2(logit.result.a2005)
pR2(logit.result)

## relative risk ratios
logit.or.b2005 <- exp(coef(logit.result.b2005))
logit.or.a2005 <- exp(coef(logit.result.a2005))
logit.or <- exp(coef(logit.result))

stargazer(list(logit.result.b2005, logit.result.a2005, logit.result), 
          type="text", coef=list(logit.or.b2005, logit.or.a2005, logit.or), p.auto=FALSE)

stargazer(list(logit.result.b2005, logit.result.a2005, logit.result), 
          type="html", coef=list(logit.or.b2005, logit.or.a2005, logit.or),
          p.auto=FALSE, out='/tmp/rrr.html')

########################################################
## desc.stat + correlation matrix
table(led.db$continent, useNA="ifany")

names(led.db)

selected_cols <- c("publn_claims", "fwd.cit", "bck.cit", "sci.cit",
    "ipc", "patentees", "inventors", "docdb_family_size")

desc.data <- led.db %>% select(selected_cols)
 
desc.data.litigated <- led.db %>% filter(litigated == 1) %>% select(selected_cols)

desc.data.non.litigated <- led.db %>% filter(litigated == 0) %>% select(selected_cols)

str(desc.data)

cor.mat <- cor(desc.data)

cor.mat[upper.tri(cor.mat)] <- NA                                               
                                                                                
cor.mat <- round(cor.mat, digits = 3)

dim(cor.mat)                                                                    
                                                                                
colnames(cor.mat) <- 1:8                                                        
numbered.row <- 1:8                                                        
cor.mat <- cbind(as.character(numbered.row), cor.mat)                           
colnames(cor.mat)[1] <- ""                                                      
                                                                                
colnames(cor.mat) 

cor.mat.table <- xtable(cor.mat, digits = 3, caption = "Pearson correalation matrix.")
print(cor.mat.table, type="html", file="/tmp/led_cor_mat.html")   

########################################################
## desc.stat

desc.stat.out <- function(desc.data){
    desc.E <- describe(desc.data)

    desc.toprint <- desc.E[,c("n","mean","sd", "se", "median", "min", "max")]       
    desc.toprint$n <- as.character(desc.toprint$n)                                  
    names(desc.toprint)[1] <- "N"                                                   


    desc.stat.table <- xtable(desc.toprint, label="descriptive_stat",                       
                              caption="Descriptive statistics.")

    return(desc.stat.table)    

}

desc.stat.table <- desc.stat.out(desc.data)
print(desc.stat.table, type="html", file="/tmp/led_desc_table.html")

desc.stat.table <- desc.stat.out(desc.data.litigated)
print(desc.stat.table, type="html", file="/tmp/led_desc_table_litigated.html")

desc.stat.table <- desc.stat.out(desc.data.non.litigated)
print(desc.stat.table, type="html", file="/tmp/led_desc_table_NON_litigated.html")


