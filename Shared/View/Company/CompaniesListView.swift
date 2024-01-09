import SwiftUI

struct CompaniesListView: View {
    let companies: [ProductionCompany]
    var body: some View {
        Form {
            if companies.isEmpty {
                CenterHorizontalView { ProgressView().padding() }
            } else {
                Section {
                    List(companies, id: \.self) { item in
                        NavigationLink(value: item) {
                            Text(item.name)
                        }
                    }
                }
            }
        }
        .navigationTitle("companiesTitle")
#if os(macOS)
        .formStyle(.grouped)
#elseif os(iOS)
        .navigationBarTitleDisplayMode(.large)
#endif
    }
}
