describe("dagri_adjacency()", {
  reg <- dagri_registry(dagri_kind("a"), dagri_kind("b"))

  # 4 nodes, one isolated; 2 edges: n1 -> n2, n1 -> n3
  g <- dagri_graph(reg) |>
    dagri_add_node("n1", "a") |>
    dagri_add_node("n2", "b") |>
    dagri_add_node("n3", "b") |>
    dagri_add_node("n4", "b") |> # isolated
    dagri_add_edge("n1", "n2", id = "e1") |>
    dagri_add_edge("n1", "n3", id = "e2")

  it("returns all four named maps keyed by every node id", {
    idx <- dagri_adjacency(g)

    expect_setequal(names(idx), c("forward", "reverse", "forward_edges", "reverse_edges"))

    for (map_name in c("forward", "reverse", "forward_edges", "reverse_edges")) {
      expect_setequal(names(idx[[map_name]]), c("n1", "n2", "n3", "n4"))
    }
  })

  it("builds forward and reverse neighbor maps", {
    idx <- dagri_adjacency(g)

    expect_setequal(idx$forward[["n1"]], c("n2", "n3"))
    expect_identical(idx$forward[["n2"]], character(0))
    expect_identical(idx$forward[["n3"]], character(0))
    expect_identical(idx$forward[["n4"]], character(0)) # isolated

    expect_identical(idx$reverse[["n1"]], character(0)) # root
    expect_setequal(idx$reverse[["n2"]], "n1")
    expect_setequal(idx$reverse[["n3"]], "n1")
    expect_identical(idx$reverse[["n4"]], character(0)) # isolated
  })

  it("builds forward_edges and reverse_edges maps (not uniqued)", {
    idx <- dagri_adjacency(g)

    expect_setequal(idx$forward_edges[["n1"]], c("e1", "e2"))
    expect_identical(idx$forward_edges[["n2"]], character(0))
    expect_identical(idx$forward_edges[["n3"]], character(0))
    expect_identical(idx$forward_edges[["n4"]], character(0))

    expect_identical(idx$reverse_edges[["n1"]], character(0))
    expect_identical(idx$reverse_edges[["n2"]], "e1")
    expect_identical(idx$reverse_edges[["n3"]], "e2")
    expect_identical(idx$reverse_edges[["n4"]], character(0))
  })

  it("preserves parallel edges distinctly in *_edges maps but uniques neighbors", {
    # Two edges between the same pair of nodes.
    g2 <- dagri_graph(reg) |>
      dagri_add_node("a", "a") |>
      dagri_add_node("b", "b") |>
      dagri_add_edge("a", "b", id = "e1") |>
      dagri_add_edge("a", "b", id = "e2")

    idx <- dagri_adjacency(g2)

    # forward neighbors are uniqued to a single entry
    expect_identical(idx$forward[["a"]], "b")
    expect_identical(idx$reverse[["b"]], "a")
    # forward_edges keeps both distinct edges
    expect_setequal(idx$forward_edges[["a"]], c("e1", "e2"))
    expect_setequal(idx$reverse_edges[["b"]], c("e1", "e2"))
  })

  it("returns four empty named lists for an empty graph", {
    idx <- dagri_adjacency(dagri_graph(reg))

    expect_setequal(names(idx), c("forward", "reverse", "forward_edges", "reverse_edges"))
    for (map_name in c("forward", "reverse", "forward_edges", "reverse_edges")) {
      expect_identical(idx[[map_name]], stats::setNames(list(), character(0)))
    }
  })

  it("aborts on an invalid graph", {
    expect_error(
      dagri_adjacency(list(nodes = list())),
      class = "dagri_error_invalid_argument"
    )
  })
})

describe("adjacency-indexed traversals are correct", {
  reg <- dagri_registry(dagri_kind("source"), dagri_kind("process"))

  # n1 -> n2 -> n3, with a gate on e1
  g <- dagri_graph(reg) |>
    dagri_add_node("n1", "source") |>
    dagri_add_node("n2", "process") |>
    dagri_add_node("n3", "process") |>
    dagri_add_edge("n1", "n2", id = "e1") |>
    dagri_add_edge("n2", "n3", id = "e2") |>
    dagri_add_gate("e1", id = "gate1")

  it("dagri_ancestors and dagri_descendants return the expected sets", {
    expect_setequal(dagri_ancestors(g, "n3"), c("n1", "n2"))
    expect_setequal(dagri_ancestors(g, "n2"), "n1")
    expect_identical(dagri_ancestors(g, "n1"), character(0))

    expect_setequal(dagri_descendants(g, "n1"), c("n2", "n3"))
    expect_setequal(dagri_descendants(g, "n2"), "n3")
    expect_identical(dagri_descendants(g, "n3"), character(0))
  })

  it("dagri_has_path identifies reachability in both directions", {
    expect_true(dagri_has_path(g, "n1", "n3"))
    expect_true(dagri_has_path(g, "n1", "n2"))
    expect_false(dagri_has_path(g, "n3", "n1"))
    expect_false(dagri_has_path(g, "n2", "n1"))
    # self is not considered reachable (descendants excludes start)
    expect_false(dagri_has_path(g, "n1", "n1"))
  })

  it("dagri_topo_order returns a valid ordering", {
    order <- dagri_topo_order(g)
    expect_setequal(order, c("n1", "n2", "n3"))
    expect_true(which(order == "n1") < which(order == "n2"))
    expect_true(which(order == "n2") < which(order == "n3"))
  })

  it("dagri_recompute_state marks gate and downstream blockage", {
    g_state <- dagri_recompute_state(g)

    expect_identical(dagri_node(g_state, "n1")$state, "ready")
    expect_identical(dagri_node(g_state, "n2")$state, "blocked")
    expect_identical(dagri_node(g_state, "n2")$block_reason, "gate")
    expect_identical(dagri_node(g_state, "n3")$state, "blocked")
    expect_identical(dagri_node(g_state, "n3")$block_reason, "upstream_blocked")
  })

  it("dagri_plan threads one shared index through topo and external_blocked", {
    g_resolved <- dagri_resolve_gate(g, "gate1") |> dagri_recompute_state()
    plan <- dagri_plan(
      g_resolved,
      targets = "n3",
      external_holds = list(n1 = "manual_pause")
    )

    expect_setequal(plan$targets, c("n1", "n2", "n3"))
    expect_setequal(plan$terminal, "n3")
    expect_setequal(plan$eligible, c("n1", "n2", "n3"))
    expect_identical(
      plan$external_blocked,
      list(
        n1 = "manual_pause",
        n2 = "manual_pause",
        n3 = "manual_pause"
      )
    )
    expect_identical(plan$blocked, stats::setNames(list(), character(0)))
    expect_identical(plan$pending_gates, character(0))
  })
})

describe("adjacency index scales to 1000 nodes", {
  it("dagri_descendants on a 1000-node chain completes quickly", {
    skip_on_cran()

    reg <- dagri_registry(dagri_kind("node"))
    g <- dagri_graph(reg)
    for (i in 1:1000) {
      g <- dagri_add_node(g, as.character(i), "node")
    }
    for (i in 1:999) {
      g <- dagri_add_edge(g, as.character(i), as.character(i + 1))
    }

    t0 <- proc.time()[["elapsed"]]
    desc <- dagri_descendants(g, "1")
    elapsed <- proc.time()[["elapsed"]] - t0

    expect_length(desc, 999L)
    cat(sprintf("\n[dagri_descendants 1000-chain] elapsed=%.3fs\n", elapsed))
    expect_true(elapsed < 5)
  })

  it("dagri_plan on a 1000-node layered graph completes quickly", {
    skip_on_cran()

    # 10 layers x 100 nodes; edges connect node i to i+100 (layer to next layer).
    reg <- dagri_registry(dagri_kind("node"))
    g <- dagri_graph(reg)
    for (i in 1:1000) {
      g <- dagri_add_node(g, as.character(i), "node")
    }
    for (layer in 0:8) {
      for (j in 1:100) {
        from <- layer * 100 + j
        to <- from + 100
        g <- dagri_add_edge(g, as.character(from), as.character(to))
      }
    }
    g <- dagri_recompute_state(g)

    t0 <- proc.time()[["elapsed"]]
    plan <- dagri_plan(g, targets = as.character(901:1000))
    elapsed <- proc.time()[["elapsed"]] - t0

    cat(sprintf("\n[dagri_plan 1000-layered] elapsed=%.3fs\n", elapsed))
    expect_true(elapsed < 5)
    expect_length(plan$topo_order, 1000L)
    # all 1000 nodes are reachable from the last layer (full ancestor closure)
    expect_length(plan$targets, 1000L)
  })
})

describe("dagri_terminal and dagri_external_blocked on a non-linear (diamond + parallel-edge) graph", {
  reg <- dagri_registry(dagri_kind("a"), dagri_kind("b"))

  # Diamond: n1 -> n2 -> n4, n1 -> n3 -> n4, plus a parallel edge n1 -> n4
  # to exercise neighbor dedup.
  g <- dagri_graph(reg) |>
    dagri_add_node("n1", "a") |>
    dagri_add_node("n2", "b") |>
    dagri_add_node("n3", "b") |>
    dagri_add_node("n4", "b") |>
    dagri_add_edge("n1", "n2", id = "e1") |>
    dagri_add_edge("n1", "n3", id = "e2") |>
    dagri_add_edge("n2", "n4", id = "e3") |>
    dagri_add_edge("n3", "n4", id = "e4") |>
    dagri_add_edge("n1", "n4", id = "e5") # parallel edge to the diamond sink

  it("dagri_terminal returns the only leaf on the full graph", {
    expect_setequal(dagri_terminal(g), "n4")
  })

  it("dagri_terminal respects the targets scope", {
    # Excluding n4: n2 and n3 become the leaves of the scoped closure.
    expect_setequal(dagri_terminal(g, targets = c("n1", "n2", "n3")), c("n2", "n3"))
  })

  it("dagri_plan propagates an external hold on n2 downstream to n4 but not n3", {
    plan <- dagri_plan(g, external_holds = list(n2 = "manual"))

    expect_setequal(names(plan$external_blocked), c("n2", "n4"))
    expect_false("n3" %in% names(plan$external_blocked))
    expect_identical(plan$external_blocked[["n2"]], "manual")
    expect_identical(plan$external_blocked[["n4"]], "manual")
  })

  it("dagri_ancestors and dagri_descendants return the expected sets on the diamond", {
    expect_setequal(dagri_ancestors(g, "n4"), c("n1", "n2", "n3"))
    expect_setequal(dagri_descendants(g, "n1"), c("n2", "n3", "n4"))
  })
})
