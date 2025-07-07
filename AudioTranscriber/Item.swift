//
//  Item.swift
//  AudioTranscriber
//
//  Created by Asawari Tajne on 06/07/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
