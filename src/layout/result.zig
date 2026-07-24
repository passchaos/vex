//! Layout result data structures.

pub const Point = struct {
    x: f64,
    y: f64,
};

pub const NodeLayout = struct {
    center: Point,
    width: f64,
    height: f64,
};

pub const SubgraphLayout = struct {
    id: usize,
    x: f64,
    y: f64,
    width: f64,
    height: f64,
};

pub const EdgeWaypoint = struct {
    rank: usize,
    point: Point,
};

pub const EdgeWaypoints = struct {
    points: []EdgeWaypoint,
};
