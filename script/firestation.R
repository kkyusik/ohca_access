#' @title data_firestation
#' @initialized 7-21-23
#' @description
#'      데이터는 data.go.kr에서 다운받으며, 소방청 전국 소방서 및 119 안전센터 정보 2021년 12월 31일 자료임. 
#' @update


source("load_pkgs.R")
load_pkgs(c("tidyverse", "tmap", "sf", "here", "openxlsx", "data.table"))


poi <- read_csv("./data/raw/firestation_sido_20200121.csv", skip=1)
poi

poi <- poi %>%
        filter(grepl("충북|세종|대전|충남", 본부명))
poi

firestation <- read.csv("./data/raw/firestation_sido_2021.12.31.csv") %>%
        as_tibble# 소방서
firestation

firesafe <- read.csv("./data/raw/fire_safe_2021.csv") %>% as_tibble

firesafe


firestation <- firestation %>%
        filter(본부명 %in% c("세종", "대전", "충북", "충남"))
firestation <- firestation %>%
        select(본부명, 소방서, 주소)
firesafe <- firesafe %>%
        filter(시도본부 %in% c("세종", "대전", "충북", "충남")) %>%
        select(시도본부, 소방서, X119안전센터명, 주소)


# geocoding
library(jsonlite)
library(httr)

## API 활용 기본정보 입력
# NAVER 용
naver_API_ID<-'8m6hkay386'
naver_API_key<-'ehKVpacsL8sYrV7nPLox9nopzR0LxmFU4OMRdw3L'

url<-"https://naveropenapi.apigw.ntruss.com/map-geocode/v2/geocode" # geocoding

df <- firestation
for (row in 1:nrow(df)){
        
        query <- df[row, "주소"]
        addr_json <- GET(url = url,
                         query = list(query=query), 
                         add_headers("X-NCP-APIGW-API-KEY-ID"= naver_API_ID,
                                     "X-NCP-APIGW-API-KEY" = naver_API_key,
                                     Accept="application/json")) %>%
                content(as="text") %>%
                fromJSON()
        
        tmp <- tibble(addr_json$addresses)
        if (nrow(tmp) != 0) {
                df[row, "x"] <- tmp[1, "x"]
                df[row, "y"] <- tmp[1, "y"]
        }
        
        cat(row, "/", nrow(df), "\n")
}

firestation <- df

df <- firesafe
for (row in 1:nrow(df)){
        
        query <- df[row, "주소"]
        addr_json <- GET(url = url,
                         query = list(query=query), 
                         add_headers("X-NCP-APIGW-API-KEY-ID"= naver_API_ID,
                                     "X-NCP-APIGW-API-KEY" = naver_API_key,
                                     Accept="application/json")) %>%
                content(as="text") %>%
                fromJSON()
        
        tmp <- tibble(addr_json$addresses)
        if (nrow(tmp) != 0) {
                df[row, "x"] <- tmp[1, "x"]
                df[row, "y"] <- tmp[1, "y"]
        }
        
        cat(row, "/", nrow(df), "\n")
}

df %>% filter(is.na(x))
firesafe <- df


firestation$type <- "소방서"
firesafe$type <- "안전센터"

firestation <- firestation %>% rename(name = 소방서)
firestation <- firestation %>% rename(시도본부 = 본부명)
firesafe <- firesafe %>% rename(name = X119안전센터명)
firesafe <- firesafe %>% select(-소방서)
poi <- rbind.data.frame(firestation, firesafe)
poi <- poi %>% filter(!is.na(x))

# xy to point(geom)
poi <- st_as_sf(poi, coords = c("x", "y"), crs=4326)
qtm(poi)

# Get poi within study area
studyarea <- read_sf("./data/tidy/study_area_sgg.gpkg")
studyarea_buffer <- read_sf("./data/tidy/study_area_buffer_sgg.gpkg")
poi <- st_transform(poi, st_crs(studyarea))

idx <- st_intersects(poi, studyarea_buffer, sparse = TRUE)
poi <- poi[which(lengths(idx) > 0), ]

poi <- poi %>% mutate(id = paste0("fire_", 1:nrow(poi)))

qtm(studyarea_buffer) + qtm(studyarea) + qtm(poi)

# export firestations and safecenters
st_write(poi, "./data/tidy/poi_fire.gpkg", delete_layer = TRUE)

