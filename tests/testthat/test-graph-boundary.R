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

    # Fixture with deliberately non-sorted id insertion order (zeta before
    # alpha, edge_z before edge_a) so ordering assertions cannot pass by
    # accident through sorting.
    build_value_graph <- function(edge_type = "data", edge_metadata = list()) {
      graph <- dagri_graph(dagri_registry())
      graph$registry$kinds[["source"]] <- dagri_kind("source")
      graph$registry$kinds[["fit"]] <- dagri_kind("fit")
      graph <- dagri_add_node(graph, "zeta", "source", label = "Z")
      graph <- dagri_add_node(graph, "alpha", "fit", label = "A")
      graph <- dagri_add_node(graph, "omega", "fit", label = "W")
      graph <- dagri_add_edge(
        graph,
        from = "zeta",
        to = "omega",
        id = "edge_z",
        type = edge_type,
        metadata = edge_metadata
      )
      graph <- dagri_add_edge(
        graph,
        from = "zeta",
        to = "alpha",
        id = "edge_a",
        type = edge_type,
        metadata = edge_metadata
      )
      graph
    }

    it("keeps a structural add/remove diff free of changes and values", {
      graph_before <- base_graph()
      graph_after <- dagri_add_node(graph_before, "node_c", "fit", label = "C")
      graph_after <- dagri_add_edge(
        graph_after,
        from = "node_b",
        to = "node_c",
        id = "edge_bc"
      )

      diff <- dagri_graph_diff(graph_before, graph_after)

      expect_equal(diff$added_nodes, "node_c")
      expect_equal(diff$added_edges, "edge_bc")
      expect_equal(diff$removed_nodes, character())
      expect_equal(diff$removed_edges, character())
      expect_equal(diff$added_gates, character())
      expect_equal(diff$removed_gates, character())
      expect_equal(diff$changed_nodes, character())
      expect_equal(diff$changed_edges, character())
      expect_equal(diff$changed_gates, character())
      # values is only present when include_values = TRUE.
      expect_null(diff$values)
      expect_named(
        diff,
        c(
          "added_nodes",
          "removed_nodes",
          "added_edges",
          "removed_edges",
          "added_gates",
          "removed_gates",
          "changed_nodes",
          "changed_edges",
          "changed_gates"
        )
      )
    })

    it("reports a node label edit with before/after values", {
      graph_before <- base_graph()
      graph_after <- dagri_update_node(graph_before, "node_a", label = "A (edited)")

      diff <- dagri_graph_diff(graph_before, graph_after)
      expect_equal(diff$changed_nodes, "node_a")
      expect_equal(diff$changed_edges, character())
      expect_equal(diff$changed_gates, character())
      # A pure value edit leaves the structural vectors untouched.
      expect_equal(diff$added_nodes, character())
      expect_equal(diff$removed_nodes, character())

      value_diff <- dagri_graph_diff(
        graph_before,
        graph_after,
        include_values = TRUE
      )
      expect_equal(value_diff$changed_nodes, "node_a")
      expect_equal(
        value_diff$values$nodes$node_a,
        list(label = list(before = "A", after = "A (edited)"))
      )
      # Only differing fields appear; the other tracked fields are unchanged.
      expect_named(value_diff$values$nodes$node_a, "label")
      expect_null(value_diff$values$nodes$node_a$kind)
    })

    it("tracks node params and metadata replacement", {
      graph_before <- base_graph()

      params_after <- dagri_update_node(
        graph_before,
        "node_b",
        params = list(prior = "normal")
      )
      diff <- dagri_graph_diff(graph_before, params_after, include_values = TRUE)
      expect_equal(diff$changed_nodes, "node_b")
      expect_equal(
        diff$values$nodes$node_b,
        list(params = list(before = list(), after = list(prior = "normal")))
      )

      metadata_after <- dagri_update_node(
        graph_before,
        "node_b",
        metadata = list(owner = "reviewer")
      )
      value_diff <- dagri_graph_diff(
        graph_before,
        metadata_after,
        include_values = TRUE
      )
      expect_equal(value_diff$changed_nodes, "node_b")
      expect_equal(
        value_diff$values$nodes$node_b,
        list(metadata = list(before = list(), after = list(owner = "reviewer")))
      )
    })

    it("tracks state and block_reason changes from a recompute pass", {
      graph_before <- base_graph()
      # The recompute flips both nodes from "new" to "ready"; block_reason
      # stays "none", so only the state field appears per node.
      graph_after <- dagri_recompute_state(graph_before)

      diff <- dagri_graph_diff(graph_before, graph_after, include_values = TRUE)
      expect_equal(diff$changed_nodes, c("node_a", "node_b"))
      expect_equal(
        diff$values$nodes$node_a,
        list(state = list(before = "new", after = "ready"))
      )
      expect_equal(
        diff$values$nodes$node_b,
        list(state = list(before = "new", after = "ready"))
      )

      # With a pending gate, node_b becomes blocked and the block_reason
      # field is tracked alongside state.
      gated <- dagri_add_gate(graph_before, "edge_ab", id = "gate_ab")
      gated_before <- dagri_recompute_state(gated)
      resolved_after <- dagri_recompute_state(dagri_resolve_gate(gated_before, "gate_ab"))

      gate_diff <- dagri_graph_diff(
        gated_before,
        resolved_after,
        include_values = TRUE
      )
      expect_equal(gate_diff$changed_nodes, "node_b")
      expect_equal(
        gate_diff$values$nodes$node_b,
        list(
          state = list(before = "blocked", after = "ready"),
          block_reason = list(before = "gate", after = "none")
        )
      )
    })

    it("tracks edge type and metadata edits via changed_edges with values", {
      graph_before <- build_value_graph()

      typed_after <- build_value_graph(edge_type = "model")
      diff <- dagri_graph_diff(graph_before, typed_after, include_values = TRUE)
      expect_equal(diff$changed_edges, c("edge_z", "edge_a"))
      expect_equal(
        diff$values$edges$edge_a,
        list(type = list(before = "data", after = "model"))
      )
      expect_equal(diff$added_edges, character())
      expect_equal(diff$removed_edges, character())
      expect_equal(diff$changed_nodes, character())

      metadata_after <- build_value_graph(edge_metadata = list(review = "ok"))
      value_diff <- dagri_graph_diff(
        graph_before,
        metadata_after,
        include_values = TRUE
      )
      expect_equal(value_diff$changed_edges, c("edge_z", "edge_a"))
      expect_equal(
        value_diff$values$edges$edge_a,
        list(metadata = list(before = list(), after = list(review = "ok")))
      )
    })

    it("covers edge endpoint moves via remove + re-add", {
      graph_before <- base_graph()
      # Edge from/to cannot change through the public editing API; moving an
      # endpoint is a removal plus a re-add.
      base_with_c <- dagri_add_node(graph_before, "node_c", "fit", label = "C")

      # Re-adding under the same id keeps the key present in both graphs, so
      # the moved endpoint surfaces as a changed field, not an add/remove.
      same_id_after <- dagri_remove_edge(base_with_c, "edge_ab")
      same_id_after <- dagri_add_edge(
        same_id_after,
        from = "node_c",
        to = "node_b",
        id = "edge_ab"
      )
      diff <- dagri_graph_diff(graph_before, same_id_after, include_values = TRUE)
      expect_equal(diff$added_edges, character())
      expect_equal(diff$removed_edges, character())
      expect_equal(diff$changed_edges, "edge_ab")
      expect_equal(
        diff$values$edges$edge_ab$from,
        list(before = "node_a", after = "node_c")
      )

      # Re-adding under a new id is the purely structural add/remove path.
      new_id_after <- dagri_remove_edge(base_with_c, "edge_ab")
      new_id_after <- dagri_add_edge(
        new_id_after,
        from = "node_c",
        to = "node_b",
        id = "edge_cb"
      )
      structural_diff <- dagri_graph_diff(graph_before, new_id_after)
      expect_equal(structural_diff$added_edges, "edge_cb")
      expect_equal(structural_diff$removed_edges, "edge_ab")
      expect_equal(structural_diff$changed_edges, character())
    })

    it("tracks gate resolution with status before/after", {
      gated <- dagri_add_gate(base_graph(), "edge_ab", id = "gate_ab")
      resolved <- dagri_resolve_gate(gated, "gate_ab")

      diff <- dagri_graph_diff(gated, resolved, include_values = TRUE)
      expect_equal(diff$changed_gates, "gate_ab")
      expect_equal(
        diff$values$gates$gate_ab,
        list(status = list(before = "pending", after = "resolved"))
      )
      expect_equal(diff$added_gates, character())
      expect_equal(diff$removed_gates, character())
    })

    it("tracks gate metadata set at creation", {
      # Gates have no public update; creating the same gate id with different
      # metadata keeps the key present in both graphs.
      plain <- dagri_add_gate(base_graph(), "edge_ab", id = "gate_ab")
      annotated <- dagri_add_gate(
        base_graph(),
        "edge_ab",
        id = "gate_ab",
        metadata = list(signoff = "max")
      )

      diff <- dagri_graph_diff(plain, annotated, include_values = TRUE)
      expect_equal(diff$changed_gates, "gate_ab")
      expect_equal(
        diff$values$gates$gate_ab,
        list(metadata = list(before = list(), after = list(signoff = "max")))
      )
    })

    it("reports added and removed gates without reporting changes", {
      graph_before <- base_graph()
      gated <- dagri_add_gate(graph_before, "edge_ab", id = "gate_ab")
      ungated <- dagri_remove_gate(gated, "gate_ab")

      added_diff <- dagri_graph_diff(graph_before, gated)
      expect_equal(added_diff$added_gates, "gate_ab")
      expect_equal(added_diff$removed_gates, character())
      expect_equal(added_diff$changed_gates, character())

      removed_diff <- dagri_graph_diff(gated, ungated)
      expect_equal(removed_diff$added_gates, character())
      expect_equal(removed_diff$removed_gates, "gate_ab")
      expect_equal(removed_diff$changed_gates, character())
    })

    it("returns empty changed vectors and empty values for unchanged graphs", {
      graph <- dagri_add_gate(base_graph(), "edge_ab", id = "gate_ab")

      diff <- dagri_graph_diff(graph, graph)
      expect_equal(
        unname(diff[vapply(diff, is.character, logical(1))]),
        rep(list(character()), 9)
      )

      value_diff <- dagri_graph_diff(graph, graph, include_values = TRUE)
      expect_named(value_diff, c(names(diff), "values"))
      expect_named(value_diff$values$nodes, character(0))
      expect_named(value_diff$values$edges, character(0))
      expect_named(value_diff$values$gates, character(0))
      expect_equal(value_diff$values$nodes, setNames(list(), character(0)))
    })

    it("orders changed ids by after's insertion order, not sorted order", {
      graph_before <- build_value_graph()
      # Update in reverse insertion order; the result must still follow the
      # named-map insertion order of `after` (zeta, alpha, omega).
      graph_after <- dagri_update_node(graph_before, "alpha", label = "A2")
      graph_after <- dagri_update_node(graph_after, "zeta", label = "Z2")

      node_diff <- dagri_graph_diff(
        graph_before,
        graph_after,
        include_values = TRUE
      )
      expect_equal(node_diff$changed_nodes, c("zeta", "alpha"))
      expect_named(node_diff$values$nodes, c("zeta", "alpha"))

      # Edge ids were inserted as edge_z then edge_a; changed_edges follows
      # that insertion order rather than the sorted edge_a, edge_z.
      edge_diff <- dagri_graph_diff(
        graph_before,
        build_value_graph(edge_type = "model")
      )
      expect_equal(edge_diff$changed_edges, c("edge_z", "edge_a"))
    })

    it("rejects a non-scalar include_values flag", {
      graph <- base_graph()
      expect_error(
        dagri_graph_diff(graph, graph, include_values = NA),
        class = "dagri_error_invalid_argument"
      )
      expect_error(
        dagri_graph_diff(graph, graph, include_values = c(TRUE, FALSE)),
        class = "dagri_error_invalid_argument"
      )
      expect_error(
        dagri_graph_diff(graph, graph, include_values = "yes"),
        class = "dagri_error_invalid_argument"
      )
    })
  })
})
