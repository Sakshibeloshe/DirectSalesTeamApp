import GRDB
import Foundation

struct LeadRecord: Codable, FetchableRecord, PersistableRecord {
    static var databaseTableName = "leads"
    var id: String
    var applicationID: String?
    var name: String
    var phone: String
    var email: String
    var borrowerProfileID: String?
    var borrowerUserID: String?
    var loanType: String
    var loanAmount: Double
    var status: String
    var createdAt: Double
    var updatedAt: Double
    var isAadhaarKycVerified: Bool
    var isPanKycVerified: Bool
    var aadhaarVerifiedName: String
    var aadhaarVerifiedDOB: String
    var isDeleted: Bool

    init(from lead: Lead) {
        id = lead.id; applicationID = lead.applicationID
        name = lead.name; phone = lead.phone; email = lead.email
        borrowerProfileID = lead.borrowerProfileID
        borrowerUserID = lead.borrowerUserID
        loanType = lead.loanType.rawValue; loanAmount = lead.loanAmount
        status = lead.status.rawValue
        createdAt = lead.createdAt.timeIntervalSince1970
        updatedAt = lead.updatedAt.timeIntervalSince1970
        isAadhaarKycVerified = lead.isAadhaarKycVerified
        isPanKycVerified = lead.isPanKycVerified
        aadhaarVerifiedName = lead.aadhaarVerifiedName
        aadhaarVerifiedDOB = lead.aadhaarVerifiedDOB
        isDeleted = false
    }

    func toLead() -> Lead? {
        guard let lt = LoanType(rawValue: loanType),
              let st = LeadStatus(rawValue: status) else { return nil }
        return Lead(
            id: id, applicationID: applicationID,
            name: name, phone: phone, email: email,
            borrowerProfileID: borrowerProfileID,
            borrowerUserID: borrowerUserID,
            loanType: lt, loanAmount: loanAmount, status: st,
            createdAt: Date(timeIntervalSince1970: createdAt),
            updatedAt: Date(timeIntervalSince1970: updatedAt),
            isAadhaarKycVerified: isAadhaarKycVerified,
            isPanKycVerified: isPanKycVerified,
            aadhaarVerifiedName: aadhaarVerifiedName,
            aadhaarVerifiedDOB: aadhaarVerifiedDOB
        )
    }
}

final class SQLiteLeadStore {
    private let db: DatabasePool
    init(db: DatabasePool = DatabaseManager.shared.dbPool) { self.db = db }

    func all() -> [Lead] {
        (try? db.read { db in
            try LeadRecord.filter(Column("isDeleted") == false).fetchAll(db)
        })?.compactMap { $0.toLead() } ?? []
    }

    func save(_ lead: Lead) {
        try? db.write { db in try LeadRecord(from: lead).save(db) }
    }

    func remove(id: String) {
        try? db.write { db in
            try LeadRecord.filter(Column("id") == id)
                .updateAll(db, Column("isDeleted").set(to: true))
        }
    }
}
