dagri_has_closure <- function(x) {
  if (is.function(x)) {
    return(TRUE)
  }
  if (is.list(x)) {
    return(any(vapply(x, dagri_has_closure, logical(1))))
  }
  FALSE
}

# Metadata must be plain data (see dagri_validate_metadata()): this recursive
# check mirrors dagri_has_closure()'s no-code approach and additionally rejects
# reference-bearing values (environments carry mutable state, formulas carry
# environments, external pointers are opaque native references).
dagri_has_reference_value <- function(x) {
  if (
    is.function(x) ||
      is.environment(x) ||
      inherits(x, "formula") ||
      identical(typeof(x), "externalptr")
  ) {
    return(TRUE)
  }
  if (is.list(x)) {
    return(any(vapply(x, dagri_has_reference_value, logical(1))))
  }
  FALSE
}

#' Define a dagriculture kind
#'
#' Creates a kind record describing one node type: its input contract, output
#' type, and parameter schema. The record is plain data and carries an opaque
#' caller-owned `metadata` field.
#'
#' @param name The name of the kind.
#' @param input_contract Input contract list.
#' @param output_type Output type string.
#' @param param_schema A named list describing expected parameters. Arbitrary nested
#'   list structure is allowed, but executable closures are rejected for safety.
#' @param metadata Opaque caller-owned extension data: a named list of plain
#'   data (nested lists, vectors, and scalars are fine). Closures,
#'   environments, formulas, and external pointers are rejected recursively.
#' @return A kind record: a named list with fields `name`, `input_contract`,
#'   `output_type`, `param_schema`, and `metadata`.
#'
#' @section Errors:
#' - `dagri_error_invalid_argument` when `name` is not a single non-empty
#'   string, `input_contract` is not a named list of single strings/`NULL`,
#'   `param_schema` is not a named list free of closures, or `metadata` fails
#'   the plain-data check (see [dagri_graph()]).
#'
#' @examples
#' dagri_kind("source", output_type = "data.frame")
#' dagri_kind(
#'   "fit",
#'   input_contract = list(data = "data.frame"),
#'   metadata = list(owner = "team_a", revision = 2)
#' )
#' @export
dagri_kind <- function(
  name,
  input_contract = NULL,
  output_type = NULL,
  param_schema = NULL,
  metadata = list()
) {
  dagri_validate_id(name, "name")
  dagri_validate_metadata(metadata)
  if (!is.null(input_contract)) {
    if (!is.list(input_contract)) {
      abort_dagri(
        "dagri_error_invalid_argument",
        "`input_contract` must be a list or NULL."
      )
    }
    contract_names <- names(input_contract)
    if (is.null(contract_names) || anyNA(contract_names) || any(contract_names == "")) {
      abort_dagri(
        "dagri_error_invalid_argument",
        "`input_contract` must be a named list."
      )
    }
    invalid_entries <- !vapply(
      input_contract,
      function(x) is.null(x) || (is.character(x) && length(x) == 1L && !is.na(x)),
      logical(1)
    )
    if (any(invalid_entries)) {
      abort_dagri(
        "dagri_error_invalid_argument",
        sprintf(
          "`input_contract` values must be character strings or NULL. Invalid entries: %s.",
          paste(contract_names[invalid_entries], collapse = ", ")
        )
      )
    }
  }

  if (!is.null(param_schema)) {
    if (!is.list(param_schema) || inherits(param_schema, "data.frame")) {
      abort_dagri(
        "dagri_error_invalid_argument",
        "`param_schema` must be a named list or NULL."
      )
    }
    schema_names <- names(param_schema)
    if (
      length(param_schema) > 0L &&
        (is.null(schema_names) || anyNA(schema_names) || any(schema_names == ""))
    ) {
      abort_dagri(
        "dagri_error_invalid_argument",
        "`param_schema` must be a named list."
      )
    }
    if (dagri_has_closure(param_schema)) {
      abort_dagri(
        "dagri_error_invalid_argument",
        "Executable closures are not allowed in param_schema."
      )
    }
  }

  list(
    name = name,
    input_contract = input_contract,
    output_type = output_type,
    param_schema = param_schema,
    metadata = metadata
  )
}

#' Define a dagriculture registry
#'
#' Bundles one or more [dagri_kind()] records into a registry keyed by kind
#' name. The registry carries an opaque caller-owned `metadata` field.
#'
#' @param ... \code{dagri_kind} objects.
#' @param metadata Opaque caller-owned extension data: a named list of plain
#'   data (nested lists, vectors, and scalars are fine). Closures,
#'   environments, formulas, and external pointers are rejected recursively.
#' @return A registry: a named list with fields `kinds` (a named map of kind
#'   records) and `metadata`.
#'
#' @section Errors:
#' - `dagri_error_invalid_argument` when `metadata` is not a named list of
#'   plain data.
#'
#' @examples
#' reg <- dagri_registry(
#'   dagri_kind("source"),
#'   dagri_kind("process"),
#'   metadata = list(origin = "hand-authored")
#' )
#' names(reg$kinds)
#' reg$metadata
#' @export
dagri_registry <- function(..., metadata = list()) {
  dagri_validate_metadata(metadata)

  kinds_list <- list(...)
  kinds_env <- list()
  for (k in kinds_list) {
    kinds_env[[k$name]] <- k
  }
  list(
    kinds = kinds_env,
    metadata = metadata
  )
}

#' Create an empty dagriculture graph
#'
#' Returns a new immutable graph carrying the given registry and empty
#' node/edge/gate collections. The result has S3 class `c("dagri_graph",
#' "list")` so [print.dagri_graph()] dispatches; underneath it remains a plain
#' named list and serializes identically to before. Graph-mutating functions
#' (`dagri_add_node()`, `dagri_add_edge()`, ...) preserve the class on the
#' returned copy.
#'
#' Graph-level `metadata` is opaque caller-owned extension data; every record
#' type (kind, registry, graph, node, edge, gate) carries the same field. It
#' must be a named list of plain data — closures, environments, formulas, and
#' external pointers are rejected recursively — so it stays serializable under
#' the persistence contract.
#'
#' @param registry A \code{dagri_registry} object.
#' @param metadata Opaque caller-owned extension data: a named list of plain
#'   data (nested lists, vectors, and scalars are fine). Closures,
#'   environments, formulas, and external pointers are rejected recursively.
#' @return A `dagri_graph` (a named list with S3 class
#'   \code{c("dagri_graph", "list")}) with fields `registry`, `nodes`, `edges`,
#'   `gates`, `version` (0L), and `metadata`.
#'
#' @section Errors:
#' - `dagri_error_invalid_argument` when `metadata` is not a named list of
#'   plain data.
#'
#' @examples
#' reg <- dagri_registry(dagri_kind("source"))
#' g <- dagri_graph(reg, metadata = list(project = "pilot"))
#' g$version
#' g$metadata
#' @export
dagri_graph <- function(registry, metadata = list()) {
  dagri_validate_metadata(metadata)

  structure(
    list(
      registry = registry,
      nodes = stats::setNames(list(), character(0)),
      edges = stats::setNames(list(), character(0)),
      gates = stats::setNames(list(), character(0)),
      version = 0L,
      metadata = metadata
    ),
    class = c("dagri_graph", "list")
  )
}
