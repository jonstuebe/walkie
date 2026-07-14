import SwiftUI
import SwiftData

struct GraveyardView: View {
    @Query(sort: \GraveyardPet.deathDate, order: .reverse) private var deadPets: [GraveyardPet]

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    var body: some View {
        NavigationStack {
            ZStack {
                GraveyardBackdrop()
                    .ignoresSafeArea()

                if deadPets.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVGrid(
                            columns: [GridItem(.flexible(), spacing: 18), GridItem(.flexible(), spacing: 18)],
                            alignment: .center,
                            spacing: 18
                        ) {
                            ForEach(deadPets) { pet in
                                memorial(for: pet)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Graveyard")
            .toolbarBackground(.clear, for: .navigationBar)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 52))
                .foregroundStyle(.white.opacity(0.85))
                .shadow(color: Color(red: 0.6, green: 0.7, blue: 1.0).opacity(0.5), radius: 16)

            Text("No koalas rest here")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(.white)

            Text("Keep walking to keep your koala alive.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private func memorial(for pet: GraveyardPet) -> some View {
        VStack(spacing: 14) {
            KoalaPortrait(color: pet.color)

            VStack(spacing: 5) {
                Text(pet.name)
                    .font(.system(.title3, design: .rounded).weight(.heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text("Lived \(pet.daysLived) day\(pet.daysLived == 1 ? "" : "s")")
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(.white.opacity(0.55))

                Text(dateFormatter.string(from: pet.deathDate))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - Portrait medallion

private struct KoalaPortrait: View {
    var color: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.16))
            Circle()
                .strokeBorder(color.opacity(0.35), lineWidth: 1)

            KoalaView(color: color, bodyScale: 0.85)
                .scaleEffect(0.52)
                .frame(width: 120, height: 120)
                .offset(y: 8)
        }
        .frame(width: 104, height: 104)
        .clipShape(Circle())
        .overlay(
            Circle().strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}

// MARK: - Night backdrop

struct GraveyardBackdrop: View {
    // Deterministic star field — no randomness so the layout is stable across redraws.
    private static let stars: [(x: CGFloat, y: CGFloat, s: CGFloat, o: Double)] = [
        (0.12, 0.10, 2.0, 0.8), (0.28, 0.06, 1.4, 0.5), (0.45, 0.13, 1.8, 0.7),
        (0.62, 0.05, 1.2, 0.4), (0.86, 0.22, 2.2, 0.9), (0.92, 0.09, 1.5, 0.6),
        (0.18, 0.24, 1.3, 0.5), (0.53, 0.27, 1.6, 0.6), (0.70, 0.18, 1.1, 0.4),
        (0.35, 0.20, 1.0, 0.35), (0.05, 0.30, 1.4, 0.45)
    ]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.06, blue: 0.13),
                        Color(red: 0.09, green: 0.10, blue: 0.20),
                        Color(red: 0.07, green: 0.09, blue: 0.15),
                        Color(red: 0.03, green: 0.04, blue: 0.08)
                    ],
                    startPoint: .top, endPoint: .bottom
                )

                ForEach(0..<Self.stars.count, id: \.self) { i in
                    let star = Self.stars[i]
                    Circle()
                        .fill(Color.white.opacity(star.o))
                        .frame(width: star.s, height: star.s)
                        .position(x: w * star.x, y: h * star.y)
                }

                // Moon + glow, upper right
                ZStack {
                    Circle()
                        .fill(Color(red: 0.75, green: 0.80, blue: 0.95))
                        .frame(width: 120, height: 120)
                        .blur(radius: 40)
                        .opacity(0.3)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(red: 0.97, green: 0.98, blue: 1.0), Color(red: 0.80, green: 0.84, blue: 0.95)],
                                center: .init(x: 0.38, y: 0.35),
                                startRadius: 2, endRadius: 44
                            )
                        )
                        .frame(width: 56, height: 56)
                }
                .position(x: w * 0.80, y: h * 0.11)
            }
            .frame(width: w, height: h)
            .clipped()
        }
    }
}
