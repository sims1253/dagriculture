#' Abort with a typed groots error
#'
#' @param class Error class.
#' @param message Error message.
#' @param details Optional details list.
#' @export
abort_groots <- function(class, message, details = list()) {
  rlang::abort(message, class = class, details = details)
}
