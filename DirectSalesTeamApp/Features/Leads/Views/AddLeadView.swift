import SwiftUI
import GRPCCore

@MainActor
struct AddLeadView: View {
    @ObservedObject var viewModel: LeadsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var amountText = ""
    @State private var selectedProductID: String? = nil

    // Reset KYC flag when user changes phone/email (might be different borrower)
    private func resetBorrowerState() {
        kycIncomplete = false
        borrowerStatus = .unknown
        borrowerLookupErrorMessage = ""
    }

    // Borrower Profile Resolution
    @State private var borrowerStatus: BorrowerStatus = .unknown
    @State private var borrowerLookupErrorMessage = ""
    @State private var showBorrowerSignupPrompt = false
    @State private var isCheckingBorrower = false
    @State private var isAddingLead = false
    @State private var kycIncomplete = false
    private let borrowerLookupService = BorrowerLookupService()

    enum BorrowerStatus {
        case unknown
        case checking
        case found(profileID: String?, name: String)
        case notFound
        case error

        var displayText: String {
            switch self {
            case .unknown:            return ""
            case .checking:           return "Checking if borrower exists..."
            case .found(_, let name): return "✓ Found: \(name)"
            case .notFound:           return "⚠️ Borrower not registered"
            case .error:              return "Unable to verify borrower"
            }
        }
        var color: Color {
            switch self {
            case .unknown:   return .clear
            case .checking:  return .gray
            case .found:     return .green
            case .notFound:  return .red
            case .error:     return .orange
            }
        }
        var icon: String? {
            switch self {
            case .unknown, .checking: return nil
            case .found:              return "checkmark.circle.fill"
            case .notFound:           return "exclamationmark.triangle.fill"
            case .error:              return "xmark.circle.fill"
            }
        }
    }

    // MARK: - Computed
    private var nameTrimmed: String  { name.trimmingCharacters(in: .whitespaces) }
    private var phoneDigits: String  { phone.filter(\.isNumber) }
    private var emailTrimmed: String { email.trimmingCharacters(in: .whitespaces) }

    private var emailError: String? {
        guard !emailTrimmed.isEmpty else { return nil }
        let regex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return emailTrimmed.range(of: regex, options: .regularExpression) == nil ? "Invalid email" : nil
    }

    private var formValid: Bool {
        let amount = Double(amountText) ?? 0
        let rangeValid: Bool
        if let p = selectedProduct,
           let min = Double(p.minAmount),
           let max = Double(p.maxAmount) {
            rangeValid = amount >= min && amount <= max
        } else {
            rangeValid = amount > 0
        }

        return !kycIncomplete &&
               nameTrimmed.count >= 2 &&
               phoneDigits.count == 10 &&
               (emailTrimmed.isEmpty || emailError == nil) &&
               rangeValid &&
               selectedProductID != nil
    }

    private var selectedProduct: LoanProduct? {
        viewModel.loanProducts.first { $0.id == selectedProductID }
    }

    private var inferredLoanType: LoanType {
        guard let p = selectedProduct else { return .personal }
        switch p.category {
        case .home:      return .home
        case .vehicle:   return .auto
        case .education: return .education
        default:         return .personal
        }
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {
                        sectionLabel("Borrower Details")

                        formCard {
                            formField("Full Name") {
                                TextField("Required", text: $name)
                                    .autocorrectionDisabled()
                            }
                            Divider().padding(.leading, 16)
                            formField("Phone") {
                                TextField("10-digit number", text: $phone)
                                    .keyboardType(.numberPad)
                            }
                            Divider().padding(.leading, 16)
                            formField("Email") {
                                TextField("Optional", text: $email)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                            }
                        }

                        if borrowerStatus != .unknown {
                            borrowerStatusBadge
                        }

                        if kycIncomplete {
                            kycWarningBanner
                        }

                        sectionLabel("Loan Details")

                        formCard {
                            // Product picker — uses data already in viewModel (no async task here)
                            formField("Loan Product") {
                                if viewModel.loanProducts.isEmpty {
                                    Text("Loading products…")
                                        .foregroundColor(.secondary)
                                        .font(.subheadline)
                                } else {
                                    Menu {
                                        Button("Select…") { selectedProductID = nil }
                                        ForEach(viewModel.loanProducts) { p in
                                            Button("\(p.name) · \(p.baseInterestRate)%") {
                                                selectedProductID = p.id
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            Text(selectedProduct?.name ?? "Select…")
                                                .foregroundColor(selectedProductID == nil ? .secondary : .primary)
                                            Spacer()
                                            Image(systemName: "chevron.up.chevron.down")
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            Divider().padding(.leading, 16)
                            formField("Amount (₹)") {
                                TextField("e.g. 500000", text: $amountText)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                            }
                            if let p = selectedProduct {
                                HStack {
                                    Spacer()
                                    Text("Range: ₹\(fmt(p.minAmount)) – ₹\(fmt(p.maxAmount))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 16)
                                        .padding(.bottom, 10)
                                }
                            }
                        }

                        if let p = selectedProduct, !p.requiredDocuments.isEmpty {
                            requiredDocsPreview(p)
                        }
                    }
                    .padding(16)
                }

                submitBar
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Add Lead")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                if viewModel.loanProducts.isEmpty {
                    await viewModel.fetchLoanProducts()
                }
                if selectedProductID == nil, let first = viewModel.loanProducts.first {
                    selectedProductID = first.id
                }
            }
            .onChange(of: viewModel.errorMessage) { err in
                if err != nil && !(err?.lowercased().contains("kyc") == true) {
                    showErrorAlert = true
                }
            }
            .onChange(of: borrowerLookupErrorMessage) { msg in
                if !msg.isEmpty { showErrorAlert = true }
            }
            .onChange(of: phone) { _ in resetBorrowerState() }
            .onChange(of: email) { _ in resetBorrowerState() }
            .sheet(isPresented: $showBorrowerSignupPrompt) { borrowerSignupSheet }
            .alert("Action Required", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { 
                    viewModel.errorMessage = nil
                    borrowerLookupErrorMessage = ""
                }
            } message: {
                Text(errorMessageForAlert)
            }
        }
    }

    @State private var showErrorAlert = false
    private var errorMessageForAlert: String {
        if let vmError = viewModel.errorMessage { return vmError }
        if !borrowerLookupErrorMessage.isEmpty { return borrowerLookupErrorMessage }
        return "An unexpected error occurred."
    }

    // MARK: - Sub-views

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(.separator).opacity(0.4), lineWidth: 1))
    }

    private func formField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private var borrowerStatusBadge: some View {
        HStack(spacing: 8) {
            if case .checking = borrowerStatus {
                ProgressView().scaleEffect(0.8)
            } else if let icon = borrowerStatus.icon {
                Image(systemName: icon).foregroundColor(borrowerStatus.color)
            }
            Text(borrowerStatus.displayText)
                .font(.subheadline)
                .foregroundColor(borrowerStatus.color)
            Spacer()
        }
        .padding(12)
        .background(borrowerStatus.color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var kycWarningBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.shield.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 18))
                Text("KYC Verification Required")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(.orange)
                Spacer()
            }
            Text("This borrower's KYC (identity verification) is incomplete. Ask them to open the Borrower app, go to their Profile, and complete KYC before you can add a lead.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.orange.opacity(0.3), lineWidth: 1))
    }

    private func requiredDocsPreview(_ product: LoanProduct) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Required Documents")

            formCard {
                ForEach(Array(product.requiredDocuments.enumerated()), id: \.element.id) { idx, doc in
                    HStack(spacing: 12) {
                        Image(systemName: docIcon(doc.requirementType))
                            .font(.system(size: 14))
                            .foregroundColor(Color.brandBlue)
                            .frame(width: 28)
                        Text(doc.requirementType.displayName)
                            .font(.subheadline)
                        Spacer()
                        if doc.isMandatory {
                            Text("Required")
                                .font(.caption2).fontWeight(.medium)
                                .foregroundColor(Color.brandBlue)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.brandBlue.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 11)
                    if idx < product.requiredDocuments.count - 1 {
                        Divider().padding(.leading, 56)
                    }
                }
            }
        }
    }

    private var submitBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button(action: submit) {
                HStack(spacing: 8) {
                    if isCheckingBorrower || isAddingLead {
                        ProgressView().tint(.white).scaleEffect(0.85)
                    }
                    Text(isCheckingBorrower ? "Verifying…" : (isAddingLead ? "Creating Lead…" : "Add Lead"))
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(formValid && !isCheckingBorrower ? Color.brandBlue : Color(.systemGray4))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!formValid || isCheckingBorrower || isAddingLead)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGroupedBackground))
        }
    }

    private var borrowerSignupSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .font(.system(size: 36)).foregroundStyle(.orange)
                Text("Borrower not registered").font(.headline)
                Text("No borrower account found. Ask the user to download the Borrower app and sign up first.")
                    .font(.subheadline).foregroundStyle(.secondary)
                Spacer()
            }
            .padding()
            .navigationTitle("Registration Required")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { showBorrowerSignupPrompt = false }
                }
            }
        }
        .presentationDetents([.height(280)])
    }

    // MARK: - Actions

    private func submit() {
        guard formValid, !isCheckingBorrower, !isAddingLead else { return }
        let id      = UUID().uuidString
        let name    = nameTrimmed
        let phone   = phoneDigits
        let email   = emailTrimmed
        let amount  = Double(amountText) ?? 0
        let type    = inferredLoanType
        let prodID  = selectedProductID
        Task {
            await verifyAndSubmit(id: id, name: name, phone: phone,
                                  email: email, amount: amount,
                                  loanType: type, productID: prodID)
        }
    }

    @MainActor
    private func verifyAndSubmit(id: String, name: String, phone: String,
                                 email: String, amount: Double,
                                 loanType: LoanType, productID: String?) async {
        borrowerStatus = .checking
        isCheckingBorrower = true
        defer { isCheckingBorrower = false }
        do {
            if let result = try await borrowerLookupService.resolveBorrower(email: email, phone: phone) {
                borrowerStatus = .found(profileID: result.borrowerProfileID, name: result.displayName)
                let lead = Lead(
                    id: id, name: name, phone: phone, email: email,
                    borrowerProfileID: result.borrowerProfileID,
                    borrowerUserID: result.userID,
                    loanType: loanType,
                    loanProductID: productID,
                    loanAmount: amount,
                    status: .new,
                    createdAt: Date(), updatedAt: Date()
                )
                isAddingLead = true
                viewModel.addLead(lead) { [self] success in
                    isAddingLead = false
                    if success {
                        dismiss()
                    } else if let err = viewModel.errorMessage,
                              err.lowercased().contains("kyc") {
                        // Specific KYC error — show inline banner, clear generic alert
                        kycIncomplete = true
                        viewModel.errorMessage = nil
                    }
                }
            } else {
                borrowerStatus = .notFound
                showBorrowerSignupPrompt = true
            }
        } catch let rpcError as RPCError where rpcError.code == .cancelled {
            borrowerStatus = .unknown
        } catch is CancellationError {
            borrowerStatus = .unknown
        } catch {
            borrowerStatus = .error
            borrowerLookupErrorMessage = (error as? BorrowerLookupError)?.localizedDescription
                ?? error.localizedDescription
            // Alert is triggered by onChange(of: borrowerLookupErrorMessage)
        }
    }

    // MARK: - Helpers

    private func fmt(_ raw: String) -> String {
        guard let v = Double(raw) else { return raw }
        let l = v / 100_000
        if l >= 100 { return "\(Int(l/100))Cr" }
        return v.truncatingRemainder(dividingBy: 100_000) == 0 ? "\(Int(l))L" : "\(String(format: "%.1f", l))L"
    }

    private func docIcon(_ type: DocumentRequirementType) -> String {
        switch type {
        case .identity:   return "person.text.rectangle"
        case .income:     return "indianrupeesign.circle"
        case .collateral: return "building.columns"
        default:          return "doc.text"
        }
    }
}

extension AddLeadView.BorrowerStatus: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.unknown, .unknown), (.checking, .checking),
             (.notFound, .notFound), (.error, .error): return true
        case (.found(let a, let b), .found(let c, let d)): return a == c && b == d
        default: return false
        }
    }
}
