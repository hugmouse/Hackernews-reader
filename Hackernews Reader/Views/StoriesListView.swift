import SwiftUI

struct StoriesListView: View {
    @ObservedObject var viewModel: HackerNewsViewModel
    @ObservedObject var searchViewModel: SearchViewModel
    @Binding var selectedStory: Story?
    @State private var selectedCategory: StoryCategory = .top
    @State private var selectedSearchResult: SearchResult?
    
    var body: some View {
        VStack(spacing: 0) {
            if !searchViewModel.isSearching {
                Picker("Category", selection: $selectedCategory) {
                    ForEach(StoryCategory.allCases, id: \.self) { category in
                        Text(category.displayName)
                            .tag(category)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding([.leading], 8)
                .padding([.trailing], 4)
                .accessibilityLabel("Story category")
                .accessibilityHint("Select a category of stories to view")
                storiesSection
            }
            
            
            if searchViewModel.isSearching && !searchViewModel.searchResults.isEmpty {
                SearchResultsView(searchResults: searchViewModel.searchResults) { result in
                    selectedSearchResult = result
                    if let story = viewModel.stories.first(where: { $0.id == result.storyId }) {
                        selectedStory = story
                        // If this is a comment, highlight it
                        if result.type == .comment, let commentId = result.commentId {
                            searchViewModel.selectCommentFromSearch(commentId)
                        }
                    }
                }
            }
        }
        .frame(minWidth: 300.0)
        .navigationTitle(searchViewModel.isSearching ? "Search Results" : "Hacker News")
        .onChange(of: selectedCategory) { oldCategory, newCategory in
            Task {
                viewModel.loadStories(for: newCategory)
            }
        }
    }
    
    private var storiesSection: some View {
        List(
            searchViewModel.isSearching ? searchViewModel.filteredStories : viewModel.stories, id: \.id,
            selection: $selectedStory
        ) { story in
            StoryRowView(
                story: story,
                isRead: viewModel.isStoryRead(story),
                isReading: selectedStory?.id == story.id
            )
            .tag(story)
            .contextMenu(menuItems: {
                Button {
                    NSWorkspace.shared.open(URL(string:"https://news.ycombinator.com/item?id=\(story.id)")!)
                } label: {
                    Label("Open in Browser", systemImage: "safari")
                }
                Button {
                    let hnLink = "https://news.ycombinator.com/item?id=\(story.id)"
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(hnLink, forType: .string)
                } label: {
                    Label("Copy Hackernews Link", systemImage: "link")
                }
                if let url = story.url {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(url, forType: .string)
                    } label: {
                        Label("Copy External Link", systemImage: "arrow.up.right.square")
                    }
                }
            })
        }
        .contentMargins(.top, 0)
        .listStyle(.sidebar)
        .refreshable {
            viewModel.loadStories(for: selectedCategory)
        }
    }
    
}

#Preview {
    @Previewable @State var selectedStory: Story?
    let viewModel = HackerNewsViewModel()
    
    NavigationSplitView {
        StoriesListView(
            viewModel: viewModel, searchViewModel: SearchViewModel(), selectedStory: $selectedStory)
    } detail: {
        Text("Preview")
    }
}
