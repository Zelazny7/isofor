#' @title predict.iForest
#'
#' @description return predictions of various types for the isolation forest
#' object
#'
#' @param object an \code{iForest} object
#'
#' @param newdata a data.frame to predict
#' @param ... optional arguments not used.
#' @param nodes if true return nobs x ntrees dim matrix with terminal node ids
#' @param sparse if true return sparse Matrix of dimension nobs x nTerminalNodes.
#' Each column represents a terminal node. There are as many ones in each row
#' as there are trees in the forest. Each observation can only belong to one
#' terminal node per tree. Useful for further modeling or to identify predictive
#' interactions.
#' @param replace_missing if TRUE, replaces missing factor levels with "." and missing
#' numeric values with the \code{sentinel} argument
#' @param sentinel value to use as stand-in for missing numeric values
#' @details By default the predict function returns an anomaly score. The
#' anomaly score is a [0,1] scaled measure of isolation. Higher scores
#' correspond to more isolated observations. If sparse or nodes are set to TRUE,
#' a matrix of the requested type is returned.
#' @examples
#' mod <- iForest(iris, phi=16, nt=5)
#' score <- predict(mod, newdata = iris)
#' @return A numeric vector of length \code{nrow(newdata)} containing values between zero and one.
#' Values closer to zero are less likely to be anomalous.
#' @import Matrix
#' @importFrom parallel detectCores
#' @export
predict.iForest <- function(object, newdata, ..., nodes = FALSE, sparse = FALSE, replace_missing=TRUE, sentinel=-9999999999) {

  if (!is.data.frame(newdata)) newdata <- as.data.frame(newdata)

  ## check column types
  classes = unlist(lapply(newdata, class))
  if (!all(classes %in% c("numeric","factor","integer", "ordered"))) {
    stop("newdata contains classes other than numeric, factor, and integer")
  }

  ## impute missing values
  if (replace_missing) {
    for (i in seq_along(newdata)) {
      if (is.numeric(newdata[[i]])) {
        newdata[[i]][is.na(newdata[[i]])] <- sentinel
      } else if (is.factor(newdata[[i]])) {
        levels(newdata[[i]]) <- c(levels(newdata[[i]]), ".")
        newdata[[i]][is.na(newdata[[i]])] <- "."
      }
    }
  }

  ## check for missing values
  for (k in seq_along(newdata)) {
    if (any(is.na(newdata[k]))) stop("Missing values found in newdata")
  }

  ## check for column name mismatches
  i = match(object$vNames, names(newdata))
  if (any(is.na(i))) {
    m = object$vNames[!object$vNames %in% names(newdata)]
    stop(strwrap(c("Variables found in model not found in newdata: ",
      paste0(m, collapse = ", ")), width = 80, prefix = " "), call. = F)
  }

  ## dispatch to requested prediction method
  if (sparse){
	  predict_iForest_sparse_nodes(newdata, object)
  } else if (nodes) {
	  predict_iForest_nodes_cpp(newdata, object)
  } else {
    predict_iForest_pathlength_cpp(newdata, object)
  }
}
