//
//  SQUserIcon.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/8/25.
//

import SwiftUI

// PTD finish this view to load an actual image

struct SQUserIcon: View {
    let user: SQUser
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(SQColor.backgroundTertiaryLight.color))
            
            Text((user.name.first ?? .init("")).uppercased())
                .sqFont(.bodySemiBold)
        }
        .frame(width: 34, height: 34)
    }
}
