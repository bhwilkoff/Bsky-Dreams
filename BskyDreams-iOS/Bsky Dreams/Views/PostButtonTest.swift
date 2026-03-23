import SwiftUI

// MARK: - POST Button Rounded-Rect Suppression Test
//
// HOW TO RUN: Open in Xcode Preview.
//
// PostButtonTestView (OLD): Uses ToolbarItem — shows the rounded-rect problem.
// PostButtonFixTestView (NEW): Uses custom safeAreaInset header — the correct fix.
//
// PASS: No gray/material rounded rectangle is visible around the POST button.
// FAIL: A rounded rectangle background appears around the POST button.

// ── Old approach (ToolbarItem) — still shows the system rounded rect ──────────
struct PostButtonOldView: View {
    @State private var trigger = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.red.opacity(0.15).ignoresSafeArea()
                Text("FAIL: rounded rect still visible in ToolbarItem")
                    .font(.inter(12)).foregroundStyle(.red)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Text("POST")
                        .font(.syne(12, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.nbAccent)
                        .overlay(Rectangle().strokeBorder(Color.nbBlack, lineWidth: 2))
                        .contentShape(Rectangle())
                        .onTapGesture { trigger.toggle() }
                }
            }
            .toolbarBackground(Color.green.opacity(0.3), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

// ── New approach (custom safeAreaInset header) — no UIBarButtonItem involved ──
struct PostButtonFixTestView: View {
    @State private var trigger = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.green.opacity(0.3).ignoresSafeArea()
                Text("PASS: no rounded rect — custom header bypasses UIBarButtonItem")
                    .font(.inter(12)).foregroundStyle(.green)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack {
                    CloudLogoView(size: 28)
                    Spacer()
                    Text("POST")
                        .font(.syne(12, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.nbAccent)
                        .overlay(Rectangle().strokeBorder(Color.nbBlack, lineWidth: 2))
                        .contentShape(Rectangle())
                        .onTapGesture { trigger.toggle() }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(Color.green.opacity(0.3))
            }
        }
    }
}

#Preview("OLD — ToolbarItem (shows rounded rect)") {
    PostButtonOldView()
}

#Preview("NEW — Custom header (fix)") {
    PostButtonFixTestView()
}
