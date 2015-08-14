args <- commandArgs(trailingOnly=T)
file1 <- args[1]
file2 <- args[2]
a <- read.table(file1, header=T)
b <- read.table(file2, header=T)

mz.tol <- 0.5
rt.tol <- 180
if (length(args)>=3) {
  mz.tol <- args[3]
}
if (length(args)>=4) {
  rt.tol <- args[4]
}
column.names <- c("mzmed","rtmed",paste("fold",file1,sep="."), paste("fold",file2,sep="."))
out.df <- matrix(nrow=0, ncol=length(column.names))
colnames <- column.names
a[,"fold"] <- a[,"fold"]*((as.numeric(a[,"tstat"]>0)-0.5)*2)
b[,"fold"] <- b[,"fold"]*((as.numeric(b[,"tstat"]>0)-0.5)*2)
for ( i in 1:dim(a)[1] ) {
  mz <- a[i,"mzmed"]
  rt <- a[i,"rtmed"]
  mz.filter <- (abs(b[,"mzmed"]-mz)<=mz.tol)
  rt.filter <- (abs(b[,"rtmed"]-rt)<=rt.tol)
  j <- which (mz.filter & rt.filter)
  if ( length(j) == 1) {
    this.df <- c(mz,rt,a[i,"fold"],b[j,"fold"])
    names(this.df) <- column.names
    out.df <- rbind(out.df,this.df)
  }
}

write.table(out.df, file=paste(file1,file2,"align.txt",sep="_"),quote=F, sep="\t", row.names=F)
