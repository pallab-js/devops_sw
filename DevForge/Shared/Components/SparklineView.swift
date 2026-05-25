import SwiftUI

struct SparklineView: Shape {
    let data: [Double]

    func path(in rect: CGRect) -> Path {
        guard data.count > 1 else { return Path() }
        let minVal = data.min() ?? 0
        let maxVal = data.max() ?? 1
        let range = max(maxVal - minVal, 1)
        let stepX = rect.width / CGFloat(data.count - 1)

        var path = Path()
        path.move(to: CGPoint(
            x: 0,
            y: rect.height - CGFloat((data[0] - minVal) / range) * rect.height
        ))
        for i in 1..<data.count {
            path.addLine(to: CGPoint(
                x: CGFloat(i) * stepX,
                y: rect.height - CGFloat((data[i] - minVal) / range) * rect.height
            ))
        }
        return path
    }
}

struct SparklineAreaShape: Shape {
    let data: [Double]

    func path(in rect: CGRect) -> Path {
        guard data.count > 1 else { return Path() }
        let minVal = data.min() ?? 0
        let maxVal = data.max() ?? 1
        let range = max(maxVal - minVal, 1)
        let stepX = rect.width / CGFloat(data.count - 1)

        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(
            x: 0,
            y: rect.height - CGFloat((data[0] - minVal) / range) * rect.height
        ))
        for i in 1..<data.count {
            path.addLine(to: CGPoint(
                x: CGFloat(i) * stepX,
                y: rect.height - CGFloat((data[i] - minVal) / range) * rect.height
            ))
        }
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()
        return path
    }
}

struct SparklineContainerView: View {
    let data: [Double]
    let color: Color
    @State private var animatedData: [Double] = []

    var body: some View {
        ZStack {
            SparklineAreaShape(data: animatedData)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [color.opacity(0.25), color.opacity(0.01)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            SparklineView(data: animatedData)
                .stroke(color, lineWidth: 1.5)
        }
        .frame(height: 50)
        .onChange(of: data) { _, newValue in
            if !animatedData.isEmpty {
                withAnimation(.easeInOut(duration: 0.3)) {
                    animatedData = newValue
                }
            } else {
                animatedData = newValue
            }
        }
        .onAppear {
            animatedData = data
        }
    }
}
