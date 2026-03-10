describe("graph editing operations", {
  # Setup basic registry and empty graph
  reg <- dagri_registry(dagri_kind("source"), dagri_kind("process"))
  g0 <- dagri_graph(reg)

  describe("dagri_add_node()", {
    it("adds a node and increments graph version", {
      g1 <- dagri_add_node(g0, id = "n1", kind = "source")
      expect_identical(g1$version, g0$version + 1L)
      expect_true("n1" %in% names(g1$nodes))

      n1 <- g1$nodes[["n1"]]
      expect_identical(n1$id, "n1")
      expect_identical(n1$kind, "source")
      expect_identical(n1$state, "new")
      expect_identical(n1$block_reason, "none")
    })

    it("rejects unknown kinds", {
      expect_error(
        dagri_add_node(g0, "n1", kind = "unknown"),
        class = "dagri_error_unknown_kind"
      )
    })

    it("rejects duplicate ids", {
      g1 <- dagri_add_node(g0, "n1", "source")
      expect_error(
        dagri_add_node(g1, "n1", "source"),
        class = "dagri_error_duplicate_id"
      )
    })
  })

  describe("dagri_update_node()", {
    it("updates a node and increments graph version", {
      g1 <- dagri_add_node(g0, id = "n1", kind = "source")
      g2 <- dagri_update_node(g1, node_id = "n1", label = "Updated Source")

      expect_identical(g2$version, g1$version + 1L)
      expect_identical(g2$nodes[["n1"]]$label, "Updated Source")
    })

    it("errors if node is not found", {
      expect_error(
        dagri_update_node(g0, "missing", label = "Test"),
        class = "dagri_error_not_found"
      )
    })
  })

  describe("dagri_remove_node()", {
    it("removes a node and increments graph version", {
      g1 <- dagri_add_node(g0, id = "n1", kind = "source")
      g2 <- dagri_remove_node(g1, "n1")

      expect_identical(g2$version, g1$version + 1L)
      expect_false("n1" %in% names(g2$nodes))
    })

    it("removes incident edges and their gates", {
      g1 <- dagri_add_node(g0, "n1", "source")
      g2 <- dagri_add_node(g1, "n2", "process")
      g3 <- dagri_add_edge(g2, "n1", "n2", id = "e1")
      g4 <- dagri_add_gate(g3, "e1", id = "gate1")

      g5 <- dagri_remove_node(g4, "n1")

      expect_false("n1" %in% names(g5$nodes))
      expect_false("e1" %in% names(g5$edges))
      expect_false("gate1" %in% names(g5$gates))
    })
  })

  describe("dagri_add_edge()", {
    g1 <- dagri_add_node(g0, "n1", "source")
    g2 <- dagri_add_node(g1, "n2", "process")
    g3 <- dagri_add_node(g2, "n3", "process")

    it("adds an edge and increments version", {
      g_edge <- dagri_add_edge(g2, from = "n1", to = "n2", id = "e1")
      expect_identical(g_edge$version, g2$version + 1L)
      expect_true("e1" %in% names(g_edge$edges))
      expect_identical(g_edge$edges[["e1"]]$from, "n1")
      expect_identical(g_edge$edges[["e1"]]$to, "n2")
    })

    it("prevents cycles", {
      g_edge <- dagri_add_edge(g3, "n1", "n2", id = "e1")
      g_edge <- dagri_add_edge(g_edge, "n2", "n3", id = "e2")
      expect_error(
        dagri_add_edge(g_edge, "n3", "n1"),
        class = "dagri_error_cycle"
      )
    })

    it("rejects duplicate edge ids", {
      g_edge <- dagri_add_edge(g2, from = "n1", to = "n2", id = "e1")
      expect_error(
        dagri_add_edge(g_edge, from = "n1", to = "n2", id = "e1"),
        class = "dagri_error_duplicate_id"
      )
    })

    it("rejects edges between missing nodes", {
      expect_error(
        dagri_add_edge(g2, from = "n1", to = "n_missing"),
        class = "dagri_error_not_found"
      )
    })
  })

  describe("dagri_remove_edge()", {
    it("removes an edge and increments version", {
      g2 <- dagri_add_node(g0, "n1", "source") |> dagri_add_node("n2", "process")
      g_edge <- dagri_add_edge(g2, "n1", "n2", id = "e1")

      g_removed <- dagri_remove_edge(g_edge, "e1")
      expect_identical(g_removed$version, g_edge$version + 1L)
      expect_false("e1" %in% names(g_removed$edges))
    })

    it("removes gates attached to the edge", {
      g2 <- dagri_add_node(g0, "n1", "source") |> dagri_add_node("n2", "process")
      g_edge <- dagri_add_edge(g2, "n1", "n2", id = "e1") |>
        dagri_add_gate(edge_id = "e1", id = "gate1")

      g_removed <- dagri_remove_edge(g_edge, "e1")

      expect_false("e1" %in% names(g_removed$edges))
      expect_false("gate1" %in% names(g_removed$gates))
    })
  })

  describe("dagri_add_gate()", {
    g1 <- dagri_add_node(g0, "n1", "source")
    g2 <- dagri_add_node(g1, "n2", "process")
    g_edge <- dagri_add_edge(g2, from = "n1", to = "n2", id = "e1")

    it("adds a gate targeting an existing edge", {
      g_gate <- dagri_add_gate(g_edge, edge_id = "e1", id = "gate1")
      expect_identical(g_gate$version, g_edge$version + 1L)
      expect_true("gate1" %in% names(g_gate$gates))
      expect_identical(g_gate$gates[["gate1"]]$status, "pending")
    })

    it("rejects gates for missing edges", {
      expect_error(
        dagri_add_gate(g_edge, edge_id = "e_missing", id = "gate2"),
        class = "dagri_error_not_found"
      )
    })

    it("rejects duplicate gate ids", {
      g_gate <- dagri_add_gate(g_edge, edge_id = "e1", id = "gate1")
      expect_error(
        dagri_add_gate(g_gate, edge_id = "e1", id = "gate1"),
        class = "dagri_error_duplicate_id"
      )
    })
  })

  describe("dagri_resolve_gate()", {
    it("resolves a pending gate", {
      g2 <- dagri_add_node(g0, "n1", "source") |> dagri_add_node("n2", "process")
      g_gate <- dagri_add_edge(g2, "n1", "n2", id = "e1") |>
        dagri_add_gate(edge_id = "e1", id = "gate1")

      g_resolved <- dagri_resolve_gate(g_gate, "gate1")
      expect_identical(g_resolved$version, g_gate$version + 1L)
      expect_identical(g_resolved$gates[["gate1"]]$status, "resolved")
    })
  })

  describe("dagri_reopen_gate()", {
    it("reopens a resolved gate", {
      g2 <- dagri_add_node(g0, "n1", "source") |> dagri_add_node("n2", "process")
      g_gate <- dagri_add_edge(g2, "n1", "n2", id = "e1") |>
        dagri_add_gate(edge_id = "e1", id = "gate1") |>
        dagri_resolve_gate("gate1")

      g_reopened <- dagri_reopen_gate(g_gate, "gate1")
      expect_identical(g_reopened$version, g_gate$version + 1L)
      expect_identical(g_reopened$gates[["gate1"]]$status, "pending")
    })
  })
})
