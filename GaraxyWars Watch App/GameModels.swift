//
//  GameModels.swift
//  GaraxyWars Watch App
//
//  Created by satoshi goto on 7/1/26.
//

import SwiftUI

// プレイヤーの宇宙船
struct Player {
    var position: CGPoint
    let size: CGSize = CGSize(width: 12, height: 12) // 小さくした
    var health: Int = 3
    
    init(position: CGPoint) {
        self.position = position
    }
}

// 敵の種類
enum EnemyType: Int, CaseIterable {
    case small = 0    // 小さな敵（速い、弾を打たない）
    case medium = 1  // 中サイズの敵（普通、たまに弾を打つ）
    case large = 2   // 大きな敵（遅い、頻繁に弾を打つ）
    case boss = 3     // ボス（遅い、常に弾を打つ）
    case homing = 4   // ホーミング敵（プレイヤーに向かってくる）
    
    var size: CGSize {
        switch self {
        case .small: return CGSize(width: 10, height: 10)
        case .medium: return CGSize(width: 14, height: 14)
        case .large: return CGSize(width: 18, height: 18)
        case .boss: return CGSize(width: 22, height: 22)
        case .homing: return CGSize(width: 12, height: 12)
        }
    }
    
    var speedRange: ClosedRange<CGFloat> {
        switch self {
        case .small: return 1.5...2.5
        case .medium: return 1.0...1.8
        case .large: return 0.6...1.2
        case .boss: return 0.4...0.8
        case .homing: return 1.2...1.8
        }
    }
    
    var fireInterval: TimeInterval? {
        switch self {
        case .small: return nil // 弾を打たない
        case .medium: return 2.0
        case .large: return 1.0
        case .boss: return 0.5
        case .homing: return nil // ホーミング敵は弾を打たない
        }
    }
    
    var isHoming: Bool {
        return self == .homing
    }
    
    var color: Color {
        switch self {
        case .small: return .red
        case .medium: return .orange
        case .large: return .purple
        case .boss: return .pink
        case .homing: return .green
        }
    }
    
    var score: Int {
        switch self {
        case .small: return 10
        case .medium: return 20
        case .large: return 30
        case .boss: return 50
        case .homing: return 25
        }
    }
}

// 敵の宇宙船
struct Enemy {
    var position: CGPoint
    let type: EnemyType
    let size: CGSize
    var speed: CGFloat
    var lastFireTime: Date = Date()
    var health: Int
    var verticalDirection: CGFloat = 1.0 // 上下移動の方向（1.0 = 下、-1.0 = 上）
    var verticalOffset: CGFloat = 0.0 // 上下移動のオフセット
    var hasStoppedAtCenter: Bool = false // 中央で止まったかどうか（medium用）
    var stopTime: Date? = nil // 中央で止まった時刻（medium用）
    
    init(position: CGPoint, type: EnemyType) {
        self.position = position
        self.type = type
        self.size = type.size
        self.speed = CGFloat.random(in: type.speedRange)
        // ボスは3回、mediumは2回打たないと倒せない
        if type == .boss {
            self.health = 3
        } else if type == .medium {
            self.health = 2
        } else {
            self.health = 1
        }
    }
    
    func canFire() -> Bool {
        guard let interval = type.fireInterval else { return false }
        return Date().timeIntervalSince(lastFireTime) >= interval
    }
    
    var isBoss: Bool {
        return type == .boss
    }
    
    var isMedium: Bool {
        return type == .medium
    }
}

// 弾丸
struct Bullet {
    var position: CGPoint
    let size: CGSize = CGSize(width: 8, height: 4) // 横スクロール用（横長）
    let speed: CGFloat
    let isPlayerBullet: Bool
    var velocityX: CGFloat = 0.0 // X方向の速度
    var velocityY: CGFloat = 0.0 // Y方向の速度（斜め発射用）
    
    init(position: CGPoint, isPlayerBullet: Bool = true, velocityX: CGFloat = 0.0, velocityY: CGFloat = 0.0) {
        self.position = position
        self.isPlayerBullet = isPlayerBullet
        if isPlayerBullet {
            // プレイヤーの弾は速く、右方向
            self.speed = 4.0
            self.velocityX = 4.0
            self.velocityY = 0.0
        } else {
            // 敵の弾
            if velocityX != 0.0 || velocityY != 0.0 {
                // 斜め発射の場合
                self.velocityX = velocityX
                self.velocityY = velocityY
                self.speed = sqrt(velocityX * velocityX + velocityY * velocityY)
            } else {
                // 通常の弾（左方向）
                self.speed = 2.5
                self.velocityX = -2.5
                self.velocityY = 0.0
            }
        }
    }
}

// 衝突判定のヘルパー関数
func checkCollision(_ rect1: CGRect, _ rect2: CGRect) -> Bool {
    return rect1.intersects(rect2)
}

