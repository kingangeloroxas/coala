import SwiftUI
import MapKit
import Contacts

/// Address autocomplete with MapKit that resolves to full address + CITY.
/// - `text`: what the user types/sees
/// - `resolvedAddress`: full formatted address (optional usage)
/// - `resolvedCity`: the city (locality) extracted from the selected place
struct LocationSearchField: View {
    @Binding var text: String
    @Binding var resolvedAddress: String
    @Binding var resolvedCity: String

    @StateObject private var vm = ViewModel()

    var placeholder: String = "Type your address"

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .onChange(of: text) { oldValue, newValue in    // ✅ iOS 17+ signature
                    resolvedAddress = ""
                    resolvedCity = ""
                    vm.query = newValue
                }
                .padding(14)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )

            if !vm.suggestions.isEmpty && resolvedCity.isEmpty {
                VStack(spacing: 0) {
                    ForEach(vm.suggestions, id: \.self) { s in
                        Button { select(s) } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(s.title).foregroundColor(.primary)
                                if !s.subtitle.isEmpty {
                                    Text(s.subtitle)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                        }
                        .buttonStyle(.plain)

                        if s != vm.suggestions.last { Divider() }
                    }
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 6)
            }
        }
        .onDisappear { vm.suggestions = [] }
    }

    private func select(_ completion: MKLocalSearchCompletion) {
        // Populate text immediately
        text = [completion.title, completion.subtitle].filter { !$0.isEmpty }.joined(separator: ", ")

        // Resolve to placemark -> full address + city
        let request = MKLocalSearch.Request(completion: completion)
        MKLocalSearch(request: request).start { response, error in
            guard error == nil, let item = response?.mapItems.first else { return }

            if let postal = item.placemark.postalAddress {
                let formatted = CNPostalAddressFormatter.string(from: postal, style: .mailingAddress)
                    .replacingOccurrences(of: "\n", with: ", ")
                resolvedAddress = formatted
                resolvedCity = postal.city
            } else {
                let p = item.placemark
                let parts = [p.name,
                             p.subThoroughfare,
                             p.thoroughfare,
                             p.locality,
                             p.administrativeArea,
                             p.postalCode,
                             p.country].compactMap { $0 }
                resolvedAddress = parts.joined(separator: ", ")
                resolvedCity = p.locality ?? ""
            }

            vm.suggestions.removeAll()
        }
    }

    // MARK: - ViewModel

    final class ViewModel: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
        @Published var suggestions: [MKLocalSearchCompletion] = []
        @Published var query: String = "" {
            didSet { completer.queryFragment = query }
        }

        private let completer: MKLocalSearchCompleter

        override init() {
            let c = MKLocalSearchCompleter()
            c.resultTypes = [.address, .pointOfInterest] // or [.address] if you want only addresses
            self.completer = c
            super.init()
            self.completer.delegate = self
        }

        func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
            suggestions = Array(completer.results.prefix(8))
        }

        func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
            suggestions.removeAll()
        }
    }
}

