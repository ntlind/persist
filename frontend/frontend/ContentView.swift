import SwiftUI

struct Card: Codable, Identifiable {
    let id = UUID()
    let front: String
    let back: String
    let tags: [String]
    let lastAsked: String
    let nextReview: String
    let answers: Answers
    let retired: Bool

    enum CodingKeys: String, CodingKey {
        case front, back, tags
        case lastAsked = "last_asked"
        case nextReview = "next_review"
        case answers, retired
    }
}

struct Answers: Codable {
    let correct: Int
    let partial: Int
    let incorrect: Int
}

struct ContentView: View {
    @State private var cards: [Card] = []
    @State private var isLoading = true
    @State private var selectedTag: String = "All"

    private var uniqueTags: [String] {
        var tags = Set<String>()
        cards.forEach { card in
            tags.formUnion(card.tags)
        }
        let allTags = ["All"] + Array(tags).sorted()
        print("Available tags: \(allTags)")
        return allTags
    }

    private var filteredCards: [Card] {
        if selectedTag == "All" {
            return cards
        }
        return cards.filter { $0.tags.contains(selectedTag) }
    }

    var body: some View {
        VStack {
            if isLoading {
                ProgressView()
            } else {
                Picker("Select Tag", selection: $selectedTag) {
                    ForEach(uniqueTags, id: \.self) { tag in
                        Text(tag)
                    }
                }
                .pickerStyle(.menu)
                .padding()

                ScrollView {
                    LazyVStack(alignment: .leading) {
                        ForEach(filteredCards) { card in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(card.front)
                                    .font(.headline)
                                Text(card.back)
                                    .font(.subheadline)
                                Divider()
                            }
                            .padding()
                        }
                    }
                }
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

extension Font {
    static func helvetica(size: CGFloat) -> Font {
        return Font.custom("Helvetica", size: size)
    }
}

#Preview {
    ContentView()
}
