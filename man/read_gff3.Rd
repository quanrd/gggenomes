% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/read_gff3.R
\name{read_gff3}
\alias{read_gff3}
\title{Read features from GFF3 files}
\usage{
read_gff3(
  file,
  sources = NULL,
  types = NULL,
  infer_cds_parents = FALSE,
  col_names = def_names("gff3"),
  col_types = def_types("gff3")
)
}
\arguments{
\item{sources}{only return features from these sources}

\item{types}{only return features of these types, e.g. gene, CDS, ...}

\item{infer_cds_parents}{infer the mRNA parent for CDS features based on
overlapping coordinates. In most GFFs this is properly set, but sometimes
this information is missing. Generally, this is not a problem, however,
geom_gene calls parse the parent information to determine which CDS and
mRNAs are part of the same gene model. Without the parent info, mRNA and
CDS are plotted as individual features.}

\item{col_names}{column names to use. Defaults to \link{def_names("blast")}
compatible with blast tabular output (\verb{--outfmt 6/7} in blast++ and \code{-m8}
in blast-legacy). \link{def_names("blast")} can easily be combined with extra
columns: \code{col_names = c(def_names("blast"), "more", "things")}.}
}
\value{
tibble
}
\description{
Files with \verb{##FASTA} section work but result in parsing problems for all
lines of the fasta section. Just ignore those warnings, or strip the fasta
section ahead of time from the file.
}
