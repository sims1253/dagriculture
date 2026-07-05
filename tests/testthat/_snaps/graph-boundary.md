# graph boundary helpers / dagri_edge_ids / aborts when neither names nor ids yield complete identifiers

    Code
      dagri_edge_ids(list(list(from = "a", to = "b"), list(from = "c", to = "d")))
    Condition
      Error in `abort_dagri()`:
      ! Graph edges must be named or carry non-empty `id` fields for diffing.

