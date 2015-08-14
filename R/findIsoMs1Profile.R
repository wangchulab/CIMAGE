library(xcms)

input.path <- "C:/cygwin/home/chuwang/light/"
input.file.base <- "test"
input.file.suffix <-".mzXML"
output.path <- paste(input.path,"xcms_plot/",sep="")
output.file.base <- paste(input.file.base,"doublet",sep="_")
output.file.suffix <- ".png"

filename <- paste(input.path, input.file.base, input.file.suffix, sep="")
xfile <- xcmsRaw( filename )

xpeaks <- findPeaks(xfile,snthresh=2.0)
num.peaks <- dim(xpeaks)[1]
rownames(xpeaks) <- seq(1, num.peaks)

# sort the matrix by retention time first
xpeaks <- xpeaks[order(xpeaks[,"rt"]), ]

# within 5 sec of retention window
rt.cut <- 5.0

mz.ppm.cut <- 0.00002 # 20ppm
# From Eranthie's isotopically labeled probe
pair.mass.delta <- 6.01381
# nature mass difference between C12 and C13
isotope.mass.unit <- 1.00286864
# possible charge states
charge.states <- seq(1,5)
# peak intensity ratio
intensity.tag <- "maxo" #
intensity.ratio.range <- c(0.5,2.0) # ratio of intensity of heavy and light peaks


# make a fresh empty list
n.nonredundant.hit <- 0
pair.list <- NULL

for ( rt in levels(factor(xpeaks[,"rt"])) ) {
  this.rt <- factor(xpeaks[,"rt"]) == rt
  if ( sum(this.rt) <= 1 ) next
  # get all peaks with this retension time and sort by mz
  xpeaks.this.rt <- xpeaks[this.rt,]
  xpeaks.this.rt <- xpeaks.this.rt[order(xpeaks.this.rt[,"mz"]), ]
  mz.this.rt <- xpeaks.this.rt[,"mz"]
  num.mz.this.rt <- length( mz.this.rt )
  mz.delta <- matrix(0, num.mz.this.rt, num.mz.this.rt, dimnames=list(names(mz.this.rt), names(mz.this.rt) ) )
  mz.delta.ppm <- mz.delta # tolerance matrix

  for (i in 1:num.mz.this.rt ) {
    for ( j in i:num.mz.this.rt ) {
      mz.delta[i,j] <- mz.delta[j,i] <- abs(mz.this.rt[i] - mz.this.rt[j])
      mz.delta.ppm[i,j] <- mz.delta.ppm[j,i]  <- mz.ppm.cut * ( mz.this.rt[i]+mz.this.rt[j] ) / 2.0
    }
  }
  for (charge in charge.states) {
    pair.list.this.charge <- NULL
    pair.mz.delta <- pair.mass.delta / charge
    mz.delta.pass <- abs(mz.delta - pair.mz.delta) < mz.delta.ppm
    for (i in 1:num.mz.this.rt ) {
      for ( j in i:num.mz.this.rt ) {
        if ( mz.delta.pass[i,j] ) {
          # earlier sorting by mz ensures that 1 is alway lighter peak
          peak.index1 <- dimnames(mz.delta.pass)[[1]][i]
          peak.index2 <- dimnames(mz.delta.pass)[[2]][j]
          # check proper isotopic distribution given this charge
          # simple criteria -- for each of light and heavy peaks, there is at least one isotopic peak nearby
          isotope.mz.delta <- isotope.mass.unit / charge
          isotope.delta.pass <- abs(mz.delta - isotope.mz.delta) < mz.delta.ppm
          # not for profile data if ( (sum(isotope.delta.pass[i,]) == 0) | (sum(isotope.delta.pass[,j]) == 0) ) next
          # mz
          peak.mz1 <- xpeaks[peak.index1, "mz"]
          peak.mz2 <- xpeaks[peak.index2, "mz"]
          # intensity
          peak.maxo1 <- xpeaks[peak.index1, intensity.tag]
          peak.maxo2 <- xpeaks[peak.index2, intensity.tag]
          #check peak intensity ratio to fall in certain range
          ratio <- peak.maxo1 / peak.maxo2
          if ( ratio < intensity.ratio.range[1] | ratio > intensity.ratio.range[2] ) next
          new.pair <- c( peak.index1, peak.index2, charge, "0" ) # last number is tracking nonredudant hit
          if ( length(pair.list.this.charge) == 0 ) {
            n.nonredundant.hit <- n.nonredundant.hit + 1
            new.pair[4] <- n.nonredundant.hit
            pair.list.this.charge <- new.pair
          } else {
            for ( k in seq(1,length(pair.list.this.charge),by=4) ) {
              tmp.mz1 <- xpeaks[ pair.list.this.charge[k], "mz" ]
              tmp.mz2 <- xpeaks[ pair.list.this.charge[k+1], "mz" ]
              if ( ((tmp.mz2>peak.mz1)&(tmp.mz2<peak.mz2)) | ((tmp.mz1>peak.mz1)&(tmp.mz1<peak.mz2)) ) {
                # this pair is from an existing isotopic cluster
                new.pair[4] <- pair.list.this.charge[k+3]
                break
              }
            }
            if ( new.pair[4] == "0" ) {
              n.nonredundant.hit <- n.nonredundant.hit + 1
              new.pair[4] = n.nonredundant.hit
            }
            pair.list.this.charge <- c( pair.list.this.charge, new.pair)
          }
        }
      }
    }
    if ( length(pair.list) == 0 ) {
      pair.list <- pair.list.this.charge
    } else {
      pair.list <- c( pair.list, pair.list.this.charge )
    }
    pair.list.this.charge <- NULL
  }
}
pair.matrix <- matrix(pair.list, ncol=4, byrow=TRUE)
colnames(pair.matrix) <- c("idx1", "idx2", "charge", "hit.id")

rt.window.per.scan <- 6.0 # time elapse per ms1 scan
mass.window <- 2.0 # plot 10.0 m/z unit from center of delected peak
num.ms2.per.ms1 <- 18
for ( i in 1:dim(pair.matrix)[1] ) {
  peak.index1 <- pair.matrix[i,1]
  peak.index2 <- pair.matrix[i,2]
  charge <- pair.matrix[i,3]
  hit.id <- pair.matrix[i,4]

  rt <- ( xpeaks[peak.index1,"rt"] + xpeaks[peak.index2,"rt"] ) / 2.0
  rt.range <- c( rt-rt.window.per.scan, rt+rt.window.per.scan)
  peak.mz1 <- xpeaks[ peak.index1, "mz"]
  peak.mz2 <- xpeaks[ peak.index2, "mz"]
  peak.maxo1 <- xpeaks[ peak.index1, "maxo"]
  peak.maxo2 <- xpeaks[ peak.index2, "maxo"]
  mass <- (peak.mz1+peak.mz2) / 2.0
  mass.range <- c(peak.mz1 - mass.window, peak.mz2 + mass.window)
  raw.EIC.data <- rawEIC(xfile, mzrange=mass.range, timerange=rt.range)
  best.scan.number <- raw.EIC.data$scan[ order(raw.EIC.data$intensity)[length(raw.EIC.data$intensity)] ]
  out.filename <- paste( output.path, output.file.base, "_", i, output.file.suffix, sep="")
  # make plot for each individual hit
  png(out.filename)
  par(mfrow=c(2,1))
  # mz spectrum top
  plotScan(xfile, best.scan.number, mzrange=mass.range)
  scan.data <- getScan(xfile, best.scan.number, mzrange=mass.range)
  #ylimit <- c(0, max( peak.maxo1, peak.maxo2) * 1 )
  #plot( scan.data[,1], scan.data[,2], type='h', xlab="m/z", ylab="intensity", ylim=ylimit)
  title( paste("search charge:",charge,"; raw ms1 #", (best.scan.number-1)*(num.ms2.per.ms1+1)+1), line=0.5)
  ymark <- min( scan.data[,2] ) + 10
  points( peak.mz1, ymark, pch=23, col="red",bg="red")
  points( peak.mz2, ymark, pch=23, col="blue",bg="blue")
  #chromatogram bottom
  raw.ECI.light <- rawEIC(xfile, c(peak.mz1*(1-mz.ppm.cut), peak.mz1*(1+mz.ppm.cut)) )
  raw.ECI.heavy <- rawEIC(xfile, c(peak.mz2*(1-mz.ppm.cut), peak.mz2*(1+mz.ppm.cut)) )
  xlimit <-c( max(0, best.scan.number-25), min(best.scan.number+25, length(raw.ECI.light[[1]]) ) )
  ylimit <- range(c(raw.ECI.light[[2]][xlimit[1]:xlimit[2]], raw.ECI.heavy[[2]][xlimit[1]:xlimit[2]]))
  plot(raw.ECI.light[[1]], raw.ECI.light[[2]], type="l", col="red",xlab="scan #", ylab="intensity",
       main=paste("chromatogram of", as.character(format(peak.mz1, digits=7)),
         "and", as.character(format(peak.mz2,digits=7)), "m/z"), xlim=xlimit, ylim=ylimit)
  lines(raw.ECI.heavy[[1]], raw.ECI.heavy[[2]], col='blue', xlim=xlimit, ylim=ylimit)
  dev.off()
}
