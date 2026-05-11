import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var petName = ""
    @State private var selectedColor: PetColor = .gray
    @State private var step: OnboardingStep = .welcome

    enum OnboardingStep { case welcome, customize, done }

    var body: some View {
        NavigationStack {
            switch step {
            case .welcome:
                WelcomeScreen(onContinue: { step = .customize })
            case .customize:
                CustomizeScreen(
                    petName: $petName,
                    selectedColor: $selectedColor,
                    onCreate: createPet
                )
            case .done:
                EmptyView()
            }
        }
    }

    private func createPet() {
        guard !petName.isEmpty else { return }
        let pet = Pet(name: petName, colorHex: selectedColor.hex)
        modelContext.insert(pet)
        AppIconManager.sync(toColorHex: pet.colorHex)
        step = .done
    }
}

private struct WelcomeScreen: View {
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            KoalaView(color: .gray, bodyScale: 1.0)
            VStack(spacing: 12) {
                Text("Meet Your Koala")
                    .font(.largeTitle.bold())
                Text("Keep your koala alive by hitting your daily step goals. Miss too many days and your koala will starve.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Spacer()
            Button(action: onContinue) {
                Text("Get Started")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .navigationBarHidden(true)
    }
}

private struct CustomizeScreen: View {
    @Binding var petName: String
    @Binding var selectedColor: PetColor
    var onCreate: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 32) {
                    KoalaView(color: selectedColor.color, bodyScale: 1.0)
                        .animation(.spring, value: selectedColor)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name your koala").font(.headline)
                        TextField("e.g. Koko", text: $petName)
                            .textFieldStyle(.roundedBorder)
                            .font(.title3)
                    }
                    .padding(.horizontal, 24)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Choose a color").font(.headline)
                            .padding(.horizontal, 24)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 0) {
                                ForEach(PetColor.allCases) { petColor in
                                    ColorSwatch(petColor: petColor, isSelected: selectedColor == petColor) {
                                        selectedColor = petColor
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.vertical, 24)
            }
            .scrollDismissesKeyboard(.interactively)

            VStack {
                Button(action: onCreate) {
                    Text("Adopt \(petName.isEmpty ? "Your Koala" : petName)")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(petName.isEmpty ? Color.gray : Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(petName.isEmpty)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
        }
        .navigationTitle("Customize")
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
