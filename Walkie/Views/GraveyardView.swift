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
            Group {
                if deadPets.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ForEach(deadPets) { pet in
                                tombstone(for: pet)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Graveyard")
            .background(.clear)
            .toolbarBackground(.clear, for: .navigationBar)
        }
        .background(.clear)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("🌿")
                .font(.system(size: 64))
            Text("No koalas here yet")
                .font(.title3.bold())
            Text("Keep walking to keep your koala alive!")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private func tombstone(for pet: GraveyardPet) -> some View {
        VStack(spacing: 12) {
            KoalaView(color: pet.color, bodyScale: 0.5, isAlive: false)
                .scaleEffect(0.55)
                .frame(height: 90)

            Text("R.I.P.")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)

            Text(pet.name)
                .font(.headline)
                .lineLimit(1)

            Text("\(pet.daysLived) day\(pet.daysLived == 1 ? "" : "s") lived")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(dateFormatter.string(from: pet.deathDate))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.primary.opacity(0.08), lineWidth: 1)
        )
    }
}
