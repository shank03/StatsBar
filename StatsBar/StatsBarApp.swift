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

    //    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true
    //    @Environment(\.dismissWindow) private var dismissWindow

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
        popOver.animates = true
        popOver.behavior = .transient

        popOver.contentViewController = NSViewController()
        popOver.contentViewController?.view = NSHostingView(rootView: MenuView(delegate: self))
        popOver.contentViewController?.view.window?.makeKey()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let menuButton = statusItem?.button {
            menuButton.action = #selector(menuButtonAction(sender:))
            menuButton.target = self

            let iconView = NSHostingView(rootView: PopupText())
            iconView.frame = NSRect(x: 0, y: 0, width: 72, height: 24)

            menuButton.addSubview(iconView)
            menuButton.frame = iconView.frame
        }
    }

    @objc func menuButtonAction(sender: AnyObject) {
        if popOver.isShown {
            popOver.performClose(sender)
        } else {
            if let menuButton = statusItem?.button {
                popOver.show(relativeTo: menuButton.bounds, of: menuButton, preferredEdge: .minY)
            }
        }
    }
}
