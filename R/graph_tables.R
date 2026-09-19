# --- Tabular accessors ---

#' Scalar character column from record fields
#'
#' Internal helper for the tabular accessors. Extracts `field` from every
#' record in `records`; a missing or `NULL` field becomes `NA_character_`.
#' An empty record list yields `character(0)`, so the empty-graph skeleton
#' keeps the exact column type of the populated case.
#'
#' @param records Named list of records (nodes, edges, or gates).
#' @param field Name of the scalar field to extract.
#' @return Unnamed character vector with one entry per record, in record
#'   (insertion) order.
#' @keywords internal
dagri_table_chr <- function(records, field) {
  unname(vapply(
    records,
    function(record) record[[field]] %||% NA_character_,
    character(1)
  ))
}

#' List-column from record fields
#'
#' Internal helper for the tabular accessors. Extracts `field` from every
#' record in `records`, verbatim, as one cell per row. Graphs store these
#' fields as plain lists, so the cells are plain lists; no graph or record
#' objects leak into cells. An empty record list yields the empty `list()`
#' column of the empty-graph skeleton.
#'
#' @param records Named list of records (nodes, edges, or gates).
#' @param field Name of the list field to extract.
#' @return Unnamed list with one cell per record, in record (insertion)
#'   order.
#' @keywords internal
dagri_table_list <- function(records, field) {
  unname(lapply(records, function(record) record[[field]]))
}

#' Assemble a tabular accessor's data.frame
#'
#' Internal helper shared by [dagri_nodes_df()], [dagri_edges_df()], and
#' [dagri_gates_df()]. The scalar character columns go through
#' `data.frame()`; the list-columns are attached afterwards because
#' `data.frame()` would spread a list argument across several columns.
#' Row names stay the plain automatic sequence — record ids are data in the
#' `id` column, never row names. When every column is zero-length this
#' returns the empty skeleton: a zero-row frame with identical column names
#' and per-column classes as the populated case.
#'
#' @param scalar_columns Named list of equal-length character vectors.
#' @param list_columns Named list of list-columns (one cell per row).
#' @return A base `data.frame` with the scalar columns followed by the
#'   list-columns.
#' @keywords internal
dagri_table_frame <- function(scalar_columns, list_columns) {
  df <- do.call(
    data.frame,
    c(scalar_columns, list(stringsAsFactors = FALSE, check.names = FALSE))
  )
  for (column in names(list_columns)) {
    df[[column]] <- list_columns[[column]]
  }
  df
}

#' Tabular view of graph nodes
#'
#' Builds a base `data.frame` with one row per node, for reporting and quick
#' inspection. Rows follow graph insertion order (the order of the
#' `graph$nodes` map); sort or subset the result explicitly when a different
#' order is needed.
#'
#' Aborts with class `dagri_error_invalid_argument` when `graph` is not a
#' valid `dagri_graph`.
#'
#' @param graph A \code{dagri_graph}.
#'
#' @return A base `data.frame` with one row per node and these columns, in
#'   this exact order:
#'   \itemize{
#'     \item `id`, `kind`, `state`, `block_reason`: character.
#'     \item `label`: character; `NA_character_` when the node has no label.
#'     \item `params`, `metadata`: list-columns; each cell is the node's
#'       stored `params`/`metadata` list, verbatim.
#'   }
#'   Node ids live in the `id` column as character values and the frame
#'   carries plain automatic row names — ids never become row names. An
#'   empty graph returns a zero-row frame with identical column names and
#'   per-column classes.
#'
#' @details `state` and `block_reason` mirror the STORED node fields —
#'   whatever [dagri_recompute_state()] last wrote (`"new"` / `"none"` until
#'   then). This is an accessor, not a planner: it never derives state.
#'
#' @examples
#' registry <- dagri_registry(dagri_kind("source"), dagri_kind("fit"))
#' graph <- dagri_graph(registry) |>
#'   dagri_add_node("data", "source", label = "Data") |>
#'   dagri_add_node("fit", "fit", params = list(method = "lm")) |>
#'   dagri_add_edge("data", "fit", id = "e1")
#'
#' nodes <- dagri_nodes_df(graph)
#' nodes[, c("id", "kind", "label", "state")]
#' nodes$params
#' @export
dagri_nodes_df <- function(graph) {
  dagri_validate_graph(graph)

  nodes <- graph$nodes
  dagri_table_frame(
    scalar_columns = list(
      id = dagri_table_chr(nodes, "id"),
      kind = dagri_table_chr(nodes, "kind"),
      label = dagri_table_chr(nodes, "label"),
      state = dagri_table_chr(nodes, "state"),
      block_reason = dagri_table_chr(nodes, "block_reason")
    ),
    list_columns = list(
      params = dagri_table_list(nodes, "params"),
      metadata = dagri_table_list(nodes, "metadata")
    )
  )
}

#' Tabular view of graph edges
#'
#' Builds a base `data.frame` with one row per edge, for reporting and quick
#' inspection. Rows follow graph insertion order (the order of the
#' `graph$edges` map); sort or subset the result explicitly when a different
#' order is needed.
#'
#' Aborts with class `dagri_error_invalid_argument` when `graph` is not a
#' valid `dagri_graph`.
#'
#' @param graph A \code{dagri_graph}.
#'
#' @return A base `data.frame` with one row per edge and these columns, in
#'   this exact order:
#'   \itemize{
#'     \item `id`, `from`, `to`, `type`: character.
#'     \item `metadata`: list-column; each cell is the edge's stored
#'       `metadata` list, verbatim.
#'   }
#'   Edge ids live in the `id` column as character values and the frame
#'   carries plain automatic row names — ids never become row names. An
#'   empty graph returns a zero-row frame with identical column names and
#'   per-column classes.
#'
#' @examples
#' registry <- dagri_registry(dagri_kind("source"), dagri_kind("fit"))
#' graph <- dagri_graph(registry) |>
#'   dagri_add_node("data", "source") |>
#'   dagri_add_node("fit", "fit") |>
#'   dagri_add_edge("data", "fit", id = "e1", metadata = list(weight = 2))
#'
#' edges <- dagri_edges_df(graph)
#' edges[, c("id", "from", "to", "type")]
#' edges$metadata
#' @export
dagri_edges_df <- function(graph) {
  dagri_validate_graph(graph)

  edges <- graph$edges
  dagri_table_frame(
    scalar_columns = list(
      id = dagri_table_chr(edges, "id"),
      from = dagri_table_chr(edges, "from"),
      to = dagri_table_chr(edges, "to"),
      type = dagri_table_chr(edges, "type")
    ),
    list_columns = list(
      metadata = dagri_table_list(edges, "metadata")
    )
  )
}

#' Tabular view of graph gates
#'
#' Builds a base `data.frame` with one row per gate, for reporting and quick
#' inspection. Rows follow graph insertion order (the order of the
#' `graph$gates` map); sort or subset the result explicitly when a different
#' order is needed.
#'
#' Aborts with class `dagri_error_invalid_argument` when `graph` is not a
#' valid `dagri_graph`.
#'
#' @param graph A \code{dagri_graph}.
#'
#' @return A base `data.frame` with one row per gate and these columns, in
#'   this exact order:
#'   \itemize{
#'     \item `id`, `edge_id`, `status`: character.
#'     \item `metadata`: list-column; each cell is the gate's stored
#'       `metadata` list, verbatim.
#'   }
#'   Gate ids live in the `id` column as character values and the frame
#'   carries plain automatic row names — ids never become row names. An
#'   empty graph returns a zero-row frame with identical column names and
#'   per-column classes.
#'
#' @examples
#' registry <- dagri_registry(dagri_kind("source"), dagri_kind("fit"))
#' graph <- dagri_graph(registry) |>
#'   dagri_add_node("data", "source") |>
#'   dagri_add_node("fit", "fit") |>
#'   dagri_add_edge("data", "fit", id = "e1") |>
#'   dagri_add_gate("e1", id = "review")
#'
#' gates <- dagri_gates_df(graph)
#' gates[, c("id", "edge_id", "status")]
#' gates$metadata
#' @export
dagri_gates_df <- function(graph) {
  dagri_validate_graph(graph)

  gates <- graph$gates
  dagri_table_frame(
    scalar_columns = list(
      id = dagri_table_chr(gates, "id"),
      edge_id = dagri_table_chr(gates, "edge_id"),
      status = dagri_table_chr(gates, "status")
    ),
    list_columns = list(
      metadata = dagri_table_list(gates, "metadata")
    )
  )
}
