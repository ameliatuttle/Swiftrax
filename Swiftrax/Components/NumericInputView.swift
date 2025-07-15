import SwiftUI

struct NumericInputView: View {
    let title: String
    @Binding var value: String
    let unit: String
    
    var body: some View {
        HStack {
            Text(title)
            
            Spacer()
            
            TextField("0", text: $value)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 60)
            
            Text(unit)
                .foregroundColor(.secondary)
                .font(.caption)
        }
    }
}

#Preview {
    Form {
        NumericInputView(title: "Calories", value: .constant("150"), unit: "kcal")
        NumericInputView(title: "Protein", value: .constant("25"), unit: "g")
    }
}
