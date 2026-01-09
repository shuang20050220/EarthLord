//
//  Item.swift
//  EarthLord
//
//  Created by Mandy on 2026/1/9.
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
