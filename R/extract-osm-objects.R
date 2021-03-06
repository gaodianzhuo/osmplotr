#' extract_osm_objects
#'
#' Downloads OSM XML objects and converts to \code{sp} objects
#' (\code{SpatialPointsDataFrame}, \code{SpatialLinesDataFrame}, or
#' \code{SpatialPolygonsDataFrame}).
#'
#' @param key OSM key to search for. Useful keys include \code{building},
#' \code{waterway}, \code{natural}, \code{grass}, \code{park}, \code{amenity},
#' \code{shop}, \code{boundary}, and \code{highway}. Others will be passed
#' directly to the overpass API and may not necessarily return results.
#' @param value OSM value to match to key. If \code{NULL}, all keys will be
#' returned.  Negation is specified by \code{!value}.
#' @param extra_pairs A list of additional \code{key-value} pairs to be passed
#' to the overpass API.
#' @param bbox the bounding box within which all key-value objects should be
#' downloaded.  A 2-by-2 matrix of 4 elements with columns of min and
#' max values, and rows of x and y values.
#' @param return_type If specified, force return of spatial (\code{point},
#' \code{line}, \code{polygon}, \code{multiline}, \code{multipolygon}) objects.
#' \code{return_type = 'line'} will, for example, always return a
#' SpatialLinesDataFrame. If not specified, defaults to 'sensible' values (for
#' example, \code{lines} for highways, \code{points} for trees, \code{polygons}
#' for bulidings).
#' @param verbose If \code{TRUE}, provides notification of progress.
#'
#' @return Either a \code{SpatialPointsDataFrame}, \code{SpatialLinesDataFrame},
#' or \code{SpatialPolygonsDataFrame}.
#' @export
#'
#' @seealso \code{\link{add_osm_objects}}.
#'
#' @examples
#' \dontrun{
#' bbox <- get_bbox (c(-0.13,51.50,-0.11,51.52))
#' dat_B <- extract_osm_objects (key = 'building', bbox = bbox)
#' dat_H <- extract_osm_objects (key = 'highway', bbox = bbox)
#' dat_BR <- extract_osm_objects (key = 'building', value = 'residential',
#'                                bbox = bbox)
#' dat_HP <- extract_osm_objects (key = 'highway', value = 'primary', bbox = bbox)
#' dat_HNP <- extract_osm_objects (key = 'highway', value = '!primary', bbox = bbox)
#' extra_pairs <- c ('name', 'Royal.Festival.Hall')
#' dat <- extract_osm_objects (key = 'building', extra_pairs = extra_pairs,
#'                             bbox = bbox)
#' }
extract_osm_objects <- function (key, value, extra_pairs, bbox,
                                 return_type, verbose = FALSE)
{
    check_arg (key, 'key', 'character')

    bbox <- check_bbox_arg (bbox)
    if (!missing (value) & missing (key))
        stop ('key must be provided for value')

    q_keys <- key
    if (missing (value))
        q_vals <- NA
    else
        q_vals <- value

    if (!missing (extra_pairs))
    {
        if (!is.list (extra_pairs))
            extra_pairs <- list (extra_pairs)
        nprs <- vapply (extra_pairs, length, 1L)
        if (!all (nprs %in% 1:2))
            stop ('Extra pairs must be just keys or key-val pairs')

        q_keys <- c (q_keys,
                     vapply (extra_pairs, function (x) x [1], character (1)))
        q_vals <- c (q_vals,
                     vapply (extra_pairs, function (x) x [2], character (1)))
    }

    val_list <- c ('grass', 'park', 'tree', 'water')
    key_list <- c ('landuse', 'leisure', 'natural', 'ntural')
    indx <- which (q_keys %in% val_list)
    if (length (indx) > 0)
    {
        indx2 <- match (q_keys [indx], val_list)
        q_keys [indx] <- key_list [indx2]
        q_vals [indx] <- val_list [indx2]
    }

    # default to non-exact matches
    qry <- osmdata::opq (bbox = bbox)
    for (i in seq (q_keys))
    {
        if (is.na (q_vals [i]))
            qry <- osmdata::add_feature (qry, key = q_keys [i],
                                         key_exact = FALSE,
                                         value_exact = FALSE,
                                         match_case = FALSE)
        else
            qry <- osmdata::add_feature (qry, key = q_keys [i],
                                         value = q_vals [i],
                                         key_exact = FALSE,
                                         value_exact = FALSE,
                                         match_case = FALSE)
    }

    obj <- osmdata::osmdata_sp (qry)

    if (!missing (return_type))
    {
        return_type <- tolower (return_type)
        if (substring (return_type, 1, 3) == 'poi')
            obj <- obj$osm_points
        else if (substring (return_type, 1, 1) == 'l')
            obj <- obj$osm_lines
        else if (substring (return_type, 1, 6) == 'multil')
            obj <- obj$osm_multilines
        else if (substring (return_type, 1, 6) == 'multip')
            obj <- obj$osm_multipolygons
        else
            obj <- obj$osm_polygons
    } else
    {
        if (key == 'highway')
            obj <- obj$osm_lines
        if (key == 'building')
            obj <- obj$osm_polygons
        else if (key == 'route')
            obj <- obj$osm_multilines
        else if (key == 'boundary' | key == 'waterway')
            obj <- obj$osm_multipolygons
        else if (!missing (value))
        {
            if (value == 'tree')
                obj <- obj$osm_points
            else
            {
                message (paste0 ('Cannot determine return_type;',
                                 ' maybe specify explicitly?'))
                obj <- obj$osm_lines
            }
        } else
            obj <- obj$osm_polygons
    }

    if (nrow (obj) == 0)
        warning ('No valid data returned')

    return (obj)
}
