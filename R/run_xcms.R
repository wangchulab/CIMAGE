args <- commandArgs(trailingOnly=T)
### I/O options ###
folder1 <- args[1]
folder2 <- args[2]

args <- commandArgs(trailingOnly=T)
if(length(args) >= 2) {
  folder1 <- args[1]
  folder2 <- args[2]
}
cat(folder1)
cat(folder2)

result <- "results"
###################
library(xcms)
xset<-xcmsSet()
xset<-group(xset)
xset.list <- list()
xset.list[[length(xset.list)+1]] <- xset.cur <- xset

last.rtcg.num <- rtcg.num <- 0
do.retcor <- T
count <- 0
while( do.retcor ) {
  Sys.sleep(1)
  last.rtcg.num <- rtcg.num
  sink("xcms.rtcg.out",split=T)
  count <- count + 1
  png(paste("retcor_",count,".png",sep=""))
  xset.new <- retcor(xset.cur, family="s", plottype="m")
  dev.off()
  sink()
  rtcg.sink <- read.table("xcms.rtcg.out",header=F)
  rtcg.num <- rtcg.sink[1,5]
  xset.new <- group(xset.new,bw=10)
  xset.list[[length(xset.list)+1]] <- xset.cur <- xset.new
  do.retcor <- ( last.rtcg.num != rtcg.num )
}

xset.new <-fillPeaks(xset.cur)
reporttab<-diffreport(xset.new, folder1, folder2, result, 500, metlin=0.15)
