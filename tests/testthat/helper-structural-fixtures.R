dagri_fixture_gated_chain <- function() {
  reg <- dagri_registry(dagri_kind("source"), dagri_kind("process"))
  graph <- dagri_graph(reg) |>
    dagri_add_node("n1", "source") |>
    dagri_add_node("n2", "process") |>
    dagri_add_node("n3", "process") |>
    dagri_add_edge("n1", "n2", id = "e1") |>
    dagri_add_edge("n2", "n3", id = "e2") |>
    dagri_add_gate("e1", id = "gate1")

  list(
    graph = graph,
    targets = "n3",
    gate_id = "gate1"
  )
}

dagri_fixture_branching_graph <- function() {
  reg <- dagri_registry(dagri_kind("source"), dagri_kind("process"))
  graph <- dagri_graph(reg) |>
    dagri_add_node("n1", "source") |>
    dagri_add_node("n2", "process") |>
    dagri_add_node("n3", "process") |>
    dagri_add_node("n4", "process") |>
    dagri_add_edge("n1", "n2", id = "e1") |>
    dagri_add_edge("n2", "n3", id = "e2") |>
    dagri_add_edge("n2", "n4", id = "e3")

  list(
    graph = graph,
    targets = c("n3", "n4")
  )
}
