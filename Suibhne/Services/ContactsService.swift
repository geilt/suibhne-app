// ContactsService.swift
// Contacts.framework bridge

import Foundation
import Contacts

public actor ContactsService {
    public static let shared = ContactsService()
    
    private let store = CNContactStore()
    private var authorized = false
    
    private init() {}
    
    // MARK: - Authorization
    
    public func requestAccess() async throws {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        
        switch status {
        case .authorized:
            authorized = true
            log.info("Contacts access already authorized")
            
        case .notDetermined:
            log.info("Requesting Contacts access...")
            authorized = try await store.requestAccess(for: .contacts)
            log.info("Contacts access \(authorized ? "granted" : "denied")")
            
        case .denied, .restricted:
            log.warn("Contacts access denied or restricted")
            throw ContactsError.accessDenied
            
        @unknown default:
            throw ContactsError.unknown
        }
    }
    
    private func ensureAuthorized() async throws {
        if !authorized {
            try await requestAccess()
        }
        guard authorized else {
            throw ContactsError.accessDenied
        }
    }
    
    // MARK: - Search
    
    public func search(query: String) async throws -> [Contact] {
        try await ensureAuthorized()
        
        log.debug("Searching contacts", context: ["query": query])
        
        let predicate = CNContact.predicateForContacts(matchingName: query)
        let keys: [CNKeyDescriptor] = [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactNoteKey as CNKeyDescriptor
        ]
        
        let cnContacts = try store.unifiedContacts(matching: predicate, keysToFetch: keys)
        
        let contacts = cnContacts.map { mapContact($0) }
        log.info("Search complete", context: ["query": query, "results": contacts.count])
        
        return contacts
    }
    
    // MARK: - Get
    
    public func get(id: String) async throws -> Contact? {
        try await ensureAuthorized()
        
        let keys: [CNKeyDescriptor] = [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactNoteKey as CNKeyDescriptor
        ]
        
        do {
            let cnContact = try store.unifiedContact(withIdentifier: id, keysToFetch: keys)
            return mapContact(cnContact)
        } catch {
            log.warn("Contact not found", context: ["id": id])
            return nil
        }
    }
    
    // MARK: - List
    
    public func list(limit: Int = 100) async throws -> [Contact] {
        try await ensureAuthorized()
        
        let keys: [CNKeyDescriptor] = [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor
        ]
        
        var contacts: [Contact] = []
        let request = CNContactFetchRequest(keysToFetch: keys)
        
        try store.enumerateContacts(with: request) { cnContact, stop in
            contacts.append(mapContact(cnContact))
            if contacts.count >= limit {
                stop.pointee = true
            }
        }
        
        log.info("Listed contacts", context: ["count": contacts.count, "limit": limit])
        return contacts
    }
    
    // MARK: - Create
    
    public func create(name: String, phone: String?, email: String?, organization: String?) async throws -> Contact {
        try await ensureAuthorized()
        
        let contact = CNMutableContact()
        
        // Parse name (simple split on space)
        let nameParts = name.split(separator: " ", maxSplits: 1)
        contact.givenName = String(nameParts.first ?? "")
        if nameParts.count > 1 {
            contact.familyName = String(nameParts[1])
        }
        
        if let org = organization {
            contact.organizationName = org
        }
        
        if let phone = phone {
            contact.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: phone))]
        }
        
        if let email = email {
            contact.emailAddresses = [CNLabeledValue(label: CNLabelHome, value: email as NSString)]
        }
        
        let saveRequest = CNSaveRequest()
        saveRequest.add(contact, toContainerWithIdentifier: nil)
        
        try store.execute(saveRequest)
        
        log.info("Created contact", context: ["name": name, "id": contact.identifier])
        
        return Contact(
            id: contact.identifier,
            name: name,
            organization: organization,
            phones: phone.map { [$0] } ?? [],
            emails: email.map { [$0] } ?? []
        )
    }
    
    // MARK: - Update
    
    public func update(id: String, addPhone: String?, addEmail: String?, setOrganization: String?, setNotes: String?) async throws -> Contact {
        try await ensureAuthorized()
        
        let keys: [CNKeyDescriptor] = [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactNoteKey as CNKeyDescriptor
        ]
        
        let cnContact = try store.unifiedContact(withIdentifier: id, keysToFetch: keys)
        let mutableContact = cnContact.mutableCopy() as! CNMutableContact
        
        if let phone = addPhone {
            let existingPhones = Set(mutableContact.phoneNumbers.map { $0.value.stringValue.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression) })
            let normalizedNew = phone.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
            
            if !existingPhones.contains(normalizedNew) {
                mutableContact.phoneNumbers.append(CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: phone)))
            }
        }
        
        if let email = addEmail {
            let existingEmails = Set(mutableContact.emailAddresses.map { ($0.value as String).lowercased() })
            
            if !existingEmails.contains(email.lowercased()) {
                mutableContact.emailAddresses.append(CNLabeledValue(label: CNLabelHome, value: email as NSString))
            }
        }
        
        if let org = setOrganization {
            mutableContact.organizationName = org
        }
        
        if let notes = setNotes {
            mutableContact.note = notes
        }
        
        let saveRequest = CNSaveRequest()
        saveRequest.update(mutableContact)
        
        try store.execute(saveRequest)
        
        log.info("Updated contact", context: ["id": id])
        
        return mapContact(mutableContact)
    }
    
    // MARK: - Delete
    
    public func delete(id: String) async throws -> Bool {
        try await ensureAuthorized()
        
        let keys: [CNKeyDescriptor] = [CNContactIdentifierKey as CNKeyDescriptor]
        let cnContact = try store.unifiedContact(withIdentifier: id, keysToFetch: keys)
        let mutableContact = cnContact.mutableCopy() as! CNMutableContact
        
        let saveRequest = CNSaveRequest()
        saveRequest.delete(mutableContact)
        
        try store.execute(saveRequest)
        
        log.info("Deleted contact", context: ["id": id])
        
        return true
    }
    
    // MARK: - Mapping
    
    private func mapContact(_ cnContact: CNContact) -> Contact {
        let name = [cnContact.givenName, cnContact.familyName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        
        let phones = cnContact.phoneNumbers.map { $0.value.stringValue }
        let emails = cnContact.emailAddresses.map { $0.value as String }
        
        return Contact(
            id: cnContact.identifier,
            name: name.isEmpty ? "(No Name)" : name,
            organization: cnContact.organizationName.isEmpty ? nil : cnContact.organizationName,
            phones: phones,
            emails: emails,
            notes: cnContact.note.isEmpty ? nil : cnContact.note
        )
    }
}

// MARK: - Errors

public enum ContactsError: LocalizedError {
    case accessDenied
    case notFound
    case unknown
    
    public var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Contacts access denied. Please grant access in System Settings > Privacy & Security > Contacts."
        case .notFound:
            return "Contact not found."
        case .unknown:
            return "An unknown error occurred."
        }
    }
}
