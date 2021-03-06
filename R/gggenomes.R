#' Plot genomes, features and synteny maps
#'
#' Sequence data: `read_fai`
#'
#' Feat data: `read_gff`
#'
#' Link data: `read_paf`
#' @param seqs a table with sequence data (seq_id, bin_id, length)
#' @param genes a table or a list of table with gene data to be added as feat
#'   tracks. Required columns: seq_id, bin_id, start, end.
#'
#'   For a single table, adds the track_id will be "genes". For a list,
#'   track_ids are parsed from the list names, or if names are missing from the
#'   name of the variable containing each table.
#' @param feats same as genes, but the single table track_id will default to
#'   "feats".
#' @param links a table or a list of tables with link data to be added as link
#'   tracks (columns: from, to, from_start, from_end, to_start, to_end). Same
#'   naming scheme as for feats.
#' @param ... layout parameters passed on to [layout_genomes()] /
#'   [layout_seqs()]
#' @param theme choose a gggenomes default theme, NULL to omit.
#' @param .layout a pre-computed layout from [layout_genomes()]. Useful for
#'   developmental purposes.
#' @import ggplot2 grid rlang
#' @export
#' @return gggenomes-flavored ggplot object
#' @examples
#' # Compare the genomic organization of three viral elements
#' # EMALEs: endogenous mavirus-like elements (example data shipped with gggenomes)
#' gggenomes(emale_seqs, emale_genes, emale_tirs, emale_ava) +
#'   geom_seq() + geom_bin_label() +                  # chromosomes and labels
#'   geom_feat(size=8) +                              # terminal inverted repeats
#'   geom_gene(aes(fill=strand), position="strand") + # genes
#'   geom_link(offset = 0.15)                         # synteny-blocks
#'
#' # with some more information
#' gggenomes(emale_seqs, emale_genes, emale_tirs, emale_ava) %>%
#'   add_feats(emale_ngaros, emale_gc) %>%
#'   add_clusters(emale_cogs) %>%
#'   flip_nicely() +
#'   geom_link(offset = 0.15, color="white") +                        # synteny-blocks
#'   geom_seq() + geom_bin_label() +                  # chromosomes and labels
#'   # thistle4, salmon4, burlywood4
#'   geom_feat(size=6, position="identity") +                              # terminal inverted repeats
#'   geom_feat(data=feats(emale_ngaros), color="turquoise4", alpha=.3,
#'             position="strand", size=16) +
#'   geom_feat_note(aes(label=type), data=feats(emale_ngaros),
#'                  position="strand", nudge_y = .3) +
#'   geom_gene(aes(fill=cluster_id), position="strand") + # genes
#'   scale_fill_brewer("Conserved genes", palette="Dark2", na.value = "cornsilk3") +
#'   #scale_fill_viridis_b() +
#'   geom_ribbon(aes(x=(x+xend)/2, ymax=y+.24, ymin=y+.38-(.4*score),
#'                   group=seq_id, linetype="GC-content"), feats(emale_gc),
#'               fill="lavenderblush4", position=position_nudge(y=-.1))
gggenomes <- function(seqs=NULL, genes=NULL, feats=NULL, links=NULL, ...,
  theme = c("clean", NULL), .layout=NULL){

  # parse track_args to tracks - some magic for a convenient api
  genes_exprs <- enexpr(genes)
  feats_exprs <- enexpr(feats)
  links_exprs <- enexpr(links)

  genes <- as_tracks(genes, genes_exprs, "seqs")
  feats <- as_tracks(feats, feats_exprs, c("seqs", names2(genes)))
  feats <- c(genes, feats) # genes are just feats
  links <- as_tracks(links, links_exprs, c("seqs", names2(feats)))


  layout <- .layout %||% layout_genomes(seqs=seqs, genes=genes, feats=feats,
                                        links=links, ...)

  p <- ggplot(data = layout)
  class(p) <- c('gggenomes', class(p))

  p <- p + scale_y_continuous("", expand = expansion(add=.1, mult=.1),
      trans = scales::reverse_trans())

  #p <- p + scale_x_continuous("", labels=scales::label_bytes())

  theme_name <- theme[[1]] %||% match.arg(theme[[1]], c("clean"))
  if(!is.null(theme_name)){ # add theme
    theme_args <- if(is.list(theme) && length(theme) >1) theme[-1] else list()
    p <- p + do.call(paste0("theme_gggenomes_", theme), theme_args)
  }

  p
}

#' ggplot.default tries to `fortify(data)` and we don't want that here
#'
#' @export
#' @keywords internal
ggplot.gggenomes_layout <- function(data, mapping = aes(), ...,
                               environment = parent.frame()) {
  if (!missing(mapping) && !inherits(mapping, "uneval")) {
    stop("Mapping should be created with `aes() or `aes_()`.", call. = FALSE)
  }

  p <- structure(list(
    data = data,
    layers = list(),
    scales = ggplot2:::scales_list(),
    mapping = mapping,
    theme = list(),
    coordinates = coord_cartesian(default = TRUE),
    facet = facet_null(),
    plot_env = environment
  ), class = c("gg", "ggplot"))

  p$labels <- ggplot2:::make_labels(mapping)

  ggplot2:::set_last_plot(p)
  p
}
#' @rdname gggenomes
#' @inheritParams gggenomes
#' @param infer_length,infer_start,infer_end,infer_bin_id used to infer pseudo
#' seqs if only feats or links are provided, or if no bin_id column was
#' provided. The expressions are evaluated in the context of the first feat
#' or link track.
#'
#' By default subregions of sequences from the first to the last feat/link
#' are generated. Set `infer_start` to 0 to show all sequences from their
#' true beginning.
#' @return gggenomes_layout object
#' @export
layout_genomes <- function(seqs=NULL, genes=NULL, feats=NULL, links=NULL,
    infer_bin_id = seq_id, infer_start = min(start,end), infer_end = max(start,end),
    infer_length = max(start,end), ...){

  # check seqs / infer seqs if not provided
  if(!is.null(seqs)){
    if(!has_name(seqs, "bin_id"))
      seqs <- mutate(seqs, bin_id = {{ infer_bin_id }})
  }else{
    if(is.null(feats) & is.null(links))
      abort("Need at least one of: seqs, genes, feats or links")

    # infer dummy seqs
    if(!is.null(feats)){
      inform("No seqs provided, inferring seqs from feats")
      seqs <- infer_seqs_from_feats(feats[[1]], {{infer_bin_id}}, {{infer_start}},
                                     {{infer_end}}, {{infer_length}})
    }else if(!is.null(links)){
      inform("No seqs or feats provided, inferring seqs from links")
      seqs <- infer_seqs_from_links(links[[1]],  {{infer_bin_id}}, {{infer_start}},
                                     {{infer_end}}, {{infer_length}})
    }
  }

  # init the gggenomes_layout object
  x <- list(seqs = NULL, feats = list(), links = list(), orig_links = list(),
            args_seqs = list(...))
  x %<>% set_class("gggenomes_layout", "prepend")

  # add track data to layout
  x %<>% add_seqs(seqs, ...) # layout seqs
  if(!is.null(feats)) x <- add_feat_tracks(x, feats)
  if(!is.null(links)) x <- add_link_tracks(x, links)

  x
}

#' `ggplot2::facet_null` checks data with `empty(df)` using `dim`. This causes
#' and error because dim(gggenome_layout) is undefined. Return dim of primary
#' table instead
#' @export
#' @keywords internal
dim.gggenomes_layout <- function(x) dim(get_seqs(x))

#' @export
print.gggenomes_layout <- function(x) track_info(x)

infer_seqs_from_feats <- function(feats, infer_bin_id = seq_id, infer_start = min(start,end),
    infer_end = max(start,end), infer_length = max(start,end)){
  if(!has_name(feats, "bin_id"))
    feats <- mutate(feats, bin_id = {{ infer_bin_id }})
  else
    warn("bin_id found in feats, won't overwrite")

  seqs <- feats %>%
    group_by(bin_id, seq_id) %>%
    summarize(
      length = {{ infer_length }},
      .start = {{ infer_start }},
      .end = {{ infer_end }}
    ) %>%
    dplyr::rename(start=.start, end=.end) # this is necessary, so {{ infer_end }} does
                                 # not already use the "start" from {{ infer_start }}

  ungroup(seqs)
}

infer_seqs_from_links <- function(links, infer_bin_id = seq_id, infer_start = min(start,end),
    infer_end = max(start,end), infer_length = max(start,end)){

  seqs <- bind_rows(
    select_at(links, vars(ends_with("1")), str_replace, "1", ""),
    select_at(links, vars(ends_with("2")), str_replace, "2", "")
  )

  if(!has_name(seqs, "bin_id"))
    seqs <- mutate(seqs, bin_id = {{ infer_bin_id }})

  seqs %<>%
    mutate(bin_id = {{ infer_bin_id }}) %>%
    group_by(seq_id, bin_id) %>%
    summarize(
      length = {{ infer_length }},
      .start = {{ infer_start }},
      .end = {{ infer_end }}
    ) %>%
      dplyr::rename(start=.start, end=.end)

  ungroup(seqs)
}

#' gggenomes default theme
#' @importFrom ggplot2 theme_bw
#' @importFrom ggplot2 theme
#' @inheritParams ggplot2::theme_bw
#' @export
theme_gggenomes_clean <- function(base_size = 12, base_family = "", base_line_size = base_size/30, base_rect_size = base_size/30){
  theme_bw(
    base_size = base_size, base_family = base_family,
    base_line_size = base_line_size, base_rect_size = base_rect_size
  ) + theme(
    panel.border = element_blank(),
    panel.grid.major = element_blank(),
    panel.grid.minor = element_blank(),
    panel.background = element_rect(fill = "white"),
    # x-axis
    axis.line.x = element_line(color = "black", size=.4),
    axis.title.x = element_blank(),
    axis.text.x= element_text(color = "black", size=7),
    axis.ticks.length.x = unit(.7, "mm"),
    # y-axis
    axis.title.y=element_blank(),
    axis.ticks.y=element_blank(),
    axis.text.y=element_blank()
  )
}

#' @inheritParams ggplot2::scale_x_continuous
#' @export
scale_x_continuous <- function(...){
  ggplot2::scale_x_continuous(labels = label_bp(), ...)
}

label_bp <- function (accuracy = 1, unit = "", sep = "", ...) {
  scales:::force_all(accuracy, ...)
  function(x) {
    breaks <- c(0, 10^c(k = 3, M = 6, G = 9))
    n_suffix <- cut(abs(x), breaks = c(unname(breaks), Inf),
                    labels = c(names(breaks)), right = FALSE)
    n_suffix[is.na(n_suffix)] <- ""
    suffix <- paste0(sep, n_suffix, unit)
    scale <- 1/breaks[n_suffix]
    scale[which(scale %in% c(Inf, NA))] <- 1
    scales::number(x, accuracy = accuracy, scale = unname(scale),
           suffix = suffix, ...)
  }
}
