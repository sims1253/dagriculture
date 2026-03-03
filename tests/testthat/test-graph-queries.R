describe("graph querying and topology", {
  reg <- groots_registry(groots_kind("a"), groots_kind("b"))
  g <- groots_graph(reg) |>
    groots_add_node("n1", "a") |>
    groots_add_node("n2", "b") |>
    groots_add_node("n3", "b") |>
    groots_add_node("n4", "b") |>
    groots_add_edge("n1", "n2", id = "e1") |>
    groots_add_edge("n2", "n3", id = "e2") |>
    groots_add_edge("n1", "n4", id = "e3") |>
    groots_add_gate("e2", id = "g1")

  describe("node and edge accessors", {
    it("groots_node() retrieves a node", {
      expect_identical(groots_node(g, "n1")$id, "n1")
    })

    it("groots_node() errors if missing", {
      expect_error(groots_node(g, "missing"), class = "groots_error_not_found")
    })

    it("groots_edge() retrieves an edge", {
      expect_identical(groots_edge(g, "e1")$id, "e1")
    })

    it("groots_gate() retrieves a gate", {
      expect_identical(groots_gate(g, "g1")$id, "g1")
    })

    it("plural accessors retrieve lists", {
      expect_length(groots_nodes(g), 4)
      expect_length(groots_edges(g), 3)
      expect_length(groots_gates(g), 1)
    })
  })

  describe("topology functions", {
    it("groots_upstream() and downstream() return immediate neighbors", {
      expect_setequal(groots_upstream(g, "n3"), "n2")
      expect_setequal(groots_downstream(g, "n1"), c("n2", "n4"))
    })

    it("groots_ancestors() and descendants() traverse the full graph", {
      expect_setequal(groots_ancestors(g, "n3"), c("n1", "n2"))
      expect_setequal(groots_descendants(g, "n1"), c("n2", "n3", "n4"))
    })

    it("groots_roots() and leaves() find endpoints", {
      expect_setequal(groots_roots(g), "n1")
      expect_setequal(groots_leaves(g), c("n3", "n4"))
    })

    it("groots_has_path() correctly identifies reachability", {
      expect_true(groots_has_path(g, "n1", "n3"))
      expect_false(groots_has_path(g, "n3", "n1"))
      expect_false(groots_has_path(g, "n2", "n4"))
    })

    it("groots_topo_order() returns a valid sorting", {
      order <- groots_topo_order(g)
      expect_length(order, 4)
      expect_true(which(order == "n1") < which(order == "n2"))
      expect_true(which(order == "n2") < which(order == "n3"))
      expect_true(which(order == "n1") < which(order == "n4"))
    })

    it("groots_topo_order(subset) returns valid sorting for subset", {
      order <- groots_topo_order(g, subset = c("n1", "n3"))
      expect_length(order, 2)
      expect_true(which(order == "n1") < which(order == "n3"))
    })
  })
})
