import Foundation

/// A graph node in the constellation force graph.
public struct GraphNode: Identifiable, Equatable {
    public let id: String
    public var handle: String
    public var displayName: String?
    public var avatar: String?
    public var weight: Int = 0
    public var degree: Int = 0
    public var isSeed: Bool = false
    public var x: Double
    public var y: Double
    public var vx: Double = 0
    public var vy: Double = 0

    public init(id: String, handle: String, displayName: String? = nil,
                avatar: String? = nil, weight: Int = 0, degree: Int = 0,
                isSeed: Bool = false, x: Double = 0, y: Double = 0) {
        self.id = id; self.handle = handle; self.displayName = displayName
        self.avatar = avatar; self.weight = weight; self.degree = degree
        self.isSeed = isSeed; self.x = x; self.y = y
    }

    /// Visual/hit-testing radius of this node.
    public func radius(maxDegree: Int) -> Double {
        if isSeed { return 18 }
        let base: Double = 7
        let scale = sqrt(Double(max(degree, 0)) / Double(max(maxDegree, 1)))
        return min(base + scale * 8, 15)
    }

    public static func == (lhs: GraphNode, rhs: GraphNode) -> Bool { lhs.id == rhs.id }
}

public struct GraphEdge: Identifiable {
    public var id: String { "\(from)|\(to)" }
    public let from: String
    public let to: String
    public var weight: Int = 1

    public init(from: String, to: String, weight: Int = 1) {
        self.from = from; self.to = to; self.weight = weight
    }
}
