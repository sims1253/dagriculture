skip_if_not_installed("jsonlite")

# Inline copies of the canonical writer/reader recipe from
# vignettes/serialization-boundary.Rmd. Kept here so the recipe itself is
# under test; dagriculture deliberately ships no public serialization API.

write_graph_json <- function(graph, pretty = FALSE) {
  jsonlite::toJSON(
    graph,
    auto_unbox = TRUE,
    null = "null",
    digits = NA,
    pretty = pretty
  )
}

normalize_nulls <- function(graph) {
  nullable_kind_fields <- c("input_contract", "output_type", "param_schema")
  for (i in seq_along(graph$registry$kinds)) {
    kind <- graph$registry$kinds[[i]]
    for (field in nullable_kind_fields) {
      if (is.list(kind[[field]]) && length(kind[[field]]) == 0L) {
        kind[[field]] <- NULL
      }
    }
    graph$registry$kinds[[i]] <- kind
  }
  for (i in seq_along(graph$nodes)) {
    node <- graph$nodes[[i]]
    if (is.list(node$label) && length(node$label) == 0L) {
      node$label <- NULL
    }
    graph$nodes[[i]] <- node
  }
  graph
}

check_snapshot_maps <- function(graph) {
  stopifnot(
    identical(names(graph$nodes), unname(vapply(graph$nodes, `[[`, character(1), "id"))),
    identical(names(graph$edges), unname(vapply(graph$edges, `[[`, character(1), "id"))),
    identical(names(graph$gates), unname(vapply(graph$gates, `[[`, character(1), "id"))),
    identical(
      names(graph$registry$kinds),
      unname(vapply(graph$registry$kinds, `[[`, character(1), "name"))
    )
  )
  invisible(TRUE)
}

read_graph_json <- function(txt) {
  graph <- jsonlite::fromJSON(txt, simplifyVector = FALSE)
  graph <- normalize_nulls(graph)
  check_snapshot_maps(graph)
  structure(graph, class = c("dagri_graph", "list"))
}

serialization_fixture_graph <- function() {
  reg <- dagri_registry(
    dagri_kind("source", output_type = "data.frame"),
    dagri_kind("fit", param_schema = list(required = c("model"))),
    metadata = list(origin = "hand-authored")
  )
  dagri_graph(reg, metadata = list(project = "pilot")) |>
    dagri_add_node("raw", "source", label = "Raw Data") |>
    dagri_add_node("m1", "fit", params = list(model = "baseline")) |>
    dagri_add_node("m2", "fit") |>
    dagri_add_edge("raw", "m1", id = "e1", metadata = list(weight = 2L)) |>
    dagri_add_edge("m1", "m2", id = "e2") |>
    dagri_add_gate("e1", id = "g1", metadata = list(approver = "rev_a"))
}

describe("canonical writer options", {
  it("writes R NULL as JSON null, not {}", {
    g <- serialization_fixture_graph()
    txt <- write_graph_json(g)
    expect_match(txt, '"label":null', fixed = TRUE)
    expect_match(txt, '"param_schema":null', fixed = TRUE)
    expect_match(txt, '"output_type":null', fixed = TRUE)
  })

  it("jsonlite's default null handling emits {} for NULL", {
    g <- serialization_fixture_graph()
    txt_default <- jsonlite::toJSON(g, auto_unbox = TRUE)
    expect_match(txt_default, '"label":\\{}')
  })

  it("writes doubles at full precision via digits = NA", {
    reg <- dagri_registry(dagri_kind("source"))
    g <- dagri_graph(reg) |>
      dagri_add_node("raw", "source", params = list(weight = 1.23456789))
    txt <- write_graph_json(g)
    expect_match(txt, "1.23456789", fixed = TRUE)
    back <- read_graph_json(txt)
    expect_identical(back$nodes$raw$params$weight, 1.23456789)
  })
})

describe("canonical reader round trip", {
  it("restores a graph that passes dagri_validate_graph()", {
    g <- serialization_fixture_graph()
    back <- read_graph_json(write_graph_json(g))

    expect_no_error(dagri_validate_graph(back))
    expect_s3_class(back, "dagri_graph")
    expect_identical(back$version, g$version)
    expect_identical(names(back$nodes), c("raw", "m1", "m2"))
    expect_identical(names(back$edges), c("e1", "e2"))
    expect_identical(names(back$gates), "g1")
    expect_identical(back$nodes$raw$label, "Raw Data")
    expect_identical(back$nodes$raw$state, "new")
    expect_identical(back$nodes$raw$block_reason, "none")
    expect_identical(back$nodes$m1$params$model, "baseline")
    expect_identical(back$edges$e1$from, "raw")
    expect_identical(back$edges$e1$to, "m1")
    expect_identical(back$edges$e1$type, "data")
    expect_identical(back$edges$e1$metadata$weight, 2L)
    expect_identical(back$gates$g1$edge_id, "e1")
    expect_identical(back$gates$g1$status, "pending")
    expect_identical(back$registry$metadata$origin, "hand-authored")
    expect_identical(back$registry$kinds$source$output_type, "data.frame")
    expect_identical(back$metadata$project, "pilot")
  })

  it("round-tripped graphs work through the public surface", {
    back <- read_graph_json(write_graph_json(serialization_fixture_graph()))
    expect_identical(dagri_topo_order(back), c("raw", "m1", "m2"))
    resolved <- dagri_resolve_gate(back, id = "g1")
    expect_identical(resolved$gates$g1$status, "resolved")
  })

  it("keeps empty named maps as named lists under simplifyVector = FALSE", {
    reg <- dagri_registry(dagri_kind("source"))
    g <- dagri_graph(reg)
    txt <- write_graph_json(g)
    expect_match(txt, '"edges":{}', fixed = TRUE)
    expect_match(txt, '"gates":{}', fixed = TRUE)

    back <- read_graph_json(txt)
    expect_type(back$nodes, "list")
    expect_identical(names(back$nodes), character(0))
    expect_identical(names(back$edges), character(0))
    expect_identical(names(back$gates), character(0))
    expect_no_error(dagri_validate_graph(back))
  })

  it("vectors come back as lists, so identical() needs normalized comparison", {
    reg <- dagri_registry(
      dagri_kind("fit", param_schema = list(required = c("model", "seed")))
    )
    g <- dagri_graph(reg)
    back <- read_graph_json(write_graph_json(g))

    expect_type(g$registry$kinds$fit$param_schema$required, "character")
    expect_type(back$registry$kinds$fit$param_schema$required, "list")
    expect_false(identical(
      g$registry$kinds$fit$param_schema$required,
      back$registry$kinds$fit$param_schema$required
    ))
    expect_identical(
      unlist(back$registry$kinds$fit$param_schema$required),
      c("model", "seed")
    )
  })
})

describe("null normalization", {
  it("restores nullable fields as R NULL after a canonical round trip", {
    back <- read_graph_json(write_graph_json(serialization_fixture_graph()))
    expect_null(back$nodes$m1$label)
    expect_true("label" %in% names(back$nodes$m1))
    expect_null(back$nodes$m2$label)
    expect_null(back$registry$kinds$source$param_schema)
    expect_true("param_schema" %in% names(back$registry$kinds$source))
    expect_null(back$registry$kinds$fit$output_type)
    expect_null(back$registry$kinds$fit$input_contract)
    expect_no_error(dagri_validate_graph(back))
  })

  it("repairs the {} that non-canonical writers emit for NULL", {
    g <- serialization_fixture_graph()
    txt_bad <- jsonlite::toJSON(g, auto_unbox = TRUE)
    raw <- jsonlite::fromJSON(txt_bad, simplifyVector = FALSE)
    expect_type(raw$nodes$m1$label, "list") # {} before normalization
    expect_length(raw$nodes$m1$label, 0)

    back <- normalize_nulls(raw)
    expect_null(back$nodes$m1$label)
    expect_null(back$registry$kinds$source$param_schema)
    expect_null(back$registry$kinds$fit$output_type)
    expect_null(back$registry$kinds$fit$input_contract)
  })
})

describe("named-map keys vs embedded ids", {
  it("keys and embedded ids agree after a round trip", {
    back <- read_graph_json(write_graph_json(serialization_fixture_graph()))
    expect_no_error(check_snapshot_maps(back))
  })

  it("flags a key/id mismatch that dagri_validate_graph() accepts", {
    back <- read_graph_json(write_graph_json(serialization_fixture_graph()))
    tampered <- dagri_add_node(back, "iso", "source")
    names(tampered$nodes)[[4]] <- "renamed"

    expect_no_error(dagri_validate_graph(tampered))
    expect_error(check_snapshot_maps(tampered))
  })
})

describe("default jsonlite simplification hazards", {
  it("turns nulls into NA and unboxes length-1 arrays", {
    txt <- '{"params": {"tags": ["a", null, "b"]}, "required": ["model"]}'
    simplified <- jsonlite::fromJSON(txt)
    expect_identical(simplified$params$tags, c("a", NA, "b"))
    expect_identical(simplified$required, "model")

    literal <- jsonlite::fromJSON(txt, simplifyVector = FALSE)
    expect_identical(literal$params$tags, list("a", NULL, "b"))
    expect_identical(literal$required, list("model"))
  })
})

describe("RDS load path and the no-code boundary", {
  it("dagri_validate_graph() does not scan params for closures on load", {
    reg <- dagri_registry(dagri_kind("source"))
    g <- dagri_graph(reg) |>
      dagri_add_node("raw", "source", params = list(loader = function(x) x))

    f <- tempfile(fileext = ".rds")
    saveRDS(g, f)
    on.exit(unlink(f), add = TRUE)
    loaded <- readRDS(f)

    expect_type(loaded$nodes$raw$params$loader, "closure")
    expect_no_error(dagri_validate_graph(loaded))
    expect_no_error(dagri_topo_order(loaded))
  })

  it("entry points still reject reference-bearing metadata", {
    reg <- dagri_registry(dagri_kind("source"))
    expect_error(
      dagri_add_node(
        dagri_graph(reg),
        "raw",
        "source",
        metadata = list(loader = function(x) x)
      ),
      class = "dagri_error_invalid_argument"
    )
    expect_error(
      dagri_graph(reg, metadata = list(env = new.env())),
      class = "dagri_error_invalid_argument"
    )
  })
})
