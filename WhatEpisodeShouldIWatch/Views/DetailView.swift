//
//  DetailView.swift
//  WhatEpisodeShouldIWatch
//
//  Created by Dean Levinson on 30/10/2023.
//

import SwiftUI

import CachedAsyncImage

struct DetailView: View {
    @State var episode: Episode? = nil
    @State var episodeHistory: [Episode] = []
    @State var episodeHistoryIndex = -1
    @State var isPresentRatingWebView = false
    // TODO save in store and load
    @State var seasonMax = 1
    @State var seasonMin = 1
    let show: Show;
    
    func fetchEpisode(initial: Bool) {
        episode = nil
        Task {
            do {
                if (initial) {
                    episode = try await APIWrapper.fetchEpisode(id: show.id).episode
                    seasonMax = episode!.totalSeasons
                } else {
                    episode = try await APIWrapper.fetchEpisode(id: show.id, seasonMin: seasonMin, seasonMax: seasonMax).episode
                }
                episodeHistory.append(episode!)
                episodeHistoryIndex = episodeHistory.count - 1
            } catch {
                print(error)
            }
        }
    }
    
    var body: some View {
        ZStack {
            Color(red: 17 / 255, green: 24 / 255, blue: 39 / 255).ignoresSafeArea()
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
                        Text("To")
                        Picker("", selection: $seasonMax) {
                            ForEach(seasonMin...episode!.totalSeasons, id: \.self) { season in
                                Text("Season \(season)").tag(season)
                            }
                        }
                        Button(action: {
                            fetchEpisode(initial: false)
                        }) {
                            Text("Another!")
                        }
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
                        CachedAsyncImage(url: URL(string: episode!.posterUrl)) { phase in
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
            fetchEpisode(initial: true)
        }
    }
}

#Preview {
    DetailView(show: SampleShows[0])
}
