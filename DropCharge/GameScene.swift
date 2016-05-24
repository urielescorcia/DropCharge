//
//  GameScene.swift
//  DropCharge
//
//  Created by Urisito on 5/23/16.
//  Copyright (c) 2016 Urisito. All rights reserved.
//

import SpriteKit
import CoreMotion

struct PhysicsCategory {
    static let None: UInt32 = 0
    static let Player: UInt32 = 0b1 // 1
    static let PlatformNormal: UInt32 = 0b10 // 2
    static let PlatformBreakable: UInt32 = 0b100 // 4
    static let CoinNormal: UInt32 = 0b1000 // 8
    static let CoinSpecial: UInt32 = 0b10000 // 16
    static let Edges: UInt32 = 0b100000 // 32
}

class GameScene: SKScene, SKPhysicsContactDelegate {
    
    // MARK: - Properties
    var bgNode = SKNode()
    var fgNode = SKNode()
    var background: SKNode!
    var backHeight: CGFloat = 0.0
    var player: SKSpriteNode!
    
    var platform5Across: SKSpriteNode!
    var coinArrow: SKSpriteNode!
    var lastItemPosition = CGPointZero
    var lastItemHeight: CGFloat = 0.0
    var levelY: CGFloat = 0.0
    
    var isPlaying = false
    let motionManager = CMMotionManager()
    var xAcceleration = CGFloat(0)
    let cameraNode = SKCameraNode()
    var lava: SKSpriteNode!
    var lastUpdateTimeInterval: NSTimeInterval = 0
    var deltaTime: NSTimeInterval = 0
    
    override func didMoveToView(view: SKView) {
        setupNodes()
        setupLevel()
        setupPlayer()
        setupCoreMotion()
        
        physicsWorld.contactDelegate = self
        setCameraPosition(CGPoint(x: size.width / 2, y: size.height / 2))
    }
    
    func setupNodes() {
        let worldNode = childNodeWithName("World")!
        bgNode = worldNode.childNodeWithName("Background")!
        background = bgNode.childNodeWithName("Overlay")!.copy() as! SKNode
        backHeight = background.calculateAccumulatedFrame().height
        fgNode = worldNode.childNodeWithName("Foreground")!
        player = fgNode.childNodeWithName("Player") as! SKSpriteNode
        fgNode.childNodeWithName("Bomb")?.runAction(SKAction.hide())
        lava = fgNode.childNodeWithName("Lava") as! SKSpriteNode
        
        platform5Across = loadOverlayNode("Platform5Across")
        coinArrow = loadOverlayNode("CoinArrow")
        
        addChild(cameraNode)
        camera = cameraNode
    }
    
    func setupLevel() {
        // Place initial platform
        let initialPlatform = platform5Across.copy() as! SKSpriteNode
        var itemPosition = player.position
        itemPosition.y = player.position.y - ((player.size.height * 0.5) + (initialPlatform.size.height * 0.20))
        initialPlatform.position = itemPosition
        fgNode.addChild(initialPlatform)
        lastItemPosition = itemPosition
        lastItemHeight = initialPlatform.size.height / 2
        
        //Create random level
        levelY = bgNode.childNodeWithName("Overlay")!.position.y + backHeight
        while lastItemPosition.y < levelY {
            addRandomOverlayNode()
        }
    }
    
    func setupPlayer() {
        player.physicsBody = SKPhysicsBody(circleOfRadius: player.size.width * 0.3)
        player.physicsBody!.dynamic = false
        player.physicsBody!.allowsRotation = false
        player.physicsBody!.categoryBitMask = PhysicsCategory.Player
        player.physicsBody!.collisionBitMask = 0
    }
    
    func setupCoreMotion() {
        motionManager.accelerometerUpdateInterval = 0.2
        let queue = NSOperationQueue()
        motionManager.startAccelerometerUpdatesToQueue(queue) { accelerometerData, error in
            guard let accelerometerData = accelerometerData else {
                return
            }
            let acceleration = accelerometerData.acceleration
            self.xAcceleration = (CGFloat(acceleration.x) * 0.75) + (self.xAcceleration * 0.25)
        }
    }
    
    // MARK: Platform/Coin overlay nodes.
    
    func loadOverlayNode(fileName: String) -> SKSpriteNode {
        let overlayScene = SKScene(fileNamed: fileName)
        let contentTemplateNode = overlayScene?.childNodeWithName("Overlay")
        return contentTemplateNode as! SKSpriteNode
    }
    
    func createOverlayNode(noteType: SKSpriteNode, flipX: Bool) {
        let platform = noteType.copy() as! SKSpriteNode
        lastItemPosition.y = lastItemPosition.y + (lastItemHeight + (platform.size.height / 2))
        lastItemHeight = platform.size.height / 2
        platform.position = lastItemPosition
        if flipX {
            platform.xScale = -1.0
        }
        fgNode.addChild(platform)
    }
    
    func addRandomOverlayNode() {
        let overlaySprite: SKSpriteNode!
        let platformPercentage = 60
        if Int.random(min: 1, max: 100) <= platformPercentage {
            overlaySprite = platform5Across
        }else{
            overlaySprite = coinArrow
        }
        createOverlayNode(overlaySprite, flipX: false)
    }
    
    func createBackgroundNode() {
        let backNode = background.copy() as! SKNode
        backNode.position = CGPoint(x: 0.0, y: levelY)
        bgNode.addChild(backNode)
        levelY += backHeight
    }
    
    // MARK: - Events
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        if !isPlaying {
            bombDrop()
        }
    }
    
    func bombDrop() {
        let scaleUp = SKAction.scaleTo(1.25, duration: 0.25)
        let scaleDown = SKAction.scaleTo(1, duration: 0.25)
        let sequence = SKAction.sequence([scaleUp, scaleDown])
        let repeatSeq = SKAction.repeatActionForever(sequence)
        fgNode.childNodeWithName("Bomb")!.runAction(SKAction.unhide())
        fgNode.childNodeWithName("Bomb")!.runAction(repeatSeq)
        runAction(SKAction.sequence([
            SKAction.waitForDuration(2.0),
            SKAction.runBlock(startGame)
            ]))
    }
    
    func startGame() {
        fgNode.childNodeWithName("Title")!.removeFromParent()
        fgNode.childNodeWithName("Bomb")!.removeFromParent()
        isPlaying = true
        player.physicsBody!.dynamic = true
        superBoostPlayer()
    }
    
    func setPlayerVelocity(amount: CGFloat) {
        let gain: CGFloat = 2.5
        player.physicsBody!.velocity.dy = max(player.physicsBody!.velocity.dy, amount * gain)
    }
    
    func jumpPlayer() {
        setPlayerVelocity(650)
    }
    
    func boostPlayer() {
        setPlayerVelocity(1200)
    }
    
    func superBoostPlayer() {
        setPlayerVelocity(1700)
    }
    
    func didBeginContact(contact: SKPhysicsContact) {
        let other = contact.bodyA.categoryBitMask == PhysicsCategory.Player ? contact.bodyB : contact.bodyA
        switch other.categoryBitMask {
        case PhysicsCategory.CoinNormal:
            if let coin = other.node as? SKSpriteNode {
                coin.removeFromParent()
                jumpPlayer()
            }
            
        case PhysicsCategory.PlatformNormal:
            if let _ = other.node as? SKSpriteNode {
                if player.physicsBody!.velocity.dy < 0 {
                    jumpPlayer()
                }
            }
        default:
            break;
        }
    }
    
    // MARK: - Updates
    
    override func update(currentTime: NSTimeInterval) {
        if lastUpdateTimeInterval > 0 {
            deltaTime = currentTime - lastUpdateTimeInterval
        }else{
            deltaTime = 0
        }
        lastUpdateTimeInterval = currentTime
        
        if paused {
            return
        }
        
        if isPlaying {
            updateCamera()
            updatePlayer()
            updateLava(deltaTime)
            updateCollisionLava()
        }
        updateLevel()
        
    }
    
    func updatePlayer() {
        // Set velocity based on core motion
        player.physicsBody?.velocity.dx = xAcceleration * 1000.0
        // Wrap player around edges of screen
        var playerPosition = convertPoint(player.position, fromNode: fgNode)
        if playerPosition.x < -player.size.width/2 {
            playerPosition = convertPoint(CGPoint(x: size.width + player.size.width/2, y: 0.0), toNode: fgNode)
            player.position.x = playerPosition.x
        }else if playerPosition.x > size.width + player.size.width/2 {
            playerPosition = convertPoint(CGPoint(x: -player.size.width/2, y: 0.0), toNode: fgNode)
            player.position.x = playerPosition.x
        }
    }
    
    func updateCamera() {
        let cameraTarget = convertPoint(player.position, fromNode: fgNode)
        var targetPosition = CGPoint(x: getCameraPosition().x, y: cameraTarget.y - (scene!.view!.bounds.height * 0.40))
        
        let lavaPos = convertPoint(lava.position, fromNode: fgNode)
        targetPosition.y = max(targetPosition.y, lavaPos.y)
        
        let diff = targetPosition - getCameraPosition()
        
        let lerpValue = CGFloat(0.2)
        let lerpDiff = diff * lerpValue
        let newPosition = getCameraPosition() + lerpDiff
        
        setCameraPosition(CGPoint(x: size.width / 2, y: newPosition.y))
    }
    
    func updateLava(dt: NSTimeInterval) {
        let lowerLeft = CGPoint(x: 0, y: cameraNode.position.y - (size.height / 2 ))
        let visibleMinYFg = scene!.convertPoint(lowerLeft, toNode: fgNode).y
        let lavaVelocity = CGPoint(x: 0, y: 120)
        let lavaStep = lavaVelocity * CGFloat(dt)
        var newPosition = lava.position + lavaStep
        
        newPosition.y = max(newPosition.y, (visibleMinYFg - 125.0))
        lava.position = newPosition
    }
    
    func updateCollisionLava() {
        if player.position.y < lava.position.y + 90 {
            boostPlayer()
        }
    }
    
    func updateLevel() {
        let cameraPos = getCameraPosition()
        if cameraPos.y > levelY - size.height * 0.55 {
            createBackgroundNode()
            while lastItemPosition.y < levelY {
                addRandomOverlayNode()
            }
        }
    }
    
    // MARK: - Camera
    
    func overlapAmount() -> CGFloat {
        guard let view = self.view else {
            return 0
        }
        let scale = view.bounds.size.height / self.size.height
        let scaledWidth = self.size.width * scale
        let scaledOverlap = scaledWidth - view.bounds.size.width
        return scaledOverlap / scale
    }
    
    func getCameraPosition() -> CGPoint {
        return CGPoint(
            x: cameraNode.position.x + overlapAmount()/2,
            y: cameraNode.position.y)
    }
    
    func setCameraPosition(position: CGPoint) {
        cameraNode.position = CGPoint(
            x: position.x - overlapAmount()/2,
            y: position.y)
    }
    
}































