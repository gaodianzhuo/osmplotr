#' add_osm_groups
#'
#' Plots spatially distinct groups of OSM objects in different colours. 
#'
#' @param map A \code{ggplot2} object to which the grouped objects are to be
#' added.
#' @param obj An \code{sp} \code{SpatialPointsDataFrame},
#' \code{SpatialPolygonsDataFrame}, or \code{SpatialLinesDataFrame} (list of
#' polygons or lines) returned by \code{\link{extract_osm_objects}}.
#' @param groups A list of spatial points objects, each of which contains the
#' coordinates of points defining one group.
#' @param cols Either a vector of >= 4 colours passed to \code{colour_mat} (if
#' \code{colmat = TRUE}) to arrange as a 2-D map of visually distinct colours
#' (default uses \code{rainbow} colours), or (if \code{colmat = FALSE}), a
#' vector of the same length as groups specifying individual colours for each.
#' @param bg If given, then any objects not within groups are coloured this
#' colour, otherwise (if not given) they are assigned to nearest group and
#' coloured accordingly (\code{boundary} has no effect in this latter case).
#' @param make_hull Either a single boolean value or a vector of same length as
#' groups specifying whether convex hulls should be constructed around all
#' groups (\code{TRUE}), or whether the group already defines a hull (convex or
#' otherwise; \code{FALSE}).
#' @param boundary (negative, 0, positive) values define whether the boundary of
#' groups should (exclude, bisect, include) objects which straddle the precise
#' boundary. (Has no effect if \code{bg} is given).
#' @param size Size argument passed to \code{ggplot2} (polygon, path, point)
#' functions: determines width of lines for (polygon, line), and sizes of
#' points.  Respective defaults are (0, 0.5, 0.5).
#' @param shape Shape of points or lines (the latter passed as \code{linetype});
#' see \code{?ggplot2::shape}.
#' @param border_width If given, draws convex hull borders around entire groups
#' in same colours as groups (try values around 1-2).
#' @param colmat If \code{TRUE} generates colours according to
#' \code{colour_mat}, otherwise the colours of groups are specified directly by
#' the vector of \code{cols}.
#' @param rotate Passed to \code{colour_mat} to rotate colours by the specified
#' number of degrees clockwise.
#' @return Modified version of \code{map} with groups added.
#' @export
#'
#' @section Note:
#' Any group that is entirely contained within any other group is assumed to
#' represent a hole, such that points internal to the smaller contained group
#' are *excluded* from the group, while those outside the smaller yet inside the
#' bigger group are included.
#'
#' @seealso \code{\link{colour_mat}}, \code{\link{add_osm_objects}}.
#'
#' @examples
#' bbox <- get_bbox (c (-0.13, 51.5, -0.11, 51.52))
#' # Download data using 'extract_osm_objects'
#' \dontrun{
#' dat_HP <- extract_osm_objects (key = 'highway', value = 'primary', bbox = bbox)
#' dat_T <- extract_osm_objects (key = 'tree', bbox = bbox)
#' dat_BNR <- extract_osm_objects (key = 'building', value = '!residential',
#' bbox = bbox)
#' }
#' # These data are also provided in
#' dat_HP <- london$dat_HP
#' dat_T <- london$dat_T
#' dat_BNR <- london$dat_BNR
#'
#' # Define a function to easily generate a basemap
#' bmap <- function ()
#' {
#'     map <- osm_basemap (bbox = bbox, bg = "gray20")
#'     map <- add_osm_objects (map, dat_HP, col = "gray70", size = 1)
#'     add_osm_objects (map, dat_T, col = "green")
#' }
#' 
#' # Highlight a single region using all objects lying partially inside the
#' # boundary (via the boundary = 1 argument)
#' pts <- sp::SpatialPoints (cbind (c (-0.115, -0.125, -0.125, -0.115),
#'                                  c (51.505, 51.505, 51.515, 51.515)))
#' \dontrun{
#' dat_H <- extract_osm_objects (key = 'highway', bbox = bbox) # all highways
#' map <- bmap ()
#' map <- add_osm_groups (map, dat_BNR, groups = pts, cols = "gray90",
#'                        bg = "gray40", boundary = 1)
#' map <- add_osm_groups (map, dat_H, groups = pts, cols = "gray80",
#'                        bg = "gray30", boundary = 1)
#' print_osm_map (map)
#' }
#' 
#' # Generate random points to serve as group centres
#' set.seed (2)
#' ngroups <- 6
#' x <- bbox [1,1] + runif (ngroups) * diff (bbox [1,])
#' y <- bbox [2,1] + runif (ngroups) * diff (bbox [2,])
#' groups <- cbind (x, y)
#' groups <- apply (groups, 1, function (i) 
#'               sp::SpatialPoints (matrix (i, nrow = 1, ncol = 2)))
#' # plot a basemap and add groups
#' map <- bmap ()
#' cols <- rainbow (length (groups))
#' \dontrun{
#' map <- add_osm_groups (map, obj = london$dat_BNR, group = groups, cols = cols)
#' cols <- adjust_colours (cols, -0.2)
#' map <- add_osm_groups (map, obj = london$dat_H, groups = groups, cols = cols)
#' print_osm_map (map)
#' 
#' # Highlight convex hulls containing groups:
#' map <- bmap ()
#' map <- add_osm_groups (map, obj = london$dat_BNR, group = groups, cols = cols,
#'                        border_width = 2)
#' print_osm_map (map)
#' }

add_osm_groups <- function (map, obj, groups, cols, bg, make_hull = FALSE,
                            boundary = -1, size, shape, border_width,
                            colmat, rotate)
{
    # ---------------  sanity checks and warnings  ---------------
    if (missing (map))
        stop ('map must be supplied')
    check_map_arg (map)
    if (missing (obj))
        stop ('obj must be supplied')
    check_obj_arg (obj)
    groups <- check_groups_arg (groups)
    if (length (groups) == 1)
    {
        colmat <- FALSE
        if (missing (bg))
        {
            message (paste0 ('Plotting one group only makes sense with bg;',
                             ' defaulting to gray40'))
            bg <- 'gray40'
        }
    }
    # ---------- cols
    if (missing (cols))
    {
        if (missing (bg))
            stop ("Either 'cols' or 'bg' must be minimally given")
        else
        {
            warning (paste0 ('No group colours defined in add_osm_groups: ',
                             'passing to add_osm_objects'))
            add_osm_objects (map, obj, col = bg)
        }
    }
    if (!missing (colmat))
    {
        colmat <- check_arg (colmat, 'colmat', 'logical')
        if (is.na (colmat))
            stop ('colmat can not be coerced to logical', call. = FALSE)
    }
    # ---------- others
    make_hull <- check_hull_arg (make_hull, groups)
    if (!is.numeric (boundary))
        boundary <- 0
    if (missing (colmat))
        colmat <- FALSE
    # ---------------  end sanity checks and warnings  ---------------

    # Set up group colours
    cmat <- NULL
    if (!colmat)
    {
        cols_default <- group_colours_default (cols, groups, bg)
        cols <- cols_default$cols
        bg <- cols_default$bg
    } else
    {
        cols_colourmat <- group_colours_colourmat (cols, groups, rotate)
        cols <- cols_colourmat$cols
        cmat <- cols_colourmat$cmat
    }
    if (missing (bg))
        bg <- NULL

    if (!class (obj) %in% c ('SpatialPolygonsDataFrame',
                             'SpatialLinesDataFrame'))
        stop ('obj must be SpatialPolygonsDataFrame or SpatialLinesDataFrame')
    # ... because points not yet implemented
    objtxt <- get_objtxt (obj)

    # Determine whether any groups are holes - not implemented at present
    if (length (groups) > 1)
        holes <- groups_are_holes (groups)

    obj_xy <- trip_obj_to_map (obj, map, objtxt)
    obj <- obj_xy$obj

    cent_bdy <- group_centroids_bdrys (groups, make_hull, cols, cmat, obj_xy,
                                       map)
    cols <- cent_bdy$cols

    coords <- get_obj_coords (obj, objtxt, cent_bdy)

    # Get membership of objects within groups
    if (is.null (bg)) # include all points in groups
    {
        membs <- membs_single_group (groups, coords, obj_xy, cent_bdy)
        xy <- membs$xy
        membs <- membs$membs
    } else
    {
        if (boundary != 0) # exclude objects outside group boundaries
            membs <- membs_multiple_groups_bdry (coords, boundary)
        else # split groups across boundaries
            membs <- membs_multiple_groups (coords)

        xy <- membs$xy
        membs <- membs$membs
        # Re-map membs == 0:
        membs [membs == 0] <- length (groups) + 1
    } # end else bg

    xyflat <- cbind_membs_xy (membs, xy)

    if (!missing (bg))
        cols <- c (cols, bg)
    lon <- lat <- id <- NULL # suppress 'no visible binding' error
    aes <- ggplot2::aes (x = lon, y = lat, group = id)

    if (class (obj) == 'SpatialPolygonsDataFrame')
        map <- map_plus_spPolydf_grps (map, xyflat, aes, cols, size) #nolint
    else if (class (obj) == 'SpatialLinesDataFrame')
        map <- map_plus_spLinedf_grps (map, xyflat, aes, cols, size, shape) #nolint
    else if (class (obj) == 'SpatialPointsDataFrame')
    {
        # Not implemented yet
    }

    map <- map_plus_hulls (map, border_width, groups, xyflat, cols)

    return (map)
}

#' check groups argument
#'
#' @noRd
check_groups_arg <- function (groups)
{
    if (missing (groups))
        stop ('groups must be provided', call. = FALSE)

    if (class (groups) != 'list')
    {
        if (!is (groups, 'SpatialPoints'))
            stop ('groups must be a SpatialPoints object (or list thereof)')
        groups <- list (groups)
    } else if (!all( (lapply (groups, class)) == 'SpatialPoints'))
    {
        e <- simpleError ('Cannot coerce groups to SpatialPoints')
        tryCatch (
                  groups <- lapply (groups, function (x)
                                    as (x, 'SpatialPoints')),
                  finally = stop (e))
    }

    return (groups)
}

#' check structure of 'make_hull' arg
#'
#' @noRd
check_hull_arg <- function (make_hull, groups)
{
    if (length (make_hull) > length (groups))
    {
        warning (paste0 ('make_hull has length > number of groups'))
        make_hull <- make_hull [seq (groups)]
    } else if (length (make_hull) > 1 & length (make_hull) < length (groups))
    {
        warning (paste0 ('make_hull should have length 1 or equal to numbers ',
                         'of groups; using first value only'))
        make_hull <- make_hull [1]
    }
    if (max (sapply (groups, length)) < 3) # No groups have > 2 members
        make_hull <- FALSE

    return (make_hull)
}

#' default group colours with no colourmat
#'
#' @noRd
group_colours_default <- function (cols, groups, bg)
{
    if (missing (cols))
        cols <- rainbow (length (groups))
    else if (length (cols) < length (groups))
        cols <- rep (cols, length.out = length (groups))

    ret <- list ('cols' = cols)
    if (length (groups) == 1 & missing (bg))
    {
        warning ('There is only one group; using default bg')
        if (cols [1] != 'gray40')
            bg <- 'gray40'
        else
            bg <- 'white'

        ret ['bg'] <- bg
    } else if (!missing (bg))
        ret ['bg'] <- bg

    return (ret)
}

#' group colours from colourmat
#'
#' @noRd
group_colours_colourmat <- function (cols, groups, rotate)
{
    if (missing (cols))
        cols <- rainbow (4)
    else if (length (cols) < 4)
        cols <- rainbow (4)
    ncols <- 20
    if (missing (rotate))
        cmat <- colour_mat (ncols, cols = cols)
    else
    {
        if (!is.numeric (rotate))
            rotate <- 0
        cmat <- colour_mat (ncols, cols = cols, rotate)
    }
    cols <- rep (NA, length (groups))
    # cols is then a vector of colours to be filled by matching group
    # centroids to relative positions within cmat

    return (list ('cols' = cols, 'cmat' = cmat))
}

#' identify groups which are holes in other groups
#'
#' @note This is not currently used, but the code is ready to implement in this
#' form.
#'
#' @noRd
groups_are_holes <- function (groups)
{
    holes <- rep (FALSE, length (groups))
    group_pairs <- combn (length (groups), 2)
    for (i in seq (ncol (group_pairs)))
    {
        n1 <- length (groups [[group_pairs [1, i] ]])
        n2 <- length (groups [[group_pairs [2, i] ]])
        if (n1 > 2 & n2 > 2) # otherwise can't be a hole
        {
            x1 <- sp::coordinates (groups [[group_pairs [1, i] ]]) [, 1]
            y1 <- sp::coordinates (groups [[group_pairs [1, i] ]]) [, 2]
            indx <- which (!duplicated (cbind (x1, y1)))
            x1 <- x1 [indx]
            y1 <- y1 [indx]
            xy1 <- spatstat::ppp (x1, y1,
                                  xrange = range (x1), yrange = range (y1))
            ch1 <- spatstat::convexhull (xy1)
            bdry1 <- cbind (ch1$bdry[[1]]$x, ch1$bdry[[1]]$y)
            x2 <- sp::coordinates (groups [[group_pairs [2, i] ]]) [, 1]
            y2 <- sp::coordinates (groups [[group_pairs [2, i] ]]) [, 2]
            indx <- which (!duplicated (cbind (x2, y2)))
            x2 <- x2 [indx]
            y2 <- y2 [indx]
            xy2 <- spatstat::ppp (x2, y2,
                                  xrange = range (x2), yrange = range (y2))
            ch2 <- spatstat::convexhull (xy2)
            bdry2 <- cbind (ch2$bdry[[1]]$x, ch2$bdry[[1]]$y)

            indx <- sapply (bdry1, function (x)
                            sp::point.in.polygon (bdry2 [, 1], bdry2 [, 2],
                                                  bdry1 [, 1], bdry1 [, 2]))
            if (all (indx == 1))
                holes [group_pairs [1, i]] <- TRUE
            indx <- sapply (bdry2, function (x)
                            sp::point.in.polygon (bdry1 [, 1], bdry1 [, 2],
                                                  bdry2 [, 1], bdry2 [, 2]))
            if (all (indx == 1))
                holes [group_pairs [2, i]] <- TRUE
        }
    }

    return (holes)
}

#' Trim coordinates of obj to be plotted down to coordinates of map
#'
#' @noRd
trip_obj_to_map <- function (obj, map, objtxt)
{
    xrange <- map$coordinates$limits$x
    yrange <- map$coordinates$limits$y
    xylims <- lapply (slot (obj, objtxt [1]), function (i)
                      {
                          xyi <- slot (slot (i, objtxt [2]) [[1]], 'coords')
                          c (apply (xyi, 2, min), apply (xyi, 2, max))
                      })
    xylims <- do.call (rbind, xylims)
    indx <- which (xylims [, 1] > xrange [1] & xylims [, 2] > yrange [1] &
                   xylims [, 3] < xrange [2] & xylims [, 4] < yrange [2])
    obj <- obj [indx, ]

    # then extract mean coordinates for every polygon or line in obj:
    xy_mn <- lapply (slot (obj, objtxt [1]),  function (x)
                     colMeans  (slot (slot (x, objtxt [2]) [[1]], 'coords')))
    xmn <- sapply (xy_mn, function (x) x [1])
    ymn <- sapply (xy_mn, function (x) x [2])

    return (list ('obj' = obj, 'xy_mn' = xy_mn, 'xmn' = xmn, 'ymn' = ymn))
}

#' Get centroids and boundaries of group objects
#'
#' @note This function constructs
#' 1.  grp_centroids list for centroids of each object in each group; used to
#' reallocate stray objects if is.null (bg)
#' 2. boundaries list of enclosing polygons, creating convex hulls if necessary.
#'
#' @noRd
group_centroids_bdrys <- function (groups, make_hull, cols, cmat, obj_xy, map)
{
    boundaries <- list ()
    grp_centroids <- list ()

    for (i in seq (groups))
    {
        if ( (length (make_hull) == 1 & make_hull) |
            (length (make_hull) > 1 & make_hull [i]))
        {
            x <- slot (groups [[i]], 'coords') [, 1]
            y <- slot (groups [[i]], 'coords') [, 2]
            if (length (x) > 2)
            {
                xy <- spatstat::ppp (x, y,
                                     xrange = range (x), yrange = range (y))
                ch <- spatstat::convexhull (xy)
                bdry <- cbind (ch$bdry[[1]]$x, ch$bdry[[1]]$y)
            } else
                bdry <- sp::coordinates (groups [[i]])
        }
        else
            bdry <- sp::coordinates (groups [[i]])
        if (nrow (bdry) > 1) # otherwise group is obviously a single point
        {
            bdry <- rbind (bdry, bdry [1, ]) #enclose bdry back to 1st point
            # The next 4 lines are only used if is.null (bg)
            indx <- sapply (obj_xy$xy_mn, function (x)
                            sp::point.in.polygon (x [1], x [2],
                                                  bdry [, 1], bdry [, 2]))
            indx <- which (indx > 0) # see below for point.in.polygon values
            grp_centroids [[i]] <- cbind (obj_xy$xmn [indx], obj_xy$ymn [indx])
        } else
        {
            grp_centroids [[i]] <- bdry
            # indx closest point to bdry
            d <- sqrt ( (obj_xy$xmn - bdry [1]) ^ 2 +
                       (obj_xy$ymn - bdry [2]) ^ 2)
            indx <- which.min (d)
        }

        boundaries [[i]] <- bdry

        if (!is.null (cmat))
        {
            # Then get colour from colour.mat
            xrange <- map$coordinates$limits$x
            yrange <- map$coordinates$limits$y
            xi <- ceiling (nrow (cmat) * (mean (obj_xy$xmn [indx]) -
                                          xrange [1]) / diff (xrange))
            yi <- ceiling (nrow (cmat) * (mean (obj_xy$ymn [indx]) -
                                          yrange [1]) / diff (yrange))
            cols [i] <- cmat [xi, yi]
        }
    }

    return (list ('bdry' = boundaries, 'grp_centroids' = grp_centroids,
                  'cols' = cols))
}

#' get coordinates of each obj to be plotted
#'
#' @note pinpooly returns (0,1,2) for (not, on, in) boundary. Also note that the
#' nrow > 2 clause ensures poin.in.polygon is only applied to groups of
#' sufficient size
#'
#' @noRd
get_obj_coords <- function (obj, objtxt, cent_bdy)
{
    coords <- lapply (slot (obj, objtxt [1]),  function (x)
                      slot (slot (x, objtxt [2]) [[1]], 'coords'))
    coords <- lapply (coords, function (i)
                      {
                          pins <- lapply (cent_bdy$bdry, function (j)
                                          {
                                              if (nrow (j) > 2)
                                                  sp::point.in.polygon (
                                                        i [, 1], i [, 2],
                                                        j [, 1], j [, 2])
                                              else
                                                  rep (0, nrow (i))
                                          })
                          pins <- do.call (cbind, pins)
                          cbind (i, pins)
                      })

    return (coords)
}

#' get members of single group
#'
#' @noRd
membs_single_group <- function (groups, coords, obj_xy, cent_bdy)
{
    membs <- sapply (coords, function (i)
                     {
                         temp <- i [, 3:ncol (i)]
                         if (!is.matrix (temp))
                             temp <- matrix (temp, ncol = 1,
                                             nrow = length (temp))
                         temp [temp > 1] <- 1
                         n <- colSums (temp)
                         if (max (n) < 3) # must have > 2 elements in group
                             n <- 0
                         else
                         {
                             indx <- which (n == max (n))
                             n <- indx [ceiling (runif (1) * length (indx))]
                         }
                         return (n)
                     })
    indx <- which (membs == 0)
    x0 <- obj_xy$xmn [indx]
    y0 <- obj_xy$ymn [indx]
    dists <- array (NA, dim = c (length (indx), length (groups)))
    for (i in seq (groups))
    {
        ng <- dim (cent_bdy$grp_centroids [[i]]) [1]
        if (ng > 0)
        {
            x0mat <- array (x0, dim = c(length (x0), ng))
            y0mat <- array (y0, dim = c(length (y0), ng))
            xmat <- t (array (cent_bdy$grp_centroids [[i]] [, 1],
                              dim = c(ng, length (x0))))
            ymat <- t (array (cent_bdy$grp_centroids [[i]] [, 2],
                              dim = c(ng, length (x0))))
            dg <- sqrt ( (xmat - x0mat) ^ 2 + (ymat - y0mat) ^ 2)
            # Then the minimum distance for each stray object to any object
            # in group [i]:
            dists [, i] <- apply (dg, 1, min)
        } else
            dists [, i] <- Inf
    }
    # Then simply extract the group holding the overall minimum dist:
    membs [indx] <- apply (dists, 1, which.min)
    xy <- lapply (coords, function (i) i [, 1:2])

    return (list ('membs' = membs, 'xy' = xy))
}

#' get members of multiple groups with boundary
#'
#' This allocates objects within boundaries to groups, and all remaining
#' objects to group#0
#'
#' @noRd
membs_multiple_groups_bdry <- function (coords, boundary)
{
    xy <- lapply (coords, function (i) i [, 1:2])
    membs <- lapply (coords, function (i)
                     {
                         temp <- i [, 3:ncol (i)]
                         if (!is.matrix (temp))
                             temp <- matrix (temp, ncol = 1,
                                             nrow = length (temp))
                         temp [temp > 1] <- 1
                         n <- colSums (temp)
                         if (boundary < 0)
                         {
                             if (max (n) < nrow (temp))
                                 n <- 0
                             else
                                 n <- which.max (n)
                         } else if (boundary > 0 & max (n) > 0)
                             n <- which.max (n)
                         else
                             n <- 0
                         return (n)
                     })

    return (list ('membs' = membs, 'xy' = xy))
}

#' get members of multiple groups without boundary
#'
#' @note This potentially splits objects across boundaries, thereby extending
#' coords and thus requiring an explicit loop. TODO: Rcpp this?
#'
#' @noRd
membs_multiple_groups <- function (coords)
{
    split_objs <- sapply (coords, function (i)
                          {
                              temp <- i [, 3:ncol (i)]
                              if (!is.matrix (temp))
                                  temp <- matrix (temp, ncol = 1,
                                                  nrow = length (temp))
                              temp [temp > 1] <- 1
                              n <- colSums (temp)
                              if (max (n) > 0 & max (n) < nrow (temp))
                                  return (which.max (n))
                              else
                                  return (0)
                          })
    split_objs <- which (split_objs > 0)

    # Then split coords into 2 lists, one for non-split objects and one
    # containing those listed in split_objs
    coords_split <- lapply (split_objs, function (i) coords [[i]])
    indx <- seq (coords) [!seq (coords) %in% split_objs]
    coords <- lapply (indx, function (i) coords [[i]])
    # Then make new lists of xy and memberships by spliiting objects in
    # coords_split. These lists are of unknown length, requiring an
    # unsightly double loop.
    xy <- list ()
    membs <- NULL
    for (i in coords_split)
    {
        temp <- i [, 3:ncol (i)]
        temp [temp > 1] <- 1
        if (!is.matrix (temp))
            temp <- matrix (temp, ncol = 1, nrow = length (temp))
        n <- colSums (temp)
        if (max (n) < 3)
        {
            xy [[length (xy) + 1]] <- i [, 1:2]
            membs <- c (membs, 0)
        } else
        {
            # Allow for multiple group memberships
            indx_i <- which (n > 2)
            for (j in indx_i)
            {
                indx_j <- which (temp [, j] == 1)
                if (length (indx_j) > 2)
                {
                    xy [[length (xy) + 1]] <- i [indx_j, 1:2]
                    membs <- c (membs, j)
                }
                indx_j <- which (temp [, j] == 0)
                if (length (indx_j) > 2)
                {
                    xy [[length (xy) + 1]] <- i [indx_j, 1:2]
                    membs <- c (membs, 0)
                }
            } # end for j
        } # end else !(max (n) < 3)
    } # end for i
    # Then add the non-split groups
    xy <- c (xy, lapply (coords, function (i) i [, 1:2]))
    membs2 <- sapply (coords, function (i)
                      {
                          temp <- i [, 3:ncol (i)]
                          if (!is.matrix (temp))
                              temp <- matrix (temp, ncol = 1,
                                              nrow = length (temp))
                          temp [temp > 1] <- 1
                          n <- colSums (temp)
                          if (max (n) < nrow (temp))
                              n <- 0
                          else
                              n <- which.max (n)
                          return (n)
                      })
    membs <- c (membs, membs2)

    return (list ('membs' = membs, 'xy' = xy))
}

#' cbind membs to xy so that membs maps straight onto cols
#'
#' @noRd
cbind_membs_xy <- function (membs, xy)
{
    xym <- mapply (cbind, xy, membs)
    for (i in seq (xym))
    {
        xym [[i]] <- data.frame (cbind (i, xym [[i]]))
        names (xym [[i]]) <- c ("id", "lon", "lat", "col")
    }

    do.call (rbind, xym)
}

#' add SpatialPolygonsDataFrame to map
#'
#' @noRd
map_plus_spPolydf_grps <- function (map, xy, aes, cols, size) #nolint
{
    if (missing (size))
        size <- 0
    else if (!is.numeric (size))
        size <- 0

    map + ggplot2::geom_polygon (data = xy, mapping = aes, fill = cols [xy$col],
                                 size = size)
}

#' add SpatialLinesDataFrame to map
#'
#' @noRd
map_plus_spLinedf_grps <- function (map, xyflat, aes, cols, size, shape) #nolint
{
    if (missing (size))
        size <- 0.5
    else if (!is.numeric (size))
        size <- 0.5

    if (missing (shape))
        shape <- 1
    else if (!is.numeric (shape))
        shape <- 1

    map + ggplot2::geom_path (data = xyflat, mapping = aes,
                              colour = cols [xyflat$col], size = size,
                              linetype = shape)
}

#' draw convex hulls around groups on map
#'
#' @noRd
map_plus_hulls <- function (map, border_width, groups, xyflat, cols)
{

    id <- NULL # suppress R CMD check note for aes (..,`group = id`) below
    if (!missing (border_width)) # draw hulls around entire groups
    {
        if (!is.numeric (border_width))
            return (map)

        bdry <- list ()
        for (i in seq (groups))
        {
            indx <- which (xyflat$col == i) # col = group membership
            if (length (indx) > 1)
            {
                x <- xyflat$lon [indx]
                y <- xyflat$lat [indx]
                indx <- which (!duplicated (cbind (x, y)))
                x <- x [indx]
                y <- y [indx]
                xy2 <- spatstat::ppp (x, y, xrange = range (x),
                                      yrange = range (y))
                ch <- spatstat::convexhull (xy2)
                bdry [[i]] <- cbind (ch$bdry[[1]]$x, ch$bdry[[1]]$y)
            }
            bdry [[i]] <- cbind (i, bdry [[i]])
        }
        bdry <- data.frame (do.call (rbind, bdry))
        names (bdry) <- c ("id", "x", "y")

        aes <- ggplot2::aes (x = x, y = y, group = id)
        map <- map + ggplot2::geom_polygon (data = bdry, mapping = aes,
                                            colour = cols [bdry$id],
                                            fill = "transparent",
                                            size = border_width)
    }

    return (map)
}
