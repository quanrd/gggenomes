% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/focus.R
\name{focus}
\alias{focus}
\title{Focus on feats and regions of interest}
\usage{
focus(
  x,
  ...,
  track_id = genes,
  plus = 2000,
  marginal = c("trim", "drop", "keep"),
  subseqs = NULL
)
}
\arguments{
\item{x}{a gggenomes object}

\item{...}{Logical predicates defined in terms of the variables in the track
given by 'track_id'. Multiple conditions are combined with ‘&’. Only rows
where the condition evaluates to ‘TRUE’ are kept.

The arguments in ‘...’ are automatically quoted and evaluated in the context
of the data frame. They support unquoting and splicing. See
‘vignette("programming")’ for an introduction to these concepts.}

\item{track_id}{the track to filter from}

\item{plus}{the amount to nucleotides to extend the focus around the target
feats. Give two values for different up- and downstream extensions.}

\item{marginal}{how to handle feats that stick out of sequences, for
example after focusing in on a subregion. Choices are to "drop" them, "keep"
them or "trim" them to the subregion boundaries.}

\item{subseqs}{a dataframe specifying sequence regions (subseqs) of interest
directly. Required columns are 'seq_id, start, end'. Superceeds \code{...}.}
}
\description{
Only show subsequences from the complete data set containing feats of
interest.
}
