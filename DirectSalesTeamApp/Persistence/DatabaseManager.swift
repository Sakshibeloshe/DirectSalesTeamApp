import GRDB
import Foundation

final class DatabaseManager {
    static let shared = try! DatabaseManager()
    let dbPool: DatabasePool

    private init() throws {
        let folder = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )
        let dbURL = folder.appendingPathComponent("dst_local.db")
        dbPool = try DatabasePool(path: dbURL.path)
        try migrate()
    }

    private func migrate() throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.create(table: "leads") { t in
                t.primaryKey("id", .text)
                t.column("applicationID", .text)
                t.column("name", .text).notNull()
                t.column("phone", .text).notNull()
                t.column("email", .text).notNull().defaults(to: "")
                t.column("borrowerProfileID", .text)
                t.column("borrowerUserID", .text)
                t.column("loanType", .text).notNull()
                t.column("loanAmount", .double).notNull()
                t.column("status", .text).notNull().defaults(to: "New")
                t.column("createdAt", .double).notNull()
                t.column("updatedAt", .double).notNull()
                t.column("isAadhaarKycVerified", .boolean).notNull().defaults(to: false)
                t.column("isPanKycVerified", .boolean).notNull().defaults(to: false)
                t.column("aadhaarVerifiedName", .text).notNull().defaults(to: "")
                t.column("aadhaarVerifiedDOB", .text).notNull().defaults(to: "")
                t.column("isDeleted", .boolean).notNull().defaults(to: false)
            }
            try db.create(table: "lead_documents") { t in
                t.primaryKey("id", .text)
                t.column("leadID", .text).notNull().references("leads", onDelete: .cascade)
                t.column("name", .text).notNull()
                t.column("kind", .text).notNull()
                t.column("statusType", .text).notNull().defaults(to: "notUploaded")
                t.column("uploadedFileName", .text)
                t.column("mediaFileID", .text)
                t.column("requestedAt", .double)
                t.column("uploadedAt", .double)
                t.column("verifiedAt", .double)
                t.column("verifiedName", .text)
                t.column("verifiedDocNumber", .text)
                t.column("verifiedDOB", .text)
                t.column("verificationNote", .text)
            }
            try db.create(table: "lead_metadata") { t in
                t.primaryKey("applicationID", .text)
                t.column("name", .text).notNull()
                t.column("phone", .text).notNull()
                t.column("email", .text).notNull().defaults(to: "")
            }
        }
        migrator.registerMigration("v2_userdefaults_migration") { db in
            // One-time migration from UserDefaults LocalLeadStore
            let key = "dst.leads.local.list"
            guard let data = UserDefaults.standard.data(forKey: key),
                  let legacyLeads = try? JSONDecoder().decode([Lead].self, from: data)
            else { return }
            for lead in legacyLeads {
                let record = LeadRecord(from: lead)
                try record.insert(db, onConflict: .ignore)
            }
            UserDefaults.standard.removeObject(forKey: key)
        }
        try migrator.migrate(dbPool)
    }
}
