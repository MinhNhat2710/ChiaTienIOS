import SwiftUI

struct GroupSplitView: View {
    @Environment(SplitStore.self) private var store
    @State private var newName = ""
    @State private var showAddExpense = false

    var body: some View {
        NavigationStack {
            List {
                membersSection
                expensesSection
                if !store.expenses.isEmpty {
                    settlementSection
                    balanceSection
                }
            }
            .navigationTitle("Chia tiền nhóm")
            .sheet(isPresented: $showAddExpense) {
                AddExpenseView()
            }
        }
    }

    private var membersSection: some View {
        Section {
            ForEach(store.people) { person in
                Label(person.name, systemImage: "person.fill")
            }
            .onDelete { offsets in
                offsets
                    .map { store.people[$0].id }
                    .forEach(store.removePerson)
            }
            HStack {
                TextField("Tên thành viên", text: $newName)
                    .onSubmit(addMember)
                Button(action: addMember) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        } header: {
            Text("Thành viên (\(store.people.count))")
        } footer: {
            if store.people.isEmpty {
                Text("Thêm thành viên rồi nhập các khoản chi — app sẽ tự tính ai nợ ai.")
            }
        }
    }

    private var expensesSection: some View {
        Section("Khoản chi") {
            ForEach(store.expenses) { expense in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(expense.title)
                        Spacer()
                        Text(expense.amount.vnd)
                            .bold()
                    }
                    let payerNames = expense.payers
                        .compactMap { store.person(withID: $0.personID)?.name }
                        .joined(separator: ", ")
                    Text("\(payerNames.isEmpty ? "?" : payerNames) trả · chia \(expense.participantIDs.count) người")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onDelete { store.expenses.remove(atOffsets: $0) }

            Button {
                showAddExpense = true
            } label: {
                Label("Thêm khoản chi", systemImage: "plus.circle.fill")
            }
            .disabled(store.people.isEmpty)
        }
    }

    private var settlementSection: some View {
        Section("Quyết toán") {
            let debts = store.settlements()
            if debts.isEmpty {
                Label("Không ai nợ ai cả", systemImage: "checkmark.seal")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(debts.enumerated()), id: \.offset) { _, debt in
                    HStack(spacing: 6) {
                        Text(debt.from.name).bold()
                        Image(systemName: "arrow.right")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        Text(debt.to.name).bold()
                        Spacer()
                        Text(debt.amount.vnd)
                            .foregroundStyle(.orange)
                            .bold()
                    }
                }
            }
        }
    }

    private var balanceSection: some View {
        Section("Số dư từng người") {
            ForEach(store.people) { person in
                let net = store.netBalance(of: person.id)
                HStack {
                    Text(person.name)
                    Spacer()
                    if abs(net) < 0.5 {
                        Text("0đ")
                            .foregroundStyle(.secondary)
                    } else if net > 0 {
                        Text("+\(net.vnd)")
                            .foregroundStyle(.green)
                    } else {
                        Text("-\((-net).vnd)")
                            .foregroundStyle(.red)
                    }
                }
            }
        }
    }

    private func addMember() {
        store.addPerson(named: newName)
        newName = ""
    }
}

struct AddExpenseView: View {
    @Environment(SplitStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var amountText = ""
    @State private var payerID: UUID?
    @State private var participants: Set<UUID> = []
    @State private var multiPayer = false
    @State private var payerAmounts: [UUID: String] = [:]

    private var amount: Double {
        Double(amountText.filter(\.isNumber)) ?? 0
    }

    private var payerShares: [PayerShare] {
        store.people.compactMap { person in
            let value = Double((payerAmounts[person.id] ?? "").filter(\.isNumber)) ?? 0
            return value > 0 ? PayerShare(personID: person.id, amount: value) : nil
        }
    }

    private var payersTotal: Double {
        payerShares.map(\.amount).reduce(0, +)
    }

    private var expenseTotal: Double {
        multiPayer ? payersTotal : amount
    }

    private var canSave: Bool {
        let hasPayer = multiPayer ? !payerShares.isEmpty : (payerID != nil && amount > 0)
        return hasPayer && !participants.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Khoản chi") {
                    TextField("Mô tả (vd: Ăn trưa)", text: $title)
                    if multiPayer {
                        LabeledContent("Tổng") {
                            Text(payersTotal.vnd)
                                .bold()
                        }
                    } else {
                        HStack {
                            TextField("Số tiền", text: $amountText)
                                .keyboardType(.numberPad)
                            Text("đ")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    Toggle("Nhiều người cùng ứng", isOn: $multiPayer)
                    if multiPayer {
                        ForEach(store.people) { person in
                            HStack {
                                Text(person.name)
                                Spacer()
                                TextField("0", text: payerAmountBinding(for: person.id))
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 110)
                                Text("đ")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Picker("Ai đã trả?", selection: $payerID) {
                            Text("Chọn người trả").tag(UUID?.none)
                            ForEach(store.people) { person in
                                Text(person.name).tag(UUID?.some(person.id))
                            }
                        }
                    }
                } header: {
                    Text("Người trả")
                } footer: {
                    if multiPayer {
                        Text("Điền số tiền mỗi người đã ứng — để trống nếu không ứng.")
                    }
                }

                Section {
                    ForEach(store.people) { person in
                        Button {
                            if participants.contains(person.id) {
                                participants.remove(person.id)
                            } else {
                                participants.insert(person.id)
                            }
                        } label: {
                            HStack {
                                Text(person.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if participants.contains(person.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Chia cho")
                } footer: {
                    if expenseTotal > 0 && !participants.isEmpty {
                        Text("Mỗi người: \((expenseTotal / Double(participants.count)).vnd)")
                    }
                }
            }
            .navigationTitle("Thêm khoản chi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu", action: save)
                        .disabled(!canSave)
                }
            }
            .onAppear {
                participants = Set(store.people.map(\.id))
            }
        }
    }

    private func payerAmountBinding(for id: UUID) -> Binding<String> {
        Binding(
            get: { payerAmounts[id] ?? "" },
            set: { payerAmounts[id] = $0 }
        )
    }

    private func save() {
        let payers: [PayerShare]
        if multiPayer {
            payers = payerShares
            guard !payers.isEmpty else { return }
        } else {
            guard let payerID, amount > 0 else { return }
            payers = [PayerShare(personID: payerID, amount: amount)]
        }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let expense = Expense(
            title: trimmed.isEmpty ? "Khoản chi" : trimmed,
            payers: payers,
            participantIDs: store.people.map(\.id).filter { participants.contains($0) }
        )
        store.expenses.append(expense)
        dismiss()
    }
}
