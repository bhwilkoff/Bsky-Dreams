import SwiftUI

/// Temporary diagnostic view — attach to SidebarView to inspect header sizing.
/// To use: replace sidebarHeader in SidebarView.body with SidebarHeaderTestView()
struct SidebarHeaderTestView: View {
    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // --- Measurements ---
                VStack(alignment: .leading, spacing: 4) {
                    Text("GeoReader safeArea.top: \(geo.safeAreaInsets.top, specifier: "%.1f")")
                    Text("UIKit safeArea.top: \(uiKitTopInset, specifier: "%.1f")")
                    Text("Frame proposed to GeoReader: \(geo.size.height, specifier: "%.1f") × \(geo.size.width, specifier: "%.1f")")
                }
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.red)
                .padding(6)
                .background(Color.yellow.opacity(0.4))
                .border(Color.red, width: 1)
            }
        }
        // --- Key insight: without a frame, GeometryReader fills ALL available height
        // Comment out the next line to see the header expand to fill the sidebar
        .frame(height: 120)
        .border(Color.blue, width: 2)
        .overlay(alignment: .top) {
            Text("SidebarHeader bounds (blue border)")
                .font(.system(size: 9))
                .foregroundStyle(.blue)
                .padding(.top, 2)
        }
    }

    private var uiKitTopInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.keyWindow?.safeAreaInsets.top ?? -1
    }
}

/// Renders three candidate header implementations side-by-side for comparison.
/// Run in a SwiftUI preview to see sizing behavior.
struct SidebarHeaderComparison_Previews: PreviewProvider {
    static var previews: some View {
        // Simulate the sidebar VStack that the header lives inside
        VStack(spacing: 0) {
            // ── CANDIDATE A: ZStack with Color sibling (current — greedy) ──
            ZStack(alignment: .bottom) {
                Color.yellow.opacity(0.3)                   // Greedy — expands to fill VStack
                Rectangle().fill(Color.orange).frame(height: 18)
                VStack(spacing: 0) {
                    Spacer().frame(height: 59)              // Simulated safe area
                    HStack { Spacer(); Text("A: ZStack+Color (greedy)"); Spacer() }
                        .padding(.vertical, 14)
                }
            }
            .frame(minHeight: 103)
            .border(Color.red, width: 2)
            Text("↑ Candidate A (ZStack+Color) height above")
                .font(.caption).foregroundStyle(.red)

            Divider()

            // ── CANDIDATE B: VStack with .background (non-greedy) ──
            VStack(spacing: 0) {
                Spacer().frame(height: 59)                  // Simulated safe area
                HStack { Spacer(); Text("B: VStack+background (fixed)"); Spacer() }
                    .padding(.vertical, 12)
                Rectangle().fill(Color.orange).frame(height: 18)
            }
            .background(Color.yellow.opacity(0.3))
            .border(Color.green, width: 2)
            Text("↑ Candidate B (VStack+background) height above")
                .font(.caption).foregroundStyle(.green)

            Divider()

            // ── Remaining space ──
            ScrollView {
                VStack {
                    ForEach(0..<10) { i in
                        Text("Nav item \(i)").frame(maxWidth: .infinity).padding()
                    }
                }
            }
        }
        .frame(width: 280, height: 700)
        .border(Color.black, width: 1)
        .previewLayout(.sizeThatFits)
    }
}
