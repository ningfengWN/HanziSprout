import SwiftUI

struct RootView: View {
    @State private var selected = 0
    var body: some View {
        TabView(selection: $selected) {
            PinyinPracticeView().tabItem { Label("练拼音", systemImage: "character.book.closed") }.tag(2)
            ContentView().tabItem { Label("写汉字", systemImage: "pencil.and.outline") }.tag(0)
            EnglishView().tabItem { Label("说英语", systemImage: "bubble.left.and.bubble.right") }.tag(1)
        }.tint(Crayon.green).preferredColorScheme(.light)
    }
}
