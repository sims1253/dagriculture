describe("graph boundary helpers", {
  # Build the registry by mutating the graph in place via
  # $registry$kinds[[...]], then add nodes/edges through the public
  # value-oriented API.
  build_fixture_graph <- function() {
    graph <- dagri_graph(dagri_registry())
    graph$registry$kinds[["source"]] <- dagri_kind("source")
    graph$registry$kinds[["fit"]] <- dagri_kind("fit")
    graph$registry$kinds[["ppc"]] <- dagri_kind("ppc")

    graph <- dagri_add_node(graph, "node_a", "source", label = "A")
    graph <- dagri_add_node(graph, "node_b", "fit", label = "B")
    graph <- dagri_add_node(graph, "node_c", "ppc", label = "C")
    graph <- dagri_add_edge(graph, from = "node_a", to = "node_b", id = "edge_b")
    graph <- dagri_add_edge(graph, from = "node_b", to = "node_c", id = "edge_c")
    graph
  }

  describe("dagri_incoming_edges / dagri_outgoing_edges", {
    it("returns edge objects (not just ids) for a middle node", {
      graph <- build_fixture_graph()

      incoming_b <- dagri_incoming_edges(graph, "node_b")
      outgoing_b <- dagri_outgoing_edges(graph, "node_b")

      # They are full edge objects with from/to/type fields.
      expect_equal(
        unname(vapply(incoming_b, `[[`, character(1), "from")),
        "node_a"
      )
      expect_equal(
        unname(vapply(outgoing_b, `[[`, character(1), "to")),
        "node_c"
      )
      # The single incoming edge on node_b is edge_b (from node_a).
      expect_equal(
        unname(vapply(incoming_b, `[[`, character(1), "id")),
        "edge_b"
      )
    })

    it("preserves container names on the returned list", {
      graph <- build_fixture_graph()

      incoming_b <- dagri_incoming_edges(graph, "node_b")
      expect_named(incoming_b, "edge_b")
      expect_named(dagri_incoming_edges(graph, "node_c"), "edge_c")
    })

    it("returns empty list for a leaf/source node and for empty graphs", {
      graph <- build_fixture_graph()

      # node_c is a leaf: no outgoing edges.
      expect_length(dagri_outgoing_edges(graph, "node_c"), 0)
      # node_a is a source: no incoming edges.
      expect_length(dagri_incoming_edges(graph, "node_a"), 0)

      # On a graph with one isolated node, both incident-edge queries return
      # an empty (named) list. Use length + names rather than identical to
      # bare list() because Filter() preserves the named-list attribute.
      empty_graph <- dagri_graph(dagri_registry(dagri_kind("source")))
      solo_graph <- dagri_add_node(empty_graph, "solo", "source")
      expect_length(dagri_incoming_edges(solo_graph, "solo"), 0)
      expect_named(dagri_incoming_edges(solo_graph, "solo"), character(0))
      expect_length(dagri_outgoing_edges(solo_graph, "solo"), 0)
      expect_named(dagri_outgoing_edges(solo_graph, "solo"), character(0))
    })

    it("aborts with not_found when the node is missing", {
      graph <- build_fixture_graph()
      expect_error(
        dagri_incoming_edges(graph, "ghost"),
        class = "dagri_error_not_found"
      )
      expect_error(
        dagri_outgoing_edges(graph, "ghost"),
        class = "dagri_error_not_found"
      )
    })

    it("aborts with invalid_argument when node_id is not a single string", {
      graph <- build_fixture_graph()
      expect_error(
        dagri_incoming_edges(graph, c("node_a", "node_b")),
        class = "dagri_error_invalid_argument"
      )
      expect_error(
        dagri_outgoing_edges(graph, NA_character_),
        class = "dagri_error_invalid_argument"
      )
    })

    it("rejects an invalid graph", {
      bad_graph <- list(nodes = list())
      expect_error(
        dagri_incoming_edges(bad_graph, "x"),
        class = "dagri_error_invalid_argument"
      )
      expect_error(
        dagri_outgoing_edges(bad_graph, "x"),
        class = "dagri_error_invalid_argument"
      )
    })
  })

  describe("dagri_order_edges", {
    it("orders edges deterministically by edge id (late/early/middle)", {
      edges <- list(
        late = list(id = "edge_z", from = "a", to = "b"),
        early = list(id = "edge_a", from = "c", to = "d"),
        middle = list(id = "edge_m", from = "e", to = "f")
      )

      ordered <- dagri_order_edges(edges)

      expect_equal(
        unname(vapply(ordered, `[[`, character(1), "id")),
        c("edge_a", "edge_m", "edge_z")
      )
    })

    it("preserves container names after sorting", {
      edges <- list(
        late = list(id = "edge_z", from = "a", to = "b"),
        early = list(id = "edge_a", from = "c", to = "d"),
        middle = list(id = "edge_m", from = "e", to = "f")
      )

      ordered <- dagri_order_edges(edges)
      expect_named(ordered, c("early", "middle", "late"))
    })

    it("returns empty and length-1 lists unchanged", {
      expect_identical(dagri_order_edges(list()), list())
      single <- list(only = list(id = "edge_x", from = "a", to = "b"))
      expect_identical(dagri_order_edges(single), single)
    })

    it("falls back to empty string when an edge has no id", {
      edges <- list(
        z = list(from = "a", to = "b"),
        a = list(id = "edge_a", from = "c", to = "d")
      )
      ordered <- dagri_order_edges(edges)
      # The id-less edge sorts first (empty string sorts before any real id).
      expect_named(ordered, c("z", "a"))
    })
  })

  describe("dagri_edge_ids", {
    it("returns character() for an empty edge list", {
      expect_identical(dagri_edge_ids(list()), character())
    })

    it("prefers container names when all are non-empty (sorted + unique)", {
      edges <- list(
        e2 = list(id = "ignored", from = "a", to = "b"),
        e1 = list(id = "ignored", from = "c", to = "d"),
        e1_again = list(id = "ignored", from = "e", to = "f")
      )
      expect_equal(dagri_edge_ids(edges), c("e1", "e1_again", "e2"))
      # uniqueness is within names, not across names.
      # Construct the duplicate-name list without a literal duplicated argument
      # (jarl's duplicated_arguments rule flags `a = ..., a = ...` even in a
      # test fixture; building it via setNames makes the intent explicit).
      dup_names <- setNames(list(list(), list()), c("a", "a"))
      expect_equal(dagri_edge_ids(dup_names), "a")
    })

    it("falls back to embedded edge$id when names are absent", {
      edges <- unname(list(
        list(id = "edge_b", from = "a", to = "b"),
        list(id = "edge_a", from = "c", to = "d")
      ))
      expect_equal(dagri_edge_ids(edges), c("edge_a", "edge_b"))
    })

    it("aborts when neither names nor ids yield complete identifiers", {
      # No names, no embedded ids.
      expect_snapshot(
        error = TRUE,
        {
          dagri_edge_ids(list(
            list(from = "a", to = "b"),
            list(from = "c", to = "d")
          ))
        }
      )
      # Mixed: one named, one unnamed without id: not all names, ids
      # incomplete, so dagri_edge_ids aborts.
      expect_error(
        dagri_edge_ids(list(
          e1 = list(id = "e1", from = "a", to = "b"),
          list(from = "c", to = "d")
        )),
        class = "dagri_error_invalid_argument"
      )
    })
  })

  describe("dagri_graph_diff", {
    base_graph <- function() {
      graph <- dagri_graph(dagri_registry())
      graph$registry$kinds[["source"]] <- dagri_kind("source")
      graph$registry$kinds[["fit"]] <- dagri_kind("fit")
      graph <- dagri_add_node(graph, "node_a", "source", label = "A")
      graph <- dagri_add_node(graph, "node_b", "fit", label = "B")
      graph <- dagri_add_edge(graph, from = "node_a", to = "node_b", id = "edge_ab")
      graph
    }

    it("reports added/removed nodes and edges in both directions", {
      graph_before <- base_graph()
      graph_after <- dagri_add_node(graph_before, "node_c", "fit", label = "C")
      graph_after <- dagri_add_edge(
        graph_after,
        from = "node_b",
        to = "node_c",
        id = "edge_bc"
      )

      diff <- dagri_graph_diff(graph_before, graph_after)
      reverse_diff <- dagri_graph_diff(graph_after, graph_before)

      expect_equal(diff$added_nodes, "node_c")
      expect_equal(diff$removed_nodes, character())
      expect_equal(diff$added_edges, "edge_bc")
      expect_equal(diff$removed_edges, character())

      expect_equal(reverse_diff$added_nodes, character())
      expect_equal(reverse_diff$removed_nodes, "node_c")
      expect_equal(reverse_diff$added_edges, character())
      expect_equal(reverse_diff$removed_edges, "edge_bc")
    })

    it("returns all-empty vectors for two identical empty graphs", {
      empty_graph <- dagri_graph(dagri_registry())
      diff <- dagri_graph_diff(empty_graph, empty_graph)
      expect_equal(diff$added_nodes, character())
      expect_equal(diff$removed_nodes, character())
      expect_equal(diff$added_edges, character())
      expect_equal(diff$removed_edges, character())
    })

    it("handles unnamed edge lists via the embedded-id fallback", {
      graph_before <- base_graph()
      graph_after <- dagri_add_node(graph_before, "node_c", "fit", label = "C")
      graph_after <- dagri_add_edge(
        graph_after,
        from = "node_b",
        to = "node_c",
        id = "edge_bc"
      )
      unnamed_after <- list(
        nodes = graph_after$nodes,
        edges = unname(graph_after$edges)
      )

      # `unnamed_after` is not a valid dagri_graph (missing registry/gates/
      # version), so this case is checked directly through dagri_edge_ids plus
      # the named `before` edges via setdiff semantics.
      added_edges <- setdiff(
        dagri_edge_ids(unnamed_after$edges),
        dagri_edge_ids(graph_before$edges)
      )
      expect_equal(added_edges, "edge_bc")

      # Full diff still works on a valid graph whose edges we unname after
      # construction (preserving the required top-level fields).
      unnamed_graph_after <- graph_after
      names(unnamed_graph_after$edges) <- NULL
      unnamed_diff <- dagri_graph_diff(graph_before, unnamed_graph_after)
      expect_equal(unnamed_diff$added_edges, "edge_bc")
      expect_equal(unnamed_diff$removed_edges, character())
    })

    it("rejects an invalid graph argument", {
      empty_graph <- dagri_graph(dagri_registry())
      bad_graph <- list(nodes = list())
      expect_error(
        dagri_graph_diff(bad_graph, empty_graph),
        class = "dagri_error_invalid_argument"
      )
      expect_error(
        dagri_graph_diff(empty_graph, bad_graph),
        class = "dagri_error_invalid_argument"
      )
    })
  })
})
