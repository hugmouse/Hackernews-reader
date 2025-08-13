import SwiftUI

struct UserView: View {
  let username: String
  @StateObject private var viewModel = UserViewModel()

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        if viewModel.isLoading {
          ProgressView("Loading user profile...")
            .frame(maxWidth: .infinity)
            .padding()
        } else if let errorMessage = viewModel.errorMessage {
          VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
              .font(.system(size: 48))
              .foregroundStyle(.secondary)

            Text("User Not Found")
              .font(.headline)

            Text(errorMessage)
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity)
          .padding()
        } else if let user = viewModel.user {
          VStack(alignment: .leading, spacing: 20) {
            // User Header
            HStack {
              Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

              VStack(alignment: .leading, spacing: 4) {
                Text(user.id)
                  .font(.title)
                  .fontWeight(.bold)

                Text("Member since \(formattedDate(user.created))")
                  .font(.subheadline)
                  .foregroundStyle(.secondary)
              }

              Spacer()
            }

            // Stats
            HStack(spacing: 40) {
              VStack(alignment: .leading) {
                Text("\(user.karma)")
                  .font(.title2)
                  .fontWeight(.bold)
                  .foregroundStyle(.primary)
                Text("Karma")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }

              if let submitted = user.submitted {
                VStack(alignment: .leading) {
                  Text("\(submitted.count)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                  Text("Submissions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
              }
            }

            Divider()

            // About Section
            if let about = user.about, !about.isEmpty {
              VStack(alignment: .leading, spacing: 8) {
                Text("About")
                  .font(.headline)

                HTMLTextView(html: about)
              }
            } else {
              Text("No bio available")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .italic()
            }

            Divider()

            HStack {
              Link(
                "View on HN",
                destination: URL(string: "https://news.ycombinator.com/user?id=\(user.id)")!
              )
              .buttonStyle(.borderedProminent)
              .tint(.orange)
            }
          }
        }
      }
      .padding()
    }
    .frame(minWidth: 300, minHeight: 300)
    .navigationTitle("User Profile")
    .task(id: username) {
      viewModel.loadUser(username: username)
    }
  }

  private func formattedDate(_ timestamp: Int) -> String {
    let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
    let formatter = DateFormatter()
    formatter.dateStyle = .long
    return formatter.string(from: date)
  }
}

#Preview {
  NavigationStack {
    UserView(username: "jl")
  }
}
