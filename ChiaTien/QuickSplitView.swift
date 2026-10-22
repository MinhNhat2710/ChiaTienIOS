import SwiftUI

struct QuickSplitView: View {
    @State private var amountText = ""
    @State private var people = 2
    @State private var extraPercent = 0.0
    @State private var roundUp = false

    private var amount: Double {
        Double(amountText.filter(\.isNumber)) ?? 0
    }

    private var extraAmount: Double {
        amount * extraPercent / 100
    }

    private var perPerson: Double {
        guard people > 0 else { return 0 }
        let raw = (amount + extraAmount) / Double(people)
        return roundUp ? (raw / 1_000).rounded(.up) * 1_000 : raw
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Hoá đơn") {
                    HStack {
                        TextField("Số tiền", text: $amountText)
                            .keyboardType(.numberPad)
                        Text("đ")
                            .foregroundStyle(.secondary)
                    }
                    LabeledContent("Phí dịch vụ / tip") {
                        Text("\(Int(extraPercent))%")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $extraPercent, in: 0...30, step: 1)
                    Toggle("Làm tròn lên nghìn", isOn: $roundUp)
                }

                Section("Số người chia") {
                    Stepper("\(people) người", value: $people, in: 1...50)
                }

                Section("Mỗi người trả") {
                    Text(perPerson.vnd)
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                    if extraAmount > 0 {
                        Text("Đã gồm phí \(extraAmount.vnd) — tổng \((amount + extraAmount).vnd)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .navigationTitle("Chia nhanh")
        }
    }
}
