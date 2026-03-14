dagri_has_closure <- function(x) {
  if (is.function(x)) {
    return(TRUE)
  }
  if (is.list(x)) {
    return(any(vapply(x, dagri_has_closure, logical(1))))
  }
  FALSE
}

#' Define a dagriculture kind
#'
#' @param name The name of the kind.
#' @param input_contract Input contract list.
#' @param output_type Output type string.
#' @param param_schema A named list describing expected parameters. Arbitrary nested
#'   list structure is allowed, but executable closures are rejected for safety.
#' @export
dagri_kind <- function(name, input_contract = NULL, output_type = NULL, param_schema = NULL) {
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
    metadata = list()
  )
}

#' Define a dagriculture registry
#'
#' @param ... \code{dagri_kind} objects.
#' @export
dagri_registry <- function(...) {
  kinds_list <- list(...)
  kinds_env <- list()
  for (k in kinds_list) {
    kinds_env[[k$name]] <- k
  }
  list(
    kinds = kinds_env,
    metadata = list()
  )
}

#' Create an empty dagriculture graph
#'
#' @param registry A \code{dagri_registry} object.
#' @export
dagri_graph <- function(registry) {
  list(
    registry = registry,
    nodes = stats::setNames(list(), character(0)),
    edges = stats::setNames(list(), character(0)),
    gates = stats::setNames(list(), character(0)),
    version = 0L,
    metadata = list()
  )
}
