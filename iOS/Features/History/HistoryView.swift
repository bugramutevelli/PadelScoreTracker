import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: MatchStore

    var body: some View {
        Group {
            if store.matches.isEmpty {
                ContentUnavailableView("Henüz maç yok", systemImage: "figure.padel", description: Text("Tamamlanan maçların burada görünecek."))
            } else {
                List {
                    ForEach(store.matches) { match in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(match.home.displayName).lineLimit(1)
                                Spacer()
                                Text("\(match.homeSets)").font(.title3.bold())
                            }
                            HStack {
                                Text(match.away.displayName).lineLimit(1)
                                Spacer()
                                Text("\(match.awaySets)").font(.title3.bold())
                            }
                            HStack {
                                Text(match.startedAt.formatted(date: .abbreviated, time: .shortened))
                                Spacer()
                                Text("\(Int(match.duration) / 60) dk")
                            }.font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 6)
                    }.onDelete(perform: store.delete)
                }
            }
        }
        .navigationTitle("Maç Geçmişi")
    }
}
