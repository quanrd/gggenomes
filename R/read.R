#' Swap query and subject in blast-like feature tables
#'
#' Swap query and subject columns in a table read with [read_feats()] or
#' [read_links()], for example, from blast searches. Swaps columns with
#' name/name2, such as 'seq_id/seq_id2', 'start/start2', ...
#'
#' @param x tibble with query and subject columns
#' @export
#' @return tibble with swapped query/subject columns
#' @examples
#' feats <- tribble(
#'  ~seq_id, ~seq_id2, ~start, ~end, ~strand, ~start2, ~end2, ~evalue,
#'  "A", "B", 100, 200, "+", 10000, 10200, 1e-5
#' )
#' # make B the query
#' swap_query(feats)
swap_query <- function(x){
  # for every pair seq_id/seq_id2, name/name2 > name2/name
  n <- names(x)
  m <- str_subset(n, "\\D2") %>% str_remove("2$") %>% intersect(n)
  if(!length(m))
    return(x)

  m2 <- paste0(m, "2")
  i <- which(n %in% m)
  i2 <- which(n %in% m2)
  inform(c("Swapping query/subject-associated columns",
           comma(m, collapse='  '), comma(m2, collapse=' ')))
  x[c(i, i2)] <- x[c(i2, i)]
  x
}

#' Default column names and types for defined formats
#'
#' Intended to be used in [readr::read_tsv()]-like functions that accept a
#' `col_names` and a `col_types` argument.
#'
#' @export
#' @return a vector with default column names for the given format
#' @eval def_names_rd()
#' @describeIn def_names default column names for defined formats
#' @examples
#' # read a blast-tabular file with read_tsv
#' read_tsv(ex("emales/emales-prot-ava.o6"), col_names=def_names("blast"))
def_names <- function(format){
  ff <- gggenomes_global$def_names
  if(!format %in% names(ff)){
    abort(c(
      str_glue("No default col_names defined for format '{format}'.\nDefined formats are:"),
      names(ff)
    ))
  }
  ff[[format]]
}


#' @describeIn def_names default column types for defined formats
#' @export
#' @return a vector with default column types for the given format
def_types <- function(format){
  ff <- gggenomes_global$def_types
  if(!format %in% names(ff)){
    abort(c(
      str_glue("No default col_types defined for format '{format}'.\nDefined formats are:"),
      names(ff)
    ))
  }
  ff[[format]]
}

#' Defined file formats and extensions
#'
#' For seamless reading of different file formats, gggenomes uses a mapping of
#' known formats to associated file extensions and contexts in which the
#' different formats can be read. The notion of context allows one to read
#' different information from the same format/extension. For example, a gbk file
#' holds both feature and sequence information. If read in "feats" context
#' `read_feats("*.gbk")` it will return a feature table, if read in "seqs"
#' context `read_seqs("*.gbk")`, a sequence index.
#'
#'
#' @param context a file format context defined in `gggenomes_global$file_formats`
#' @return dictionarish vector of file formats with recognized extensions as names
#' @export
#' @examples
#' # vector of defined zip formats and recognized extensions as names
#' file_formats("zips")
#' @eval file_formats_rd()
file_formats <- function(context){
  ff <- gggenomes_global$file_formats
  if(!context %in% names(ff)){
    abort(c(
      str_glue("Unknown file format context '{context}'.\nDefined families are:"),
      names(ff)
    ))
  }
  ff[[context]]
}

#' Defined file extensions and associated formats
#'
#' @inheritParams file_formats
#' @return vector of file extensions with formats as names
#' @examples
#' # vector of zip-context file extensions and format names
#' gggenomes:::file_exts("zips")
file_exts <- function(context){
  f <- file_formats(context)
  set_names(names(f), f)
}

#' File format from suffix
#' @param x a vector of file extensions
#' @param context a file format context defined in [file_formats()]
#' @return a vector of formats with extensions as names
#' @examples
#' gggenomes:::ext_to_format(c("gff", "txt", "FASTA"), "feats")
ext_to_format <- function(x, context){
  x <- str_to_lower(x)
  if(is_dictionaryish(context))
    context[x]
  else
    file_formats(context)[x]
}

file_strip_zip <- function(file, ext = names(file_formats("zips"))){
  ext <- paste0("\\.", ext, "$", collapse="|")
  str_remove(file, ext)
}

file_ext <- function(file, pattern = "(?<=\\.)[^.]+$", ignore_zip = TRUE){
  if(ignore_zip)
    file <- file_strip_zip(file)
  str_extract(file, pattern)
}

file_name <- function(file, pattern = "\\.[^.]+$", ignore_zip = TRUE){
  if(ignore_zip)
    file <- file_strip_zip(file)
  str_remove(basename(file), pattern)
}

file_format <- function(file, context, allow_na = FALSE){
  ext <- file_ext(file)
  format <- ext_to_format(ext, context)
  if(!allow_na && any(is.na(format))){
    bad <- file[is.na(format)]
    names(bad) <- rep("x", length(bad))
    good <- file_formats("feats") %>%
      enframe(name = "ext", value = "format") %>%
      chop(ext) %>% mutate(ext = map_chr(ext, comma)) %>% format()
    abort(c(str_glue('Bad extention for file format context "{context}"'), bad,
      i="Recognized formats/extensions:", good[-(1:3)]))
  }
  set_names(format, file)
}

file_id <- function(file){
  vctrs::vec_as_names(file_name(file), repair="unique")
}

file_format_unique <- function(files, context, allow_duplicates = FALSE){
  fmt <- unique(file_format(files, context))
  if(!allow_duplicates && length(fmt) > 1)
    abort(c("All files need the same format.", i="Got mix of:", unname(fmt)))
  fmt
}

#' Add a unique name to files
#'
#' Given a vector of file paths, add a unique labels based on the filename as
#' vector names
file_label <- function(file){
  i <- which(!have_name(file))
  names(file)[i] <- file_id(file[i])
  file
}


file_is_zip <- function(file, ext = names(file_formats("zips"))){
  pattern <- paste0("\\.", ext, "$", collapse="|")
  str_detect(file, pattern)
}


file_is_url <- function(file){
  str_detect(file, "^((http|ftp)s?|sftp)://")
}

file_formats_rd <- function(){
  ff <- gggenomes_global$file_formats %>%
    map_df(.id="context", function(x){
      enframe(x, "extension", "format") %>% group_by(format) %>%
        summarize(extension = comma(extension), .groups="drop")
    })
  ff <- mutate(ff, context = ifelse(duplicated(context), "", context))

  ff <- str_c(sep = "\n",
      "@section Defined contexts, formats and extensions:",
      "\\preformatted{",
      #sprintf("%-9s %-12s  %s", "Context", "Format", "Extensions"),
      str_c(collapse = "\n",
            str_glue_data(ff, '{sprintf("%-8s", context)} ',
                    '{sprintf("%-7s", format)}  [{extension}]')),
      "}"
      )
  ff
}

def_names_rd <- function(){
  ns <- gggenomes_global$def_names
  ts <- gggenomes_global$def_types
  str_c(sep = "\n",
    "@section Defined formats, column types and names:",
    "\\preformatted{",
      paste0(map(names(ns),
          ~sprintf("  %-10s %-15s %s", .x, ts[[.x]], comma(ns[[.x]]))), collapse="\n"),
    "}"
  )
}

is_connection <- function(x) inherits(x, "connection")

#' Read AliTV .json file
#'
#' this file contains sequences, links and (optionally) genes
#'
#' @importFrom tidyr unnest_wider
#' @importFrom tidyr unnest
#' @importFrom jsonlite fromJSON
#' @param file path to json
#' @export
#' @return list with seqs, genes, and links
#' @examples
#' ali <- read_alitv("https://alitvteam.github.io/AliTV/d3/data/chloroplasts.json")
#' gggenomes(ali$seqs, ali$genes, links=ali$links) +
#'   geom_seq() +
#'   geom_bin_label() +
#'   geom_gene(aes(fill=class)) +
#'   geom_link()
#' p <- gggenomes(ali$seqs, ali$genes, links=ali$links) +
#'   geom_seq() +
#'   geom_bin_label() +
#'   geom_gene(aes(color=class)) +
#'   geom_link(aes(fill=identity)) +
#'   scale_fill_distiller(palette="RdYlGn", direction = 1)
#' p %>% flip_seq("Same_gi") %>% pick(1,3,2,4,5,6,7,8)
read_alitv <- function(file){
  ali <- jsonlite::fromJSON(file, simplifyDataFrame=TRUE)
  seqs <- tibble(seq = ali$data$karyo$chromosome) %>%
    mutate(seq_id = names(seq)) %>%
    unnest_wider(seq) %>%
    rename(bin_id = genome_id)
  genes <- tibble(feature = ali$data$feature) %>%
    mutate(class = names(feature)) %>%
    filter(class != "link") %>%
    unnest(feature) %>%
    rename(seq_id=karyo)
  links <- tibble(links=ali$data$links) %>% unnest(links) %>% unnest(links) %>% unnest_wider(links)
  link_pos <- tibble(link=ali$data$features$link) %>% mutate(id=names(link)) %>% unnest_wider(link)
  links <- links %>%
    left_join(link_pos, by=c("source"="id")) %>%
    left_join(link_pos, by=c("target"="id")) %>%
    transmute(
        seq_id1=karyo.x,
        start1=start.x,
        end1=end.x,
        seq_id2=karyo.y,
        start2=start.y,
        end2=end.y,
        identity=identity
    )
  return(list(seqs=seqs,genes=genes,links=links))
}

