\name{group.mzClust}
\docType{methods}
\alias{group.mzClust}
\alias{group.mzClust,xcmsSet-method}

\title{Group Peaks via High Resolution Alignment}
\description{
	Runs high resolution alignment on the peaks stored in a
	given xcmsSet.
}
\usage{
groupedobject <- group(object, method="mzClust", mzppm = 20, mzabs = 0, minsamp = 1, minsampclass=0, minfrac=0)
}
\arguments{
	\item{object}{a xcmsSet with peaks }
	\item{mzppm}{the relative error used for clustering/grouping in ppm (parts per million)}
	\item{mzabs}{the absolute error used for clustering/grouping}
	\item{minsamp}{set the minimum number of samples in one bin}
	\item{minfrac}{set the minimum fraction of each class in one bin}
}
\value{
	Returns a xcmsSet with slots groups and groupindex set.
}
\seealso{
  \code{\link{xcmsSet-class}},
}

\examples{
## load xcms and faahKO Dataset
library(xcms)
library(faahKO)
data(faahko)
## group faahko data
##faahko_grouped <- group(faahko, method="mzClust")
## get groups
##groups <- groups(faahko_grouped)
## get grouped peak indices
##idx <- groupidx(faahko_grouped)
}
\references{
	Saira A. Kazmi, Samiran Ghosh, Dong-Guk Shin,
	Dennis W. Hill and David F. Grant\cr
	\emph{Alignment of high resolution mass spectra: development of a heuristic
	approach for metabolomics}.\cr
	Metabolomics, Vol. 2, No. 2, 75-83 (2006)
}
\keyword{methods}
\keyword{file}
