//
//  GameView.swift
//  GaraxyWars Watch App
//
//  Created by satoshi goto on 7/1/26.
//

import SwiftUI

struct GameView: View {
    @StateObject private var gameEngine = GameEngine()
    @State private var starOffset: CGFloat = 0
    @State private var starPositions: [(x: CGFloat, y: CGFloat)] = []
    @State private var crownPosition: Double = 112.0 // 中央の初期値
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景（星空）
                Color.black
                    .ignoresSafeArea()
                
                // 星の背景エフェクト（右から左へスクロール）
                ForEach(0..<starPositions.count, id: \.self) { i in
                    Circle()
                        .fill(Color.white.opacity(0.6))
                        .frame(width: 1, height: 1)
                        .position(
                            x: (starPositions[i].x - starOffset).truncatingRemainder(dividingBy: geometry.size.width + 60) + geometry.size.width + 30,
                            y: starPositions[i].y)
                }
                .onReceive(Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()) { _ in
                    if gameEngine.gameState == .playing {
                        starOffset += 1.5
                    }
                }
                
                // ゲーム状態に応じた表示
                switch gameEngine.gameState {
                case .menu:
                    menuView
                case .playing, .paused:
                    playingView
                case .gameOver:
                    gameOverView
                }
            }
            .onAppear {
                // 画面サイズを更新
                updateScreenSize(width: geometry.size.width, height: geometry.size.height)
                // デジタルクラウンの初期位置を設定
                crownPosition = Double(geometry.size.height / 2)
                // 星の位置を初期化（横スクロール用）
                if starPositions.isEmpty {
                    starPositions = (0..<40).map { _ in
                        (x: CGFloat.random(in: 0...(geometry.size.width + 200)),
                         y: CGFloat.random(in: 10...(geometry.size.height - 10)))
                    }
                }
            }
            .onChange(of: geometry.size) { oldValue, newSize in
                updateScreenSize(width: newSize.width, height: newSize.height)
                // 星の位置を再初期化（画面サイズが変わった場合）
                if starPositions.isEmpty {
                    starPositions = (0..<40).map { _ in
                        (x: CGFloat.random(in: 0...(newSize.width + 200)),
                         y: CGFloat.random(in: 10...(newSize.height - 10)))
                    }
                }
            }
        }
    }
    
    private var menuView: some View {
        VStack(spacing: 10) {
            Text("GALAXY WARS")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Tap to Start")
                .font(.caption)
                .foregroundColor(.gray)
            
            Button(action: {
                gameEngine.startGame()
            }) {
                Text("START")
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(8)
            }
        }
    }
    
    private var playingView: some View {
        ZStack {
            // プレイヤー
            playerView
            
            // 敵
            ForEach(0..<gameEngine.enemies.count, id: \.self) { i in
                enemyView(enemy: gameEngine.enemies[i])
            }
            
            // プレイヤーの弾
            ForEach(0..<gameEngine.playerBullets.count, id: \.self) { i in
                bulletView(bullet: gameEngine.playerBullets[i])
            }
            
            // 敵の弾
            ForEach(0..<gameEngine.enemyBullets.count, id: \.self) { i in
                bulletView(bullet: gameEngine.enemyBullets[i])
            }
            
            // UI
            VStack {
                HStack {
                    // スコア
                    Text("Score: \(gameEngine.score)")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(4)
                    
                    Spacer()
                }
                .padding(4)
                
                Spacer()
                
                // 操作説明
                Text("Crown: Move Up/Down")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(4)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(4)
            }
        }
        .focusable()
        .digitalCrownRotation(
            $crownPosition,
            from: 0.0,
            through: Double(gameEngine.screenHeight),
            by: 1.0,
            sensitivity: .medium,
            isContinuous: true,
            isHapticFeedbackEnabled: false
        )
        .onChange(of: crownPosition) { oldValue, newValue in
            // デジタルクラウンの値に基づいてプレイヤーを直接移動
            let targetY = CGFloat(newValue)
            gameEngine.setPlayerY(targetY)
        }
    }
    
    private var gameOverView: some View {
        VStack(spacing: 15) {
            Text("GAME OVER")
                .font(.headline)
                .foregroundColor(.red)
            
            Text("Score: \(gameEngine.score)")
                .font(.title3)
                .foregroundColor(.white)
            
            Button(action: {
                gameEngine.startGame()
            }) {
                Text("Retry")
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(8)
            }
        }
    }
    
    private var playerView: some View {
        ZStack {
            // プレイヤーの宇宙船（右向き、尖っている方が前）
            Path { path in
                let center = gameEngine.player.position
                let size = gameEngine.player.size
                
                // 右向きの三角形の宇宙船（尖っている方が右/前）
                path.move(to: CGPoint(x: center.x + size.width / 2, y: center.y))
                path.addLine(to: CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2))
                path.addLine(to: CGPoint(x: center.x - size.width / 2, y: center.y + size.height / 2))
                path.closeSubpath()
            }
            .fill(Color.cyan)
            .stroke(Color.white, lineWidth: 1)
        }
    }
    
    private func enemyView(enemy: Enemy) -> some View {
        ZStack {
            // 敵の種類に応じた描画
            switch enemy.type {
            case .small:
                // 小さな敵：シンプルな三角形（左向き、尖っている方が左/前）
                Path { path in
                    let center = enemy.position
                    let size = enemy.size
                    path.move(to: CGPoint(x: center.x - size.width / 2, y: center.y))
                    path.addLine(to: CGPoint(x: center.x + size.width / 2, y: center.y - size.height / 2))
                    path.addLine(to: CGPoint(x: center.x + size.width / 2, y: center.y + size.height / 2))
                    path.closeSubpath()
                }
                .fill(enemy.type.color)
                .stroke(Color.white, lineWidth: 0.5)
                
            case .medium:
                // 中サイズの敵：四角形
                RoundedRectangle(cornerRadius: 2)
                    .fill(enemy.type.color)
                    .frame(width: enemy.size.width, height: enemy.size.height)
                    .position(enemy.position)
                
            case .large:
                // 大きな敵：六角形風
                Path { path in
                    let center = enemy.position
                    let size = enemy.size
                    let radius = size.width / 2
                    for i in 0..<6 {
                        let angle = Double(i) * .pi / 3.0
                        let x = center.x + radius * CGFloat(cos(angle))
                        let y = center.y + radius * CGFloat(sin(angle))
                        if i == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    path.closeSubpath()
                }
                .fill(enemy.type.color)
                .stroke(Color.white, lineWidth: 1)
                
            case .boss:
                // ボス：大きな星型
                Path { path in
                    let center = enemy.position
                    let size = enemy.size
                    let outerRadius = size.width / 2
                    let innerRadius = outerRadius * 0.5
                    for i in 0..<10 {
                        let angle = Double(i) * .pi / 5.0 - .pi / 2.0
                        let radius = i % 2 == 0 ? outerRadius : innerRadius
                        let x = center.x + radius * CGFloat(cos(angle))
                        let y = center.y + radius * CGFloat(sin(angle))
                        if i == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    path.closeSubpath()
                }
                .fill(enemy.type.color)
                .stroke(Color.yellow, lineWidth: 1)
                
            case .homing:
                // ホーミング敵：ダイヤモンド型（プレイヤーに向かってくる）
                Path { path in
                    let center = enemy.position
                    let size = enemy.size
                    // ダイヤモンド型（進行方向に尖っている）
                    path.move(to: CGPoint(x: center.x, y: center.y - size.height / 2))
                    path.addLine(to: CGPoint(x: center.x + size.width / 2, y: center.y))
                    path.addLine(to: CGPoint(x: center.x, y: center.y + size.height / 2))
                    path.addLine(to: CGPoint(x: center.x - size.width / 2, y: center.y))
                    path.closeSubpath()
                }
                .fill(enemy.type.color)
                .stroke(Color.yellow, lineWidth: 1)
                
            case .circle:
                // サークル敵：円形
                Circle()
                    .fill(enemy.type.color)
                    .frame(width: enemy.size.width, height: enemy.size.height)
                    .position(enemy.position)
                
            case .pentagon:
                // 五角形敵：五角形
                Path { path in
                    let center = enemy.position
                    let size = enemy.size
                    let radius = size.width / 2
                    for i in 0..<5 {
                        let angle = Double(i) * 2.0 * .pi / 5.0 - .pi / 2.0
                        let x = center.x + radius * CGFloat(cos(angle))
                        let y = center.y + radius * CGFloat(sin(angle))
                        if i == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    path.closeSubpath()
                }
                .fill(enemy.type.color)
            }
        }
    }
    
    private func bulletView(bullet: Bullet) -> some View {
        Rectangle()
            .fill(bullet.isPlayerBullet ? Color.yellow : Color.red)
            .frame(width: bullet.size.width, height: bullet.size.height)
            .position(bullet.position)
    }
    
    private func updateScreenSize(width: CGFloat, height: CGFloat) {
        gameEngine.updateScreenSize(width: width, height: height)
    }
}

