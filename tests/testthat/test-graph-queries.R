describe("graph querying and topology", {
  reg <- dagri_registry(dagri_kind("a"), dagri_kind("b"))
  g <- dagri_graph(reg) |>
    dagri_add_node("n1", "a") |>
    dagri_add_node("n2", "b") |>
    dagri_add_node("n3", "b") |>
    dagri_add_node("n4", "b") |>
    dagri_add_edge("n1", "n2", id = "e1") |>
    dagri_add_edge("n2", "n3", id = "e2") |>
    dagri_add_edge("n1", "n4", id = "e3") |>
    dagri_add_gate("e2", id = "g1")

  describe("node and edge accessors", {
    it("dagri_node() retrieves a node", {
      expect_identical(dagri_node(g, "n1")$id, "n1")
    })

    it("dagri_node() errors if missing", {
      expect_error(dagri_node(g, "missing"), class = "dagri_error_not_found")
    })

    it("dagri_edge() retrieves an edge", {
      expect_identical(dagri_edge(g, "e1")$id, "e1")
    })

    it("dagri_gate() retrieves a gate", {
      expect_identical(dagri_gate(g, "g1")$id, "g1")
    })

    it("plural accessors retrieve lists", {
      expect_length(dagri_nodes(g), 4)
      expect_length(dagri_edges(g), 3)
      expect_length(dagri_gates(g), 1)
    })
  })

  describe("topology functions", {
    it("dagri_upstream() and downstream() return immediate neighbors", {
      expect_setequal(dagri_upstream(g, "n3"), "n2")
      expect_setequal(dagri_downstream(g, "n1"), c("n2", "n4"))
    })

    it("dagri_ancestors() and descendants() traverse the full graph", {
      expect_setequal(dagri_ancestors(g, "n3"), c("n1", "n2"))
      expect_setequal(dagri_descendants(g, "n1"), c("n2", "n3", "n4"))
    })

    it("dagri_roots() and leaves() find endpoints", {
      expect_setequal(dagri_roots(g), "n1")
      expect_setequal(dagri_leaves(g), c("n3", "n4"))
    })

    it("dagri_has_path() correctly identifies reachability", {
      expect_true(dagri_has_path(g, "n1", "n3"))
      expect_false(dagri_has_path(g, "n3", "n1"))
      expect_false(dagri_has_path(g, "n2", "n4"))
    })

    it("dagri_topo_order() returns a valid sorting", {
      order <- dagri_topo_order(g)
      expect_length(order, 4)
      expect_true(which(order == "n1") < which(order == "n2"))
      expect_true(which(order == "n2") < which(order == "n3"))
      expect_true(which(order == "n1") < which(order == "n4"))
    })

    it("dagri_topo_order(subset) returns valid sorting for subset", {
      order <- dagri_topo_order(g, subset = c("n1", "n3"))
      expect_length(order, 2)
      expect_true(which(order == "n1") < which(order == "n3"))
    })

    it("dagri_topo_order() returns empty for empty graph", {
      empty_g <- dagri_graph(reg)
      expect_identical(dagri_topo_order(empty_g), character(0))
    })

    it("dagri_topo_order() returns all nodes for disconnected graph", {
      disconnected <- dagri_graph(reg) |>
        dagri_add_node("a", "a") |>
        dagri_add_node("b", "b")
      order <- dagri_topo_order(disconnected)
      expect_setequal(order, c("a", "b"))
    })
  })

  describe("graph validation in query functions", {
    bad_graph <- list(nodes = list())

    it("dagri_node rejects invalid graph", {
      expect_error(dagri_node(bad_graph, "n1"), class = "dagri_error_invalid_argument")
    })

    it("dagri_edge rejects invalid graph", {
      expect_error(dagri_edge(bad_graph, "e1"), class = "dagri_error_invalid_argument")
    })

    it("dagri_gate rejects invalid graph", {
      expect_error(dagri_gate(bad_graph, "g1"), class = "dagri_error_invalid_argument")
    })

    it("dagri_nodes rejects invalid graph", {
      expect_error(dagri_nodes(bad_graph), class = "dagri_error_invalid_argument")
    })

    it("dagri_edges rejects invalid graph", {
      expect_error(dagri_edges(bad_graph), class = "dagri_error_invalid_argument")
    })

    it("dagri_gates rejects invalid graph", {
      expect_error(dagri_gates(bad_graph), class = "dagri_error_invalid_argument")
    })

    it("dagri_upstream rejects invalid graph", {
      expect_error(dagri_upstream(bad_graph, "n1"), class = "dagri_error_invalid_argument")
    })

    it("dagri_downstream rejects invalid graph", {
      expect_error(dagri_downstream(bad_graph, "n1"), class = "dagri_error_invalid_argument")
    })

    it("dagri_has_path rejects invalid graph", {
      expect_error(dagri_has_path(bad_graph, "n1", "n2"), class = "dagri_error_invalid_argument")
    })

    it("dagri_roots rejects invalid graph", {
      expect_error(dagri_roots(bad_graph), class = "dagri_error_invalid_argument")
    })

    it("dagri_leaves rejects invalid graph", {
      expect_error(dagri_leaves(bad_graph), class = "dagri_error_invalid_argument")
    })

    it("dagri_topo_order rejects invalid graph", {
      expect_error(dagri_topo_order(bad_graph), class = "dagri_error_invalid_argument")
    })
  })
})
