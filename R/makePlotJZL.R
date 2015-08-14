library(xcms)
source("/home/chuwang/svnrepos/R/msisotope.R")

## file name from input args
args <- commandArgs(trailingOnly=T)
mz.start <- as.numeric(args[1])
mz.end <- as.numeric(args[2])
mz.bin <- as.numeric(args[3])

n.enz <- as.numeric(args[4])

n.row <- as.numeric(args[5])
n.col <- as.numeric(args[6])

file.type <- as.character(args[7])

n.empty  <- n.row*n.col-n.enz

out.filename <- paste("PlotJZL",mz.start,"_",mz.end,"_",mz.bin,".ps",sep="")
mzs <- seq(mz.start, mz.end, by=mz.bin)

##
input.path <- getwd()
if ( file.type == 'XML' ) {
  mzXML.names <- list.files(path="./",pattern="mzdata.xml$",ignore.case=T)
  name.col <- 4
}
if ( file.type == 'CDF' ) {
  mzXML.names <- list.files(path="./",pattern="CDF$",ignore.case=T)
  name.col <- 3
}
mzXML.files <- as.list( mzXML.names )
names(mzXML.files) <- mzXML.names
raw.ECI <- mzXML.files
for (name in mzXML.names) {
  cat(paste(name,"\n",sep=""))
  mzXML.files[[name]] <- xcmsRaw( paste("./",name,sep=""))
}
name.matrix<- matrix(unlist(strsplit(mzXML.names,".",fixed=T)),ncol=name.col,byrow=T)
enz.names <- levels(as.factor(name.matrix[,1]))
mock <- name.matrix[,1]=="mock"
mock.exist <- sum(mock) > 0

postscript( out.filename, horizontal=T)
par(mfrow=c(n.row,n.col))
par(oma=c(0,0,5,0), las=0)

for ( mz in mzs ) {
  mz.low <- mz
  mz.high <- mz+mz.bin
  int.low <- 100000
  int.high <- 100
  rt.low <- 0
  rt.high <- 1000000
  for (name in mzXML.names) {
    xfile <- mzXML.files[[name]]
    raw.ECI[[name]] <- rawEIC(xfile, c(mz.low, mz.high))
    int.low <- min(raw.ECI[[name]][[2]], int.low)
    int.high <- max(raw.ECI[[name]][[2]], int.high)
    rt.high <- min(max(raw.ECI[[name]][[1]]), rt.high)
  }
  raw.ECI.rt <- xfile@scantime[ raw.ECI[[name]][[1]][1:rt.high] ] / 60
  tt.main <- paste("M/Z:", mz.low, "-", mz.high, "; NL:", formatC(int.high, digits=2, format="e"))
  for (enz in enz.names) {
    if ( enz == "mock" ) next
    is.enz <- (name.matrix[,1] == enz)
    if ( mock.exist ) {
      non.enz.matrix <- name.matrix[mock,]
    } else {
      non.enz.matrix <- name.matrix[!is.enz,]
    }
    non.enz.int <- rep(0,rt.high)
    for (i in 1:nrow(non.enz.matrix)) {
      name <- paste(non.enz.matrix[i,],collapse=".")
      non.enz.int <- non.enz.int + raw.ECI[[name]][[2]][1:rt.high]
    }
    non.enz.int <- non.enz.int / nrow(non.enz.matrix)

    is.enz.matrix <- name.matrix[is.enz,]
    is.enz.int <- rep(0,rt.high)
    for (i in 1:nrow(is.enz.matrix)) {
      name <- paste(is.enz.matrix[i,],collapse=".")
      is.enz.int <- is.enz.int + raw.ECI[[name]][[2]][1:rt.high]
      ##lines(raw.ECI.rt, raw.ECI[[name]][[2]][1:rt.high], col='red', xlim=range(raw.ECI.rt),
      ##      ylim=c(int.low,int.high) )
    }
    is.enz.int <- is.enz.int / nrow(is.enz.matrix)
    xlimit <- range(raw.ECI.rt)
    ylimit <- range(non.enz.int, is.enz.int)
    ## plot non-enz
    plot(raw.ECI.rt, is.enz.int, type="l", col="red",xlab="Retention Time(min)",
         ylab="intensity", main=enz, xlim=xlimit, ylim=ylimit)
    ## plot is.enz
    lines(raw.ECI.rt, non.enz.int, col='black', xlim=xlimit,ylim=ylimit)
  }
  mtext(tt.main, line=3, outer=T)
  if ( n.empty > 0 ) {
    for (i in 1:n.empty) {
      frame()
    }
  }
}
dev.off()

