// AI_Tutor/Views/Components/ZoomableImagePager.swift
import SwiftUI

/// A horizontally-pageable image viewer with pinch-to-zoom and pan support.
/// Mirrors the ImageViewerPanel from Android's ProblemConfirmationScreen.
struct ZoomableImagePager: View {
    let images: [UIImage]

    @State private var currentPage = 0
    @State private var scales:  [CGFloat]
    @State private var offsets: [CGSize]

    init(images: [UIImage]) {
        self.images  = images
        _scales  = State(initialValue: Array(repeating: 1.0, count: images.count))
        _offsets = State(initialValue: Array(repeating: .zero, count: images.count))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Horizontal pager (TabView .page style)
            TabView(selection: $currentPage) {
                ForEach(images.indices, id: \.self) { i in
                    ZoomableImageCell(
                        image:  images[i],
                        scale:  $scales[i],
                        offset: $offsets[i]
                    )
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: images.count > 1 ? .always : .never))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            // Page counter badge (top-left)
            if images.count > 1 {
                VStack {
                    HStack {
                        Text("\(currentPage + 1) / \(images.count)")
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(.black.opacity(0.55))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .padding(6)
                        Spacer()
                    }
                    Spacer()
                }
            }

            // Zoom controls (top-right)
            VStack {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        ZoomButton(icon: "plus.magnifyingglass") {
                            scales[currentPage] = min(5.0, scales[currentPage] * 1.5)
                        }
                        ZoomButton(icon: "minus.magnifyingglass") {
                            let ns = max(1.0, scales[currentPage] / 1.5)
                            scales[currentPage]  = ns
                            if ns <= 1.0 { offsets[currentPage] = .zero }
                        }
                        ZoomButton(icon: "arrow.up.left.and.down.right.magnifyingglass") {
                            scales[currentPage]  = 1.0
                            offsets[currentPage] = .zero
                        }
                    }
                    .padding(6)
                }
                Spacer()
            }
        }
    }
}

// MARK: - Single zoomable cell
private struct ZoomableImageCell: View {
    let image: UIImage
    @Binding var scale:  CGFloat
    @Binding var offset: CGSize

    // Gesture state
    @GestureState private var dragDelta:    CGSize  = .zero
    @GestureState private var pinchDelta:   CGFloat = 1.0

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .scaleEffect(scale * pinchDelta)
            .offset(x: offset.width + dragDelta.width,
                    y: offset.height + dragDelta.height)
            .gesture(
                MagnificationGesture()
                    .updating($pinchDelta) { value, state, _ in state = value }
                    .onEnded { value in
                        let newScale = max(1.0, min(5.0, scale * value))
                        scale = newScale
                        if newScale <= 1.0 { offset = .zero }
                    }
                    .simultaneously(with:
                        DragGesture()
                            .updating($dragDelta) { value, state, _ in
                                if scale > 1.0 { state = value.translation }
                            }
                            .onEnded { value in
                                if scale > 1.0 {
                                    offset = CGSize(
                                        width:  offset.width  + value.translation.width,
                                        height: offset.height + value.translation.height
                                    )
                                }
                            }
                    )
            )
            .onTapGesture(count: 2) {
                withAnimation { scale = 1.0; offset = .zero }
            }
    }
}

// MARK: - Zoom button
private struct ZoomButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(.black.opacity(0.55))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
