import SwiftUI

struct Card: Codable, Identifiable {
    let id = UUID()
    let front: String
    let back: String
    let tags: [String]
    let lastAsked: String
    let nextReview: String
    var answers: Answers
    var retired: Bool

    enum CodingKeys: String, CodingKey {
        case front, back, tags
        case lastAsked = "last_asked"
        case nextReview = "next_review"
        case answers, retired
    }
}

struct Answers: Codable {
    var correct: Int
    var partial: Int
    var incorrect: Int
}

struct MacOSTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.placeholderString = placeholder
        textField.delegate = context.coordinator
        textField.backgroundColor = .clear
        textField.isBordered = true
        textField.bezelStyle = .roundedBezel

        textField.isSelectable = true
        textField.cell?.isScrollable = true
        textField.cell?.wraps = false
        textField.cell?.usesSingleLineMode = true

        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        nsView.stringValue = text
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                self.text.wrappedValue = textField.stringValue
            }
        }
    }
}

struct ContentView: View {
    @State private var cards: [Card] = []
    @State private var isLoading = true
    @State private var selectedTag: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Breadcrumb
            HStack(spacing: 4) {
                Button(action: {
                    selectedTag = nil
                }) {
                    Text("Your Tags")
                        .font(.helvetica(size: 12))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 8)
                .padding(.leading, 8)
                .onHover { isHovered in
                    if isHovered {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }

                if let tag = selectedTag {
                    Text(">")
                        .font(.helvetica(size: 12))
                    Text(tag)
                        .font(.helvetica(size: 12))
                        .padding(.vertical, 8)
                }
            }
            .padding(.horizontal)

            // Main Content
            if let selectedTag = selectedTag {
                let formattedTag =
                    selectedTag
                    .lowercased()
                    .replacingOccurrences(of: " ", with: "_")
                TagDetailView(cards: cards.filter { $0.tags.contains(formattedTag) })
            } else {
                TagsView(
                    cards: cards,
                    isLoading: isLoading,
                    onTagSelected: { tag in
                        self.selectedTag = tag
                    }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
        .foregroundColor(.white)
        .font(.helvetica(size: 16))
        .onAppear {
            fetchCards()
        }
    }

    func fetchCards() {
        guard let url = URL(string: "http://127.0.0.1:8000/cards") else { return }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error: \(error)")
                return
            }

            guard let data = data else { return }

            do {
                let decodedCards = try JSONDecoder().decode([Card].self, from: data)
                DispatchQueue.main.async {
                    self.cards = decodedCards
                    self.isLoading = false
                }
            } catch {
                print("Decoding error: \(error)")
            }
        }.resume()
    }
}

// New view for displaying cards of a specific tag
struct TagDetailView: View {
    let cards: [Card]
    @State private var currentIndex = 0
    @State private var isBackVisible = false
    @State private var localCards: [Card]
    @State private var pendingAnswer: String? = nil  // "correct" or "incorrect"
    @FocusState private var isFocused: Bool

    init(cards: [Card]) {
        self.cards = cards
        self._localCards = State(initialValue: cards)
    }

    var body: some View {
        VStack(spacing: 0) {
            if !cards.isEmpty {
                let card = localCards[currentIndex]
                VStack(alignment: .leading, spacing: 8) {
                    Text(card.front)
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if isBackVisible {
                        Button(action: {
                            isBackVisible = false
                        }) {
                            Text(card.back)
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(.space, modifiers: [])

                        Button(action: {
                            isBackVisible = false
                        }) {
                            EmptyView()
                        }
                        .keyboardShortcut("w", modifiers: [])
                        .opacity(0)
                    } else {
                        Button(action: {
                            isBackVisible = true
                            pendingAnswer = "correct"
                        }) {
                            Text("Press space to reveal answer")
                                .italic()
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(.space, modifiers: [])

                        Button(action: {
                            isBackVisible = true
                            pendingAnswer = "incorrect"
                        }) {
                            EmptyView()
                        }
                        .keyboardShortcut("w", modifiers: [])
                        .opacity(0)

                        Button(action: {
                            localCards[currentIndex].retired.toggle()
                            // TODO: Add API call to update retired status
                        }) {
                            EmptyView()
                        }
                        .keyboardShortcut("s", modifiers: [])
                        .opacity(0)
                    }

                    HStack {
                        VStack(alignment: .leading) {
                            HStack {
                                Text("Stats:")
                                    .fontWeight(.bold)
                                Text(
                                    "✓\(card.answers.correct) ⚠️\(card.answers.partial) ✗\(card.answers.incorrect)"
                                )
                            }
                            .font(.caption)
                            Text("Last reviewed: \(card.lastAsked)")
                                .font(.caption)
                            Text("Next review: \(card.nextReview)")
                                .font(.caption)
                        }
                        Spacer()
                        if card.retired {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.circle")
                                Text("Retired")
                            }
                            .font(.caption)
                            .foregroundColor(.gray)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Navigation arrows and counter
                HStack {
                    Spacer()
                    Button(action: {
                        if currentIndex > 0 {
                            currentIndex -= 1
                            isBackVisible = false
                        }
                    }) {
                        Image(systemName: "arrow.left")
                            .foregroundColor(.white)
                            .opacity(currentIndex > 0 ? 1 : 0.3)
                    }
                    .keyboardShortcut("a", modifiers: [])
                    .buttonStyle(.plain)
                    .onHover { isHovered in
                        if currentIndex > 0 && isHovered {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.arrow.set()
                        }
                    }

                    Text("\(currentIndex + 1) of \(cards.count)")
                        .font(.caption)
                        .padding(.horizontal, 16)

                    Button(action: {
                        if currentIndex < cards.count - 1 {
                            applyPendingAnswer()
                            currentIndex += 1
                            isBackVisible = false
                        }
                    }) {
                        Image(systemName: "arrow.right")
                            .foregroundColor(.white)
                            .opacity(currentIndex < cards.count - 1 ? 1 : 0.3)
                    }
                    .keyboardShortcut("d", modifiers: [])
                    .buttonStyle(.plain)
                    .onHover { isHovered in
                        if currentIndex < cards.count - 1 && isHovered {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.arrow.set()
                        }
                    }
                    Spacer()
                }
                .padding(.vertical)
            } else {
                Text("No cards found for this tag")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .focused($isFocused)
        .onAppear { isFocused = true }
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
        .simultaneousGesture(TapGesture())
    }

    func applyPendingAnswer() {
        if let answer = pendingAnswer {
            if answer == "correct" {
                localCards[currentIndex].answers.correct += 1
            } else if answer == "incorrect" {
                localCards[currentIndex].answers.incorrect += 1
            }
            pendingAnswer = nil  // Reset pending answer
        }
    }
}

// Update TagsView to accept onTagSelected callback
struct TagsView: View {
    let cards: [Card]
    let isLoading: Bool
    let onTagSelected: (String) -> Void
    @State private var searchText = ""

    private var uniqueTags: [String] {
        var tags = Set<String>()
        cards.forEach { card in
            tags.formUnion(
                card.tags.map { tag in
                    tag.replacingOccurrences(of: "_", with: " ")
                        .split(separator: " ")
                        .map { $0.capitalized }
                        .joined(separator: " ")
                })
        }
        let allTags = Array(tags).sorted()
        print("Available tags: \(allTags)")
        return allTags
    }

    private var filteredTags: [String] {
        if searchText.isEmpty {
            return uniqueTags
        }
        return uniqueTags.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    var body: some View {
        VStack {
            if isLoading {
                ProgressView()
            } else {
                ScrollView {
                    Text("Your Tags")
                        .font(.title)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top)

                    MacOSTextField(text: $searchText, placeholder: "Search tags...")
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal)
                        .padding(.vertical, 8)

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(filteredTags, id: \.self) { tag in
                            HStack {
                                Image(systemName: "tag")
                                    .foregroundColor(.white)
                                Text(tag)
                                    .lineLimit(1)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                            .onTapGesture {
                                if tag != "All" {
                                    onTagSelected(tag)
                                }
                            }
                            .onHover { isHovered in
                                if isHovered {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
    }
}

extension Font {
    static func helvetica(size: CGFloat) -> Font {
        return Font.custom("Helvetica", size: size)
    }
}

// Add this preference key
struct ViewSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

#Preview {
    ContentView()
}
