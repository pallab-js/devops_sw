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

struct SparklineContainerView: View {
    let data: [Double]
    let color: Color
    @State private var animatedData: [Double] = []

    var body: some View {
        SparklineView(data: animatedData)
            .stroke(color, lineWidth: 1.5)
            .frame(height: 50)
            .onChange(of: data) { _, newValue in
                withAnimation(.easeInOut(duration: 0.3)) {
                    animatedData = newValue
                }
            }
            .onAppear {
                animatedData = data
            }
    }
}
