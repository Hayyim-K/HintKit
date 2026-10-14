//
//  Hint.swift
//  HintKit
//
//  Created by Hayyim on 25/11/2024.
//

import Foundation

/// The content of a contextual hint. Localize strings in the consuming app.
public struct Hint: Codable, Equatable, Sendable {

    public var id: String
    public var title: String
    public var message: String
    public var imageName: String
    public var arrows: [Int]

    /// Leave `arrows` empty to let the presenter choose the direction.
    /// Legacy tags are 0–2 for upper arrows and 3–5 for lower arrows.
    public init(id: String, title: String = "", message: String,
                imageName: String = "", arrows: [Int] = []) {
        self.id = id
        self.title = title
        self.message = message
        self.imageName = imageName
        self.arrows = arrows
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, message, imageName, arrows
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        title = try values.decodeIfPresent(String.self, forKey: .title) ?? ""
        message = try values.decode(String.self, forKey: .message)
        imageName = try values.decodeIfPresent(String.self, forKey: .imageName) ?? ""
        arrows = try values.decodeIfPresent([Int].self, forKey: .arrows) ?? []
    }

}
