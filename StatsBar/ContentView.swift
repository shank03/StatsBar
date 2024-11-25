//
//  ContentView.swift
//  StatsBar
//
//  Created by Shashank on 11/11/24.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(items) { item in
                    NavigationLink {
                        Text("Item at \(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))")
                    } label: {
                        Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            .toolbar {
                ToolbarItem {
                    HStack {
                        Button(action: addItem) {
                            Label("Add Item", systemImage: "plus")
                        }

                        Button(action: {
                            DispatchQueue.global(qos: .background).async {
                                Task {
                                    do {
                                        let sampler = try Sampler()
                                        while true {
                                            try await Task.sleep(nanoseconds: 500 * NSEC_PER_MSEC)
                                            let metrics = try await sampler.getMetrics()
                                            print(metrics)
                                        }
                                    } catch {
                                        print(error)
                                    }
                                }
                            }
                        }) {
                            Label("Sample", systemImage: "play")
                        }
                    }
                }
            }
        } detail: {
            Text("Select an item")
        }
    }

    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            modelContext.insert(newItem)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
