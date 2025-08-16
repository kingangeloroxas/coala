import SwiftUI

struct ActivitySelectionView: View {
    @EnvironmentObject var appState: AppState
    
    // MARK: Data
    private let regularActivities: [ActivityItem] = [
        .init(name: "Hiking",     emoji: "🥾", color: Color(hue: 220/360, saturation: 0.32, brightness: 0.98)),
        .init(name: "Bowling",    emoji: "🎳", color: Color(hue: 235/360, saturation: 0.32, brightness: 0.98)),
        .init(name: "Movie",      emoji: "🎬", color: Color(hue: 250/360, saturation: 0.32, brightness: 0.98)),
        .init(name: "Pickleball", emoji: "🎾", color: Color(hue: 270/360, saturation: 0.32, brightness: 0.98)),
        .init(name: "Karaoke",    emoji: "🎤", color: Color(hue: 285/360, saturation: 0.32, brightness: 0.98)),
        .init(name: "Coffee",     emoji: "☕️", color: Color(hue: 300/360, saturation: 0.32, brightness: 0.98)),
        .init(name: "Golf",       emoji: "⛳️", color: Color(hue: 315/360, saturation: 0.32, brightness: 0.98)),
        .init(name: "Museum",     emoji: "🖼️", color: Color(hue: 330/360, saturation: 0.32, brightness: 0.98)),
        .init(name: "Yoga",       emoji: "🧘", color: Color(hue: 210/360, saturation: 0.32, brightness: 0.98)),
        .init(name: "Boba",       emoji: "🧋", color: Color(hue: 40/360, saturation: 0.32, brightness: 0.98))
    ]
    
    private let premiumActivities: [ActivityItem] = [
        .init(name: "Brunch",      emoji: "🥞", color: Color(hue: 240/360, saturation: 0.35, brightness: 0.98)),
        .init(name: "Surfing",     emoji: "🏄‍♂️", color: Color(hue: 190/360, saturation: 0.35, brightness: 0.98)),
        .init(name: "Pumpkin Patch",emoji: "🎃", color: Color(hue: 30/360,  saturation: 0.35, brightness: 0.98)),
        .init(name: "Theme Park",  emoji: "🎢", color: Color(hue: 15/360,  saturation: 0.35, brightness: 0.98))
    ]
    
    // Selection
    @State private var tempSelectedActivity: String? = nil
    private var effectiveSelection: String? { tempSelectedActivity ?? appState.selectedActivity }
    private var canContinue: Bool { effectiveSelection != nil }
    
    // Animation state
    @State private var animateScale: UUID? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(title: "pick an activity", onBack: { appState.goBack() })
            
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Regular Activities
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
                        ForEach(regularActivities) { item in
                            activityButton(for: item)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Separator
                    VStack(spacing: 4) {
                        Divider()
                        Text("Premium Activities")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Divider()
                    }
                    .padding(.horizontal)
                    
                    // Premium Activities
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
                        ForEach(premiumActivities) { item in
                            activityButton(for: item)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 16)
                .padding(.bottom, 80)
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button {
                    guard let choice = effectiveSelection else { return }
                    appState.selectedActivity = choice
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    appState.goTo(.groupSize)
                } label: {
                    Text("Continue").frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canContinue)
                .opacity(canContinue ? 1 : 0.4)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .background(.ultraThinMaterial)
        }
        .onAppear { tempSelectedActivity = appState.selectedActivity }
        .navigationBarBackButtonHidden(true)
    }
    
    // MARK: - Button Builder
    
    private func activityButton(for item: ActivityItem) -> some View {
        ActivityBubble(
            item: item,
            isSelected: effectiveSelection == item.name,
            size: CGSize(width: 160, height: 64),
            scale: animateScale == item.id ? 1.15 : 1.0
        ) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                tempSelectedActivity = (effectiveSelection == item.name) ? nil : item.name
                animateScale = item.id
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                    animateScale = nil
                }
            }
        }
    }
}

// MARK: - Bubble

private struct ActivityBubble: View {
    let item: ActivityItem
    let isSelected: Bool
    let size: CGSize
    let scale: CGFloat
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(item.emoji).font(.system(size: 24))
                Text(item.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(width: size.width, height: size.height)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(item.color)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(Color.primary.opacity(isSelected ? 0.5 : 0), lineWidth: 3)
                    )
            )
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 6)
            .scaleEffect(scale)
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: scale)
    }
}

private struct ActivityItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let emoji: String
    let color: Color
}

