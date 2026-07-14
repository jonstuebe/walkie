import SwiftUI
import SwiftData

struct SettingsView: View {
    @AppStorage("stepGoal") private var stepGoal: Int = 10_000
    @Query private var pets: [Pet]
#if DEBUG
    @Environment(\.modelContext) private var modelContext
    @Query private var graveyardPets: [GraveyardPet]
#endif

    var body: some View {
        NavigationStack {
            Form {
                if let pet = pets.first {
                    Section("Your Koala") {
                        HStack {
                            Text("Name")
                            Spacer()
                            TextField("Koala name", text: Binding(
                                get: { pet.name },
                                set: { pet.name = $0 }
                            ))
                            .multilineTextAlignment(.trailing)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Color")
                            ScrollViewReader { proxy in
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 0) {
                                        ForEach(PetColor.allCases) { petColor in
                                            ColorSwatch(
                                                petColor: petColor,
                                                isSelected: pet.colorHex == petColor.hex
                                            ) {
                                                pet.colorHex = petColor.hex
                                                AppIconManager.sync(toColorHex: petColor.hex)
                                            }
                                            .id(petColor.hex)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                                .onAppear {
                                    DispatchQueue.main.async {
                                        proxy.scrollTo(pet.colorHex, anchor: .center)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Daily Step Goal") {
                    Picker("Goal", selection: $stepGoal) {
                        Text("7K").tag(7_000)
                        Text("10K").tag(10_000)
                        Text("13K").tag(13_000)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    WakeSleepRows()
                } header: {
                    Text("Daily Schedule")
                } footer: {
                    Text("Heart loss is spread evenly across your waking hours.")
                }

#if DEBUG
                Section {
                    Button("Seed Graveyard (5 pets)") { seedGraveyard() }
                    Button("Clear Graveyard", role: .destructive) { clearGraveyard() }
                        .disabled(graveyardPets.isEmpty)
                } header: {
                    Text("Developer")
                } footer: {
                    Text("\(graveyardPets.count) pet(s) in the graveyard. DEBUG builds only.")
                }
#endif
            }
            .navigationTitle("Settings")
            .scrollContentBackground(.hidden)
            .toolbarBackground(.clear, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .background(.clear)
    }

#if DEBUG
    private func seedGraveyard() {
        let cal = Calendar.current
        let now = Date()
        // name, color, daysLived, totalSteps, daysAgoDied
        let samples: [(String, PetColor, Int, Int, Int)] = [
            ("Eucalyptus", .gray,     42, 387_204, 1),
            ("Mochi",      .brown,    17, 142_880, 3),
            ("Waffles",    .mint,      8,  61_150, 9),
            ("Biscuit",    .lavender, 63, 512_990, 21),
            ("Pip",        .peach,     3,  19_400, 60),
        ]
        for (name, petColor, daysLived, steps, diedDaysAgo) in samples {
            let deathDate = cal.date(byAdding: .day, value: -diedDaysAgo, to: now) ?? now
            let birthDate = cal.date(byAdding: .day, value: -daysLived, to: deathDate) ?? deathDate
            modelContext.insert(GraveyardPet(
                name: name,
                colorHex: petColor.hex,
                birthDate: birthDate,
                deathDate: deathDate,
                totalStepsLifetime: steps,
                daysLived: daysLived
            ))
        }
        try? modelContext.save()
    }

    private func clearGraveyard() {
        for pet in graveyardPets {
            modelContext.delete(pet)
        }
        try? modelContext.save()
    }
#endif
}

private struct ColorSwatch: View {
    var petColor: PetColor
    var isSelected: Bool
    var onTap: () -> Void

    var body: some View {
        ZStack {
            Circle()
                .fill(petColor.color)
                .frame(width: 48, height: 48)
            if isSelected {
                Circle()
                    .stroke(Color.primary, lineWidth: 3)
                    .frame(width: 58, height: 58)
            }
        }
        .frame(width: 64, height: 64)
        .contentShape(Circle())
        .onTapGesture(perform: onTap)
    }
}
