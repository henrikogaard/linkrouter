import SwiftUI

struct ForkMark: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            var path = Path()
            path.move(to: CGPoint(x: w * 0.50, y: h * 0.82))
            path.addLine(to: CGPoint(x: w * 0.50, y: h * 0.46))
            path.addLine(to: CGPoint(x: w * 0.28, y: h * 0.22))
            path.move(to: CGPoint(x: w * 0.50, y: h * 0.46))
            path.addLine(to: CGPoint(x: w * 0.72, y: h * 0.22))
            context.stroke(
                path,
                with: .color(Color.primary),
                style: StrokeStyle(lineWidth: w * 0.08, lineCap: .round, lineJoin: .round)
            )
            let r = w * 0.07
            context.fill(Path(ellipseIn: CGRect(x: w * 0.50 - r, y: h * 0.82 - r, width: r * 2, height: r * 2)), with: .color(Color.primary))
            context.fill(Path(ellipseIn: CGRect(x: w * 0.28 - r, y: h * 0.22 - r, width: r * 2, height: r * 2)), with: .color(Color.primary))
            context.fill(Path(ellipseIn: CGRect(x: w * 0.72 - r, y: h * 0.22 - r, width: r * 2, height: r * 2)), with: .color(Color.primary))
        }
        .accessibilityHidden(true)
    }
}
