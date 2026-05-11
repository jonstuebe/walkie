import SwiftUI
import SwiftData

struct SettingsView: View {
    @AppStorage("stepGoal") private var stepGoal: Int = 10_000
    @Query private var pets: [Pet]

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
            }
            .navigationTitle("Settings")
            .scrollContentBackground(.hidden)
            .toolbarBackground(.clear, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .background(.clear)
    }
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
