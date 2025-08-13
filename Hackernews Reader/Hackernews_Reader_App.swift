import SwiftUI

@main
struct HackerNewsApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView()
    }
    .windowStyle(.titleBar)
    .windowToolbarStyle(.unified)

    WindowGroup("User Profile", id: "userProfile", for: String.self) { $username in
      if let username = username {
        UserView(username: username)
      } else {
        Text("Ain't Nobody Here but Us Chickens")
      }
    }
    .defaultSize(width: 300, height: 400)
    .windowResizability(.contentMinSize)
  }
}

#Preview {
  ContentView()
}
