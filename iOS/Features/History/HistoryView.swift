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
                            if let health = match.workoutMetrics {
                                HStack(spacing: 12) {
                                    Label("\(Int(health.activeCalories)) kcal", systemImage: "flame.fill")
                                    Label("\(health.steps)", systemImage: "figure.walk")
                                    Label(String(format: "%.2f km", health.distanceMeters / 1000), systemImage: "location.fill")
                                }
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            }
                        }.padding(.vertical, 6)
                    }.onDelete(perform: store.delete)
                }
            }
        }
        .navigationTitle("Maç Geçmişi")
    }
}
