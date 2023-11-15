//
//  DetailView.swift
//  WhatEpisodeShouldIWatch
//
//  Created by Dean Levinson on 30/10/2023.
//

import SwiftUI

struct DetailView: View {
    private let defaults = UserDefaults.standard

    @State private var episode: Episode?
    @State private var episodeHistory: [Episode] = []
    @State private var episodeHistoryIndex = -1
    @State private var isError = false
    @State private var isPresentRatingWebView = false
    @State private var seasonMax = -1
    @State private var seasonMin = 1

    @Binding var seenEpisodes: [String: [SeenEpisode]]
    let show: Show
    @Binding var spoilerAvoidanceMode: Bool

    @MainActor
    private func fetchEpisode(initial: Bool) {
        episode = nil
        Task {
            do {
                if seenEpisodes[show.id] == nil {
                    seenEpisodes[show.id] = []
                }

                if initial {
                    episode = try await APIWrapper.fetchEpisode(
                        id: show.id,
                        seenEpisodes: seenEpisodes[show.id]!
                    ).episode
                    if seasonMax == -1 {
                        seasonMax = episode!.totalSeasons
                    }
                } else {
                    episode = try await APIWrapper.fetchEpisode(
                        id: show.id,
                        seenEpisodes: seenEpisodes[show.id]!,
                        seasonMin: seasonMin,
                        seasonMax: seasonMax
                    ).episode
                }
                episodeHistory.append(episode!)
                episodeHistoryIndex = episodeHistory.count - 1

                let seen = seenEpisodes[show.id]?.contains(where: { seenEpisode in
                    seenEpisode.season == episode!.season && seenEpisode.episode == episode!.episode
                })
                // we have seen this episode before which means we have exhausted the whole series!
                // clear this current season from the seen list
                if seen! {
                    seenEpisodes[show.id] = seenEpisodes[show.id]!.filter { seenEpisode in
                        seenEpisode.season != episode!.season
                    }
                }

                seenEpisodes[show.id]!.append(SeenEpisode(
                    season: episode!.season,
                    episode: episode!.episode
                ))
            } catch {
                isError = true
                print(error)
            }
        }
    }

     private func persistSeasonRange(seasonMin: Int, seasonMax: Int) {
        defaults.set(["seasonMin": seasonMin, "seasonMax": seasonMax], forKey: "range-\(show.id)")
    }

    var body: some View {
        ZStack {
            Color(UIColor(named: "MainColor")!).ignoresSafeArea()
            VStack(alignment: .leading) {
                if isError {
                    Text("Something Went Wrong")
                        .padding()
                } else if episode == nil {
                    ProgressView()
                        .progressViewStyle(.circular)
                } else {
                    ScrollView {
                        VStack(alignment: .leading) {
                            HStack {
                                Picker("", selection: $seasonMin) {
                                    ForEach(1...seasonMax, id: \.self) { season in
                                        Text("Season \(season)").tag(season)
                                    }
                                }
                                .onChange(of: seasonMin) { newValue in persistSeasonRange(seasonMin: newValue, seasonMax: seasonMax) }
                                Text("To")
                                Picker("", selection: $seasonMax) {
                                    ForEach(seasonMin...episode!.totalSeasons, id: \.self) { season in
                                        Text("Season \(season)").tag(season)
                                    }
                                }
                                .onChange(of: seasonMax) { newValue in persistSeasonRange(seasonMin: seasonMin, seasonMax: newValue) }
                                Button(action: {
                                    fetchEpisode(initial: false)
                                }, label: {
                                    Text("Another!")
                                })
                                .foregroundColor(Color(red: 224 / 255, green: 161 / 255, blue: 2 / 255))
                            }
                            HStack {
                                Button(action: {
                                    episodeHistoryIndex -= 1
                                    episode = episodeHistory[episodeHistoryIndex]
                                }, label: {
                                    Text("👈 Previous")
                                })
                                .disabled(episodeHistoryIndex == 0)
                                Button(action: {
                                    episodeHistoryIndex += 1
                                    episode = episodeHistory[episodeHistoryIndex]
                                }, label: {
                                    Text("👉 Next")
                                })
                                .disabled(episodeHistoryIndex == episodeHistory.count - 1)
                            }
                            .padding(.vertical)
                            Toggle("Spoiler Avoidance Mode™", isOn: $spoilerAvoidanceMode)
                                .padding([.trailing], 2)
                            Text("Season \(episode!.season), Episode \(episode!.episode)")
                                .bold()
                                .font(.title)
                            if !spoilerAvoidanceMode {
                                Text("\"\(episode!.title)\" (\(episode!.year))")
                            }
                            HStack {
                                Text("TMDB Rating:")
                                Button(action: {
                                    isPresentRatingWebView = true
                                }, label: {
                                    Text(episode!.rating)
                                        .underline()
                                        .foregroundColor(Color.primary)
                                })
                                .sheet(isPresented: $isPresentRatingWebView, content: {
                                    NavigationStack {
                                        // swiftlint:disable line_length
                                        WebView(url: URL(string: "https://www.themoviedb.org/tv/\(show.id)/season/\(episode!.season)/episode/\(episode!.episode)")!)
                                        // swiftlint:enable line_length
                                            .ignoresSafeArea()
                                            .navigationTitle("View TMDB")
                                            .navigationBarTitleDisplayMode(.inline)
                                    }
                                })
                            }
                            .bold()
                            .padding(3)
                            if !spoilerAvoidanceMode {
                                Text(episode!.plot)
                                    .padding(3)
                            }
                            if !spoilerAvoidanceMode {
                                HStack {
                                    Spacer()
                                    if let posterUrl = episode!.posterUrl {
                                        AsyncImage(url: URL(string: posterUrl)) { phase in
                                            switch phase {
                                            case .empty:
                                                ProgressView()
                                                    .progressViewStyle(.circular)
                                                    .frame(alignment: .center)
                                            case .success(let image):
                                                image
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fit)
                                                    .scaledToFit()
                                                    .cornerRadius(5)
                                            case .failure:
                                                EmptyView()
                                            @unknown default:
                                                EmptyView()
                                            }
                                        }
                                        .padding(.vertical)
                                        Spacer()
                                    }
                                }
                            }
                        }
                    }
                    .refreshable {
                        fetchEpisode(initial: false)
                    }
                }
                Spacer()
            }
            .padding()
            .navigationTitle("\(show.title) (\(show.yearStart))")
        }
        .onAppear {
            if let seasonRange = defaults.dictionary(forKey: "range-\(show.id)") as? [String: Int] {
                seasonMin = seasonRange["seasonMin"]!
                seasonMax = seasonRange["seasonMax"]!
                fetchEpisode(initial: false)
            } else {
                fetchEpisode(initial: true)
            }
        }
    }
}

#Preview {
    DetailView(seenEpisodes: .constant([:]), show: sampleShows[0], spoilerAvoidanceMode: .constant(false))
}
