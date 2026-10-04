import Foundation
import AVFoundation
import RealityKit

/// ✨ 純程式碼合成 3D 空間音效管理器（無需任何外部音檔，直接生成無縫循環 Wave 並掛載至 RealityKit Entity）
@MainActor
final class SpatialAudioManager {
    static let shared = SpatialAudioManager()
    
    private var ambientResource: AudioFileResource?
    private var attractResource: AudioFileResource?
    private var repelResource: AudioFileResource?
    
    private var boxAmbientController: AudioPlaybackController?
    private var handAttractControllers: [Int: AudioPlaybackController] = [:]
    private var handRepelControllers: [Int: AudioPlaybackController] = [:]
    private var currentHandModes: [Int: Float] = [0: 0.0, 1: 0.0]
    
    private var isPrepared = false
    
    private init() {}
    
    /// 預先在暫存區合成三組無縫循環的科幻空間音波
    func prepareAudioResourcesIfNeeded() {
        guard !isPrepared else { return }
        isPrepared = true
        
        do {
            // 1. 宇宙盒中心：深空星雲和弦共鳴 (110Hz A2 + 165Hz E3 + 220Hz A3, 4秒無縫循環)
            let ambientURL = try generateLoopingWavFile(
                name: "cosmic_ambient_drone.wav",
                duration: 4.0,
                frequencies: [(110.0, 0.45), (165.0, 0.30), (220.0, 0.20), (277.18, 0.08)],
                pulseHz: 0.25
            )
            ambientResource = try AudioFileResource.load(
                contentsOf: ambientURL,
                configuration: .init(loadingStrategy: .preload, shouldLoop: true)
            )
            
            // 2. 指尖引力漩渦：空靈青色泛音 (220Hz + 330Hz + 440Hz + 660Hz, 2秒無縫循環)
            let attractURL = try generateLoopingWavFile(
                name: "hand_attract_vortex.wav",
                duration: 2.0,
                frequencies: [(220.0, 0.35), (330.0, 0.35), (440.0, 0.20), (660.0, 0.12)],
                pulseHz: 1.5
            )
            attractResource = try AudioFileResource.load(
                contentsOf: attractURL,
                configuration: .init(loadingStrategy: .preload, shouldLoop: true)
            )
            
            // 3. 指尖超新星斥力：熾紅高能脈衝震波 (90Hz 重低音 + 180Hz + 540Hz, 6Hz 快速能量脈衝)
            let repelURL = try generateLoopingWavFile(
                name: "hand_repel_pulse.wav",
                duration: 1.0,
                frequencies: [(90.0, 0.50), (135.0, 0.30), (180.0, 0.25), (540.0, 0.18)],
                pulseHz: 6.0
            )
            repelResource = try AudioFileResource.load(
                contentsOf: repelURL,
                configuration: .init(loadingStrategy: .preload, shouldLoop: true)
            )
        } catch {
            print("空間音效合成失敗：\(error)")
        }
    }
    
    /// 在透明盒子與左右手指尖光球上掛載 SpatialAudioComponent 3D 雙耳空間音源
    func attachSpatialAudio(to box: Entity, leftOrb: Entity, rightOrb: Entity, isMuted: Bool) {
        prepareAudioResourcesIfNeeded()
        stopAll()
        
        // 設定透明盒子 3D 空間衰減與指向性
        var boxSpatial = SpatialAudioComponent(gain: -14.0)
        boxSpatial.distanceAttenuation = .rolloff(factor: 1.2)
        box.components.set(boxSpatial)
        
        if let ambientRes = ambientResource {
            let controller = box.prepareAudio(ambientRes)
            if !isMuted {
                controller.play()
            }
            boxAmbientController = controller
        }
        
        // 設定左右手指尖光球 3D 空間音源（跟隨指尖在盒子內的精確 3D 位置發出聲音）
        let orbs = [(0, leftOrb), (1, rightOrb)]
        for (idx, orb) in orbs {
            var orbSpatial = SpatialAudioComponent(gain: -6.0)
            orbSpatial.distanceAttenuation = .rolloff(factor: 1.8)
            orb.components.set(orbSpatial)
            
            if let attractRes = attractResource {
                handAttractControllers[idx] = orb.prepareAudio(attractRes)
            }
            if let repelRes = repelResource {
                handRepelControllers[idx] = orb.prepareAudio(repelRes)
            }
            currentHandModes[idx] = 0.0
        }
    }
    
    /// 每幀根據宇宙狀態（暫停、時間流速、靜音）與雙手「神之手」力場模式動態更新 3D 音效
    func updateAudioState(simulator: ParticleSimulator) {
        if simulator.isAudioMuted {
            if boxAmbientController?.isPlaying == true {
                boxAmbientController?.pause()
            }
            for idx in 0...1 {
                stopHandAudio(index: idx)
            }
            return
        }
        
        // 1. 更新透明盒子中心宇宙共鳴音
        if let boxCtrl = boxAmbientController {
            if !boxCtrl.isPlaying {
                boxCtrl.play()
            }
            // 開啟中心奇點時自動提升宇宙共鳴音量 (+3 ~ +6 dB)，營造深空黑洞重力場氛圍
            let singularityBoost: Float = simulator.singularityMode > 0 ? (2.0 + simulator.singularityStrength * 1.5) : 0.0
            let targetGain: Double = simulator.isPaused ? -24.0 : Double(-15.0 + min(8.0, simulator.timeScale * 3.0 + singularityBoost))
            boxCtrl.gain = targetGain
        }
        
        // 2. 更新左右手指尖 3D 力場音效 (0: 左手, 1: 右手)
        for idx in 0...1 {
            let mode = simulator.isPaused ? 0.0 : simulator.handForces[idx].w
            let prevMode = currentHandModes[idx] ?? 0.0
            
            guard mode != prevMode else { continue }
            currentHandModes[idx] = mode
            
            if mode > 0.5 {
                // ✋ 張開吸引：播放青色漩渦共鳴音
                handRepelControllers[idx]?.pause()
                if let attractCtrl = handAttractControllers[idx], !attractCtrl.isPlaying {
                    attractCtrl.play()
                }
            } else if mode < -0.5 {
                // 🤏 捏合排斥：播放熾紅超新星脈衝震波音
                handAttractControllers[idx]?.pause()
                if let repelCtrl = handRepelControllers[idx], !repelCtrl.isPlaying {
                    repelCtrl.play()
                }
            } else {
                // 手指離開透明盒子：停止該手指尖音效
                stopHandAudio(index: idx)
            }
        }
    }
    
    private func stopHandAudio(index: Int) {
        handAttractControllers[index]?.pause()
        handRepelControllers[index]?.pause()
        currentHandModes[index] = 0.0
    }
    
    func stopAll() {
        boxAmbientController?.stop()
        boxAmbientController = nil
        for idx in 0...1 {
            handAttractControllers[idx]?.stop()
            handRepelControllers[idx]?.stop()
        }
        handAttractControllers.removeAll()
        handRepelControllers.removeAll()
        currentHandModes = [0: 0.0, 1: 0.0]
    }
    
    // MARK: - 波形合成器 (Procedural Sine + Harmonic AM Synthesizer)
    
    private func generateLoopingWavFile(
        name: String,
        duration: Double,
        frequencies: [(freq: Double, amp: Double)],
        pulseHz: Double
    ) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        let sampleRate: Double = 44100.0
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channelData = buffer.floatChannelData?[0] else {
            throw NSError(domain: "SpatialAudioManager", code: -1)
        }
        
        buffer.frameLength = frameCount
        let twoPi = 2.0 * Double.pi
        
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            var sample: Double = 0.0
            
            for (freq, amp) in frequencies {
                sample += sin(twoPi * freq * t) * amp
            }
            
            // 加上平緩的振幅調變 (AM Envelope)，由於 pulseHz 與 frequencies 皆為整數週期，首尾相位 100% 零爆音無縫銜接
            let modulation = 0.78 + 0.22 * sin(twoPi * pulseHz * t)
            channelData[i] = Float(max(-0.95, min(0.95, sample * modulation * 0.35)))
        }
        
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
        
        let audioFile = try AVAudioFile(forWriting: url, settings: format.settings)
        try audioFile.write(from: buffer)
        return url
    }
}
