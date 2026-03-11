#' Abort with a typed dagriculture error
#'
#' @param class Error class.
#' @param message Error message.
#' @param details Optional details list.
#' @export
abort_dagri <- function(class, message, details = list()) {
  rlang::abort(message, class = class, details = details)
}

#' Validate a dagriculture graph object
#'
#' Ensures the graph has all required top-level fields.
#'
#' @param graph A \code{dagri_graph}.
#' @return The graph, invisibly, if valid.
#' @keywords internal
dagri_validate_graph <- function(graph) {
  if (!is.list(graph)) {
    abort_dagri(
      "dagri_error_invalid_argument",
      "`graph` must be a list created by dagri_graph()."
    )
  }
  required_fields <- c("registry", "nodes", "edges", "gates", "version")
  missing_fields <- setdiff(required_fields, names(graph))
  if (length(missing_fields) > 0) {
    abort_dagri(
      "dagri_error_invalid_argument",
      sprintf(
        "`graph` is missing required fields: %s. Use dagri_graph() to create a valid graph.",
        paste(missing_fields, collapse = ", ")
      )
    )
  }
  if (!is.integer(graph$version) || length(graph$version) != 1) {
    abort_dagri(
      "dagri_error_invalid_argument",
      "`graph$version` must be a single integer."
    )
  }
  invisible(graph)
}
