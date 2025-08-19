import SwiftUI

struct ContentView: View {
  @StateObject private var viewModel = HackerNewsViewModel()
  @StateObject private var searchViewModel = SearchViewModel()
  @State private var selectedStory: Story?
  @State private var searchText = ""

  var body: some View {
    NavigationSplitView {
      StoriesListView(
        viewModel: viewModel,
        searchViewModel: searchViewModel,
        selectedStory: $selectedStory
      )
      .navigationTitle("Hacker News")
    } detail: {
      if let story = selectedStory {
        StoryDetailView(story: story, searchViewModel: searchViewModel)
              .navigationTitle(story.title)
      } else {
        Text("Select a story to read")
          .foregroundStyle(.secondary)
          .accessibilityLabel("No story selected. Choose a story from the list to read.")
          .navigationTitle("Select Story")
      }
    }
    .navigationSplitViewStyle(.automatic)
    .searchable(text: $searchText, prompt: "Search")
    .toolbar {
      ToolbarItemGroup(placement: .navigation) {
        HStack {
          Button(action: {
            viewModel.toggleLiveUpdates()
          }) {
              HStack(alignment: .center) {
              Image(
                systemName: viewModel.isLiveUpdatesEnabled
                  ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash"
              ).frame(width: 20)
              .foregroundColor(viewModel.isLiveUpdatesEnabled ? .green : .secondary)
              Text(viewModel.isLiveUpdatesEnabled ? "Live  " : "Static")
                .font(.caption)
                .fontWeight(.medium)
                .frame(width: 35)
            }.frame(width: 55)
          }
          .buttonStyle(.plain)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(
            viewModel.isLiveUpdatesEnabled ? Color.green.opacity(0.1) : Color.secondary.opacity(0.1)
          )
          .cornerRadius(6)
          .accessibilityLabel(
            viewModel.isLiveUpdatesEnabled ? "Live updates enabled" : "Live updates disabled"
          )
          .accessibilityHint("Click to toggle live updates for stories")
        }
      }
    }
    .task {
      viewModel.loadTopStories()
    }
    .onChange(of: searchText) { _, newText in
      searchViewModel.updateSearchQuery(newText, stories: viewModel.stories)
    }
    .onChange(of: selectedStory) { _, newStory in
      if let story = newStory {
        viewModel.markStoryAsRead(story)
      }
    }.onAppear {
        // See description of preWarmHTMLEngine to see what the hell is this
        HTMLTextView.preWarmHTMLEngine()
    }
  }
}

#Preview {
  ContentView()
}
