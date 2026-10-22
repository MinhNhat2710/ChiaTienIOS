import XCTest
@testable import ChiaTien

final class ChiaTienTests: XCTestCase {

    var store: SplitStore!

    override func setUp() {
        super.setUp()
        store = SplitStore()
        store.people = []
        store.expenses = []
    }

    private func p(_ name: String) -> Person {
        store.people.first { $0.name == name }!
    }

    private func addExpense(_ amount: Double, payer: String, sharedBy: [String]) {
        store.expenses.append(Expense(
            title: "test",
            amount: amount,
            payerID: p(payer).id,
            participantIDs: sharedBy.map { p($0).id }
        ))
    }

    private func debts() -> [(from: String, to: String, amount: Double)] {
        store.settlements().map { ($0.from.name, $0.to.name, $0.amount) }
    }

    private func approx(_ a: Double, _ b: Double, eps: Double = 0.51) -> Bool {
        abs(a - b) < eps
    }

    /// Property: mọi giao dịch quyết toán phải khớp đúng số dư ròng.
    private func verifyConservation(file: StaticString = #filePath, line: UInt = #line) {
        let ds = debts()
        for person in store.people {
            let net = store.netBalance(of: person.id)
            let paid = ds.filter { $0.from == person.name }.map(\.amount).reduce(0, +)
            let received = ds.filter { $0.to == person.name }.map(\.amount).reduce(0, +)
            if net > 0.5 {
                XCTAssertTrue(approx(received, net), "\(person.name) nhận \(received) != \(net)", file: file, line: line)
            } else if net < -0.5 {
                XCTAssertTrue(approx(paid, -net), "\(person.name) trả \(paid) != \(-net)", file: file, line: line)
            } else {
                XCTAssertTrue(paid < 0.5 && received < 0.5, "\(person.name) không nên có giao dịch", file: file, line: line)
            }
        }
    }

    func testChiaDeuDonGian() {
        ["A", "B", "C"].forEach { store.addPerson(named: $0) }
        addExpense(300_000, payer: "A", sharedBy: ["A", "B", "C"])
        XCTAssertTrue(approx(store.netBalance(of: p("A").id), 200_000))
        XCTAssertTrue(approx(store.netBalance(of: p("B").id), -100_000))
        let ds = debts()
        XCTAssertEqual(ds.count, 2)
        XCTAssertTrue(ds.contains { $0.from == "B" && $0.to == "A" && approx($0.amount, 100_000) })
        XCTAssertTrue(ds.contains { $0.from == "C" && $0.to == "A" && approx($0.amount, 100_000) })
        verifyConservation()
    }

    func testNhieuNguoiTra() {
        ["A", "B", "C"].forEach { store.addPerson(named: $0) }
        addExpense(90_000, payer: "A", sharedBy: ["A", "B", "C"])
        addExpense(60_000, payer: "B", sharedBy: ["A", "B", "C"])
        XCTAssertTrue(approx(store.netBalance(of: p("A").id), 40_000))
        XCTAssertTrue(approx(store.netBalance(of: p("B").id), 10_000))
        XCTAssertTrue(approx(store.netBalance(of: p("C").id), -50_000))
        let ds = debts()
        XCTAssertEqual(ds.count, 2)
        XCTAssertTrue(ds.contains { $0.from == "C" && $0.to == "A" && approx($0.amount, 40_000) })
        XCTAssertTrue(ds.contains { $0.from == "C" && $0.to == "B" && approx($0.amount, 10_000) })
        verifyConservation()
    }

    func testChiaChoMotPhanNhom() {
        ["A", "B", "C", "D"].forEach { store.addPerson(named: $0) }
        addExpense(120_000, payer: "A", sharedBy: ["A", "B", "C"])
        XCTAssertTrue(approx(store.netBalance(of: p("D").id), 0))
        XCTAssertTrue(debts().allSatisfy { $0.from != "D" && $0.to != "D" })
        verifyConservation()
    }

    func testNguoiTraKhongAn() {
        ["A", "B", "C"].forEach { store.addPerson(named: $0) }
        addExpense(100_000, payer: "A", sharedBy: ["B", "C"])
        XCTAssertTrue(approx(store.netBalance(of: p("A").id), 100_000))
        XCTAssertTrue(approx(store.netBalance(of: p("B").id), -50_000))
        verifyConservation()
    }

    func testSoLeKhongChiaHet() {
        ["A", "B", "C"].forEach { store.addPerson(named: $0) }
        addExpense(100_000, payer: "A", sharedBy: ["A", "B", "C"])
        let ds = debts()
        XCTAssertEqual(ds.count, 2)
        XCTAssertTrue(approx(ds.map(\.amount).reduce(0, +), 66_666.67, eps: 1))
        verifyConservation()
    }

    func testNoDuoiNguong() {
        ["A", "B"].forEach { store.addPerson(named: $0) }
        addExpense(0.4, payer: "A", sharedBy: ["A", "B"])
        XCTAssertTrue(debts().isEmpty)
    }

    func testNoVongTrietTieu() {
        ["A", "B"].forEach { store.addPerson(named: $0) }
        addExpense(90_000, payer: "A", sharedBy: ["A", "B"])
        addExpense(90_000, payer: "B", sharedBy: ["A", "B"])
        XCTAssertTrue(debts().isEmpty)
    }

    func testXoaThanhVien() {
        ["A", "B", "C"].forEach { store.addPerson(named: $0) }
        addExpense(300_000, payer: "A", sharedBy: ["A", "B", "C"])
        let cID = p("C").id
        store.removePerson(cID)
        XCTAssertEqual(store.people.count, 2)
        XCTAssertFalse(store.expenses.first!.participantIDs.contains(cID))
        XCTAssertTrue(approx(store.netBalance(of: p("B").id), -150_000))

        let bID = p("B").id
        // Khoản do A+B cùng ứng -> xoá B chỉ mất phần của B, khoản vẫn còn của A
        store.expenses.append(Expense(
            title: "chung",
            payers: [
                PayerShare(personID: p("A").id, amount: 20_000),
                PayerShare(personID: bID, amount: 30_000),
            ],
            participantIDs: [p("A").id, bID]
        ))
        // Khoản do một mình B trả -> xoá B thì xoá luôn
        store.expenses.append(Expense(title: "riengB", amount: 50_000, payerID: bID, participantIDs: [p("A").id, bID]))

        store.removePerson(bID)
        let chung = store.expenses.first { $0.title == "chung" }
        XCTAssertNotNil(chung)
        XCTAssertTrue(approx(chung?.amount ?? 0, 20_000))
        XCTAssertFalse(store.expenses.contains { $0.title == "riengB" })
        XCTAssertTrue(store.expenses.allSatisfy { !$0.payers.contains { $0.personID == bID } })
        XCTAssertFalse(store.expenses.contains { $0.participantIDs.isEmpty })
    }

    /// Một món nhiều người cùng ứng trong 1 expense phải cho kết quả
    /// y hệt nhập nhiều expense riêng (A 100k, B 150k, C 150k chia 4).
    func testNhieuNguoiCungUng() {
        ["A", "B", "C", "D"].forEach { store.addPerson(named: $0) }
        store.expenses.append(Expense(
            title: "Món đồ",
            payers: [
                PayerShare(personID: p("A").id, amount: 100_000),
                PayerShare(personID: p("B").id, amount: 150_000),
                PayerShare(personID: p("C").id, amount: 150_000),
            ],
            participantIDs: store.people.map(\.id)
        ))
        // Tổng 400k / 4 = 100k mỗi người
        XCTAssertTrue(approx(store.netBalance(of: p("A").id), 0))
        XCTAssertTrue(approx(store.netBalance(of: p("B").id), 50_000))
        XCTAssertTrue(approx(store.netBalance(of: p("C").id), 50_000))
        XCTAssertTrue(approx(store.netBalance(of: p("D").id), -100_000))
        verifyConservation()
    }

    /// Data lưu từ bản cũ (amount + payerID) vẫn đọc được sang model mới.
    func testDocDuLieuDinhDangCu() throws {
        let id = UUID()
        let payerID = UUID()
        let member = UUID()
        let json = """
        {"id":"\(id.uuidString)","title":"Cũ","amount":50000,"payerID":"\(payerID.uuidString)","participantIDs":["\(member.uuidString)"],"date":0}
        """.data(using: .utf8)!
        let expense = try JSONDecoder().decode(Expense.self, from: json)
        XCTAssertEqual(expense.payers.count, 1)
        XCTAssertEqual(expense.payers.first?.personID, payerID)
        XCTAssertTrue(approx(expense.amount, 50_000))
    }

    func testBaoToanTongTienRandom() {
        for _ in 0..<5 {
            setUp()
            let names = (0..<6).map { "P\($0)" }
            names.forEach { store.addPerson(named: $0) }
            for _ in 0..<10 {
                let payer = names.randomElement()!
                let shared = Array(names.shuffled().prefix(Int.random(in: 1...6)))
                addExpense(Double(Int.random(in: 1...1000)) * 1000, payer: payer, sharedBy: shared)
            }
            let sumNet = store.people.map { store.netBalance(of: $0.id) }.reduce(0, +)
            XCTAssertLessThan(abs(sumNet), 0.01)
            verifyConservation()
        }
    }

    /// Kịch bản thực tế: nhóm 4 người — A ứng khách sạn + cọc quà + góp phần món đồ,
    /// B trả ship + góp phần, C góp phần, D không ứng đồng nào.
    /// Món đồ 400k do A(100) B(150) C(150) cùng ứng -> nhập 3 expense cùng tên.
    func testKichBanUngTienThucTe() {
        ["A", "B", "C", "D"].forEach { store.addPerson(named: $0) }
        let all = ["A", "B", "C", "D"]

        addExpense(800_000, payer: "A", sharedBy: all)  // A ứng khách sạn
        addExpense(200_000, payer: "A", sharedBy: all)  // A đặt cọc quà
        addExpense(50_000, payer: "B", sharedBy: all)   // B trả ship
        addExpense(100_000, payer: "A", sharedBy: all)  // Món đồ: A ứng 100k
        addExpense(150_000, payer: "B", sharedBy: all)  // Món đồ: B ứng 150k
        addExpense(150_000, payer: "C", sharedBy: all)  // Món đồ: C ứng 150k

        // Phần của mỗi người: (800+200+50+100+150+150)/4 = 362.5k
        // A trả 1100 -> +737.5k | B trả 200 -> -162.5k | C trả 150 -> -212.5k | D trả 0 -> -362.5k
        XCTAssertTrue(approx(store.netBalance(of: p("A").id), 737_500))
        XCTAssertTrue(approx(store.netBalance(of: p("B").id), -162_500))
        XCTAssertTrue(approx(store.netBalance(of: p("C").id), -212_500))
        XCTAssertTrue(approx(store.netBalance(of: p("D").id), -362_500))

        let ds = debts()
        XCTAssertEqual(ds.count, 3)
        XCTAssertTrue(ds.contains { $0.from == "D" && $0.to == "A" && approx($0.amount, 362_500) })
        XCTAssertTrue(ds.contains { $0.from == "C" && $0.to == "A" && approx($0.amount, 212_500) })
        XCTAssertTrue(ds.contains { $0.from == "B" && $0.to == "A" && approx($0.amount, 162_500) })
        verifyConservation()
    }

    func testKhongTrungTen() {
        store.addPerson(named: "An")
        store.addPerson(named: "an")
        store.addPerson(named: "  ")
        store.addPerson(named: "An")
        XCTAssertEqual(store.people.count, 1)
    }

    func testFormatVND() {
        XCTAssertEqual(100_000.0.vnd, "100.000đ")
        XCTAssertEqual(1_500.0.vnd, "1.500đ")
    }
}
