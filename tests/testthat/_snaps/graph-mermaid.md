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

