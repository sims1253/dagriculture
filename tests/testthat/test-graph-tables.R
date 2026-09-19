describe("tabular accessors", {
  fx <- dagri_fixture_gated_chain()
  branching <- dagri_fixture_branching_graph()

  registry <- dagri_registry(dagri_kind("source"), dagri_kind("process"))
  rich <- dagri_graph(registry) |>
    dagri_add_node(
      "n1",
      "source",
      label = "Load data",
      params = list(path = "input.csv"),
      metadata = list(owner = "max")
    ) |>
    dagri_add_node("n2", "process", label = "Clean") |>
    dagri_add_edge("n1", "n2", id = "e1", metadata = list(weight = 2L)) |>
    dagri_add_gate("e1", id = "g1", metadata = list(review = "pending"))

  describe("dagri_nodes_df()", {
    it("returns the exact columns in the contract order", {
      expect_identical(
        names(dagri_nodes_df(rich)),
        c("id", "kind", "label", "state", "block_reason", "params", "metadata")
      )
    })

    it("types scalar columns as character and record fields as list-columns", {
      expect_identical(
        vapply(dagri_nodes_df(rich), class, character(1)),
        c(
          id = "character",
          kind = "character",
          label = "character",
          state = "character",
          block_reason = "character",
          params = "list",
          metadata = "list"
        )
      )
    })

    it("preserves graph insertion order", {
      expect_identical(dagri_nodes_df(branching$graph)$id, c("n1", "n2", "n3", "n4"))
    })

    it("keeps ids as plain character data, never row names", {
      df <- dagri_nodes_df(rich)
      expect_type(df$id, "character")
      # A base data.frame always carries row names (`rownames()` never
      # returns NULL for one, and a NULL row.names attribute would break
      # `nrow()`), so "no row-name semantics" means the row names stay the
      # neutral automatic sequence and ids live in the `id` column.
      expect_identical(rownames(df), as.character(seq_len(nrow(df))))
    })

    it("maps NULL labels to NA_character_", {
      df <- dagri_nodes_df(fx$graph)
      expect_identical(df$label, rep(NA_character_, nrow(df)))
    })

    it("stores params and metadata cells identical to the graph records", {
      df <- dagri_nodes_df(rich)
      expect_identical(df$params[[1]], rich$nodes$n1$params)
      expect_identical(df$metadata[[1]], rich$nodes$n1$metadata)
      expect_identical(df$params[[2]], rich$nodes$n2$params)
      expect_identical(df$metadata[[2]], rich$nodes$n2$metadata)
    })

    it("reports the stored state fields, not recomputed ones", {
      expect_identical(dagri_nodes_df(rich)$state, c("new", "new"))

      recomputed <- dagri_recompute_state(rich)
      expect_identical(dagri_nodes_df(recomputed)$state, c("ready", "blocked"))
      expect_identical(dagri_nodes_df(recomputed)$block_reason, c("none", "gate"))
    })

    it("returns a zero-row frame with identical shape for an empty graph", {
      empty_df <- dagri_nodes_df(dagri_graph(registry))
      populated_df <- dagri_nodes_df(rich)

      expect_identical(nrow(empty_df), 0L)
      expect_identical(rownames(empty_df), character(0))
      expect_identical(names(empty_df), names(populated_df))
      expect_identical(lapply(empty_df, class), lapply(populated_df, class))
    })
  })

  describe("dagri_edges_df()", {
    it("returns the exact columns in the contract order", {
      expect_identical(
        names(dagri_edges_df(rich)),
        c("id", "from", "to", "type", "metadata")
      )
    })

    it("types scalar columns as character and metadata as a list-column", {
      expect_identical(
        vapply(dagri_edges_df(rich), class, character(1)),
        c(
          id = "character",
          from = "character",
          to = "character",
          type = "character",
          metadata = "list"
        )
      )
    })

    it("preserves graph insertion order and endpoints", {
      df <- dagri_edges_df(branching$graph)
      expect_identical(df$id, c("e1", "e2", "e3"))
      expect_identical(df$from, c("n1", "n2", "n2"))
      expect_identical(df$to, c("n2", "n3", "n4"))
    })

    it("carries the stored edge type", {
      expect_identical(dagri_edges_df(rich)$type, "data")
    })

    it("keeps ids as plain character data, never row names", {
      df <- dagri_edges_df(rich)
      expect_type(df$id, "character")
      expect_identical(rownames(df), as.character(seq_len(nrow(df))))
    })

    it("stores metadata cells identical to the graph records", {
      expect_identical(dagri_edges_df(rich)$metadata[[1]], rich$edges$e1$metadata)
    })

    it("returns a zero-row frame with identical shape for an empty graph", {
      empty_df <- dagri_edges_df(dagri_graph(registry))
      populated_df <- dagri_edges_df(rich)

      expect_identical(nrow(empty_df), 0L)
      expect_identical(rownames(empty_df), character(0))
      expect_identical(names(empty_df), names(populated_df))
      expect_identical(lapply(empty_df, class), lapply(populated_df, class))
    })
  })

  describe("dagri_gates_df()", {
    it("returns the exact columns in the contract order", {
      expect_identical(
        names(dagri_gates_df(rich)),
        c("id", "edge_id", "status", "metadata")
      )
    })

    it("types scalar columns as character and metadata as a list-column", {
      expect_identical(
        vapply(dagri_gates_df(rich), class, character(1)),
        c(
          id = "character",
          edge_id = "character",
          status = "character",
          metadata = "list"
        )
      )
    })

    it("preserves graph insertion order", {
      two_gates <- dagri_add_gate(fx$graph, "e2", id = "gate2")
      df <- dagri_gates_df(two_gates)
      expect_identical(df$id, c("gate1", "gate2"))
      expect_identical(df$edge_id, c("e1", "e2"))
    })

    it("carries the stored gate status", {
      expect_identical(dagri_gates_df(rich)$status, "pending")

      resolved <- dagri_resolve_gate(rich, "g1")
      expect_identical(dagri_gates_df(resolved)$status, "resolved")
    })

    it("keeps ids as plain character data, never row names", {
      df <- dagri_gates_df(rich)
      expect_type(df$id, "character")
      expect_identical(rownames(df), as.character(seq_len(nrow(df))))
    })

    it("stores metadata cells identical to the graph records", {
      expect_identical(dagri_gates_df(rich)$metadata[[1]], rich$gates$g1$metadata)
    })

    it("returns a zero-row frame with identical shape for an empty graph", {
      empty_df <- dagri_gates_df(dagri_graph(registry))
      populated_df <- dagri_gates_df(rich)

      expect_identical(nrow(empty_df), 0L)
      expect_identical(rownames(empty_df), character(0))
      expect_identical(names(empty_df), names(populated_df))
      expect_identical(lapply(empty_df, class), lapply(populated_df, class))
    })
  })

  describe("invalid input", {
    bad_graph <- list(nodes = list())

    it("dagri_nodes_df() rejects invalid graph", {
      expect_error(dagri_nodes_df(bad_graph), class = "dagri_error_invalid_argument")
    })

    it("dagri_edges_df() rejects invalid graph", {
      expect_error(dagri_edges_df(bad_graph), class = "dagri_error_invalid_argument")
    })

    it("dagri_gates_df() rejects invalid graph", {
      expect_error(dagri_gates_df(bad_graph), class = "dagri_error_invalid_argument")
    })
  })

  describe("immutability", {
    it("dagri_nodes_df() does not mutate the graph", {
      before <- rich
      invisible(dagri_nodes_df(rich))
      expect_identical(before, rich)
    })

    it("dagri_edges_df() does not mutate the graph", {
      before <- rich
      invisible(dagri_edges_df(rich))
      expect_identical(before, rich)
    })

    it("dagri_gates_df() does not mutate the graph", {
      before <- rich
      invisible(dagri_gates_df(rich))
      expect_identical(before, rich)
    })
  })
})
