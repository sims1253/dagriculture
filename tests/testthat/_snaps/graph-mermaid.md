# dagri_mermaid / aborts on non-string direction

    Code
      dagri_mermaid(graph, direction = 123)
    Condition
      Error in `abort_dagri()`:
      ! `direction` must be a single non-NA character string, got numeric.

---

    Code
      dagri_mermaid(graph, direction = NA_character_)
    Condition
      Error in `abort_dagri()`:
      ! `direction` must be a single non-NA character string, got character.

# dagri_mermaid / aborts on non-function node_label / node_class

    Code
      dagri_mermaid(graph, node_label = "nope")
    Condition
      Error in `abort_dagri()`:
      ! `node_label` must be NULL or a function, got character.

---

    Code
      dagri_mermaid(graph, node_class = 42)
    Condition
      Error in `abort_dagri()`:
      ! `node_class` must be NULL or a function, got numeric.

# dagri_mermaid / aborts on a malformed graph

    Code
      dagri_mermaid(list(nodes = list()))
    Condition
      Error in `abort_dagri()`:
      ! `graph` is missing required fields: registry, edges, gates, version. Use dagri_graph() to create a valid graph.

# dagri_mermaid / aborts on invalid hook arguments

    Code
      dagri_mermaid(graph, gate_label = "nope")
    Condition
      Error in `abort_dagri()`:
      ! `gate_label` must be NULL or a function, got character.

---

    Code
      dagri_mermaid(graph, include_resolved_gates = "yes")
    Condition
      Error in `abort_dagri()`:
      ! `include_resolved_gates` must be a single non-NA logical, got character.

---

    Code
      dagri_mermaid(graph, class_defs = 1:2)
    Condition
      Error in `abort_dagri()`:
      ! `class_defs` must be a character vector of Mermaid classDef statements without NAs, got integer.

---

    Code
      dagri_mermaid(graph, header = 123)
    Condition
      Error in `abort_dagri()`:
      ! `header` must be a character vector of single non-NA Mermaid preamble lines, got numeric.

# dagri_mermaid / snapshots the customization hooks together

    Code
      cat(dagri_mermaid(graph, gate_label = function(gate, edge) {
        reviewer <- gate$metadata$reviewer
        if (is.null(reviewer)) "pending review" else paste("review by", reviewer)
      }, include_resolved_gates = TRUE, class_defs = "classDef ready fill:#e8f5e9",
      header = "%%{init: {\"theme\":\"neutral\"}}%%"))
    Output
      %%{init: {"theme":"neutral"}}%%
      flowchart TD
        classDef ready fill:#e8f5e9
        node_a["A"]
        class node_a new
        node_b["node_b"]
        class node_b new
        node_c["C"]
        class node_c new
        node_a -- "review by mara" --> node_b
        node_b -- "pending review (resolved)" --> node_c

