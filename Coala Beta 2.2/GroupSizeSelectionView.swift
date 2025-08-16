import SwiftUI

struct GroupSizeSelectionView: View {
    @EnvironmentObject var appState: AppState

    private let sizes = [4, 6, 8]

    // Selection
    @State private var tempSize: Int? = nil
    private var effectiveSize: Int? { tempSize ?? appState.selectedGroupSize }
    private var canContinue: Bool { effectiveSize != nil }

    // Bounce effect (which button is temporarily expanding)
    @State private var bouncingID: Int? = nil

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(title: "group size", onBack: { appState.goBack() })

            Spacer(minLength: 40)

            VStack(spacing: 24) {
                ForEach(sizes, id: \.self) { size in
                    Button {
                        // selection toggle
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                            tempSize = (tempSize == size) ? nil : size
                        }

                        // haptic
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()

                        // bounce (expand then return)
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.75)) {
                            bouncingID = size
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                bouncingID = nil
                            }
                        }
                    } label: {
                        let isSelected = (tempSize == size)
                        let isBouncing = (bouncingID == size)

                        Text("\(size) people")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(isSelected
                                          ? pastelColor(for: size).opacity(0.9)
                                          : pastelColor(for: size).opacity(0.6))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(Color.white.opacity(isSelected ? 0.8 : 0), lineWidth: 3)
                            )
                            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                            .padding(.horizontal, 32)
                            // tactile scale (selected has a mild lift; bounce pushes it a bit more)
                            .scaleEffect(isBouncing ? 1.08 : (isSelected ? 1.03 : 1.0))
                            .animation(.spring(response: 0.28, dampingFraction: 0.85), value: isSelected)
                            .animation(.spring(response: 0.28, dampingFraction: 0.85), value: isBouncing)
                    }
                    .buttonStyle(.plain)
                    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }

            Spacer()

            Button {
                guard let size = effectiveSize else { return }
                appState.selectedGroupSize = size
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                appState.goTo(.matching)
            } label: {
                Text("Continue").frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!canContinue)
            .opacity(canContinue ? 1 : 0.4)
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .onAppear { tempSize = appState.selectedGroupSize }
        .navigationBarBackButtonHidden(true)
    }

    private func pastelColor(for size: Int) -> Color {
        switch size {
        case 4: return .pink
        case 6: return .purple
        case 8: return .blue
        default: return .gray
        }
    }
}

