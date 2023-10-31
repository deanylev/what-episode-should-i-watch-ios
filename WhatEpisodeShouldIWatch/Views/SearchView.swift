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
    let defaults = UserDefaults.standard
    @State private var search = ""
    @FocusState private var searchFocused
    @State private var searchInFlight = false
    @State private var seenEpisodes: [String: [SeenEpisode]] = [:]
    @State private var shows: [Show]

    @State var spoilerAvoidanceMode: Bool
    var spoilerAvoidanceModeInternal: Binding<Bool> { Binding(
        get: {
                return spoilerAvoidanceMode
            },
        set: {
                spoilerAvoidanceMode = $0
                defaults.setValue($0, forKey: "spoilerAvoidanceMode")
            }
        )
    }

    init(shows: [Show] = []) {
        self.shows = shows
        self.spoilerAvoidanceMode = defaults.bool(forKey: "spoilerAvoidanceMode")
        UILabel.appearance(whenContainedInInstancesOf: [UINavigationBar.self]).adjustsFontSizeToFitWidth = true
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Colour.BACKGROUND.ignoresSafeArea()
                VStack {
                    Form {
                        Toggle("Spoiler Avoidance Mode™", isOn: $spoilerAvoidanceMode)
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
                                            debounceTimer = nil
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
                    .frame(height: 130)
                    .padding(2)

                    if searchInFlight {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .padding(.vertical)
                    } else if !search.isEmpty {
                        if shows.count == 0 {
                            if debounceTimer == nil {
                                Text("No Results")
                                    .padding(.vertical)
                            }
                        } else {
                            List {
                                ForEach(shows) { show in
                                    NavigationLink(destination: DetailView(
                                        seenEpisodes: $seenEpisodes,
                                        show: show,
                                        spoilerAvoidanceMode: $spoilerAvoidanceMode)
                                    ) {
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
                    }

                    Spacer()
                }
            }
        }
    }
}

#Preview {
    return SearchView(shows: sampleShows)
}
