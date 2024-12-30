import SwiftUI

@main
struct PersistApp: App {
    class AppDelegate: NSObject, NSApplicationDelegate {
        func applicationWillTerminate(_ notification: Notification) {
            if let url = URL(string: "http://127.0.0.1:2789/shutdown") {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"

                let task = URLSession.shared.dataTask(with: request)
                task.resume()

                Thread.sleep(forTimeInterval: 0.1)
            }
        }
    }

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            CardView()
        }
    }
}
