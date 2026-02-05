//
//  ChatSession.swift
//  AIPaperReader
//
//  Created by JohnnyChan on 2/4/26.
//

import Foundation
import SwiftData

@Model
final class ChatSession {
    var id: UUID
    var documentId: String // URL absoluteString or unique ID
    var title: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade) var messages: [ChatMessageModel] = []

    init(documentId: String, title: String = "New Chat") {
        self.id = UUID()
        self.documentId = documentId
        self.title = title
        self.createdAt = Date()
    }
}

@Model
final class ChatMessageModel {
    var id: UUID
    var sessionId: UUID
    var roleRawValue: String
    var content: String
    var timestamp: Date
    
    // Reverse relationship (optional, but good for query)
    var session: ChatSession?

    init(role: MessageRole, content: String, timestamp: Date = Date()) {
        self.id = UUID()
        self.sessionId = UUID() // Temporary, will be linked to session
        self.roleRawValue = role.rawValue
        self.content = content
        self.timestamp = timestamp
    }
    
    var role: MessageRole {
        get { MessageRole(rawValue: roleRawValue) ?? .user }
        set { roleRawValue = newValue.rawValue }
    }
}
