import Flutter
import UIKit
import AVFoundation
import MediaPlayer

public class SwiftRemotePlayerPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    var player: AVPlayer?
    var playerItem: AVPlayerItem?
    var eventSink: FlutterEventSink?
    var timeObserverToken: Any?
    var stateObserverToken: Any?
    private var playerItemContext = 0
    
    static var shared: SwiftRemotePlayerPlugin?
    
    override init() {
        super.init()
        
        self.setupRemoteTransportControls()
    }
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.dralien/remote_player", binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel(name: "com.dralien/remote_player/event", binaryMessenger: registrar.messenger())
        
        let instance = SwiftRemotePlayerPlugin()
        
        SwiftRemotePlayerPlugin.shared = instance
        
        registrar.addMethodCallDelegate(instance, channel: channel)
        eventChannel.setStreamHandler(instance)
    }
    
    public func onListen(withArguments arguments: Any?,
                         eventSink: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = eventSink
        sendTimeEvent()
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        NotificationCenter.default.removeObserver(self)
        self.eventSink = nil
        return nil
    }
    
    private func addPeriodicTimeObserver() {
        guard let _player = self.player else { return }
        
        let _me = self
        
        let timeScale = CMTimeScale(NSEC_PER_SEC)
        let time = CMTime(seconds: 0.01, preferredTimescale: timeScale)
        self.timeObserverToken = _player.addPeriodicTimeObserver(forInterval: time,
                                                           queue: .main) {
                                                            [weak self] time in
                                                            _me.sendTimeEvent()
//                                                            print(time)
        }
    }
    
    private func removePeriodicTimeObserver() {
        guard let _player = self.player else { return }
        if let timeObserverToken = timeObserverToken {
            _player.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
    }
    
    private func sendTimeEvent() {
        guard let _eventSink = self.eventSink else { return }
        guard let _player = self.player else { return }
        
        let _time = _player.currentItem?.currentTime()
        if let __time = _time {
            _eventSink([ "duration": Float(CMTimeGetSeconds(__time)), "event": "onDuration" ])
        }
    }
    
    private func sendStateEvent(state: Int) {
        guard let _eventSink = self.eventSink else { return }
        _eventSink([ "state": state, "event": "onState" ])
    }
    
    func setupRemoteTransportControls() {
        // Get the shared MPRemoteCommandCenter
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Add handler for Play Command
        commandCenter.playCommand.addTarget { [unowned self] event in
            if self.player != nil {
                self.resume()
            } else {
                self.play()
                return .success
            }
            return .commandFailed
        }
        
        // Add handler for Pause Command
        commandCenter.pauseCommand.addTarget { [unowned self] event in
            if self.player?.rate == 1.0 {
                self.pause()
                return .success
            }
            return .commandFailed
        }
        
        commandCenter.stopCommand.addTarget { [unowned self] event in
            if self.player != nil {
                self.stop()
                return .success
            }
            return .commandFailed
        }
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        print(call.method)
//        enum RemotePlayerState {
//            stopped,
//            paused,
//            playing,
//            resuming,
//            error
//        }
        if (call.method == "setup") {
            if (self.player != nil) {
                let _time = self.player?.currentItem?.currentTime()
                if let __time = _time {
                    result([ "state": self.player?.rate == 1.0 ? 2 : 1, "duration": Float(CMTimeGetSeconds(__time)) ])
                } else {
                    result([ "state": self.player?.rate == 1.0 ? 2 : 1, "duration": 0.0 ])
                }
            } else {
                result([ "state": 0, "duration": 0.0 ])
            }
        } else if (call.method == "play") {
            let a = call.arguments as! NSDictionary
            let url = a["url"]
            let title = a["title"]
            let artist = a["artist"]
            let album = a["album"]
            
            if (url != nil && title != nil && artist != nil) {
                self.play(result: result,
                          url: url as! String,
                          title: title as! String,
                          artist: artist as! String,
                          album: album as! String)
                print("not null")
            } else {
                result("parameter error");
            }
        } else if (call.method == "stop") {
            self.stop()
            result("stop")
        } else if (call.method == "pause") {
            self.pause()
            result("pause")
        } else if (call.method == "resume") {
            self.resume()
            result("resumed")
        } else if (call.method == "toggle") {
            if (self.player?.rate == 1.0) {
                self.pause()
            } else {
                self.resume()
            }
        } else {
            result("Remote Audio Player plugin for iOS, Android")
        }
    }
    
    public func resume() {
        sendStateEvent(state: 3)
        if (self.player != nil) {
            self.player?.play()
            sendStateEvent(state: 2)
        } else {
            sendStateEvent(state: 4)
        }
    }
    
    public func play(result: FlutterResult, url: String, title: String, artist: String, album: String) {
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
            let remoteUrl = URL(string: url)
            self.playerItem = AVPlayerItem(url: remoteUrl!)
            self.player = AVPlayer(playerItem: self.playerItem)
            
            self.player?.addObserver(self, forKeyPath: #keyPath(AVPlayer.status), options: [.new, .initial], context: nil)
            self.player?.addObserver(self, forKeyPath: #keyPath(AVPlayer.currentItem.status), options:[.new, .initial], context: nil)
            
            self.player?.play()
            self.addPeriodicTimeObserver()
        } catch let error {
            fatalError("*** Unable to set up the audio session: \(error.localizedDescription) ***")
        }
    
        var nowPlayingInfo = [String : Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = title
        nowPlayingInfo[MPMediaItemPropertyArtist] = artist
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = album
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        
        result("playing")
        sendStateEvent(state: 2)
    }
    
    public func play() {
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
            
            self.player = AVPlayer(playerItem: self.playerItem)
            self.player?.seek(to: CMTimeMake(0, 0))
            self.player?.play()
        } catch let error {
            fatalError("*** Unable to set up the audio session: \(error.localizedDescription) ***")
        }
    }
    
    public func pause() {
        self.player!.pause()
        sendStateEvent(state: 1)
    }
    
    public func stop() {
        if player != nil {
            self.removePeriodicTimeObserver()
            self.player?.pause()
            self.player = nil
            
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            print("stopped")
        }
        sendStateEvent(state: 0)
    }
    
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        guard let _player = self.player else { return }
        print(_player.status)
//        if let player = ((object as? AVPlayer) != nil) && keyPath == #keyPath(AVPlayer.currentItem.status) {
//            let newStatus: AVPlayerItemStatus
//            if let newStatusAsNumber = change?[NSKeyValueChangeKey.newKey] as? NSNumber {
//                newStatus = AVPlayerItemStatus(rawValue: newStatusAsNumber.intValue)!
//            } else {
//                newStatus = .unknown
//            }
//            if newStatus == .failed {
//                NSLog("Error: \(String(describing: self.player?.currentItem?.error?.localizedDescription)), error: \(String(describing: self.player?.currentItem?.error))")
//            }
//        }
    }
}
