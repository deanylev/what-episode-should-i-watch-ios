//
//  ContentView.swift
//  WhatEpisodeShouldIWatch
//
//  Created by Dean Levinson on 29/10/2023.
//

import SwiftUI

import CachedAsyncImage

struct SeenEpisode {
    let season: Int
    let episode: Int
}

struct SearchView: View {
    @State private var debounceTimer: Timer?
    @State private var search = ""
    @FocusState private var searchFocused
    @State private var searchInFlight = false
    @State private var seenEpisodes: Dictionary<String, [SeenEpisode]> = [:]
    @State private var shows: [Show]

    init(shows: [Show] = []) {
        self.shows = shows
        UILabel.appearance(whenContainedInInstancesOf: [UINavigationBar.self]).adjustsFontSizeToFitWidth = true
    }
        
    var body: some View {
        NavigationStack {
            ZStack {
                Colour.BACKGROUND.ignoresSafeArea()
                VStack {
                    Form {
                        TextField("Search for a TV show...", text: $search)
                            .focused($searchFocused)
                            .onAppear {
                                searchFocused = true
                            }
                            .onChange(of: search) {
                                debounceTimer?.invalidate()
                                debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                                    Task {
                                        do {
                                            searchInFlight = true
                                            shows = try await APIWrapper.fetchShows(search: search)
                                        } catch {
                                            print(error)
                                        }
                                        searchInFlight = false
                                    }
                                }
                            }
                    }
                    .scrollContentBackground(.hidden)
                    .navigationTitle("What Episode Should I Watch?")
                    .frame(height: 80)
                    .padding(2)
                    
                    if searchInFlight {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        List {
                            ForEach(shows) { show in
                                NavigationLink(destination: DetailView(seenEpisodes: $seenEpisodes, show: show)) {
                                    HStack {
                                        if let posterUrl = show.posterUrl {
                                            CachedAsyncImage(url: URL(string: posterUrl)) { phase in
                                                switch phase {
                                                case .empty:
                                                    ProgressView()
                                                        .progressViewStyle(.circular)
                                                        .frame(width: 70, height: 105)
                                                case .success(let image):
                                                    image
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fit)
                                                        .frame(width: 70, height: 105)
                                                        .cornerRadius(5)
                                                case .failure:
                                                    Image(systemName: "photo")
                                                        .aspectRatio(contentMode: .fit)
                                                        .frame(width: 70, height: 105)
                                                @unknown default:
                                                    EmptyView()
                                                }
                                            }
                                        } else {
                                            Image(systemName: "photo")
                                                .aspectRatio(contentMode: .fit)
                                                .frame(width: 70, height: 105)
                                        }
                                        Text("\(show.title) (\(show.yearStart))")
                                            .padding(.horizontal)
                                    }
                                }
                            }
                        }
                        .scrollContentBackground(.hidden)
                    }
                    
                    Spacer()
                }
            }
        }
    }
}

#Preview {
    return SearchView(shows: SampleShows)
}
