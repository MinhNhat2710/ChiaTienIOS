import Foundation
import Observation

struct Person: Identifiable, Hashable, Codable {
    var id = UUID()
    var name: String
}

struct PayerShare: Codable, Hashable {
    var personID: UUID
    var amount: Double
}

struct Expense: Identifiable, Codable {
    var id = UUID()
    var title: String
    var payers: [PayerShare]
    var participantIDs: [UUID]
    var date = Date()

    /// Tổng tiền của khoản chi = tổng các phần mọi người đã ứng.
    var amount: Double {
        payers.map(\.amount).reduce(0, +)
    }

    init(title: String, payers: [PayerShare], participantIDs: [UUID]) {
        self.title = title
        self.payers = payers
        self.participantIDs = participantIDs
    }

    /// Convenience: một người trả.
    init(title: String, amount: Double, payerID: UUID, participantIDs: [UUID]) {
        self.init(
            title: title,
            payers: [PayerShare(personID: payerID, amount: amount)],
            participantIDs: participantIDs
        )
    }

    // Tương thích ngược: bản cũ lưu `amount` + `payerID` thay vì `payers`.
    private enum CodingKeys: String, CodingKey {
        case id, title, payers, participantIDs, date, amount, payerID
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        participantIDs = try c.decode([UUID].self, forKey: .participantIDs)
        date = try c.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        if let decoded = try c.decodeIfPresent([PayerShare].self, forKey: .payers) {
            payers = decoded
        } else if let payerID = try c.decodeIfPresent(UUID.self, forKey: .payerID),
                  let amount = try c.decodeIfPresent(Double.self, forKey: .amount) {
            payers = [PayerShare(personID: payerID, amount: amount)]
        } else {
            payers = []
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(payers, forKey: .payers)
        try c.encode(participantIDs, forKey: .participantIDs)
        try c.encode(date, forKey: .date)
    }
}

struct Settlement {
    let from: Person
    let to: Person
    let amount: Double
}

@Observable
final class SplitStore {
    var people: [Person] = [] { didSet { save() } }
    var expenses: [Expense] = [] { didSet { save() } }

    private static let storageKey = "ChiaTien.store.v1"

    init() {
        load()
    }

    func person(withID id: UUID) -> Person? {
        people.first { $0.id == id }
    }

    func addPerson(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !people.contains(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame })
        else { return }
        people.append(Person(name: trimmed))
    }

    func removePerson(_ id: UUID) {
        for index in expenses.indices {
            expenses[index].payers.removeAll { $0.personID == id }
            expenses[index].participantIDs.removeAll { $0 == id }
        }
        expenses.removeAll { $0.payers.isEmpty || $0.participantIDs.isEmpty }
        people.removeAll { $0.id == id }
    }

    /// Số dư ròng của một người: dương = được nhận lại, âm = cần trả.
    func netBalance(of id: UUID) -> Double {
        var net = 0.0
        for expense in expenses where !expense.participantIDs.isEmpty {
            for share in expense.payers where share.personID == id {
                net += share.amount
            }
            if expense.participantIDs.contains(id) {
                net -= expense.amount / Double(expense.participantIDs.count)
            }
        }
        return net
    }

    /// Greedy matching: người nợ nhiều nhất trả cho người được nhận nhiều nhất,
    /// để giảm số giao dịch cần thực hiện.
    func settlements() -> [Settlement] {
        var debtors = people
            .map { (person: $0, amount: -netBalance(of: $0.id)) }
            .filter { $0.amount > 0.5 }
            .sorted { $0.amount > $1.amount }
        var creditors = people
            .map { (person: $0, amount: netBalance(of: $0.id)) }
            .filter { $0.amount > 0.5 }
            .sorted { $0.amount > $1.amount }

        var result: [Settlement] = []
        var i = 0
        var j = 0
        while i < debtors.count && j < creditors.count {
            let pay = min(debtors[i].amount, creditors[j].amount)
            result.append(Settlement(from: debtors[i].person, to: creditors[j].person, amount: pay))
            debtors[i].amount -= pay
            creditors[j].amount -= pay
            if debtors[i].amount < 0.5 { i += 1 }
            if creditors[j].amount < 0.5 { j += 1 }
        }
        return result
    }

    private struct Snapshot: Codable {
        var people: [Person]
        var expenses: [Expense]
    }

    private func save() {
        let snapshot = Snapshot(people: people, expenses: expenses)
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data)
        else { return }
        people = snapshot.people
        expenses = snapshot.expenses
    }
}

extension Double {
    /// 150000 -> "150.000đ"
    var vnd: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        formatter.maximumFractionDigits = 0
        let digits = formatter.string(from: NSNumber(value: self)) ?? String(Int(self))
        return digits + "đ"
    }
}
