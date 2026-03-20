import Foundation

/// Pure-Swift gesture routing logic for the Constellation graph view.
/// Mirrors the logic in ConstellationView's unified DragGesture handler.
public struct ConstellationGestureEngine {

    /// Convert a screen point to graph-coordinate space.
    public static func toGraphCoord(
        screenPoint: (x: Double, y: Double),
        canvasSize:  (width: Double, height: Double),
        zoom:        Double,
        panOffset:   (width: Double, height: Double)
    ) -> (x: Double, y: Double) {
        (
            x: (screenPoint.x - canvasSize.width  / 2 - panOffset.width)  / zoom,
            y: (screenPoint.y - canvasSize.height / 2 - panOffset.height) / zoom
        )
    }

    /// Hit-test a screen point against the node list.
    /// Returns the first node whose touch target (radius + 10pt) contains the point.
    public static func hitNode(
        at screenPoint:   (x: Double, y: Double),
        nodes:            [GraphNode],
        canvasSize:       (width: Double, height: Double),
        zoom:             Double,
        panOffset:        (width: Double, height: Double),
        maxDegree:        Int
    ) -> GraphNode? {
        let gp = toGraphCoord(
            screenPoint: screenPoint,
            canvasSize:  canvasSize,
            zoom:        zoom,
            panOffset:   panOffset
        )
        return nodes.first { node in
            let r = node.radius(maxDegree: maxDegree) + 10 // generous touch target
            return hypot(node.x - gp.x, node.y - gp.y) < r
        }
    }

    /// Compute the new graph position of a dragged node.
    public static func draggedNodePosition(
        startGraphPos: (x: Double, y: Double),
        translation:   (width: Double, height: Double),
        zoom:          Double
    ) -> (x: Double, y: Double) {
        (
            x: startGraphPos.x + translation.width  / zoom,
            y: startGraphPos.y + translation.height / zoom
        )
    }

    /// Given a drag start point, decide whether it routes to a node drag or a background pan.
    public enum DragRoute {
        case nodeDrag(nodeId: String, startGraphPos: (x: Double, y: Double))
        case backgroundPan
    }

    public static func routeDrag(
        startPoint: (x: Double, y: Double),
        nodes:      [GraphNode],
        canvasSize: (width: Double, height: Double),
        zoom:       Double,
        panOffset:  (width: Double, height: Double),
        maxDegree:  Int
    ) -> DragRoute {
        if let hit = hitNode(
            at:         startPoint,
            nodes:      nodes,
            canvasSize: canvasSize,
            zoom:       zoom,
            panOffset:  panOffset,
            maxDegree:  maxDegree
        ) {
            return .nodeDrag(nodeId: hit.id, startGraphPos: (x: hit.x, y: hit.y))
        }
        return .backgroundPan
    }
}
