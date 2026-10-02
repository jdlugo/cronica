import SwiftUI

struct AdvancedFilterView: View {
    @Binding var selectedGenres: Set<Int>
    @Binding var yearRange: ClosedRange<Int>
    @Binding var ratingRange: ClosedRange<Double>
    @Binding var selectedMediaType: MediaType
    @Binding var isPresented: Bool
    var onApply: () -> Void

    private let currentYear = Calendar.current.component(.year, from: Date())

    private let movieGenres: [Genre] = [
        Genre(id: 28, name: NSLocalizedString("Action", comment: "")),
        Genre(id: 12, name: NSLocalizedString("Adventure", comment: "")),
        Genre(id: 16, name: NSLocalizedString("Animation", comment: "")),
        Genre(id: 35, name: NSLocalizedString("Comedy", comment: "")),
        Genre(id: 80, name: NSLocalizedString("Crime", comment: "")),
        Genre(id: 99, name: NSLocalizedString("Documentary", comment: "")),
        Genre(id: 18, name: NSLocalizedString("Drama", comment: "")),
        Genre(id: 10751, name: NSLocalizedString("Family", comment: "")),
        Genre(id: 14, name: NSLocalizedString("Fantasy", comment: "")),
        Genre(id: 36, name: NSLocalizedString("History", comment: "")),
        Genre(id: 27, name: NSLocalizedString("Horror", comment: "")),
        Genre(id: 10402, name: NSLocalizedString("Music", comment: "")),
        Genre(id: 9648, name: NSLocalizedString("Mystery", comment: "")),
        Genre(id: 10749, name: NSLocalizedString("Romance", comment: "")),
        Genre(id: 878, name: NSLocalizedString("Science Fiction", comment: "")),
        Genre(id: 53, name: NSLocalizedString("Thriller", comment: "")),
        Genre(id: 10752, name: NSLocalizedString("War", comment: ""))
    ]

    private let tvGenres: [Genre] = [
        Genre(id: 10759, name: NSLocalizedString("Action & Adventure", comment: "")),
        Genre(id: 16, name: NSLocalizedString("Animation", comment: "")),
        Genre(id: 35, name: NSLocalizedString("Comedy", comment: "")),
        Genre(id: 80, name: NSLocalizedString("Crime", comment: "")),
        Genre(id: 99, name: NSLocalizedString("Documentary", comment: "")),
        Genre(id: 18, name: NSLocalizedString("Drama", comment: "")),
        Genre(id: 10762, name: NSLocalizedString("Kids", comment: "")),
        Genre(id: 9648, name: NSLocalizedString("Mystery", comment: "")),
        Genre(id: 10765, name: NSLocalizedString("Sci-Fi & Fantasy", comment: ""))
    ]

    private var genres: [Genre] {
        selectedMediaType == .movie ? movieGenres : tvGenres
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Content Type") {
                    Picker("Type", selection: $selectedMediaType) {
                        Text("Movies").tag(MediaType.movie)
                        Text("TV Shows").tag(MediaType.tvShow)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedMediaType) {
                        selectedGenres.removeAll()
                    }
                }

                Section("Genres") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                        ForEach(genres) { genre in
                            Button {
                                if selectedGenres.contains(genre.id) {
                                    selectedGenres.remove(genre.id)
                                } else {
                                    selectedGenres.insert(genre.id)
                                }
                            } label: {
                                Text(genre.name ?? "")
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(selectedGenres.contains(genre.id) ? Color.accentColor : Color.secondary.opacity(0.2))
                                    .foregroundColor(selectedGenres.contains(genre.id) ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Year Range") {
                    VStack {
                        Text("\(yearRange.lowerBound) — \(yearRange.upperBound)")
                            .font(.headline)
                        RangeSlider(range: $yearRange, bounds: 1900...currentYear)
                    }
                }

                Section("Rating") {
                    VStack {
                        Text(String(format: "%.1f — %.1f", ratingRange.lowerBound, ratingRange.upperBound))
                            .font(.headline)
                        RangeSlider(range: $ratingRange, bounds: 0...10)
                    }
                }
            }
            .navigationTitle("Filters")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        isPresented = false
                        onApply()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") {
                        selectedGenres.removeAll()
                        yearRange = 1900...currentYear
                        ratingRange = 0...10
                    }
                }
            }
        }
    }
}

// MARK: - Range Slider

private struct RangeSlider<V: BinaryFloatingPoint>: View where V.Stride: BinaryFloatingPoint {
    @Binding var range: ClosedRange<V>
    let bounds: ClosedRange<V>

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let totalRange = V(bounds.upperBound - bounds.lowerBound)
            let lowerFraction = CGFloat((range.lowerBound - bounds.lowerBound) / totalRange)
            let upperFraction = CGFloat((range.upperBound - bounds.lowerBound) / totalRange)

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 4)

                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: (upperFraction - lowerFraction) * width, height: 4)
                    .offset(x: lowerFraction * width)

                Circle()
                    .fill(Color.white)
                    .shadow(radius: 2)
                    .frame(width: 24, height: 24)
                    .offset(x: lowerFraction * width - 12)
                    .gesture(DragGesture().onChanged { value in
                        let newValue = V(value.location.x / width) * totalRange + bounds.lowerBound
                        let clamped = max(bounds.lowerBound, min(newValue, range.upperBound - totalRange * 0.02))
                        range = clamped...range.upperBound
                    })

                Circle()
                    .fill(Color.white)
                    .shadow(radius: 2)
                    .frame(width: 24, height: 24)
                    .offset(x: upperFraction * width - 12)
                    .gesture(DragGesture().onChanged { value in
                        let newValue = V(value.location.x / width) * totalRange + bounds.lowerBound
                        let clamped = min(bounds.upperBound, max(newValue, range.lowerBound + totalRange * 0.02))
                        range = range.lowerBound...clamped
                    })
            }
        }
        .frame(height: 30)
    }
}

// Int version
extension RangeSlider where V == Double {
    init(range: Binding<ClosedRange<Int>>, bounds: ClosedRange<Int>) {
        self._range = Binding(
            get: { Double(range.wrappedValue.lowerBound)...Double(range.wrappedValue.upperBound) },
            set: { range.wrappedValue = Int($0.lowerBound)...Int($0.upperBound) }
        )
        self.bounds = Double(bounds.lowerBound)...Double(bounds.upperBound)
    }
}
