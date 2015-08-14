library(xcms)
source("/home/chuwang/svnrepos/R/msisotope.R")

## file name from input args
args <- commandArgs(trailingOnly=T)

infile <- read.table(args[1],sep="\t", header=T)

n.row <- 3
n.col <- 2
Hplus.mass <- 1.0072765
mz.ppm.cut <- 10e-6

out.filename <- paste("PlotAPEH",".pdf",sep="")
##
input.path <- getwd()
mzXML.names <- list.files(path="./",pattern="mzXML$",ignore.case=T)
mzXML.files <- as.list( mzXML.names )
names(mzXML.files) <- mzXML.names
raw.ECI <- mzXML.files
for (name in mzXML.names) {
  cat(paste(name,"\n",sep=""))
  mzXML.files[[name]] <- xcmsRaw( paste("./",name,sep=""))
}
name.matrix<- matrix(unlist(strsplit(mzXML.names,".",fixed=T)),ncol=2,byrow=T)
enz.names <- levels(as.factor(name.matrix[,1]))
mock <- grep("veh",name.matrix[,1])
mock.exist <- length(mock) > 0

pdf( out.filename)
par(mfrow=c(n.row,n.col))
par(oma=c(0,0,5,0), las=0)

for (i in 1:nrow(infile)) {
##for (i in 1:1) {
  mh <- infile[i,"MH"]
  seq <- infile[i,"Sequence"]
  protein <- infile[i, "Protein"]
  for (charge in 1:6) {
    mz  <- (mh + (charge-1)*Hplus.mass)/charge
    mz.low <- mz*(1-mz.ppm.cut)
    mz.high <- mz*(1+mz.ppm.cut)
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
    raw.ECI.rt <- xfile@scantime[ raw.ECI[[name]][[1]][1:rt.high] ]
    tt.main <- paste("Charge: ", charge,"; M/Z:", round(mz,digits=4),
                     "; NL:", formatC(int.high, digits=2, format="e"))
    count <- 0
    for (name in mzXML.names) {
      count <- count + 1
      if ( length(grep("veh",name)) > 0) {
        color <- "black"
      } else {
        color <- "red"
      }
      xlimit <- c(1,rt.high)
      ylimit <- c(int.low,int.high)
      ## plot non-enz
      if (count == 1) {
        plot(raw.ECI[[name]][[1]], raw.ECI[[name]][[2]], type="l", col=color,xlab="Retention Time(min)",
             ylab="intensity", main=tt.main, xlim=xlimit, ylim=ylimit)
      } else {
        lines(raw.ECI[[name]][[1]], raw.ECI[[name]][[2]], col=color, xlim=xlimit, ylim=ylimit)
      }
    }
  }
  mtext(protein, line=3.5, outer=T)
  mtext(paste(seq, "; MH+: ", mh,sep=""), cex=0.8, line=2,outer=T)
}
dev.off()
