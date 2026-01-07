//
//  GameEngine.swift
//  GaraxyWars Watch App
//
//  Created by satoshi goto on 7/1/26.
//

import SwiftUI
import Combine

class GameEngine: ObservableObject {
    @Published var player: Player
    @Published var enemies: [Enemy] = []
    @Published var playerBullets: [Bullet] = []
    @Published var enemyBullets: [Bullet] = []
    @Published var score: Int = 0
    @Published var gameState: GameState = .menu
    @Published var gameOver: Bool = false
    
    private var timer: Timer?
    private var enemySpawnTimer: Timer?
    private var autoFireTimer: Timer?
    private var lastEnemySpawnTime: Date = Date()
    private let enemySpawnInterval: TimeInterval = 1.5
    private let autoFireInterval: TimeInterval = 0.3
    
    var screenWidth: CGFloat = 184  // Apple Watch Series 9 の画面幅
    var screenHeight: CGFloat = 224 // Apple Watch Series 9 の画面高さ
    
    func updateScreenSize(width: CGFloat, height: CGFloat) {
        screenWidth = width
        screenHeight = height
        // プレイヤーの位置を調整（左側に固定）
        player.position.x = 30
        if player.position.y > screenHeight {
            player.position.y = screenHeight / 2
        }
    }
    
    enum GameState {
        case menu
        case playing
        case paused
        case gameOver
    }
    
    init() {
        let initialPosition = CGPoint(x: 30, y: 112) // 左側中央
        self.player = Player(position: initialPosition)
    }
    
    func startGame() {
        gameState = .playing
        gameOver = false
        score = 0
        player.health = 1 // 即死
        enemies.removeAll()
        playerBullets.removeAll()
        enemyBullets.removeAll()
        
        let initialPosition = CGPoint(x: 30, y: screenHeight / 2) // 左側中央
        player = Player(position: initialPosition)
        
        // ゲームループを開始
        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            self?.update()
        }
        
        // 敵の生成タイマー
        enemySpawnTimer = Timer.scheduledTimer(withTimeInterval: enemySpawnInterval, repeats: true) { [weak self] _ in
            self?.spawnEnemy()
        }
        
        // 自動発射タイマー
        autoFireTimer = Timer.scheduledTimer(withTimeInterval: autoFireInterval, repeats: true) { [weak self] _ in
            self?.fireBullet()
        }
    }
    
    func pauseGame() {
        gameState = .paused
        timer?.invalidate()
        enemySpawnTimer?.invalidate()
        autoFireTimer?.invalidate()
    }
    
    func resumeGame() {
        gameState = .playing
        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            self?.update()
        }
        enemySpawnTimer = Timer.scheduledTimer(withTimeInterval: enemySpawnInterval, repeats: true) { [weak self] _ in
            self?.spawnEnemy()
        }
        autoFireTimer = Timer.scheduledTimer(withTimeInterval: autoFireInterval, repeats: true) { [weak self] _ in
            self?.fireBullet()
        }
    }
    
    func stopGame() {
        timer?.invalidate()
        enemySpawnTimer?.invalidate()
        autoFireTimer?.invalidate()
        timer = nil
        enemySpawnTimer = nil
        autoFireTimer = nil
    }
    
    func movePlayerVertical(delta: CGFloat) {
        guard gameState == .playing else { return }
        let newY = player.position.y + delta * 2
        let clampedY = max(player.size.height / 2, min(screenHeight - player.size.height / 2, newY))
        player.position.y = clampedY
    }
    
    func setPlayerY(_ y: CGFloat) {
        guard gameState == .playing else { return }
        let clampedY = max(player.size.height / 2, min(screenHeight - player.size.height / 2, y))
        player.position.y = clampedY
    }
    
    func fireBullet() {
        guard gameState == .playing else { return }
        let bulletPosition = CGPoint(x: player.position.x + player.size.width / 2, y: player.position.y)
        let bullet = Bullet(position: bulletPosition, isPlayerBullet: true)
        playerBullets.append(bullet)
    }
    
    private func spawnEnemy() {
        guard gameState == .playing else { return }
        let y = CGFloat.random(in: 20...(screenHeight - 20))
        
        // 敵の種類をランダムに選択（スコアに応じて難易度調整）
        let enemyType: EnemyType
        let random = Int.random(in: 0...100)
        if score > 200 && random < 10 {
            enemyType = .boss
        } else if score > 150 && random < 20 {
            enemyType = .homing
        } else if score > 100 && random < 25 {
            enemyType = .large
        } else if score > 50 && random < 50 {
            enemyType = .medium
        } else if random < 30 {
            enemyType = .circle
        } else {
            enemyType = .small
        }
        
        var enemy = Enemy(position: CGPoint(x: screenWidth + 20, y: y), type: enemyType)
        if enemy.isCircle {
            // サークル敵の初期設定
            enemy.circleCenterY = y
        }
        enemies.append(enemy)
    }
    
    private func update() {
        guard gameState == .playing else { return }
        
        // プレイヤーの弾を移動（右へ）
        playerBullets = playerBullets.compactMap { bullet in
            var newBullet = bullet
            newBullet.position.x += bullet.speed
            if newBullet.position.x > screenWidth + 10 {
                return nil // 画面外に出た弾を削除
            }
            return newBullet
        }
        
        // 敵を移動（左へ）と弾の発射
        for i in 0..<enemies.count {
            if enemies[i].type.isHoming {
                // ホーミング敵：プレイヤーの位置に向かって移動
                let dx = player.position.x - enemies[i].position.x
                let dy = player.position.y - enemies[i].position.y
                let distance = sqrt(dx * dx + dy * dy)
                
                if distance > 0 {
                    // 正規化された方向ベクトル
                    let dirX = dx / distance
                    let dirY = dy / distance
                    
                    // ホーミング敵の移動速度
                    enemies[i].position.x += dirX * enemies[i].speed
                    enemies[i].position.y += dirY * enemies[i].speed
                }
            } else if enemies[i].isBoss {
                // ボス：左へ移動しながら上下に動く
                enemies[i].position.x -= enemies[i].speed
                
                // 上下移動（ジグザグパターン）
                enemies[i].verticalOffset += enemies[i].verticalDirection * 0.5
                enemies[i].position.y += enemies[i].verticalDirection * 0.5
                
                // 画面の上下で方向を反転
                if enemies[i].position.y <= enemies[i].size.height / 2 + 10 {
                    enemies[i].verticalDirection = 1.0 // 下へ
                } else if enemies[i].position.y >= screenHeight - enemies[i].size.height / 2 - 10 {
                    enemies[i].verticalDirection = -1.0 // 上へ
                }
            } else if enemies[i].isMedium {
                // Medium敵：中央で一度止まって弾を打つ
                let centerX = screenWidth / 2
                let centerThreshold: CGFloat = 5.0 // 中央とみなす範囲
                
                // 中央に到達していない場合は左へ移動
                if !enemies[i].hasStoppedAtCenter && enemies[i].position.x > centerX + centerThreshold {
                    enemies[i].position.x -= enemies[i].speed
                } else if !enemies[i].hasStoppedAtCenter && abs(enemies[i].position.x - centerX) <= centerThreshold {
                    // 中央に到達したら止まる
                    enemies[i].hasStoppedAtCenter = true
                    enemies[i].stopTime = Date()
                    // 位置を中央に固定
                    enemies[i].position.x = centerX
                } else if enemies[i].hasStoppedAtCenter {
                    // 中央で止まっている間は移動しない
                    // 1秒後に再び移動を開始
                    if let stopTime = enemies[i].stopTime,
                       Date().timeIntervalSince(stopTime) >= 1.0 {
                        // 再び左へ移動
                        enemies[i].position.x -= enemies[i].speed
                    }
                } else {
                    // 通常の敵：左へ移動
                    enemies[i].position.x -= enemies[i].speed
                }
            } else if enemies[i].isCircle {
                // サークル敵：円運動で前方に進む
                enemies[i].position.x -= enemies[i].speed
                
                // 円運動（縁を描くような動き）
                enemies[i].circleAngle += 0.1 // 角度を増やす
                let offsetY = sin(enemies[i].circleAngle) * enemies[i].circleRadius
                enemies[i].position.y = enemies[i].circleCenterY + offsetY
            } else {
                // 通常の敵：左へ移動
                enemies[i].position.x -= enemies[i].speed
            }
            
            // 敵が弾を発射できるかチェック
            if enemies[i].canFire() && enemies[i].position.x < screenWidth - 50 {
                if enemies[i].isBoss {
                    // ボス：3方向に弾を発射（斜め上、まっすぐ、斜め下）
                    let bulletSpeed: CGFloat = 2.5
                    let bulletBaseX = enemies[i].position.x - enemies[i].size.width / 2
                    let bulletY = enemies[i].position.y
                    
                    // 斜め上
                    let bullet1 = Bullet(
                        position: CGPoint(x: bulletBaseX, y: bulletY),
                        isPlayerBullet: false,
                        velocityX: -bulletSpeed,
                        velocityY: -bulletSpeed * 0.7
                    )
                    // まっすぐ
                    let bullet2 = Bullet(
                        position: CGPoint(x: bulletBaseX, y: bulletY),
                        isPlayerBullet: false,
                        velocityX: -bulletSpeed,
                        velocityY: 0.0
                    )
                    // 斜め下
                    let bullet3 = Bullet(
                        position: CGPoint(x: bulletBaseX, y: bulletY),
                        isPlayerBullet: false,
                        velocityX: -bulletSpeed,
                        velocityY: bulletSpeed * 0.7
                    )
                    
                    enemyBullets.append(bullet1)
                    enemyBullets.append(bullet2)
                    enemyBullets.append(bullet3)
                } else if enemies[i].isLarge {
                    // Large敵：3方向に弾を発射（前方やや上、真ん中、前方やや下）
                    let bulletSpeed: CGFloat = 2.5
                    let bulletBaseX = enemies[i].position.x - enemies[i].size.width / 2
                    let bulletY = enemies[i].position.y
                    
                    // 前方やや上
                    let bullet1 = Bullet(
                        position: CGPoint(x: bulletBaseX, y: bulletY),
                        isPlayerBullet: false,
                        velocityX: -bulletSpeed,
                        velocityY: -bulletSpeed * 0.5
                    )
                    // 真ん中
                    let bullet2 = Bullet(
                        position: CGPoint(x: bulletBaseX, y: bulletY),
                        isPlayerBullet: false,
                        velocityX: -bulletSpeed,
                        velocityY: 0.0
                    )
                    // 前方やや下
                    let bullet3 = Bullet(
                        position: CGPoint(x: bulletBaseX, y: bulletY),
                        isPlayerBullet: false,
                        velocityX: -bulletSpeed,
                        velocityY: bulletSpeed * 0.5
                    )
                    
                    enemyBullets.append(bullet1)
                    enemyBullets.append(bullet2)
                    enemyBullets.append(bullet3)
                } else if enemies[i].isMedium && enemies[i].hasStoppedAtCenter {
                    // Medium敵：中央で止まった時に斜め上と斜め下の2方向に発射
                    let bulletSpeed: CGFloat = 2.5
                    let bulletBaseX = enemies[i].position.x - enemies[i].size.width / 2
                    let bulletY = enemies[i].position.y
                    
                    // 斜め上
                    let bullet1 = Bullet(
                        position: CGPoint(x: bulletBaseX, y: bulletY),
                        isPlayerBullet: false,
                        velocityX: -bulletSpeed,
                        velocityY: -bulletSpeed * 0.7
                    )
                    // 斜め下
                    let bullet2 = Bullet(
                        position: CGPoint(x: bulletBaseX, y: bulletY),
                        isPlayerBullet: false,
                        velocityX: -bulletSpeed,
                        velocityY: bulletSpeed * 0.7
                    )
                    
                    enemyBullets.append(bullet1)
                    enemyBullets.append(bullet2)
                } else if enemies[i].isCircle {
                    // サークル敵：前方に1発
                    let bulletPosition = CGPoint(x: enemies[i].position.x - enemies[i].size.width / 2, y: enemies[i].position.y)
                    let bullet = Bullet(position: bulletPosition, isPlayerBullet: false)
                    enemyBullets.append(bullet)
                } else {
                    // 通常の敵：1発
                    let bulletPosition = CGPoint(x: enemies[i].position.x - enemies[i].size.width / 2, y: enemies[i].position.y)
                    let bullet = Bullet(position: bulletPosition, isPlayerBullet: false)
                    enemyBullets.append(bullet)
                }
                enemies[i].lastFireTime = Date()
            }
        }
        
        // 画面外に出た敵を削除
        enemies = enemies.filter { enemy in
            // 通常の敵：左端を超えたら削除
            // ホーミング敵：左端を超えたか、上下の画面外に出たら削除
            // ボス：左端を超えたら削除（上下は画面内に保つ）
            if enemy.type.isHoming {
                return enemy.position.x > -20 && 
                       enemy.position.y > -20 && 
                       enemy.position.y < screenHeight + 20
            } else {
                return enemy.position.x > -20
            }
        }
        
        // 敵の弾を移動
        enemyBullets = enemyBullets.compactMap { bullet in
            var newBullet = bullet
            // 斜め発射の場合はXとYの両方を更新
            if bullet.velocityX != 0.0 || bullet.velocityY != 0.0 {
                newBullet.position.x += bullet.velocityX
                newBullet.position.y += bullet.velocityY
            } else {
                // 通常の弾（左へ）
                newBullet.position.x -= bullet.speed
            }
            
            // 画面外に出た弾を削除
            if newBullet.position.x < -10 || 
               newBullet.position.x > screenWidth + 10 ||
               newBullet.position.y < -10 ||
               newBullet.position.y > screenHeight + 10 {
                return nil
            }
            return newBullet
        }
        
        // 衝突判定：プレイヤーの弾と敵
        var enemiesToRemove: [Int] = []
        var bulletsToRemove: [Int] = []
        
        for (enemyIndex, enemy) in enemies.enumerated() {
            let enemyRect = CGRect(
                x: enemy.position.x - enemy.size.width / 2,
                y: enemy.position.y - enemy.size.height / 2,
                width: enemy.size.width,
                height: enemy.size.height
            )
            
            for (bulletIndex, bullet) in playerBullets.enumerated() {
                let bulletRect = CGRect(
                    x: bullet.position.x - bullet.size.width / 2,
                    y: bullet.position.y - bullet.size.height / 2,
                    width: bullet.size.width,
                    height: bullet.size.height
                )
                
                if checkCollision(enemyRect, bulletRect) {
                    // ボスは3回打たないと倒せない
                    enemies[enemyIndex].health -= 1
                    bulletsToRemove.append(bulletIndex)
                    
                    if enemies[enemyIndex].health <= 0 {
                        enemiesToRemove.append(enemyIndex)
                        score += enemies[enemyIndex].type.score
                    }
                    break
                }
            }
        }
        
        // 衝突した敵と弾を削除
        for index in enemiesToRemove.sorted(by: >) {
            enemies.remove(at: index)
        }
        for index in bulletsToRemove.sorted(by: >) {
            playerBullets.remove(at: index)
        }
        
        // 衝突判定：敵とプレイヤー
        let playerRect = CGRect(
            x: player.position.x - player.size.width / 2,
            y: player.position.y - player.size.height / 2,
            width: player.size.width,
            height: player.size.height
        )
        
        for (index, enemy) in enemies.enumerated() {
            let enemyRect = CGRect(
                x: enemy.position.x - enemy.size.width / 2,
                y: enemy.position.y - enemy.size.height / 2,
                width: enemy.size.width,
                height: enemy.size.height
            )
            
            if checkCollision(playerRect, enemyRect) {
                // 即死
                endGame()
                break
            }
        }
        
        // 衝突判定：敵の弾とプレイヤー
        for (index, bullet) in enemyBullets.enumerated() {
            let bulletRect = CGRect(
                x: bullet.position.x - bullet.size.width / 2,
                y: bullet.position.y - bullet.size.height / 2,
                width: bullet.size.width,
                height: bullet.size.height
            )
            
            if checkCollision(playerRect, bulletRect) {
                // 即死
                enemyBullets.remove(at: index)
                endGame()
                break
            }
        }
        
    }
    
    private func endGame() {
        gameState = .gameOver
        gameOver = true
        stopGame()
    }
    
    deinit {
        stopGame()
    }
}

