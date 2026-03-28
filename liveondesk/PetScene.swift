//
//  PetScene.swift
//  liveondesk
//

import SpriteKit

enum Physics {
    static let pet:      UInt32 = 0x1
    static let platform: UInt32 = 0x2
}

class PetScene: SKScene, SKPhysicsContactDelegate {

    // MARK: - Properties

    private var petNode: PetNode!
    private let detector = WindowDetector()
    private var platformNodes: [CGWindowID: SKNode] = [:]
    private var currentPlatforms: [WindowPlatform] = []

    private var state: PetState = .falling
    private var contactCount = 0
    private var walkDirection: CGFloat = 1.0

    private let walkSpeed: CGFloat = 110
    private let petRadius: CGFloat = 32

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        // Gravedad realista para una pantalla de ~900pt — caída snappy (~0.6s de arriba a abajo)
        physicsWorld.gravity = CGVector(dx: 0, dy: -500)
        physicsWorld.contactDelegate = self

        setupGround()
        setupPet()
        startWindowDetection()
        scheduleThoughts()
    }

    // MARK: - Setup

    private func setupGround() {
        let ground = SKNode()
        ground.physicsBody = SKPhysicsBody(
            edgeFrom: CGPoint(x: 0, y: 2),
            to:       CGPoint(x: size.width, y: 2)
        )
        ground.physicsBody?.isDynamic = false
        ground.physicsBody?.friction = 1.0
        ground.physicsBody?.categoryBitMask = Physics.platform
        addChild(ground)
    }

    private func setupPet() {
        petNode = PetNode(radius: petRadius)
        
        let physics = SKPhysicsBody(circleOfRadius: petRadius)
        physics.restitution        = 0.05
        physics.friction           = 1.0
        physics.linearDamping      = 0.2
        physics.allowsRotation     = false
        physics.categoryBitMask    = Physics.pet
        physics.collisionBitMask   = Physics.platform
        physics.contactTestBitMask = Physics.platform
        petNode.physicsBody = physics
        
        petNode.position = CGPoint(x: size.width / 2, y: size.height - 50)
        addChild(petNode)
    }

    private func startWindowDetection() {
        detector.onWindowsChanged = { [weak self] platforms in
            self?.currentPlatforms = platforms
            self?.updatePlatforms(platforms)
        }
        detector.start()
    }

    // MARK: - Platform management

    private func updatePlatforms(_ platforms: [WindowPlatform]) {
        let newIDs = Set(platforms.map { $0.windowID })

        for id in Set(platformNodes.keys).subtracting(newIDs) {
            platformNodes[id]?.removeFromParent()
            platformNodes.removeValue(forKey: id)
        }

        for platform in platforms {
            let node = platformNodes[platform.windowID] ?? {
                let n = SKNode()
                addChild(n)
                platformNodes[platform.windowID] = n
                return n
            }()

            let body = SKPhysicsBody(
                edgeFrom: CGPoint(x: platform.minX, y: platform.topEdgeY),
                to:       CGPoint(x: platform.maxX, y: platform.topEdgeY)
            )
            body.isDynamic = false
            body.friction = 1.0
            body.categoryBitMask = Physics.platform
            node.physicsBody = body
        }
    }

    // MARK: - State machine

    private func transition(to newState: PetState) {
        guard newState != state else { return }
        state = newState
        removeAction(forKey: "stateDuration")

        switch newState {
        case .falling:
            petNode.setEyeStyle(.surprised)
            petNode.hideZZZ()
            if let phrase = ThoughtProvider.phrase(for: .falling) {
                showThought(phrase)
            }

        case .walking:
            petNode.setEyeStyle(.normal)
            petNode.hideZZZ()
            // Mostrar pensamiento al aterrizar/despertar — verificar estado antes de ejecutar
            run(.sequence([
                .wait(forDuration: 0.6),
                .run { [weak self] in
                    guard let self, self.state == .walking else { return }
                    self.maybeShowThought()
                }
            ]))
            let wait = SKAction.wait(forDuration: Double.random(in: 5...10))
            run(.sequence([wait, .run { [weak self] in
                self?.transition(to: .idle)
            }]), withKey: "stateDuration")

        case .idle:
            petNode.setEyeStyle(.normal)
            petNode.hideZZZ()
            let wait = SKAction.wait(forDuration: Double.random(in: 4...8))
            run(.sequence([wait, .run { [weak self] in
                self?.transition(to: .sleeping)
            }]), withKey: "stateDuration")

        case .sleeping:
            petNode.setEyeStyle(.closed)
            petNode.showZZZ()
            petNode.childNode(withName: "thought")?.removeFromParent()
            let wait = SKAction.wait(forDuration: Double.random(in: 6...14))
            run(.sequence([wait, .run { [weak self] in
                self?.transition(to: .walking)
            }]), withKey: "stateDuration")
        }
    }

    // MARK: - Physics contacts

    func didBegin(_ contact: SKPhysicsContact) {
        guard isPetContact(contact) else { return }
        contactCount += 1
        if contactCount == 1 && state == .falling {
            transition(to: .walking)
        }
    }

    func didEnd(_ contact: SKPhysicsContact) {
        guard isPetContact(contact) else { return }
        contactCount = max(0, contactCount - 1)

        // Key evita acumular múltiples checks pendientes
        run(.sequence([
            .wait(forDuration: 0.15),
            .run { [weak self] in
                guard let self, self.contactCount == 0 else { return }
                self.transition(to: .falling)
            }
        ]), withKey: "fallCheck")
    }

    private func isPetContact(_ contact: SKPhysicsContact) -> Bool {
        contact.bodyA.categoryBitMask == Physics.pet ||
        contact.bodyB.categoryBitMask == Physics.pet
    }

    // MARK: - Update loop

    override func update(_ currentTime: TimeInterval) {
        guard let body = petNode.physicsBody else { return }

        switch state {
        case .walking:
            // Solo aplicar velocidad horizontal cuando está en contacto con una superficie
            if contactCount > 0 {
                body.velocity = CGVector(dx: walkDirection * walkSpeed, dy: body.velocity.dy)
            }
            checkPlatformEdges()

        case .idle, .sleeping:
            body.velocity = CGVector(dx: body.velocity.dx * 0.85, dy: body.velocity.dy)

        case .falling:
            break
        }

        // Fallback: si cae rápido y no estamos en .falling, forzar transición.
        // Necesario porque SpriteKit no siempre dispara didEnd al eliminar un nodo.
        // Con gravedad -500, alcanza ~150 pts/s en 0.3s de caída libre.
        if state != .falling && body.velocity.dy < -150 {
            contactCount = 0
            transition(to: .falling)
        }

        // Límites de pantalla como respaldo cuando no hay plataforma activa
        if petNode.position.x < 40             { walkDirection =  1 }
        if petNode.position.x > size.width - 40 { walkDirection = -1 }
    }

    // Revierte dirección antes de caer del borde de la plataforma actual
    private func checkPlatformEdges() {
        guard let edges = nearestPlatformEdges() else { return }
        let margin: CGFloat = 40
        if petNode.position.x <= edges.minX + margin { walkDirection =  1 }
        if petNode.position.x >= edges.maxX - margin { walkDirection = -1 }
    }

    /// Devuelve los bordes de la plataforma sobre la que está parado el pet.
    /// Retorna nil si el pet no está cerca de ninguna plataforma conocida.
    private func nearestPlatformEdges() -> (minX: CGFloat, maxX: CGFloat)? {
        let px = petNode.position.x
        let py = petNode.position.y
        let standingThreshold: CGFloat = 25  // px de tolerancia vertical

        // Suelo como plataforma implícita
        var best: (minX: CGFloat, maxX: CGFloat, dist: CGFloat)?
        let groundDist = abs(py - petRadius - 2)
        if groundDist < standingThreshold {
            best = (0, size.width, groundDist)
        }

        for p in currentPlatforms {
            guard px >= p.minX && px <= p.maxX else { continue }
            let dist = abs(py - petRadius - p.topEdgeY)
            guard dist < standingThreshold else { continue }
            if best == nil || dist < best!.dist {
                best = (p.minX, p.maxX, dist)
            }
        }

        return best.map { ($0.minX, $0.maxX) }
    }

    // MARK: - Thought bubbles

    private func scheduleThoughts() {
        run(.repeatForever(.sequence([
            .wait(forDuration: 12, withRange: 8),
            .run { [weak self] in self?.maybeShowThought() }
        ])), withKey: "thinking")
    }

    private func maybeShowThought() {
        guard petNode.childNode(withName: "thought") == nil else { return }
        guard let phrase = ThoughtProvider.phrase(for: state) else { return }
        showThought(phrase)
    }

    private func showThought(_ phrase: String) {
        petNode.childNode(withName: "thought")?.removeFromParent()

        let bubble = ThoughtBubble(text: phrase)
        bubble.name = "thought"

        // Flipear posición horizontal si el pet está cerca del borde derecho
        let nearRightEdge = petNode.position.x > size.width * 0.65
        bubble.position = CGPoint(
            x: nearRightEdge ? -18 - 95 : 18,  // 95 ≈ mitad del ancho máximo de la burbuja
            y: petRadius + 48
        )
        if nearRightEdge {
            bubble.xScale = -1  // Espejear la burbuja y sus puntos
            // El texto se ve al revés si escalamos el nodo completo — mejor mover sin escalar
            bubble.xScale = 1
            bubble.position.x = -(18 + 95)
        }

        petNode.addChild(bubble)
        bubble.present(duration: 4.5)
    }


}
