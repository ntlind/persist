import SwiftUI

struct Card: Codable, Identifiable {
    let id: Int
    var front: String
    var back: String
    var tags: [String]
    var lastAsked: String
    var nextReview: String
    var answers: Answers
    var retired: Bool
    var streak: Int

    enum CodingKeys: String, CodingKey {
        case id, front, back, tags, retired, streak
        case lastAsked = "last_asked"
        case nextReview = "next_review"
        case answers
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
    @State private var allCards: [Card] = []
    @State private var cards: [Card] = []
    @State private var isLoading = true
    @State private var selectedTag: String? = nil
    @State private var editTextTags = ""
    @State private var showingHelp: Bool = false
    @State private var showingSettings: Bool = false
    @State private var hideRetiredCards: Bool = true

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    Button(action: {
                        selectedTag = nil
                        fetchCards()
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
                    Spacer()
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.8))
                        .onHover { isHovered in
                            showingHelp = isHovered
                            if isHovered {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.arrow.set()
                            }
                        }
                        .padding(.trailing, 8)
                    Button(action: { showingSettings.toggle() }) {
                        Image(systemName: "gear")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .onHover { isHovered in
                        if isHovered {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.arrow.set()
                        }
                    }
                    .padding(.trailing, 12)
                }
                .padding(.horizontal)

                if let selectedTag = selectedTag {
                    let formattedTag =
                        selectedTag
                        .lowercased()
                        .replacingOccurrences(of: " ", with: "_")
                    TagDetailView(
                        cards: cards.filter { card in
                            let formattedTags = formattedTag.split(separator: ",").map(String.init)
                            return formattedTags.allSatisfy { tag in
                                card.tags.contains(tag.trimmingCharacters(in: .whitespaces))
                            }
                        },
                        editTextTags: $editTextTags
                    )
                    .onAppear {
                        editTextTags = formattedTag
                    }
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
            if showingHelp {
                Color.black.opacity(0.8)
                    .ignoresSafeArea()
                KeyboardShortcutsView()
                    .transition(.opacity)
            }
            if showingSettings {
                Color.black.opacity(0.8)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showingSettings = false
                    }
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Settings")
                            .font(.title2)
                            .fontWeight(.bold)
                        Spacer()
                        Button(action: { showingSettings = false }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                    }

                    Toggle("Hide Retired Cards", isOn: $hideRetiredCards)
                        .onChange(of: hideRetiredCards) { oldValue, newValue in
                            cards = hideRetiredCards ? allCards.filter { !$0.retired } : allCards
                        }
                }
                .padding()
                .frame(width: 400)
                .background(Color.black)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
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
                    self.allCards = decodedCards
                    self.cards =
                        hideRetiredCards ? decodedCards.filter { !$0.retired } : decodedCards
                    self.isLoading = false
                }
            } catch {
                print("Decoding error: \(error)")
            }
        }.resume()
    }
}

struct TagDetailView: View {
    let cards: [Card]
    @State private var currentIndex = 0
    @State private var isBackVisible = false
    @State private var localCards: [Card]
    @State private var pendingAnswer: String? = nil
    @FocusState private var isFocused: Bool
    @FocusState private var keyboardFocused: Bool
    @State private var isEditing = false
    @State private var editTextFront = ""
    @State private var editTextBack = ""
    @Binding var editTextTags: String

    init(cards: [Card], editTextTags: Binding<String>) {
        self.cards = cards
        self._localCards = State(initialValue: cards)
        self._editTextTags = editTextTags
    }

    var body: some View {
        VStack(spacing: 0) {
            if !cards.isEmpty {
                let card = localCards[currentIndex]
                ZStack(alignment: .topTrailing) {
                    VStack(alignment: .leading, spacing: 4) {
                        if isEditing {
                            TextField("Front", text: $editTextFront)
                                .textFieldStyle(.plain)
                                .font(.headline)

                            TextField("Tags (comma separated)", text: $editTextTags)
                                .textFieldStyle(.plain)
                                .font(.caption)
                                .foregroundColor(.gray)
                        } else {
                            Text(
                                LocalizedStringKey(
                                    card.front.replacingOccurrences(
                                        of: "/n", with: ""))
                            )
                            .font(.headline)
                        }

                        Spacer()

                        if isEditing {
                            TextEditor(text: $editTextBack)
                                .font(.subheadline)
                                .scrollContentBackground(.hidden)
                                .background(Color.clear)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .multilineTextAlignment(.leading)
                                .padding(.horizontal, -5)
                                .focused($keyboardFocused)
                                .onAppear {
                                    keyboardFocused = true
                                }
                        } else {
                            if !isBackVisible {
                                VStack {
                                    Text("Press space to reveal answer")
                                        .italic()
                                        .foregroundColor(.gray)
                                    Spacer()
                                }
                                .frame(
                                    maxWidth: .infinity, maxHeight: .infinity,
                                    alignment: .topLeading)
                            } else {
                                ScrollView {
                                    Text(
                                        LocalizedStringKey(
                                            card.back.replacingOccurrences(of: "- ", with: "• "))
                                    )
                                    .font(.system(size: 14))
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .overlay(
                        Button(action: {
                            if !localCards[currentIndex].retired {
                                if isEditing {
                                    localCards[currentIndex].front = editTextFront
                                    localCards[currentIndex].back = editTextBack
                                    localCards[currentIndex].tags =
                                        editTextTags
                                        .split(separator: ",")
                                        .map(String.init)
                                    saveEditsIfNeeded()
                                } else {
                                    let card = localCards[currentIndex]
                                    editTextFront = card.front
                                    editTextBack = card.back
                                    editTextTags = card.tags.joined(separator: ", ")
                                }
                                isEditing = !isEditing
                            }
                        }) {
                            EmptyView()
                        }
                        .keyboardShortcut("e", modifiers: [])
                        .opacity(0)
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isEditing ? Color.orange : Color.clear, lineWidth: 2)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                HStack {
                    if localCards[currentIndex].retired {
                        Image(systemName: "xmark.circle")
                            .foregroundColor(.white)
                            .font(.system(size: 20))
                    } else {
                        Button(action: {
                            if isEditing {
                                localCards[currentIndex].front = editTextFront
                                localCards[currentIndex].back = editTextBack
                                localCards[currentIndex].tags =
                                    editTextTags
                                    .split(separator: ",")
                                    .map(String.init)
                                saveEditsIfNeeded()
                            } else {
                                editTextFront =
                                    localCards[currentIndex]
                                    .front
                                editTextBack =
                                    localCards[currentIndex]
                                    .back
                                editTextTags = localCards[currentIndex]
                                    .tags.joined(separator: ", ")
                            }
                            isEditing = !isEditing
                        }) {
                            Image(systemName: "pencil.circle")
                                .foregroundColor(.white)
                                .font(.system(size: 20))
                        }
                        .buttonStyle(.plain)
                        .onHover { isHovered in
                            if isHovered {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.arrow.set()
                            }
                        }.keyboardShortcut("e", modifiers: [.command])
                    }
                    Spacer()
                    HStack {
                        Button(action: {
                            if currentIndex > 0 {
                                saveEditsIfNeeded()
                                currentIndex -= 1
                                isBackVisible = false
                                isEditing = false
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

                        Text("\(currentIndex + 1) of \(localCards.count)")
                            .font(.caption)
                            .padding(.horizontal, 16)

                        Button(action: {
                            if currentIndex < cards.count - 1 {
                                localCards[currentIndex].answers.correct += 1
                                localCards[currentIndex].streak += 1
                                saveEditsIfNeeded()
                                currentIndex += 1
                                isBackVisible = false
                                isEditing = false
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
                    }
                    Spacer()
                    Text("Streak: \(localCards[currentIndex].streak)")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .frame(width: 80, alignment: .trailing)
                }.padding(.top, 8)
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

        ZStack {
            Button(action: {
                localCards[currentIndex].retired.toggle()
            }) {
            }
            .keyboardShortcut("s", modifiers: [])
            .frame(width: 0, height: 0)
            .contentShape(Rectangle())

            Button(action: {
                if currentIndex < localCards.count - 1 {
                    localCards[currentIndex].answers.incorrect += 1
                    localCards[currentIndex].streak = 0
                    saveEditsIfNeeded()
                    currentIndex += 1
                    isBackVisible = false
                    isEditing = false
                }
            }) {
            }
            .keyboardShortcut("w", modifiers: [])
            .frame(width: 0, height: 0)
            .contentShape(Rectangle())

            Button(action: {
                isBackVisible = !isBackVisible
            }) {
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.space, modifiers: [])
        }.opacity(0)

        // .onChange(of: cards) { oldValue, newValue in
        //     localCards = newValue
        // }
    }

    func saveEditsIfNeeded() {
        if isEditing {
            localCards[currentIndex].front = editTextFront
            localCards[currentIndex].back = editTextBack
            localCards[currentIndex].tags =
                editTextTags
                .split(separator: ",")
                .map(String.init)
        }

        guard let url = URL(string: "http://127.0.0.1:8000/cards") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let jsonData = try JSONEncoder().encode([localCards[currentIndex]])
            request.httpBody = jsonData

            // Print JSON as a formatted string
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("Sending JSON:", jsonString)
            }

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Error saving card: \(error)")
                    return
                }
                let timestamp = DateFormatter.localizedString(
                    from: Date(),
                    dateStyle: .none,
                    timeStyle: .medium
                )
                print("Card saved successfully at \(timestamp)")
            }.resume()
        } catch {
            print("Error encoding card: \(error)")
        }
    }
}

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
                                onTagSelected(tag)
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

struct KeyboardShortcutsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Keyboard Shortcuts")
                .font(.headline)
                .padding(.bottom, 4)

            Group {
                ShortcutRow(key: "Space:", action: "Reveal card")
                ShortcutRow(key: "D:", action: "Correct answer, next card")
                ShortcutRow(key: "W:", action: "Incorrect answer, next card")
                ShortcutRow(key: "A:", action: "Previous card")
                ShortcutRow(key: "E:", action: "Edit card. CMD + E to save card.")
                ShortcutRow(key: "S:", action: "Retire card")
            }
            .font(.system(size: 14))
        }
        .padding()
        .background(Color.gray.opacity(0.15))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

struct ShortcutRow: View {
    let key: String
    let action: String

    var body: some View {
        HStack {
            Text(key)
                .fontWeight(.medium)
            Text(action)
        }
    }
}

extension Font {
    static func helvetica(size: CGFloat) -> Font {
        return Font.custom("Helvetica", size: size)
    }
}

struct ViewSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

#Preview {
    ContentView()
}
