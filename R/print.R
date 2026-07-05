# Print methods for dagriculture's value-oriented result types.
#
# dagriculture has no runtime side effects; the print method is the only
# interactive UX surface, so it emits a concise multi-line summary instead of
# dumping the full nested list. Both `dagri_graph` and `dagri_plan` are plain
# named lists underneath (with S3 class); these methods are ergonomic sugar
# only, and core correctness never depends on S3 dispatch.

# --- Internal helpers --------------------------------------------------------

dagri_print_kind_summary <- function(graph) {
  kind_names <- names(graph$registry$kinds)
  if (length(kind_names) == 0L) {
    return("(none)")
  }
  paste(kind_names, collapse = ", ")
}

# --- print.dagri_graph -------------------------------------------------------

#' Print a dagriculture graph
#'
#' Prints a concise multi-line summary of a \code{dagri_graph}: package name
#' and version, node/edge/gate counts, the graph's internal \code{$version},
#' and the registry kind names. Matches the style of base R print methods
#' (writes to stdout via \code{cat()} with trailing newlines).
#'
#' @param x A \code{dagri_graph}.
#' @param ... Unused; for S3 generic compatibility.
#' @return The input \code{x}, invisibly.
#' @export
print.dagri_graph <- function(x, ...) {
  pkg_version <- utils::packageVersion("dagriculture")
  n_nodes <- length(x$nodes)
  n_edges <- length(x$edges)
  n_gates <- length(x$gates)

  cat(sprintf("<dagri_graph> dagriculture %s\n", as.character(pkg_version)))
  cat(sprintf("  nodes: %d\n", n_nodes))
  cat(sprintf("  edges: %d\n", n_edges))
  cat(sprintf("  gates: %d\n", n_gates))
  cat(sprintf("  version: %d\n", x$version))
  cat(sprintf("  registry kinds: %s\n", dagri_print_kind_summary(x)))

  invisible(x)
}

# --- print.dagri_plan --------------------------------------------------------

#' Print a dagriculture structural plan
#'
#' Prints a concise multi-line summary of a \code{dagri_plan} produced by
#' [dagri_plan()]: counts of targets, the topological order length, and the
#' eligible/blocked/terminal sets plus the number of pending gates. Matches
#' the style of base R print methods.
#'
#' @param x A \code{dagri_plan}.
#' @param ... Unused; for S3 generic compatibility.
#' @return The input \code{x}, invisibly.
#' @export
print.dagri_plan <- function(x, ...) {
  n_blocked <- length(x$blocked)
  cat("<dagri_plan>\n")
  cat(sprintf("  targets: %d\n", length(x$targets)))
  cat(sprintf("  topo order length: %d\n", length(x$topo_order)))
  cat(sprintf("  eligible: %d\n", length(x$eligible)))
  cat(sprintf("  blocked: %d\n", n_blocked))
  cat(sprintf("  terminal: %d\n", length(x$terminal)))
  cat(sprintf("  pending gates: %d\n", length(x$pending_gates)))
  invisible(x)
}
