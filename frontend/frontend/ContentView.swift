import SwiftUI

// TODO images
// TODO refactor views
// TODO proper markdown handling
// TODO remove comments
//  TODO add types
// ability to randomize cards
// make header font scale with window size
// sort the cards based on lastAsked
// sort the cards based on lowest streak or highest ratio of incorrect to correct
// ability to look at all cards in a list and/or expert them

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
    var images: [String]

    enum CodingKeys: String, CodingKey {
        case id, front, back, tags, retired, streak, images
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
    @State private var isLoading: Bool = true
    @State private var selectedTag: String? = nil
    @State private var editTextTags: String = ""
    @State private var showingHelp: Bool = false
    @State private var showingSettings: Bool = false
    @State private var hideRetiredCards: Bool = true
    @State private var showCardCreator: Bool = false
    @State private var frontBackDelimiter: String = "=>"
    @State private var cardDelimiter: String = "&"
    @State private var sourceText: String = ""
    @State private var parsedCards: [(front: String, back: String)] = []
    @State private var newCardTags: String = ""
    @State private var sessionCorrect: Int = 0
    @State private var sessionIncorrect: Int = 0
    @State private var showCorrectBorder: Bool = false
    @State private var showIncorrectBorder: Bool = false

    var body: some View {
        ZStack {
            VStack(alignment: .leading) {
                HStack(spacing: 2) {
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
                    .padding(.trailing, 8)

                    Button(action: { showCardCreator.toggle() }) {
                        Image(systemName: "plus.circle")
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
                .padding(.top, 8)

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
            if showCardCreator {
                CardCreatorView(isShowing: $showCardCreator, onSave: fetchCards)
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

    func parseCards() {
        let sections = sourceText.components(separatedBy: cardDelimiter)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        parsedCards = sections.compactMap { section in
            let parts: [String] = section.components(separatedBy: frontBackDelimiter)
            guard parts.count == 2 else { return nil }
            return (
                front: parts[0].trimmingCharacters(in: .whitespacesAndNewlines),
                back: parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }

    func saveNewCards() {
        let newCards: [NewCard] = parsedCards.map { card in
            NewCard(
                front: card.front,
                back: card.back,
                tags: newCardTags.split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            )
        }

        guard let url = URL(string: "http://127.0.0.1:8000/add_cards") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let jsonData = try JSONEncoder().encode(newCards)
            request.httpBody = jsonData

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Error adding cards: \(error)")
                    return
                }
                print("Successfully added \(newCards.count) cards")
                DispatchQueue.main.async {
                    self.showCardCreator = false
                    self.fetchCards()
                }
            }.resume()
        } catch {
            print("Error encoding cards: \(error)")
        }
    }
}

struct TagDetailView: View {
    let cards: [Card]
    @State private var currentIndex: Int = 0
    @State private var sessionCorrect: Int = 0
    @State private var sessionIncorrect: Int = 0
    @State private var isBackVisible: Bool = false
    @State private var localCards: [Card]
    @State private var pendingAnswer: String? = nil
    @FocusState private var isFocused: Bool
    @FocusState private var keyboardFocused: Bool
    @State private var isEditing: Bool = false
    @State private var editTextFront: String = ""
    @State private var editTextBack: String = ""
    @Binding var editTextTags: String
    @State private var sessionStartTime: Date = Date()
    @State private var showCorrectBorder: Bool = false
    @State private var showIncorrectBorder: Bool = false

    init(cards: [Card], editTextTags: Binding<String>) {
        self.cards = cards
        self._localCards = State(initialValue: cards)
        self._editTextTags = editTextTags
    }

    private func formatBulletPoints(text: String) -> String {
        let bulletPattern = "(?m)^\\s*-\\s"
        if let bulletRegex = try? NSRegularExpression(pattern: bulletPattern) {
            return bulletRegex.stringByReplacingMatches(
                in: text,
                range: NSRange(text.startIndex..<text.endIndex, in: text),
                withTemplate: "• "
            )
        }
        return text
    }

    private func parseCodeBlocks(from text: String) -> NSAttributedString {
        let attributedString: NSMutableAttributedString = NSMutableAttributedString(string: text)

        let pattern: String = "```([\\s\\S]*?)```"
        let regex: NSRegularExpression? = try? NSRegularExpression(pattern: pattern)
        let nsRange: NSRange = NSRange(text.startIndex..<text.endIndex, in: text)

        if let matches: [NSTextCheckingResult] = regex?.matches(in: text, range: nsRange) {
            for match: NSTextCheckingResult in matches.reversed() {
                if let range: Range<String.Index> = Range(match.range, in: text) {
                    let codeBlock: String = String(text[range])
                    let code: String = codeBlock.replacingOccurrences(of: "```", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    let codeAttributes: [NSAttributedString.Key: Any] = [
                        .font: NSFont.monospacedSystemFont(
                            ofSize: 12, weight: .regular),
                        .backgroundColor: NSColor.gray.withAlphaComponent(0.4),
                        .foregroundColor: NSColor.white,
                    ]

                    let formattedCode: NSAttributedString = NSAttributedString(
                        string: code,
                        attributes: codeAttributes
                    )

                    if let nsRange: NSRange = Range(match.range, in: text)
                        .flatMap({ NSRange($0, in: text) })
                    {
                        attributedString.replaceCharacters(in: nsRange, with: formattedCode)
                    }
                }
            }
        }

        return attributedString
    }

    private func parseMarkdownImages(from text: String) -> (text: String, imageUrls: [String]) {
        var cleanText: String = text
        var imageUrls: [String] = []

        let pattern: String = "!\\[.*?\\]\\((.*?)\\)"
        let regex: NSRegularExpression? = try? NSRegularExpression(pattern: pattern)
        let nsRange: NSRange = NSRange(text.startIndex..<text.endIndex, in: text)

        if let matches: [NSTextCheckingResult] = regex?.matches(in: text, range: nsRange) {
            for match: NSTextCheckingResult in matches.reversed() {
                if let urlRange: Range<String.Index> = Range(match.range(at: 1), in: text) {
                    let imageUrl: String = String(text[urlRange])
                    imageUrls.append(imageUrl)
                }

                if let range: Range<String.Index> = Range(match.range, in: text) {
                    cleanText.removeSubrange(range)
                }
            }
        }

        return (cleanText, imageUrls.reversed())
    }

    var body: some View {
        VStack(spacing: 0) {
            if !cards.isEmpty {
                if currentIndex >= localCards.count {
                    ReportCardView(
                        correctCount: sessionCorrect,
                        incorrectCount: sessionIncorrect,
                        sessionDuration: Date().timeIntervalSince(sessionStartTime)
                    )
                } else {
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
                                        VStack(alignment: .leading, spacing: 12) {
                                            let parsed = parseMarkdownImages(from: card.back)
                                            let bulletFormatted = formatBulletPoints(
                                                text: parsed.text)
                                            let formattedText = parseCodeBlocks(
                                                from: bulletFormatted)

                                            Text(AttributedString(formattedText))
                                                .font(.system(size: 16.8))
                                                .frame(maxWidth: .infinity, alignment: .topLeading)
                                                .textSelection(.enabled)
                                                .lineSpacing(4)

                                            ForEach(parsed.imageUrls, id: \.self) { imageUrl in
                                                AsyncImage(url: URL(string: imageUrl)) { phase in
                                                    switch phase {
                                                    case .empty:
                                                        ProgressView()
                                                    case .success(let image):
                                                        image
                                                            .resizable()
                                                            .aspectRatio(contentMode: .fit)
                                                            .frame(
                                                                maxWidth: .infinity, maxHeight: 800
                                                            )
                                                            .cornerRadius(8)
                                                    case .failure:
                                                        Image(systemName: "photo")
                                                            .foregroundColor(.gray)
                                                    @unknown default:
                                                        EmptyView()
                                                    }
                                                }
                                            }
                                        }
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
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.green, lineWidth: 2)
                                .shadow(color: Color.green.opacity(0.5), radius: 10, x: 0, y: 0)
                                .opacity(showCorrectBorder ? 1 : 0)

                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.red, lineWidth: 2)
                                .shadow(color: Color.red.opacity(0.5), radius: 10, x: 0, y: 0)
                                .opacity(showIncorrectBorder ? 1 : 0)

                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isEditing ? Color.orange : Color.clear, lineWidth: 2)
                        }
                        .animation(.easeOut(duration: 0.3), value: showCorrectBorder)
                        .animation(.easeOut(duration: 0.3), value: showIncorrectBorder)
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
                                    sessionCorrect += 1
                                    saveEditsIfNeeded()

                                    showCorrectBorder = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        showCorrectBorder = false
                                        currentIndex += 1
                                        isBackVisible = false
                                        isEditing = false
                                    }
                                } else if currentIndex == cards.count - 1 {
                                    sessionCorrect += 1
                                    currentIndex += 1
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
                }
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
                    sessionIncorrect += 1
                    saveEditsIfNeeded()

                    showIncorrectBorder = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showIncorrectBorder = false
                        currentIndex += 1
                        isBackVisible = false
                        isEditing = false
                    }
                } else if currentIndex == localCards.count - 1 {
                    sessionIncorrect += 1
                    currentIndex += 1
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
            .onAppear {
                sessionStartTime = Date()
            }
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

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    private var tagCounts: [String: Int] {
        var counts: [String: Int] = [:]
        for card in cards {
            for tag in card.tags {
                let formattedTag = tag.replacingOccurrences(of: "_", with: " ")
                    .split(separator: " ")
                    .map { $0.capitalized }
                    .joined(separator: " ")
                counts[formattedTag, default: 0] += 1
            }
        }
        return counts
    }

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
                                Spacer()
                                Text("\(tagCounts[tag, default: 0])")
                                    .foregroundColor(.gray)
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

struct NewCard: Encodable {
    let front: String
    let back: String
    let tags: [String]
}

struct CardCreatorView: View {
    @Binding var isShowing: Bool
    @State private var frontBackDelimiter = "=>"
    @State private var cardDelimiter = "&"
    @State private var sourceText = ""
    @State private var parsedCards: [(front: String, back: String)] = []
    @State private var newCardTags = ""
    var onSave: () -> Void

    var body: some View {
        Color.black
            .ignoresSafeArea()
            .onTapGesture {
                isShowing = false
            }
        VStack(spacing: 16) {
            HStack {
                Text("Card Creator")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button(action: { isShowing = false }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
            }

            HStack {
                VStack(alignment: .leading) {
                    Text("Front-Back Delimiter:")
                    TextField("", text: $frontBackDelimiter)
                        .textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading) {
                    Text("Between-Card Delimiter:")
                    TextField("", text: $cardDelimiter)
                        .textFieldStyle(.roundedBorder)
                }
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading) {
                    Text("Source Text:")
                    TextEditor(text: $sourceText)
                        .font(.system(.body))
                        .onChange(of: sourceText) { oldValue, newValue in
                            parseCards()
                        }

                    Text("Tags (comma separated):")
                        .padding(.top, 8)
                    TextField("", text: $newCardTags)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body))
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading) {
                    Text("Preview (\(parsedCards.count) cards):")
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(parsedCards, id: \.front) { card in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(card.front)")
                                        .fontWeight(.medium)
                                    Text("\(card.back)")
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                            }
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxHeight: .infinity)

            HStack {
                Spacer()
                Button(action: saveNewCards) {
                    Text("Save Cards")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }

    private func parseCards() {
        let sections = sourceText.components(separatedBy: cardDelimiter)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        parsedCards = sections.compactMap { section in
            let parts = section.components(separatedBy: frontBackDelimiter)
            guard parts.count == 2 else { return nil }
            return (
                front: parts[0].trimmingCharacters(in: .whitespacesAndNewlines),
                back: parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }

    private func saveNewCards() {
        let newCards = parsedCards.map { card in
            NewCard(
                front: card.front,
                back: card.back,
                tags: newCardTags.split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            )
        }

        guard let url = URL(string: "http://127.0.0.1:8000/add_cards") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let jsonData = try JSONEncoder().encode(newCards)
            request.httpBody = jsonData

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Error adding cards: \(error)")
                    return
                }
                print("Successfully added \(newCards.count) cards")
                DispatchQueue.main.async {
                    isShowing = false
                    onSave()
                }
            }.resume()
        } catch {
            print("Error encoding cards: \(error)")
        }
    }
}

struct ReportCardView: View {
    let correctCount: Int
    let incorrectCount: Int
    let sessionDuration: TimeInterval

    private var formattedDuration: String {
        let minutes: Int = Int(sessionDuration) / 60
        let seconds: Int = Int(sessionDuration) % 60
        return "\(minutes)m \(seconds)s"
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("You're finished! Well done.")
                .font(.title2)
                .fontWeight(.bold)

            Text("Time: \(formattedDuration)")
                .font(.headline)
                .foregroundColor(.gray)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                    Text("Correct: \(correctCount)")
                }

                HStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 12, height: 12)
                    Text("Incorrect: \(incorrectCount)")
                }

                // Simple bar graph
                GeometryReader { geometry in
                    let total = CGFloat(correctCount + incorrectCount)
                    let correctWidth =
                        total > 0 ? geometry.size.width * (CGFloat(correctCount) / total) : 0

                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.green)
                            .frame(width: correctWidth)

                        Rectangle()
                            .fill(Color.red)
                    }
                }
                .frame(height: 24)
                .cornerRadius(4)
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(8)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
}
