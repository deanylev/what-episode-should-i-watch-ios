//
//  DetailView.swift
//  WhatEpisodeShouldIWatch
//
//  Created by Dean Levinson on 30/10/2023.
//

import SwiftUI

let defaults = UserDefaults.standard

struct DetailView: View {
    @State var episode: Episode? = nil
    @State var episodeHistory: [Episode] = []
    @State var episodeHistoryIndex = -1
    @State var isPresentRatingWebView = false
    @Binding var seenEpisodes: Dictionary<String, [SeenEpisode]>
    @State var seasonMax = -1
    @State var seasonMin = 1
    let show: Show
    
    @MainActor
    func fetchEpisode(initial: Bool) {
        episode = nil
        Task {
            do {
                if seenEpisodes[show.id] == nil {
                    seenEpisodes[show.id] = []
                }
                
                if (initial) {
                    episode = try await APIWrapper.fetchEpisode(id: show.id, seenEpisodes: seenEpisodes[show.id]!).episode
                    if seasonMax == -1 {
                        seasonMax = episode!.totalSeasons
                    }
                } else {
                    episode = try await APIWrapper.fetchEpisode(id: show.id, seenEpisodes: seenEpisodes[show.id]!, seasonMin: seasonMin, seasonMax: seasonMax).episode
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
                print(error)
            }
        }
    }
    
    func persistSeasonRange() {
        defaults.set(["seasonMin": seasonMin, "seasonMax": seasonMax], forKey: "range-\(show.id)")
    }
    
    var body: some View {
        ZStack {
            Colour.BACKGROUND.ignoresSafeArea()
            VStack(alignment: .leading) {
                if episode == nil {
                    ProgressView()
                        .progressViewStyle(.circular)
                } else {
                    HStack {
                        Picker("", selection: $seasonMin) {
                            ForEach(1...seasonMax, id: \.self) { season in
                                Text("Season \(season)").tag(season)
                            }
                        }
                        .onChange(of: seasonMin) { persistSeasonRange() }
                        Text("To")
                        Picker("", selection: $seasonMax) {
                            ForEach(seasonMin...episode!.totalSeasons, id: \.self) { season in
                                Text("Season \(season)").tag(season)
                            }
                        }
                        .onChange(of: seasonMax) { persistSeasonRange() }
                        Button(action: {
                            fetchEpisode(initial: false)
                        }) {
                            Text("Another!")
                        }
                        .foregroundColor(Colour.ACCENT)
                    }
                    Text("Season \(episode!.season), Episode \(episode!.episode)")
                        .bold()
                        .font(.title)
                    Text("\"\(episode!.title)\" (\(episode!.year))")
                    HStack {
                        Button(action: {
                            episodeHistoryIndex -= 1
                            episode = episodeHistory[episodeHistoryIndex]
                        }) {
                            Text("👈 Previous Suggestion")
                        }
                        .disabled(episodeHistoryIndex == 0)
                        Button(action: {
                            episodeHistoryIndex += 1
                            episode = episodeHistory[episodeHistoryIndex]
                        }) {
                            Text("👉 Next Suggestion")
                        }
                        .disabled(episodeHistoryIndex == episodeHistory.count - 1)
                    }
                    .padding(.vertical)
                    HStack {
                        Text("TMDB Rating:")
                        Button(action: {
                            isPresentRatingWebView = true
                        }) {
                            Text(episode!.rating)
                                .underline()
                                .foregroundColor(Color.primary)
                        }
                        .sheet(isPresented: $isPresentRatingWebView, content: {
                            NavigationStack {
                                WebView(url: URL(string: "https://www.themoviedb.org/tv/\(show.id)/season/\(episode!.season)/episode/\(episode!.episode)")!)
                                    .ignoresSafeArea()
                                    .navigationTitle("View TMDB")
                                    .navigationBarTitleDisplayMode(.inline)
                            }
                        })
                    }
                    .bold()
                    .padding(3)
                    Text(episode!.plot)
                        .padding(3)
                    HStack {
                        Spacer()
                        AsyncImage(url: URL(string: episode!.posterUrl)) { phase in
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
                Spacer()
            }
            .padding()
            .navigationTitle(show.title)
        }
        .onAppear() {
            if let seasonRange = defaults.dictionary(forKey: "range-\(show.id)") as? Dictionary<String, Int> {
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
    DetailView(seenEpisodes: .constant([:]), show: SampleShows[0])
}
