import SwiftUI

enum Theme {
    static let bg = Color(red: 0.055, green: 0.063, blue: 0.075)
    static let panel = Color(red: 0.078, green: 0.090, blue: 0.106)
    static let amber = Color(red: 0.91, green: 0.64, blue: 0.24)
    static let text = Color(red: 0.79, green: 0.81, blue: 0.84)
    static let dim = Color(red: 0.62, green: 0.65, blue: 0.70)

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

struct ShieldShape: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height
        var p = Path()
        p.move(to: CGPoint(x: r.minX + 0.5 * w, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX + 0.93 * w, y: r.minY + 0.12 * h))
        p.addCurve(to: CGPoint(x: r.minX + 0.5 * w, y: r.maxY),
                   control1: CGPoint(x: r.minX + 0.93 * w, y: r.minY + 0.62 * h),
                   control2: CGPoint(x: r.minX + 0.70 * w, y: r.minY + 0.85 * h))
        p.addCurve(to: CGPoint(x: r.minX + 0.07 * w, y: r.minY + 0.12 * h),
                   control1: CGPoint(x: r.minX + 0.30 * w, y: r.minY + 0.85 * h),
                   control2: CGPoint(x: r.minX + 0.07 * w, y: r.minY + 0.62 * h))
        p.closeSubpath()
        return p
    }
}

struct EyeShape: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height
        let cx = r.minX + 0.5 * w, cy = r.minY + 0.45 * h
        let hw = 0.27 * w, hh = 0.13 * h
        var p = Path()
        p.move(to: CGPoint(x: cx - hw, y: cy))
        p.addQuadCurve(to: CGPoint(x: cx + hw, y: cy), control: CGPoint(x: cx, y: cy - 2 * hh))
        p.addQuadCurve(to: CGPoint(x: cx - hw, y: cy), control: CGPoint(x: cx, y: cy + 2 * hh))
        p.closeSubpath()
        return p
    }
}

/// Shield with a watching eye. Scales to any square-ish frame.
struct LogoView: View {
    var body: some View {
        GeometryReader { g in
            let side = min(g.size.width, g.size.height)
            ZStack {
                ShieldShape().fill(Theme.panel)
                ShieldShape().stroke(Theme.amber, lineWidth: max(1.5, side * 0.035))
                EyeShape().stroke(Theme.amber, lineWidth: max(1.2, side * 0.028))
                Circle().fill(Theme.amber)
                    .frame(width: side * 0.17, height: side * 0.17)
                    .offset(y: -side * 0.05)
                Circle().fill(Theme.panel)
                    .frame(width: side * 0.06, height: side * 0.06)
                    .offset(y: -side * 0.05)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct AmberButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.mono(14, weight: .semibold))
            .tracking(4)
            .foregroundStyle(Theme.bg)
            .padding(.horizontal, 36).padding(.vertical, 10)
            .background(Theme.amber.opacity(configuration.isPressed ? 0.7 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

struct LandingView: View {
    @EnvironmentObject var store: SessionStore
    var body: some View {
        VStack(spacing: 18) {
            LogoView().frame(width: 130, height: 130)
            Text("AGENCY HQ")
                .font(Theme.mono(40, weight: .bold)).tracking(10)
                .foregroundStyle(Theme.text)
            Text("AUTHORIZED PERSONNEL ONLY")
                .font(Theme.mono(11)).tracking(4)
                .foregroundStyle(Theme.amber)
            Button("BEGIN") { store.begin() }
                .buttonStyle(AmberButtonStyle())
                .keyboardShortcut(.defaultAction)
                .padding(.top, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
    }
}
