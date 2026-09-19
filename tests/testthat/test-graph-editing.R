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

    it("rejects non-string kind parameter", {
      expect_error(
        dagri_add_node(g0, "n1", kind = 123),
        class = "dagri_error_invalid_argument"
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
      g2 <- dagri_update_node(g1, id = "n1", label = "Updated Source")

      expect_identical(g2$version, g1$version + 1L)
      expect_identical(g2$nodes[["n1"]]$label, "Updated Source")
    })

    it("updates params only, preserving other fields", {
      g1 <- dagri_add_node(g0, id = "n1", kind = "source", label = "Original")
      g2 <- dagri_update_node(g1, id = "n1", params = list(key = "val"))

      expect_identical(g2$nodes[["n1"]]$params, list(key = "val"))
      expect_identical(g2$nodes[["n1"]]$label, "Original")
      expect_identical(g2$nodes[["n1"]]$metadata, list())
    })

    it("updates metadata only, preserving other fields", {
      g1 <- dagri_add_node(g0, id = "n1", kind = "source", label = "Original")
      g2 <- dagri_update_node(g1, id = "n1", metadata = list(tag = "test"))

      expect_identical(g2$nodes[["n1"]]$metadata, list(tag = "test"))
      expect_identical(g2$nodes[["n1"]]$label, "Original")
      expect_identical(g2$nodes[["n1"]]$params, list())
    })

    it("errors if node is not found", {
      expect_error(
        dagri_update_node(g0, "missing", label = "Test"),
        class = "dagri_error_not_found"
      )
    })

    it("params is replaced, not merged (replace semantics regression guard)", {
      # A node carrying params = list(a=1, b=2); updating with params = list(c=3)
      # must yield exactly list(c=3), NOT list(a=1, b=2, c=3). Consumers that
      # want merge must do utils::modifyList() themselves (see ?dagri_update_node).
      g1 <- dagri_add_node(g0, id = "n1", kind = "source", params = list(a = 1, b = 2))
      g2 <- dagri_update_node(g1, id = "n1", params = list(c = 3))

      expect_identical(g2$nodes[["n1"]]$params, list(c = 3))
      expect_false("a" %in% names(g2$nodes[["n1"]]$params))
      expect_false("b" %in% names(g2$nodes[["n1"]]$params))
    })

    it("metadata is replaced, not merged (replace semantics regression guard)", {
      g1 <- dagri_add_node(g0, id = "n1", kind = "source", metadata = list(a = 1, b = 2))
      g2 <- dagri_update_node(g1, id = "n1", metadata = list(c = 3))

      expect_identical(g2$nodes[["n1"]]$metadata, list(c = 3))
      expect_false("a" %in% names(g2$nodes[["n1"]]$metadata))
      expect_false("b" %in% names(g2$nodes[["n1"]]$metadata))
    })

    it("NULL params/metadata/label leave the fields untouched", {
      g1 <- dagri_add_node(
        g0,
        id = "n1",
        kind = "source",
        label = "L",
        params = list(a = 1),
        metadata = list(b = 2)
      )
      g2 <- dagri_update_node(g1, id = "n1")

      expect_identical(g2$nodes[["n1"]]$label, "L")
      expect_identical(g2$nodes[["n1"]]$params, list(a = 1))
      expect_identical(g2$nodes[["n1"]]$metadata, list(b = 2))
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

    it("rejects edges with missing from node", {
      expect_error(
        dagri_add_edge(g2, from = "n_missing", to = "n2"),
        class = "dagri_error_not_found"
      )
    })

    it("rejects invalid type parameter", {
      expect_error(
        dagri_add_edge(g2, "n1", "n2", type = 123),
        class = "dagri_error_invalid_argument"
      )
    })
  })

  describe("dagri_update_edge()", {
    g_nodes <- dagri_add_node(g0, "n1", "source") |> dagri_add_node("n2", "process")
    g_edge <- dagri_add_edge(
      g_nodes,
      from = "n1",
      to = "n2",
      id = "e1",
      type = "data",
      metadata = list(weight = 1)
    )

    it("replaces the edge type and increments graph version", {
      g2 <- dagri_update_edge(g_edge, "e1", type = "control")

      expect_identical(g2$version, g_edge$version + 1L)
      expect_identical(g2$edges[["e1"]]$type, "control")
    })

    it("replaces metadata, not merges (replace semantics regression guard)", {
      g2 <- dagri_update_edge(g_edge, "e1", metadata = list(weight = 2, note = "revised"))

      expect_identical(g2$edges[["e1"]]$metadata, list(weight = 2, note = "revised"))
      expect_identical(g2$edges[["e1"]]$type, "data")
    })

    it("updates type and metadata together", {
      g2 <- dagri_update_edge(
        g_edge,
        "e1",
        type = "control",
        metadata = list(weight = 9)
      )

      expect_identical(g2$edges[["e1"]]$type, "control")
      expect_identical(g2$edges[["e1"]]$metadata, list(weight = 9))
    })

    it("NULL type/metadata leave the fields untouched (and still bump version)", {
      g2 <- dagri_update_edge(g_edge, "e1")

      expect_identical(g2$edges[["e1"]]$type, "data")
      expect_identical(g2$edges[["e1"]]$metadata, list(weight = 1))
      expect_identical(g2$version, g_edge$version + 1L)
    })

    it("preserves id, from, and to", {
      g2 <- dagri_update_edge(g_edge, "e1", type = "control")

      expect_identical(g2$edges[["e1"]]$id, "e1")
      expect_identical(g2$edges[["e1"]]$from, "n1")
      expect_identical(g2$edges[["e1"]]$to, "n2")
    })

    it("does not mutate the original graph", {
      g2 <- dagri_update_edge(g_edge, "e1", type = "control", metadata = list(weight = 9))

      expect_identical(g_edge$edges[["e1"]]$type, "data")
      expect_identical(g_edge$edges[["e1"]]$metadata, list(weight = 1))
      expect_identical(g_edge$version, g2$version - 1L)
    })

    it("errors if edge is not found", {
      expect_error(
        dagri_update_edge(g_edge, "missing", type = "control"),
        class = "dagri_error_not_found"
      )
    })

    it("rejects invalid type values", {
      expect_error(
        dagri_update_edge(g_edge, "e1", type = 123),
        class = "dagri_error_invalid_argument"
      )
      expect_error(
        dagri_update_edge(g_edge, "e1", type = c("a", "b")),
        class = "dagri_error_invalid_argument"
      )
      expect_error(
        dagri_update_edge(g_edge, "e1", type = NA_character_),
        class = "dagri_error_invalid_argument"
      )
      expect_error(
        dagri_update_edge(g_edge, "e1", type = ""),
        class = "dagri_error_invalid_argument"
      )
    })

    it("rejects invalid metadata", {
      expect_error(
        dagri_update_edge(g_edge, "e1", metadata = "not a list"),
        class = "dagri_error_invalid_argument"
      )
      expect_error(
        dagri_update_edge(g_edge, "e1", metadata = list("unnamed")),
        class = "dagri_error_invalid_argument"
      )
      expect_error(
        dagri_update_edge(g_edge, "e1", metadata = list(fn = function(x) x)),
        class = "dagri_error_invalid_argument"
      )
    })

    it("rejects vector, NA, and empty edge_id", {
      expect_error(
        dagri_update_edge(g_edge, c("a", "b")),
        class = "dagri_error_invalid_argument"
      )
      expect_error(
        dagri_update_edge(g_edge, NA_character_),
        class = "dagri_error_invalid_argument"
      )
      expect_error(
        dagri_update_edge(g_edge, ""),
        class = "dagri_error_invalid_argument"
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

  describe("dagri_update_gate()", {
    g_gate <- dagri_add_node(g0, "n1", "source") |>
      dagri_add_node("n2", "process") |>
      dagri_add_edge(from = "n1", to = "n2", id = "e1") |>
      dagri_add_gate(edge_id = "e1", id = "gate1", metadata = list(approver = "max"))

    it("replaces gate metadata and increments graph version", {
      g2 <- dagri_update_gate(g_gate, "gate1", metadata = list(approver = "reviewer_b"))

      expect_identical(g2$version, g_gate$version + 1L)
      expect_identical(g2$gates[["gate1"]]$metadata, list(approver = "reviewer_b"))
    })

    it("replaces metadata, not merges (replace semantics regression guard)", {
      g2 <- dagri_update_gate(g_gate, "gate1", metadata = list(note = "re-prompted"))

      expect_identical(g2$gates[["gate1"]]$metadata, list(note = "re-prompted"))
      expect_false("approver" %in% names(g2$gates[["gate1"]]$metadata))
    })

    it("NULL metadata leaves the field untouched (and still bumps version)", {
      g2 <- dagri_update_gate(g_gate, "gate1")

      expect_identical(g2$gates[["gate1"]]$metadata, list(approver = "max"))
      expect_identical(g2$version, g_gate$version + 1L)
    })

    it("preserves id, edge_id, and status", {
      g2 <- dagri_update_gate(g_gate, "gate1", metadata = list(a = 1))

      expect_identical(g2$gates[["gate1"]]$id, "gate1")
      expect_identical(g2$gates[["gate1"]]$edge_id, "e1")
      expect_identical(g2$gates[["gate1"]]$status, "pending")
    })

    it("does not mutate the original graph", {
      g2 <- dagri_update_gate(g_gate, "gate1", metadata = list(a = 1))

      expect_identical(g_gate$gates[["gate1"]]$metadata, list(approver = "max"))
      expect_identical(g_gate$version, g2$version - 1L)
    })

    it("errors if gate is not found", {
      expect_error(
        dagri_update_gate(g_gate, "missing", metadata = list(a = 1)),
        class = "dagri_error_not_found"
      )
    })

    it("rejects invalid metadata", {
      expect_error(
        dagri_update_gate(g_gate, "gate1", metadata = "not a list"),
        class = "dagri_error_invalid_argument"
      )
      expect_error(
        dagri_update_gate(g_gate, "gate1", metadata = list("unnamed")),
        class = "dagri_error_invalid_argument"
      )
      expect_error(
        dagri_update_gate(g_gate, "gate1", metadata = list(env = new.env())),
        class = "dagri_error_invalid_argument"
      )
    })

    it("rejects vector, NA, and empty gate_id", {
      expect_error(
        dagri_update_gate(g_gate, c("a", "b")),
        class = "dagri_error_invalid_argument"
      )
      expect_error(
        dagri_update_gate(g_gate, NA_character_),
        class = "dagri_error_invalid_argument"
      )
      expect_error(
        dagri_update_gate(g_gate, ""),
        class = "dagri_error_invalid_argument"
      )
    })
  })

  describe("metadata validation at editing entry points", {
    it("dagri_add_node rejects closures in metadata", {
      expect_error(
        dagri_add_node(g0, "n1", "source", metadata = list(a = function(x) x)),
        class = "dagri_error_invalid_argument"
      )
    })

    it("dagri_add_node rejects nested closures in metadata", {
      expect_error(
        dagri_add_node(g0, "n1", "source", metadata = list(a = list(b = function() 1))),
        class = "dagri_error_invalid_argument"
      )
    })

    it("dagri_add_node rejects non-list and unnamed metadata", {
      expect_error(
        dagri_add_node(g0, "n1", "source", metadata = "not a list"),
        class = "dagri_error_invalid_argument"
      )
      expect_error(
        dagri_add_node(g0, "n1", "source", metadata = list("unnamed")),
        class = "dagri_error_invalid_argument"
      )
    })

    it("dagri_add_node round-trips valid metadata", {
      g1 <- dagri_add_node(
        g0,
        "n1",
        "source",
        metadata = list(uri = "source:observations_v1", tags = c("raw", "etl"))
      )
      expect_identical(
        g1$nodes[["n1"]]$metadata,
        list(uri = "source:observations_v1", tags = c("raw", "etl"))
      )
    })

    it("dagri_update_node rejects invalid metadata", {
      g1 <- dagri_add_node(g0, "n1", "source")
      expect_error(
        dagri_update_node(g1, "n1", metadata = list(fn = function(x) x)),
        class = "dagri_error_invalid_argument"
      )
      expect_error(
        dagri_update_node(g1, "n1", metadata = list("unnamed")),
        class = "dagri_error_invalid_argument"
      )
    })

    it("dagri_add_edge rejects invalid metadata", {
      g2 <- dagri_add_node(g0, "n1", "source") |> dagri_add_node("n2", "process")
      expect_error(
        dagri_add_edge(g2, "n1", "n2", id = "e1", metadata = list(fn = mean)),
        class = "dagri_error_invalid_argument"
      )
      expect_error(
        dagri_add_edge(g2, "n1", "n2", id = "e1", metadata = "not a list"),
        class = "dagri_error_invalid_argument"
      )
    })

    it("dagri_add_gate rejects invalid metadata", {
      g2 <- dagri_add_node(g0, "n1", "source") |>
        dagri_add_node("n2", "process") |>
        dagri_add_edge("n1", "n2", id = "e1")
      expect_error(
        dagri_add_gate(g2, "e1", metadata = list(env = new.env())),
        class = "dagri_error_invalid_argument"
      )
      expect_error(
        dagri_add_gate(g2, "e1", metadata = list("unnamed")),
        class = "dagri_error_invalid_argument"
      )
    })

    it("graph-level constructor metadata flows into editing functions", {
      g <- dagri_graph(dagri_registry(dagri_kind("source")), metadata = list(project = "p"))
      g1 <- dagri_add_node(g, "n1", "source")
      expect_identical(g1$metadata, list(project = "p"))
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

  describe("dagri_remove_gate()", {
    it("removes a gate and increments version", {
      g2 <- dagri_add_node(g0, "n1", "source") |> dagri_add_node("n2", "process")
      g_gate <- dagri_add_edge(g2, "n1", "n2", id = "e1") |>
        dagri_add_gate(edge_id = "e1", id = "gate1")

      g_removed <- dagri_remove_gate(g_gate, "gate1")
      expect_identical(g_removed$version, g_gate$version + 1L)
      expect_false("gate1" %in% names(g_removed$gates))
    })

    it("errors if gate is not found", {
      expect_error(
        dagri_remove_gate(g0, "nonexistent"),
        class = "dagri_error_not_found"
      )
    })
  })

  describe("graph validation in editing functions", {
    bad_graph <- list(nodes = list())

    it("dagri_add_node rejects invalid graph", {
      expect_error(
        dagri_add_node(bad_graph, "n1", "source"),
        class = "dagri_error_invalid_argument"
      )
    })

    it("dagri_update_node rejects invalid graph", {
      expect_error(
        dagri_update_node(bad_graph, "n1"),
        class = "dagri_error_invalid_argument"
      )
    })

    it("dagri_remove_node rejects invalid graph", {
      expect_error(
        dagri_remove_node(bad_graph, "n1"),
        class = "dagri_error_invalid_argument"
      )
    })

    it("dagri_add_edge rejects invalid graph", {
      expect_error(
        dagri_add_edge(bad_graph, "n1", "n2"),
        class = "dagri_error_invalid_argument"
      )
    })

    it("dagri_update_edge rejects invalid graph", {
      expect_error(
        dagri_update_edge(bad_graph, "e1"),
        class = "dagri_error_invalid_argument"
      )
    })

    it("dagri_remove_edge rejects invalid graph", {
      expect_error(
        dagri_remove_edge(bad_graph, "e1"),
        class = "dagri_error_invalid_argument"
      )
    })

    it("dagri_add_gate rejects invalid graph", {
      expect_error(
        dagri_add_gate(bad_graph, "e1"),
        class = "dagri_error_invalid_argument"
      )
    })

    it("dagri_update_gate rejects invalid graph", {
      expect_error(
        dagri_update_gate(bad_graph, "gate1"),
        class = "dagri_error_invalid_argument"
      )
    })

    it("dagri_resolve_gate rejects invalid graph", {
      expect_error(
        dagri_resolve_gate(bad_graph, "gate1"),
        class = "dagri_error_invalid_argument"
      )
    })

    it("dagri_reopen_gate rejects invalid graph", {
      expect_error(
        dagri_reopen_gate(bad_graph, "gate1"),
        class = "dagri_error_invalid_argument"
      )
    })

    it("dagri_remove_gate rejects invalid graph", {
      expect_error(
        dagri_remove_gate(bad_graph, "gate1"),
        class = "dagri_error_invalid_argument"
      )
    })
  })

  describe("id argument validation", {
    g1 <- dagri_add_node(g0, "n1", "source")
    g2 <- dagri_add_node(g1, "n2", "source")
    ge <- dagri_add_edge(g2, "n1", "n2", id = "e1")
    gg <- dagri_add_gate(ge, edge_id = "e1", id = "gate1")

    it("dagri_add_node rejects vector, NA, and empty ids", {
      expect_error(
        dagri_add_node(g0, c("a", "b"), "source"),
        class = "dagri_error_invalid_argument"
      )
      expect_error(
        dagri_add_node(g0, NA_character_, "source"),
        class = "dagri_error_invalid_argument"
      )
      expect_error(dagri_add_node(g0, "", "source"), class = "dagri_error_invalid_argument")
      expect_error(dagri_add_node(g0, 123, "source"), class = "dagri_error_invalid_argument")
    })

    it("dagri_add_edge rejects vector, NA, and empty from/to/id", {
      expect_error(dagri_add_edge(g2, c("a", "b"), "n2"), class = "dagri_error_invalid_argument")
      expect_error(dagri_add_edge(g2, "n1", NA_character_), class = "dagri_error_invalid_argument")
      expect_error(dagri_add_edge(g2, "n1", ""), class = "dagri_error_invalid_argument")
      expect_error(
        dagri_add_edge(g2, "n1", "n2", id = c("x", "y")),
        class = "dagri_error_invalid_argument"
      )
    })

    it("dagri_update_node rejects bad ids", {
      expect_error(dagri_update_node(g1, c("a", "b")), class = "dagri_error_invalid_argument")
      expect_error(dagri_update_node(g1, NA_character_), class = "dagri_error_invalid_argument")
    })

    it("dagri_remove_node rejects bad ids", {
      expect_error(dagri_remove_node(g1, c("a", "b")), class = "dagri_error_invalid_argument")
      expect_error(dagri_remove_node(g1, NA_character_), class = "dagri_error_invalid_argument")
    })

    it("dagri_remove_edge rejects bad ids", {
      expect_error(dagri_remove_edge(ge, c("a", "b")), class = "dagri_error_invalid_argument")
      expect_error(dagri_remove_edge(ge, NA_character_), class = "dagri_error_invalid_argument")
    })

    it("dagri_add_gate (edge_id) and gate verbs reject bad ids", {
      expect_error(
        dagri_add_gate(ge, edge_id = c("a", "b")),
        class = "dagri_error_invalid_argument"
      )
      expect_error(
        dagri_add_gate(ge, edge_id = NA_character_),
        class = "dagri_error_invalid_argument"
      )
      expect_error(dagri_resolve_gate(gg, c("a", "b")), class = "dagri_error_invalid_argument")
      expect_error(dagri_reopen_gate(gg, NA_character_), class = "dagri_error_invalid_argument")
      expect_error(dagri_remove_gate(gg, c("a", "b")), class = "dagri_error_invalid_argument")
    })

    it("dagri_kind rejects bad names", {
      expect_error(dagri_kind(c("a", "b")), class = "dagri_error_invalid_argument")
      expect_error(dagri_kind(NA_character_), class = "dagri_error_invalid_argument")
      expect_error(dagri_kind(""), class = "dagri_error_invalid_argument")
      expect_error(dagri_kind(123), class = "dagri_error_invalid_argument")
    })
  })
})
