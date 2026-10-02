import SwiftUI

struct ChangelogView: View {
    @Binding var showChangelog: Bool
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                VStack {
                    ScrollView {
                        changelogItem(
                            title: "featureOneTitle",
                            description: "featureOneDescription",
                            image: "sparkles.tv",
                            color: .orange
                        ).padding(.vertical)
                        
                        changelogItem(
                            title: "featureTwoTitle",
                            description: "featureTwoDescription",
                            image: "film.stack",
                            color: .red
                        ).padding(.vertical)
                        
                        changelogItem(
                            title: "featureThreeTitle",
                            description: "featureThreeDescription",
                            image: "gearshape",
                            color: .blue
                        ).padding(.vertical)
                    }
                }
                .padding(.horizontal)
                Spacer()
                Button {
                    showChangelog = false
                } label: {
                    Text("Continue").frame(minWidth: 200)
                }
#if os(iOS) || os(macOS)
                .controlSize(.large)
#endif
                .buttonStyle(.borderedProminent)
                .tint(SettingsStore.shared.appTheme.color.gradient)
                .padding()
            }
            .navigationTitle("changelogViewTitle")

        }
    }
    
    private func changelogItem(title: String, description: String, image: String, color: Color) -> some View {
        HStack {
            Image(systemName: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40, alignment: .center)
                .foregroundColor(color)
            VStack(alignment: .leading) {
                Text(LocalizedStringKey(title))
                    .font(.title3)
                    .fontWeight(.semibold)
                Text(LocalizedStringKey(description))
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            .padding(.leading, 12)
            Spacer()
        }
        .padding(.horizontal)
    }
    

}

#Preview {
    ChangelogView(showChangelog: .constant(false))
}
