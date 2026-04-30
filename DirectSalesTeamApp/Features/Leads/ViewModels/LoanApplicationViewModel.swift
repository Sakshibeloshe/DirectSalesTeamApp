// LoanApplicationViewModel.swift
// Direct Sales Team App

import Foundation
import Combine
import SwiftUI
import GRPCCore

@available(iOS 18.0, *)
@MainActor
final class LoanApplicationViewModel: ObservableObject {
    let lead: Lead
    
    // KYC state
    @Published var aadhaarNumber = ""
    @Published var aadhaarConsentGranted = false
    @Published var aadhaarReferenceID = ""
    @Published var aadhaarOTP = ""
    @Published var isAadhaarVerified = false
    @Published var aadhaarVerifiedName = ""
    @Published var aadhaarVerifiedDOB = ""
    @Published var aadhaarVerifiedGender = ""
    
    @Published var panNumber = ""
    @Published var panConsentGranted = false
    @Published var isPanVerified = false
    @Published var panNameAsPerVerification = ""
    @Published var panDateOfBirth = ""
    
    // Document upload state
    @Published var uploadedDocuments: [UUID: String] = [:]  // docID -> mediaFileID
    @Published var uploadingDocumentIDs: Set<UUID> = []
    
    // Application submission state
    @Published var isSubmitting = false
    @Published var submittedApplicationID: String?
    @Published var submissionError: String?
    
    // MARK: - Loan Products State
    @Published var loanProducts: [LoanProduct] = []
    @Published var selectedProductID: String?
    
    // MARK: - Branches State
    @Published var branches: [BorrowerBranch] = []
    @Published var selectedBranchID: String?
    
    // Loading / error state
    @Published var isLoading = false
    @Published var loadingMessage = ""
    @Published var errorMessage: String?
    
    private let kycRepository: KYCRepository
    private let mediaRepository: MediaRepository
    private let loanService: LoanServiceProtocol
    private let branchService: BranchServiceProtocol
    private let authService: AuthGRPCClient
    /// Called whenever KYC state changes so the caller can persist the updated Lead.
    var onLeadUpdated: ((Lead) -> Void)?
    var onDocumentUploaded: ((UUID, String, String) -> Void)?
    
    init(
        lead: Lead,
        kycRepository: KYCRepository = KYCRepository(),
        mediaRepository: MediaRepository = MediaRepository(),
        loanService: LoanServiceProtocol = LoanGRPCClient(),
        branchService: BranchServiceProtocol = BranchGRPCClient(),
        authService: AuthGRPCClient = AuthGRPCClient()
    ) {
        self.lead = lead
        self.kycRepository = kycRepository
        self.mediaRepository = mediaRepository
        self.loanService = loanService
        self.branchService = branchService
        self.authService = authService
        // Restore persisted KYC state
        self.isAadhaarVerified = lead.isAadhaarKycVerified
        self.isPanVerified = lead.isPanKycVerified
        self.aadhaarVerifiedName = lead.aadhaarVerifiedName
        self.aadhaarVerifiedDOB = lead.aadhaarVerifiedDOB
    }
    
    var normalizedAadhaar: String {
        aadhaarNumber.filter(\.isNumber)
    }
    
    var normalizedPAN: String {
        panNumber.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Aadhaar Actions
    
    func sendAadhaarOTP() async -> Bool {
        guard !isLoading else { return false }
        
        isLoading = true
        loadingMessage = "Initiating Aadhaar KYC..."
        errorMessage = nil
        
        // DEBUG – remove after confirming
        print("[KYC] lead.borrowerUserID = \(lead.borrowerUserID ?? "NIL")")
        print("[KYC] lead.borrowerProfileID = \(lead.borrowerProfileID ?? "NIL")")
        
        do {
            try await kycRepository.recordUserConsent(type: .aadhaar, borrowerUserID: lead.borrowerUserID)
            let result = try await kycRepository.initiateAadhaarKyc(aadhaarNumber: normalizedAadhaar, borrowerUserID: lead.borrowerUserID)
            self.aadhaarReferenceID = result.referenceID
            isLoading = false
            return true
        } catch {
            isLoading = false
            if let kycError = error as? KYCError {
                errorMessage = kycError.errorDescription
            } else {
                errorMessage = error.localizedDescription
            }
            return false
        }
    }
    
    func verifyAadhaarOTP() async -> Bool {
        guard !isLoading, !aadhaarReferenceID.isEmpty, aadhaarOTP.count == 6 else { return false }
        
        isLoading = true
        loadingMessage = "Verifying OTP..."
        errorMessage = nil
        
        do {
            let result = try await kycRepository.verifyAadhaarKycOtp(
                referenceID: aadhaarReferenceID,
                otp: aadhaarOTP,
                borrowerUserID: lead.borrowerUserID
            )
            
            if result.isValid {
                isAadhaarVerified = true
                aadhaarVerifiedName = result.verifiedName
                aadhaarVerifiedDOB = result.verifiedDateOfBirth
                aadhaarVerifiedGender = result.verifiedGender
                persistKYCState()
                isLoading = false
                return true
            } else {
                isLoading = false
                errorMessage = result.message.isEmpty ? "Invalid OTP. Please try again." : result.message
                return false
            }
        } catch {
            isLoading = false
            if let kycError = error as? KYCError {
                errorMessage = kycError.errorDescription
            } else {
                errorMessage = error.localizedDescription
            }
            return false
        }
    }
    
    // MARK: - PAN Actions
    
    func verifyPAN() async -> Bool {
        guard !isLoading else { return false }
        
        isLoading = true
        loadingMessage = "Verifying PAN..."
        errorMessage = nil
        
        do {
            try await kycRepository.recordUserConsent(type: .pan, borrowerUserID: lead.borrowerUserID)
            let result = try await kycRepository.verifyPanKyc(
                pan: normalizedPAN,
                nameAsPerPan: aadhaarVerifiedName,
                dateOfBirth: aadhaarVerifiedDOB,
                borrowerUserID: lead.borrowerUserID
            )
            
            if result.isValid {
                isPanVerified = true
                persistKYCState()
                isLoading = false
                return true
            } else {
                isLoading = false
                errorMessage = result.message.isEmpty ? "PAN verification failed." : result.message
                return false
            }
        } catch {
            isLoading = false
            if let kycError = error as? KYCError {
                errorMessage = kycError.errorDescription
            } else {
                errorMessage = error.localizedDescription
            }
            return false
        }
    }
    
    // MARK: - Document Upload
    
    func uploadDocument(id: UUID, data: Data, fileName: String, contentType: String) async -> Bool {
        uploadingDocumentIDs.insert(id)
        errorMessage = nil
        
        do {
            let uploadedMedia = try await mediaRepository.uploadMedia(
                fileData: data,
                fileName: fileName,
                contentType: contentType,
                note: "borrower_document"
            )
            
            uploadedDocuments[id] = uploadedMedia.mediaID
            onDocumentUploaded?(id, fileName, uploadedMedia.mediaID)
            uploadingDocumentIDs.remove(id)
            return true
        } catch {
            uploadingDocumentIDs.remove(id)
            errorMessage = "Failed to upload document: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Submit Application
    
    func submitApplication(
        productID: String,
        branchID: String?,
        requestedAmount: String,
        tenureMonths: Int,
        leadDocuments: [LeadDocument]
    ) async -> Bool {
        guard !isSubmitting else { return false }
        
        isSubmitting = true
        submissionError = nil
        
        do {
            // 0. Ensure products are loaded (needed for document mapping)
            if loanProducts.isEmpty {
                await fetchLoanProducts()
            }
            
            // 1. Resolve Branch ID if not provided
            let finalBranchID: String
            if let bID = branchID, !bID.isEmpty {
                finalBranchID = bID
            } else {
                finalBranchID = try await fetchDstBranchID()
            }

            // 2. Always create a new application on the backend (it will be initialized as .submitted)
            // This avoids the 'invalid dst status transition' error for DRAFT -> SUBMITTED.
            let application = try await loanService.createLoanApplication(
                primaryBorrowerProfileId: lead.borrowerProfileID ?? "",
                loanProductId: productID,
                branchId: finalBranchID,
                requestedAmount: requestedAmount,
                tenureMonths: tenureMonths
            )
            let targetApplicationID = application.id
            
            let product = self.loanProducts.first(where: { $0.id == productID })
            var availableReqDocs = product?.requiredDocuments ?? []
            
            // 3. Add each uploaded document
            for (docID, mediaFileID) in uploadedDocuments {
                let leadDoc = leadDocuments.first(where: { $0.id == docID })
                var matchedReqDocID: String?
                
                if let leadDoc = leadDoc {
                    let expectedType: DocumentRequirementType
                    switch leadDoc.kind {
                    case .aadhaar, .pan: expectedType = .identity
                    case .supporting: expectedType = .income
                    }
                    
                    if let idx = availableReqDocs.firstIndex(where: { $0.requirementType == expectedType }) {
                        matchedReqDocID = availableReqDocs[idx].id
                        availableReqDocs.remove(at: idx)
                    }
                }
                
                if matchedReqDocID == nil && !availableReqDocs.isEmpty {
                    matchedReqDocID = availableReqDocs.removeFirst().id
                }
                
                // CRITICAL FIX: Do not send random UUID if mapping fails. 
                // Only proceed if we have a valid requiredDocId for this product.
                guard let finalRequiredDocId = matchedReqDocID else {
                    print("DEBUG: Skipping document \(docID) as no matching requirement found in product \(productID)")
                    continue
                }
                
                _ = try await loanService.addApplicationDocument(
                    applicationId: targetApplicationID,
                    borrowerProfileId: lead.borrowerProfileID ?? "",
                    requiredDocId: finalRequiredDocId,
                    mediaFileId: mediaFileID
                )
            }
            
            // 4. Cleanup old draft
            // Since DRAFTs are now local, we just delete them locally.
            // If it's a legacy backend DRAFT, we cancel it on the backend.
            if let oldDraftID = lead.applicationID, !oldDraftID.isEmpty, oldDraftID != targetApplicationID {
                print("DEBUG: Cleaning up original draft lead \(oldDraftID)")
                if oldDraftID.hasPrefix("LOCAL-") {
                    LocalLeadStore.shared.remove(id: oldDraftID)
                } else {
                    try? await loanService.deleteLoanApplication(applicationId: oldDraftID)
                }
            }
            
            // 6. Persist name for the new/updated application ID so it shows up in the Applications list
            LeadMetadataStore().save(
                applicationID: targetApplicationID,
                name: lead.name,
                phone: lead.phone,
                email: lead.email,
                loanProductID: productID,
                profileID: lead.borrowerProfileID
            )
            
            self.submittedApplicationID = targetApplicationID
            isSubmitting = false
            
            // Post notification for cross-tab sync
            NotificationCenter.default.post(name: .dstDataChanged, object: nil)
            
            return true
        } catch {
            isSubmitting = false
            submissionError = "Failed to submit application: \(error.localizedDescription)"
            return false
        }
    }

    private func fetchDstBranchID() async throws -> String {
        guard let token = try TokenStore.shared.accessToken(), !token.isEmpty else {
            throw LoanError.unauthenticated
        }
        let (options, metadata) = AuthCallOptionsFactory.authenticated(accessToken: token)
        let response = try await authService.getMyProfile(request: .init(), metadata: metadata, options: options)
        
        if case .dstProfile(let dstProfile) = response.profile {
            let bID = dstProfile.branch.branchID.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if !bID.isEmpty { return bID }
        }
        throw LoanError.preconditionFailed("DST branch is missing in profile.")
    }
    
    // MARK: - Private Helpers
    
    func fetchLoanProducts() async {
        do {
            let products = try await loanService.listLoanProducts(limit: 50, offset: 0)
            DispatchQueue.main.async {
                self.loanProducts = products
                if self.selectedProductID == nil {
                    self.selectedProductID = products.first?.id
                }
            }
        } catch {
            print("Failed to fetch loan products: \(error)")
        }
    }
    
    func fetchBranches() async {
        do {
            let fetchedBranches = try await branchService.listBranches(limit: 50, offset: 0)
            DispatchQueue.main.async {
                self.branches = fetchedBranches
                if self.selectedBranchID == nil {
                    self.selectedBranchID = fetchedBranches.first?.id
                }
            }
        } catch {
            print("Failed to fetch branches: \(error)")
        }
    }

    /// Returns the required documents for a specific product ID.
    /// Called by LeadDetailView after products are fetched to pre-populate the document list.
    func requiredDocuments(for productID: String?) -> [ProductRequiredDocument] {
        guard let productID else { return [] }
        return loanProducts.first(where: { $0.id == productID })?.requiredDocuments ?? []
    }
    
    private func persistKYCState() {
        var updated = lead
        updated.isAadhaarKycVerified = isAadhaarVerified
        updated.isPanKycVerified = isPanVerified
        updated.aadhaarVerifiedName = aadhaarVerifiedName
        updated.aadhaarVerifiedDOB = aadhaarVerifiedDOB
        onLeadUpdated?(updated)
    }
    
}
