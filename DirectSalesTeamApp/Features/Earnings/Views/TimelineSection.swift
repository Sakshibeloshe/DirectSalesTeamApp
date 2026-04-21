//
//  TimelineSection.swift
//  DirectSalesTeamApp
//
//  Created by Apple on 17/04/26.
//
import SwiftUI

struct TimelineSection: View {
    let steps: [TimelineStep]
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Payment Timeline")
                .font(AppFont.headline())
            
            ForEach(steps, id: \.title) { step in
                HStack(spacing: 12) {
                    
                    Circle()
                        .fill(step.isCompleted ? Color.statusApproved : Color.borderMedium)
                        .frame(width: 10, height: 10)
                    
                    Text(step.title)
                        .font(AppFont.body())
                        .foregroundColor(step.isCompleted ? .textPrimary : .textSecondary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color.surfacePrimary)
        .cornerRadius(AppRadius.lg)
        .cardShadow()
    }
}

