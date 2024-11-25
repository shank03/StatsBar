//
//  MenuView.swift
//  StatsBar
//
//  Created by Shashank on 25/11/24.
//

import SwiftUI

struct MenuView: View {

    @State private var isRunning: Bool = false
    @State private var metrics: Metrics?
    @State var delegate: AppDelegate

    var body: some View {
        VStack {
            Button(action: {
                if isRunning {
                    isRunning = false
                    return
                }

                isRunning = true
                DispatchQueue.global(qos: .background).async {
                    Task {
                        do {
                            let sampler = try Sampler()
                            while await isRunning {
                                try await Task.sleep(nanoseconds: 500 * NSEC_PER_MSEC)
                                let metrics = try await sampler.getMetrics(duration: 500)
                                DispatchQueue.main.async {
                                    self.metrics = metrics

                                    if let menuButton = self.delegate.statusItem?.button {
                                        let iconView = NSHostingView(rootView: PopupText(metrics: self.metrics))
                                        iconView.frame = NSRect(x: 0, y: 0, width: 196, height: 22)

                                        menuButton.subviews[0] = iconView
                                        menuButton.frame = iconView.frame
                                    }
                                }
                            }
                        } catch {
                            print(error)
                        }
                    }
                }
            }) {
                Label(self.isRunning ? "Stop" : "Sample", systemImage: self.isRunning ? "stop" : "play")
            }

            if let metrics = self.metrics {
                Button {

                } label: {
                    HStack {
                        Text("E-CPU")
                        Text("\(metrics.eCpuUsage.0) MHz")
                    }
                }

            }
        }
        .frame(width: 320, height: 450)
    }
}

//#Preview {
//    MenuView()
//}
