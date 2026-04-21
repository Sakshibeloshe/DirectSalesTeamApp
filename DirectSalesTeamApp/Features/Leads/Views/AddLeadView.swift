import SwiftUI

struct AddLeadView: View {
    @ObservedObject var viewModel: LeadsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name           = ""
    @State private var phone          = ""
    @State private var selectedType   = LoanType.home
    @State private var amountText     = ""
    @State private var showTypePicker = false
    @State private var didAttemptSubmit = false   // show errors only after first tap
    @FocusState private var focused: Field?

    enum Field { case name, phone, amount }

    // MARK: - Validation (live, not just on submit)
    private var nameTrimmed: String { name.trimmingCharacters(in: .whitespaces) }
    private var phoneDigits: String { phone.filter(\.isNumber) }

    private var nameError: String? {
        guard didAttemptSubmit || !name.isEmpty else { return nil }
        return nameTrimmed.count < 2 ? "Enter at least 2 characters" : nil
    }
    private var phoneError: String? {
        guard didAttemptSubmit || !phone.isEmpty else { return nil }
        if phoneDigits.isEmpty { return "Enter a phone number" }
        return phoneDigits.count != 10 ? "Must be exactly 10 digits (\(phoneDigits.count)/10)" : nil
    }
    private var amountError: String? {
        guard didAttemptSubmit || !amountText.isEmpty else { return nil }
        return (Double(amountText) ?? 0) <= 0 ? "Enter a valid amount" : nil
    }

    private var formValid: Bool {
        nameTrimmed.count >= 2 &&
        phoneDigits.count == 10 &&
        (Double(amountText) ?? 0) > 0
    }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {

            // ── Drag handle ──
            Capsule()
                .fill(Color(UIColor.systemGray4))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 20)

            // ── Header ──
            HStack {
                Text("New Lead")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color.textPrimary)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(Color(UIColor.systemGray6))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.bottom, AppSpacing.lg)

            // ── Scrollable form ──
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.lg) {

                    // Full Name
                    formField(
                        label: "FULL NAME",
                        placeholder: "e.g. Arjun Mehta",
                        text: $name,
                        field: .name,
                        keyboard: .default,
                        errorMessage: nameError
                    )
                    .onChange(of: name) { _ in
                        if didAttemptSubmit { /* keep showing errors once triggered */ }
                    }

                    // Phone Number — live digit counter
                    phoneField

                    // Loan Type
                    loanTypePicker

                    // Loan Amount
                    amountField
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.bottom, AppSpacing.md)
            }

            // ── Sticky bottom button ──
            bottomButton
        }
        .background(Color.surfacePrimary)
        // Dismiss keyboard on drag
        .gesture(
            DragGesture(minimumDistance: 10, coordinateSpace: .local)
                .onChanged { _ in focused = nil }
        )
    }

    // MARK: - Phone field (special: shows digit counter)
    private var phoneField: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("PHONE NUMBER")
                .font(AppFont.captionMed())
                .foregroundColor(Color.textSecondary)
                .tracking(0.6)

            HStack {
                TextField("10-digit mobile number", text: $phone)
                    .font(AppFont.body())
                    .foregroundColor(Color.textPrimary)
                    .keyboardType(.phonePad)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($focused, equals: .phone)
                    .onChange(of: phone) { val in
                        // Cap at 10 digits
                        let digits = val.filter(\.isNumber)
                        if digits.count > 10 {
                            phone = String(digits.prefix(10))
                        } else {
                            phone = digits   // strip non-digits as user types
                        }
                    }

                if !phoneDigits.isEmpty {
                    Text("\(phoneDigits.count)/10")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(phoneDigits.count == 10 ? Color.statusSubmitted : Color.textTertiary)
                        .animation(.easeInOut, value: phoneDigits.count)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 16)
            .background(fieldBackground(for: .phone, hasError: phoneError != nil))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
            .overlay(fieldBorder(for: .phone, hasError: phoneError != nil))

            if let err = phoneError {
                errorLabel(err)
            }
        }
    }

    // MARK: - Loan Type Picker
    private var loanTypePicker: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("LOAN TYPE")
                .font(AppFont.captionMed())
                .foregroundColor(Color.textSecondary)
                .tracking(0.6)

            Button { showTypePicker = true } label: {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: selectedType.icon)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.brandBlue)
                        Text(selectedType.rawValue)
                            .font(AppFont.body())
                            .foregroundColor(Color.textPrimary)
                    }
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.textTertiary)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, 16)
                .background(Color(hex: "#F0F4FF"))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
            }
            .buttonStyle(.plain)
            .confirmationDialog("Select Loan Type", isPresented: $showTypePicker, titleVisibility: .visible) {
                ForEach(LoanType.allCases, id: \.self) { t in
                    Button(t.rawValue) { selectedType = t }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    // MARK: - Amount Field
    private var amountField: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("LOAN AMOUNT")
                .font(AppFont.captionMed())
                .foregroundColor(Color.textSecondary)
                .tracking(0.6)

            HStack(spacing: 6) {
                Text("₹")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(Color.textSecondary)
                TextField("0", text: $amountText)
                    .font(AppFont.body())
                    .foregroundColor(Color.textPrimary)
                    .keyboardType(.numberPad)
                    .focused($focused, equals: .amount)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 16)
            .background(fieldBackground(for: .amount, hasError: amountError != nil))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
            .overlay(fieldBorder(for: .amount, hasError: amountError != nil))

            // Live formatted preview
            if let amt = Double(amountText), amt > 0 {
                let dummy = Lead(id: UUID(), name: "", phone: "", email: "",
                                 loanType: selectedType, loanAmount: amt,
                                 status: .new, createdAt: Date(), updatedAt: Date())
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Color.statusSubmitted)
                    Text("≈ \(dummy.formattedAmount)")
                        .font(AppFont.caption())
                        .foregroundColor(Color.statusSubmitted)
                }
                .padding(.leading, 4)
            } else if let err = amountError {
                errorLabel(err)
            }
        }
    }

    // MARK: - Sticky Bottom Button
    private var bottomButton: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                didAttemptSubmit = true
                guard formValid else { return }
                submit()
            } label: {
                HStack(spacing: 8) {
                    if formValid {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Text("Add Lead")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(formValid ? .white : Color.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.sm)
                        .fill(formValid ? Color.brandBlue : Color(UIColor.systemGray5))
                )
                .animation(.easeInOut(duration: 0.18), value: formValid)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, 12)
            .padding(.bottom, max(AppSpacing.md, 8))  // safe area clearance
        }
        .background(Color.surfacePrimary)
    }

    // MARK: - Generic form field
    private func formField(
        label: String,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        keyboard: UIKeyboardType,
        errorMessage: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(AppFont.captionMed())
                .foregroundColor(Color.textSecondary)
                .tracking(0.6)

            TextField(placeholder, text: text)
                .font(AppFont.body())
                .foregroundColor(Color.textPrimary)
                .keyboardType(keyboard)
                .autocorrectionDisabled()
                .textInputAutocapitalization(field == .name ? .words : .never)
                .focused($focused, equals: field)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, 16)
                .background(fieldBackground(for: field, hasError: errorMessage != nil))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                .overlay(fieldBorder(for: field, hasError: errorMessage != nil))

            if let err = errorMessage {
                errorLabel(err)
            }
        }
    }

    // MARK: - Helpers
    private func fieldBackground(for field: Field, hasError: Bool) -> Color {
        if hasError { return Color(hex: "#FFF1F1") }
        if focused == field { return Color(hex: "#EEF3FF") }
        return Color(hex: "#F0F4FF")
    }

    private func fieldBorder(for field: Field, hasError: Bool) -> some View {
        RoundedRectangle(cornerRadius: AppRadius.sm)
            .strokeBorder(
                hasError ? Color.statusRejected.opacity(0.5)
                    : focused == field ? Color.brandBlue.opacity(0.5)
                    : Color.clear,
                lineWidth: 1.5
            )
    }

    private func errorLabel(_ text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 11))
                .foregroundColor(Color.statusRejected)
            Text(text)
                .font(AppFont.caption())
                .foregroundColor(Color.statusRejected)
        }
        .padding(.leading, 4)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Submit
    private func submit() {
        guard let amount = Double(amountText) else { return }
        let newLead = Lead(
            id: UUID(),
            name: nameTrimmed,
            phone: phoneDigits,
            email: "",
            loanType: selectedType,
            loanAmount: amount,
            status: .new,
            createdAt: Date(),
            updatedAt: Date(),
            assignedRM: nil,
            branchCode: nil
        )
        viewModel.addLead(newLead)
        dismiss()
    }
}
