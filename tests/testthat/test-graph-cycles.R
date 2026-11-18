# Helpers for building cyclic graphs by bypassing dagri_add_edge(). The editing
# API (dagri_add_edge) refuses cycles, so to exercise the load-time cycle
# detection we hand-construct the edge list directly, mirroring what a
# corrupted JSON snapshot deserialized into R would look like.

dagri_force_edge <- function(graph, from, to, id = paste0("e_", from, "_", to)) {
  # Mutates the graph in place like a deserialized corrupted file would.
  graph$edges[[id]] <- list(id = id, from = from, to = to, type = "data", metadata = list())
  graph$version <- graph$version + 1L
  graph
}

describe("dagri_topo_order() cycle detection", {
  reg <- dagri_registry(dagri_kind("a"), dagri_kind("b"))

  it("aborts with dagri_error_cycle on a simple 2-node cycle", {
    g <- dagri_graph(reg) |>
      dagri_add_node("n1", "a") |>
      dagri_add_node("n2", "b")
    # Bypass dagri_add_edge: n1 -> n2 and n2 -> n1.
    g <- dagri_force_edge(g, "n1", "n2", id = "e1")
    g <- dagri_force_edge(g, "n2", "n1", id = "e2")

    err <- tryCatch(dagri_topo_order(g), error = function(e) e)
    expect_s3_class(err, "dagri_error_cycle")
    expect_setequal(err$details$cycle_nodes, c("n1", "n2"))
  })

  it("aborts with dagri_error_cycle on a 3-node cycle", {
    g <- dagri_graph(reg) |>
      dagri_add_node("n1", "a") |>
      dagri_add_node("n2", "b") |>
      dagri_add_node("n3", "b")
    g <- dagri_force_edge(g, "n1", "n2", id = "e1")
    g <- dagri_force_edge(g, "n2", "n3", id = "e2")
    g <- dagri_force_edge(g, "n3", "n1", id = "e3")

    err <- tryCatch(dagri_topo_order(g), error = function(e) e)
    expect_s3_class(err, "dagri_error_cycle")
    expect_setequal(err$details$cycle_nodes, c("n1", "n2", "n3"))
  })

  it("aborts with dagri_error_cycle when a cycle sits inside a subset", {
    g <- dagri_graph(reg) |>
      dagri_add_node("n1", "a") |>
      dagri_add_node("n2", "b") |>
      dagri_add_node("n3", "b") |>
      dagri_add_node("n4", "b")
    # n1 -> n2 is acyclic and outside the cycle; n2 <-> n3 forms the cycle.
    g <- dagri_force_edge(g, "n1", "n2", id = "e1")
    g <- dagri_force_edge(g, "n2", "n3", id = "e2")
    g <- dagri_force_edge(g, "n3", "n2", id = "e3")
    # n4 is an isolated node (no incident edges).
    err <- tryCatch(dagri_topo_order(g, subset = c("n2", "n3", "n4")), error = function(e) e)
    expect_s3_class(err, "dagri_error_cycle")
    expect_setequal(err$details$cycle_nodes, c("n2", "n3"))
  })

  it("regression: returns the full order for an acyclic graph", {
    g <- dagri_graph(reg) |>
      dagri_add_node("n1", "a") |>
      dagri_add_node("n2", "b") |>
      dagri_add_node("n3", "b") |>
      dagri_add_edge("n1", "n2", id = "e1") |>
      dagri_add_edge("n2", "n3", id = "e2")

    order <- dagri_topo_order(g)
    expect_length(order, 3)
    expect_true(which(order == "n1") < which(order == "n2"))
    expect_true(which(order == "n2") < which(order == "n3"))
  })

  it("dagri_add_edge still rejects cycles at edit time (edit-time guard)", {
    # Confirms the edit-time guard still fires before topo is ever called.
    g <- dagri_graph(reg) |>
      dagri_add_node("n1", "a") |>
      dagri_add_node("n2", "b") |>
      dagri_add_edge("n1", "n2", id = "e1")
    expect_error(dagri_add_edge(g, "n2", "n1"), class = "dagri_error_cycle")
  })
})

describe("self-loops", {
  reg <- dagri_registry(dagri_kind("a"))
  g <- dagri_graph(reg) |>
    dagri_add_node("n1", "a") |>
    dagri_add_node("n2", "a") |>
    dagri_add_edge("n1", "n2", id = "e1")

  it("dagri_add_edge() refuses an edge from a node to itself, naming the node", {
    err <- tryCatch(dagri_add_edge(g, "n1", "n1"), error = function(e) e)
    expect_s3_class(err, "dagri_error_cycle")
    expect_match(conditionMessage(err), "n1", fixed = TRUE)
    expect_identical(err$details$cycle_nodes, "n1")
  })

  it("refuses a graph that already holds a self-loop at every public entry", {
    looped <- dagri_force_edge(g, "n1", "n1", id = "loop")
    calls <- list(
      topo_order = function() dagri_topo_order(looped),
      recompute_state = function() dagri_recompute_state(looped),
      plan = function() dagri_plan(looped),
      eligible = function() dagri_eligible(looped),
      roots = function() dagri_roots(looped),
      has_path = function() dagri_has_path(looped, "n1", "n1"),
      mermaid = function() dagri_mermaid(looped),
      add_edge = function() dagri_add_edge(looped, "n2", "n1")
    )
    for (name in names(calls)) {
      err <- tryCatch(
        {
          calls[[name]]()
          NULL
        },
        error = function(e) e
      )
      expect_true(inherits(err, "dagri_error_cycle"), info = name)
      expect_identical(err$details$cycle_nodes, "n1", info = name)
      expect_identical(err$details$edge_id, "loop", info = name)
    }
  })
})
