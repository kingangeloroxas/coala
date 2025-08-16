import SwiftUI

struct AppTopBar: View {
    var title: String
    var onBack: (() -> Void)? = nil

    var body: some View {
        HStack {
            if let onBack = onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .padding(8)
                }
            }
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .center)
            if onBack != nil {
                Color.clear.frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
}

