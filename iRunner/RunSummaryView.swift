//
//  RunSummaryView.swift
//  iRunner
//
//  Created by 宋壕杰 on 2024/10/2.
//

import SwiftUI

struct Achievement: Identifiable {
    let id = UUID()
    let type: AchievementType
    let value: Double
    let title: String
    let description: String
}

enum AchievementType {
    case distance
    case time
    case pace
}
struct RunSummaryView: View {
    let distance: Double
    let time: Int
    let pace: Double
    
    @Binding var isPresented: Bool
    var onDismiss: () -> Void
    
    var nextAchievement: (milestone: Int, progress: Double) {
        let milestones = [1, 5, 10, 21, 42]
        let nextMilestone = milestones.first { $0 > Int(distance) } ?? milestones.last!
        let progress = distance / Double(nextMilestone)
        return (nextMilestone, progress)
    }
    
    var achievements: [Achievement] {
        getAchievements(distance: distance, time: time, pace: pace)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("跑步总结")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "figure.run")
                        Text("总距离: \(distance, specifier: "%.2f") 公里")
                    }
                    HStack {
                        Image(systemName: "clock")
                        Text("总时长: \(formatTime(seconds: time))")
                    }
                    HStack {
                        Image(systemName: "speedometer")
                        Text("平均配速: \(pace, specifier: "%.2f") 分钟/公里")
                    }
                }
                .font(.title2)
                
                Divider()
                
                VStack(spacing: 10) {
                    Text("成就进度")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    ProgressView(value: nextAchievement.progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .green))
                    
                    Text("距离下一个成就还有 \(nextAchievement.milestone - Int(distance)) 公里")
                        .font(.subheadline)
                }
                
                if !achievements.isEmpty {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("获得的成就:")
                            .font(.headline)
                        ForEach(achievements) { achievement in
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                VStack(alignment: .leading) {
                                    Text(achievement.title)
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                    Text(achievement.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                
                Spacer()
                
                Button("完成") {
                    isPresented = false
                    onDismiss()
                }
                .font(.title2)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding()
        }
    }
    func getAchievements(distance: Double, time: Int, pace: Double) -> [Achievement] {
        var achievements: [Achievement] = []
        
        // Distance achievements
        if distance >= 5 {
            achievements.append(Achievement(type: .distance, value: 5, title: "5公里勇士", description: "完成5公里跑步"))
        }
        if distance >= 10 {
            achievements.append(Achievement(type: .distance, value: 10, title: "10公里冠军", description: "完成10公里跑步"))
        }
        
        // Time achievements
        if time >= 1800 { // 30 minutes
            achievements.append(Achievement(type: .time, value: 30, title: "持久跑者", description: "跑步持续30分钟"))
        }
        if time >= 3600 { // 60 minutes
            achievements.append(Achievement(type: .time, value: 60, title: "马拉松精神", description: "跑步持续60分钟"))
        }
        
        // Pace achievements
        if pace <= 5 {
            achievements.append(Achievement(type: .pace, value: 5, title: "疾风步伐", description: "平均配速低于5分钟/公里"))
        }
        if pace <= 4 {
            achievements.append(Achievement(type: .pace, value: 4, title: "闪电速度", description: "平均配速低于4分钟/公里"))
        }
        
        return achievements
    }
}

func formatTime(seconds: Int) -> String {
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60
    let seconds = (seconds % 3600) % 60
    return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
}
