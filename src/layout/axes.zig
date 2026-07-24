//! Rank-direction axis helpers for layout geometry.

pub fn Axes(comptime RankDir: type, comptime Point: type) type {
    return struct {
        const Self = @This();

        rankdir: RankDir,

        pub fn init(rankdir: RankDir) Self {
            return .{ .rankdir = rankdir };
        }

        pub fn horizontalRanks(self: Self) bool {
            return self.rankdir == .LR or self.rankdir == .RL;
        }

        pub fn reversedRanks(self: Self) bool {
            return self.rankdir == .BT or self.rankdir == .RL;
        }

        pub fn orientSize(self: Self, size: anytype) @TypeOf(size) {
            return switch (self.rankdir) {
                .TB, .BT => size,
                .LR, .RL => .{ .width = size.height, .height = size.width },
            };
        }

        pub fn orientPoint(self: Self, along: f64, depth: f64, total_depth: f64, margin_x: f64, margin_y: f64) Point {
            return switch (self.rankdir) {
                .TB => .{ .x = margin_x + along, .y = margin_y + depth },
                .BT => .{ .x = margin_x + along, .y = total_depth + margin_y * 2.0 - (margin_y + depth) },
                .LR => .{ .x = margin_x + depth, .y = margin_y + along },
                .RL => .{ .x = total_depth + margin_x * 2.0 - (margin_x + depth), .y = margin_y + along },
            };
        }

        pub fn alongMargin(self: Self, options: anytype) f64 {
            return if (self.horizontalRanks()) options.margin_y else options.margin;
        }

        pub fn depthMargin(self: Self, options: anytype) f64 {
            return if (self.horizontalRanks()) options.margin else options.margin_y;
        }

        pub fn layoutWidth(self: Self, base_along: f64, base_depth: f64) f64 {
            return if (self.horizontalRanks()) base_depth else base_along;
        }

        pub fn layoutHeight(self: Self, base_along: f64, base_depth: f64) f64 {
            return if (self.horizontalRanks()) base_along else base_depth;
        }

        pub fn pointAlong(self: Self, point: anytype) f64 {
            return switch (self.rankdir) {
                .TB, .BT => point.x,
                .LR, .RL => point.y,
            };
        }

        pub fn orientWaypoint(self: Self, along_screen: f64, depth: f64, layout: anytype) Point {
            return switch (self.rankdir) {
                .TB => .{ .x = along_screen, .y = layout.margin_y + depth },
                .BT => .{ .x = along_screen, .y = layout.height - (layout.margin_y + depth) },
                .LR => .{ .x = layout.margin_x + depth, .y = along_screen },
                .RL => .{ .x = layout.width - (layout.margin_x + depth), .y = along_screen },
            };
        }

        pub fn offsetPoint(self: Self, point: anytype, offset: f64) @TypeOf(point) {
            return switch (self.rankdir) {
                .TB, .BT => .{ .x = point.x + offset, .y = point.y },
                .LR, .RL => .{ .x = point.x, .y = point.y + offset },
            };
        }

        pub fn rankAxisDelta(self: Self, dx: f64, dy: f64) f64 {
            return if (self.horizontalRanks()) @abs(dx) else @abs(dy);
        }

        pub fn nodeAlongHalfSize(self: Self, node: anytype) f64 {
            return switch (self.rankdir) {
                .TB, .BT => node.width / 2.0,
                .LR, .RL => node.height / 2.0,
            };
        }
    };
}
