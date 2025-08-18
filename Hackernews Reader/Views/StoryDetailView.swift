import SwiftUI

struct StoryDetailView: View {
  let story: Story
  let searchViewModel: SearchViewModel?
  @StateObject private var viewModel = StoryDetailViewModel()

  init(story: Story, searchViewModel: SearchViewModel? = nil)
  {
    self.story = story
    self.searchViewModel = searchViewModel
  }

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          StoryHeaderView(story: story)

          if let text = story.text, !text.isEmpty {
            HTMLTextView(
              html: text,
              highlightQuery: searchViewModel?.isSearching == true
                ? (searchViewModel?.searchQuery ?? "") : "")
          }

          Divider()

          CommentsSectionHeader(count: story.descendants ?? 0)

          if viewModel.isLoading {
            CommentsLoadingView()
          } else {
            CommentsListView(
              comments: viewModel.comments,
              highlightedCommentId: searchViewModel?.highlightedCommentId,
              searchQuery: searchViewModel?.isSearching == true
                ? (searchViewModel?.searchQuery ?? "") : ""
            )
          }
        }
        .padding()
      }
      .onChange(of: searchViewModel?.highlightedCommentId) { _, commentId in
        if let commentId = commentId {
          scrollToCommentWhenReady(proxy: proxy, commentId: commentId)
        }
      }
      .onChange(of: viewModel.isLoading) { _, isLoading in
        if !isLoading, let commentId = searchViewModel?.highlightedCommentId {
          scrollToCommentWhenReady(proxy: proxy, commentId: commentId)
        }
      }
      .onChange(of: searchViewModel?.isSearching) { _, _ in
        // Force view update
      }
    }
    .task(id: story.id) {
      if story.kids != nil, !story.kids!.isEmpty {
        viewModel.loadComments(for: story)
      }
      searchViewModel?.registerCommentsForSearch(story: story, comments: viewModel.comments)
    }
    .onChange(of: viewModel.comments) { _, newComments in
      searchViewModel?.registerCommentsForSearch(story: story, comments: newComments)
    }
    .onDisappear {
      viewModel.cleanup()
    }
  }

  private func scrollToCommentWhenReady(proxy: ScrollViewProxy, commentId: Int) {
    if !viewModel.isLoading {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        withAnimation(.easeInOut(duration: 0.5)) {
          proxy.scrollTo("comment_\(commentId)", anchor: .center)
        }
      }
    }
  }
}

#Preview {
  let sampleStory = Story(
    id: 1,
    title: "Sample Story with Long Title That Demonstrates How Text Wraps",
    by: "sample_user",
    time: Int(Date().timeIntervalSince1970) - 7200,
    score: 125,
    descendants: 42,
    url: "https://example.com/article",
    text:
      "<p>This is a sample story text with <em>HTML</em> formatting that would normally be parsed.</p>",
    kids: [2, 3, 4, 5]
  )

  StoryDetailView(story: sampleStory)
}
