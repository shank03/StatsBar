//
//  StatsBarApp.swift
//  StatsBar
//
//  Created by Shashank on 11/11/24.
//

import SwiftUI

@main
struct StatsBarApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        Settings {}
    }
}

class AppDelegate: NSObject, ObservableObject, NSApplicationDelegate {

    @Published var statusItem: NSStatusItem?
    @Published var popOver = NSPopover()

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let window = NSApplication.shared.windows.first {
            window.close()
        }

        setupMenu()
    }

    func setupMenu() {
        let contentView = NSHostingView(rootView: MenuView(updateMenu: { metrics in
            if let menuButton = self.statusItem?.button {
                menuButton.subviews.removeAll()
                let iconView = NSHostingView(rootView: PopupText(metrics: metrics))
                iconView.frame = NSRect(x: 0, y: 0, width: POPUP_VIEW_HEIGHT * 10, height: POPUP_VIEW_HEIGHT)

                menuButton.addSubview(iconView)
                menuButton.frame = iconView.frame
            }
        }))
        contentView.frame = NSRect(x: 0, y: 0, width: 620, height: 620)

        let menuItem = NSMenuItem()
        menuItem.view = contentView

        let menu = NSMenu()
        menu.addItem(menuItem)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.menu = menu
        if let menuButton = statusItem?.button {
            menuButton.target = self

            let iconView = NSHostingView(rootView: PopupText())
            iconView.frame = NSRect(x: 0, y: 0, width: 72, height: 24)

            menuButton.addSubview(iconView)
            menuButton.frame = iconView.frame
        }
    }
}
