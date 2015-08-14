library(xcms)
source("/home/chuwang/svnrepos/R/msisotope.R")

table1 <- read.table("file.list",header=T)
table2 <- read.table("mass.list",header=T)

files <- as.list(as.character(table1[,"file"]))
names(files) <- names <- files
charges <- seq(1,1)
masses <- table2[,"mass"]
ppm <- 15*1e-6
Hplus <- 1.0072765

#postscript("output.ps",horizontal=T)
postscript("output.ps",paper="letter")
par(mfrow=c(3,2), oma=c(0,0,5,0))
for (i in 1:length(files)) {
  files[[i]] <- xcmsRaw( names(files)[i], profstep=0)
}

for ( m in 1:length(masses) ) {
  mass <- masses[m]
  for ( i in 1:length(files) ) {
    xfile <- files[[i]]
    name <- names[[i]]
    for ( j in 1:length(charges) ){
      charge <- charges[j]
      mz <- mass/charge + Hplus
      mr <- c( mz*(1-ppm), mz*(1+ppm) )
      raw.ECI <- rawEIC(xfile, mr)
      raw.ECI.rt <- xfile@scantime[raw.ECI[[1]]]/60
      ylimit <- max(raw.ECI[[2]])
      plot(raw.ECI.rt, raw.ECI[[2]], type="l",xlab="RT(min)", ylab="intensity",
           main=paste("mz: ", as.character(round(mz, digits=5)), "; charge: ", j,
             "; NL: ", formatC(ylimit, digits=2, format="e")))
      noise <- estimateChromPeakNoise(raw.ECI[[2]])
      if (noise < 10) next
      raw.spec <- cbind(raw.ECI.rt, raw.ECI[[2]])
      dimnames(raw.spec)[[2]] <- c("rt","intensity")
      peaks <- findChromPeaks( raw.spec, noise)
      if (nrow(peaks)>0) {
        for ( k in 1:nrow(peaks) ) {
          rt <- peaks[k,"rt"]
          rt.min <- peaks[k,"rt.min"]
          rt.max <- peaks[k,"rt.max"]
          peak.scan.num <- raw.ECI[[1]][raw.ECI.rt == rt ]
          peak.scan.int <- raw.ECI[[2]][raw.ECI.rt == rt ]
          if ( peak.scan.int < 1e4 ) next
          peak.scan <- getScan(xfile, peak.scan.num, massrange=c(mass/charge-2, mass/charge+4 ))
          predicted.dist <- isotope.dist( averagine.count(mass) )
          mono.check <- checkChargeAndMonoMass( peak.scan, mass, charge, ppm, predicted.dist)
          if (mono.check > 0.8) {
            lines(c(rt,rt),c(ylimit*0.9,ylimit),col="green",lty=1)
          }
        }
      }
    }
    mtext(paste("Mass of ", as.character(format(mass,digits=7)), " in ", name), outer=T)
  }
}

dev.off()

