---
title: "在移动端使用 WebRTC (Android/iOS)"
description: "1. [移动端 WebRTC 概述](#1-移动端-webrtc-概述)"
pubDate: "2025-12-17"
tags: ["webrtc","audio","video"]
category: "webrtc"
series: "WebRTC 音视频开发"
order: 25
---

> 本文是 WebRTC 系列专栏的第二十五篇,也是本系列的收官之作。我们将探讨如何在 Android 和 iOS 平台上使用 WebRTC Native SDK 构建跨平台实时应用。

---

## 目录

1. [移动端 WebRTC 概述](#1-移动端-webrtc-概述)
2. [Android 集成](#2-android-集成)
3. [iOS 集成](#3-ios-集成)
4. [跨平台方案](#4-跨平台方案)
5. [性能优化](#5-性能优化)
6. [常见问题](#6-常见问题)
7. [总结](#7-总结)

---

## 1. 移动端 WebRTC 概述

### 1.1 移动端特点

```
移动端 WebRTC 挑战:

1. 硬件差异
   - 不同设备性能差异大
   - 摄像头/麦克风规格不同

2. 网络环境
   - WiFi/4G/5G 切换
   - 网络不稳定

3. 电量消耗
   - 编解码耗电
   - 网络传输耗电

4. 后台限制
   - iOS 后台限制严格
   - Android 后台服务限制

5. 权限管理
   - 摄像头/麦克风权限
   - 后台运行权限
```

### 1.2 SDK 选择

| 方案 | 说明 | 适用场景 |
|------|------|---------|
| WebRTC Native | Google 官方 SDK | 原生开发 |
| WebView | 浏览器内核 | 简单集成 |
| Flutter WebRTC | Flutter 插件 | 跨平台 |
| React Native | RN 插件 | 跨平台 |

### 1.3 架构对比

```
原生 SDK vs WebView:

原生 SDK:
+------------------+
|   Application    |
+------------------+
|  WebRTC Native   |
+------------------+
|   OS (Android/iOS)|
+------------------+

优点: 性能好,功能完整
缺点: 开发成本高

WebView:
+------------------+
|   Application    |
+------------------+
|     WebView      |
+------------------+
|  WebRTC (浏览器)  |
+------------------+
|   OS             |
+------------------+

优点: 开发简单,跨平台
缺点: 性能受限,功能受限
```

---

## 2. Android 集成

### 2.1 添加依赖

```groovy
// build.gradle (app)
dependencies {
    // WebRTC 官方库
    implementation 'org.webrtc:google-webrtc:1.0.32006'
    
    // 或使用 JitsiMeet 维护的版本
    // implementation 'com.onesignal:onesignal-webrtc:1.0.0'
}

// 权限配置 AndroidManifest.xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

<uses-feature android:name="android.hardware.camera" />
<uses-feature android:name="android.hardware.camera.autofocus" />
```

### 2.2 初始化

```kotlin
// WebRTCManager.kt
class WebRTCManager(private val context: Context) {
    
    private var peerConnectionFactory: PeerConnectionFactory? = null
    private var peerConnection: PeerConnection? = null
    private var localVideoTrack: VideoTrack? = null
    private var localAudioTrack: AudioTrack? = null
    
    private var videoCapturer: VideoCapturer? = null
    private var surfaceTextureHelper: SurfaceTextureHelper? = null
    
    private val eglBase = EglBase.create()
    
    // 初始化
    fun initialize() {
        // 初始化 PeerConnectionFactory
        val options = PeerConnectionFactory.InitializationOptions.builder(context)
            .setEnableInternalTracer(true)
            .createInitializationOptions()
        PeerConnectionFactory.initialize(options)
        
        // 创建 PeerConnectionFactory
        val encoderFactory = DefaultVideoEncoderFactory(
            eglBase.eglBaseContext,
            true,  // 启用硬件加速
            true   // 启用 H.264 高配置
        )
        val decoderFactory = DefaultVideoDecoderFactory(eglBase.eglBaseContext)
        
        peerConnectionFactory = PeerConnectionFactory.builder()
            .setVideoEncoderFactory(encoderFactory)
            .setVideoDecoderFactory(decoderFactory)
            .setOptions(PeerConnectionFactory.Options())
            .createPeerConnectionFactory()
    }
    
    // 创建 PeerConnection
    fun createPeerConnection(observer: PeerConnection.Observer): PeerConnection? {
        val iceServers = listOf(
            PeerConnection.IceServer.builder("stun:stun.l.google.com:19302").createIceServer()
        )
        
        val rtcConfig = PeerConnection.RTCConfiguration(iceServers).apply {
            sdpSemantics = PeerConnection.SdpSemantics.UNIFIED_PLAN
            continualGatheringPolicy = PeerConnection.ContinualGatheringPolicy.GATHER_CONTINUALLY
        }
        
        peerConnection = peerConnectionFactory?.createPeerConnection(rtcConfig, observer)
        return peerConnection
    }
    
    // 创建本地媒体
    fun createLocalMedia(localView: SurfaceViewRenderer) {
        // 初始化本地视图
        localView.init(eglBase.eglBaseContext, null)
        localView.setMirror(true)
        
        // 创建视频源
        videoCapturer = createCameraCapturer()
        surfaceTextureHelper = SurfaceTextureHelper.create("CaptureThread", eglBase.eglBaseContext)
        
        val videoSource = peerConnectionFactory?.createVideoSource(videoCapturer!!.isScreencast)
        videoCapturer?.initialize(surfaceTextureHelper, context, videoSource?.capturerObserver)
        videoCapturer?.startCapture(1280, 720, 30)
        
        localVideoTrack = peerConnectionFactory?.createVideoTrack("video0", videoSource)
        localVideoTrack?.addSink(localView)
        
        // 创建音频源
        val audioConstraints = MediaConstraints().apply {
            mandatory.add(MediaConstraints.KeyValuePair("googEchoCancellation", "true"))
            mandatory.add(MediaConstraints.KeyValuePair("googNoiseSuppression", "true"))
            mandatory.add(MediaConstraints.KeyValuePair("googAutoGainControl", "true"))
        }
        val audioSource = peerConnectionFactory?.createAudioSource(audioConstraints)
        localAudioTrack = peerConnectionFactory?.createAudioTrack("audio0", audioSource)
    }
    
    private fun createCameraCapturer(): VideoCapturer? {
        val enumerator = Camera2Enumerator(context)
        
        // 优先使用前置摄像头
        for (deviceName in enumerator.deviceNames) {
            if (enumerator.isFrontFacing(deviceName)) {
                return enumerator.createCapturer(deviceName, null)
            }
        }
        
        // 使用后置摄像头
        for (deviceName in enumerator.deviceNames) {
            if (enumerator.isBackFacing(deviceName)) {
                return enumerator.createCapturer(deviceName, null)
            }
        }
        
        return null
    }
    
    // 添加轨道到 PeerConnection
    fun addTracksToConnection() {
        localVideoTrack?.let { track ->
            peerConnection?.addTrack(track, listOf("stream0"))
        }
        localAudioTrack?.let { track ->
            peerConnection?.addTrack(track, listOf("stream0"))
        }
    }
    
    // 创建 Offer
    fun createOffer(callback: (SessionDescription?) -> Unit) {
        val constraints = MediaConstraints().apply {
            mandatory.add(MediaConstraints.KeyValuePair("OfferToReceiveVideo", "true"))
            mandatory.add(MediaConstraints.KeyValuePair("OfferToReceiveAudio", "true"))
        }
        
        peerConnection?.createOffer(object : SdpObserver {
            override fun onCreateSuccess(sdp: SessionDescription?) {
                peerConnection?.setLocalDescription(object : SdpObserver {
                    override fun onSetSuccess() {
                        callback(sdp)
                    }
                    override fun onSetFailure(error: String?) {}
                    override fun onCreateSuccess(sdp: SessionDescription?) {}
                    override fun onCreateFailure(error: String?) {}
                }, sdp)
            }
            override fun onCreateFailure(error: String?) {
                callback(null)
            }
            override fun onSetSuccess() {}
            override fun onSetFailure(error: String?) {}
        }, constraints)
    }
    
    // 设置远程描述
    fun setRemoteDescription(sdp: SessionDescription, callback: () -> Unit) {
        peerConnection?.setRemoteDescription(object : SdpObserver {
            override fun onSetSuccess() {
                callback()
            }
            override fun onSetFailure(error: String?) {}
            override fun onCreateSuccess(sdp: SessionDescription?) {}
            override fun onCreateFailure(error: String?) {}
        }, sdp)
    }
    
    // 添加 ICE Candidate
    fun addIceCandidate(candidate: IceCandidate) {
        peerConnection?.addIceCandidate(candidate)
    }
    
    // 设置远程视频视图
    fun setRemoteView(remoteView: SurfaceViewRenderer) {
        remoteView.init(eglBase.eglBaseContext, null)
    }
    
    // 释放资源
    fun release() {
        videoCapturer?.stopCapture()
        videoCapturer?.dispose()
        surfaceTextureHelper?.dispose()
        localVideoTrack?.dispose()
        localAudioTrack?.dispose()
        peerConnection?.close()
        peerConnectionFactory?.dispose()
        eglBase.release()
    }
}
```

### 2.3 Activity 实现

```kotlin
// VideoCallActivity.kt
class VideoCallActivity : AppCompatActivity(), PeerConnection.Observer {
    
    private lateinit var webRTCManager: WebRTCManager
    private lateinit var signalingClient: SignalingClient
    
    private lateinit var localView: SurfaceViewRenderer
    private lateinit var remoteView: SurfaceViewRenderer
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_video_call)
        
        localView = findViewById(R.id.localView)
        remoteView = findViewById(R.id.remoteView)
        
        // 检查权限
        if (checkPermissions()) {
            initWebRTC()
        } else {
            requestPermissions()
        }
    }
    
    private fun initWebRTC() {
        webRTCManager = WebRTCManager(this)
        webRTCManager.initialize()
        webRTCManager.createPeerConnection(this)
        webRTCManager.createLocalMedia(localView)
        webRTCManager.setRemoteView(remoteView)
        webRTCManager.addTracksToConnection()
        
        // 初始化信令
        signalingClient = SignalingClient(this)
        signalingClient.connect()
    }
    
    // 发起通话
    fun startCall() {
        webRTCManager.createOffer { sdp ->
            sdp?.let {
                signalingClient.sendOffer(it)
            }
        }
    }
    
    // PeerConnection.Observer 实现
    override fun onIceCandidate(candidate: IceCandidate?) {
        candidate?.let {
            signalingClient.sendCandidate(it)
        }
    }
    
    override fun onTrack(transceiver: RtpTransceiver?) {
        transceiver?.receiver?.track()?.let { track ->
            if (track is VideoTrack) {
                runOnUiThread {
                    track.addSink(remoteView)
                }
            }
        }
    }
    
    override fun onIceConnectionChange(state: PeerConnection.IceConnectionState?) {
        Log.d("WebRTC", "ICE state: $state")
    }
    
    // 其他 Observer 方法...
    override fun onSignalingChange(state: PeerConnection.SignalingState?) {}
    override fun onIceConnectionReceivingChange(receiving: Boolean) {}
    override fun onIceGatheringChange(state: PeerConnection.IceGatheringState?) {}
    override fun onAddStream(stream: MediaStream?) {}
    override fun onRemoveStream(stream: MediaStream?) {}
    override fun onDataChannel(channel: DataChannel?) {}
    override fun onRenegotiationNeeded() {}
    override fun onAddTrack(receiver: RtpReceiver?, streams: Array<out MediaStream>?) {}
    
    override fun onDestroy() {
        super.onDestroy()
        webRTCManager.release()
        signalingClient.disconnect()
    }
}
```

---

## 3. iOS 集成

### 3.1 添加依赖

```ruby
# Podfile
platform :ios, '12.0'

target 'YourApp' do
  use_frameworks!
  
  # WebRTC
  pod 'GoogleWebRTC'
  
  # 或使用 Location 维护的版本
  # pod 'WebRTC-lib'
end
```

```xml
<!-- Info.plist 权限配置 -->
<key>NSCameraUsageDescription</key>
<string>需要访问摄像头进行视频通话</string>
<key>NSMicrophoneUsageDescription</key>
<string>需要访问麦克风进行语音通话</string>
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
    <string>voip</string>
</array>
```

### 3.2 WebRTC 管理器

```swift
// WebRTCManager.swift
import WebRTC

class WebRTCManager: NSObject {
    
    private var peerConnectionFactory: RTCPeerConnectionFactory!
    private var peerConnection: RTCPeerConnection?
    private var localVideoTrack: RTCVideoTrack?
    private var localAudioTrack: RTCAudioTrack?
    
    private var videoCapturer: RTCCameraVideoCapturer?
    private var localVideoSource: RTCVideoSource?
    
    weak var delegate: WebRTCManagerDelegate?
    
    // 初始化
    func initialize() {
        RTCInitializeSSL()
        
        let encoderFactory = RTCDefaultVideoEncoderFactory()
        let decoderFactory = RTCDefaultVideoDecoderFactory()
        
        peerConnectionFactory = RTCPeerConnectionFactory(
            encoderFactory: encoderFactory,
            decoderFactory: decoderFactory
        )
    }
    
    // 创建 PeerConnection
    func createPeerConnection() {
        let config = RTCConfiguration()
        config.iceServers = [
            RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"])
        ]
        config.sdpSemantics = .unifiedPlan
        config.continualGatheringPolicy = .gatherContinually
        
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: nil
        )
        
        peerConnection = peerConnectionFactory.peerConnection(
            with: config,
            constraints: constraints,
            delegate: self
        )
    }
    
    // 创建本地媒体
    func createLocalMedia(localView: RTCMTLVideoView) {
        // 视频
        localVideoSource = peerConnectionFactory.videoSource()
        videoCapturer = RTCCameraVideoCapturer(delegate: localVideoSource!)
        
        localVideoTrack = peerConnectionFactory.videoTrack(
            with: localVideoSource!,
            trackId: "video0"
        )
        localVideoTrack?.add(localView)
        
        // 启动摄像头
        startCapture()
        
        // 音频
        let audioConstraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: nil
        )
        let audioSource = peerConnectionFactory.audioSource(with: audioConstraints)
        localAudioTrack = peerConnectionFactory.audioTrack(
            with: audioSource,
            trackId: "audio0"
        )
    }
    
    private func startCapture() {
        guard let capturer = videoCapturer else { return }
        
        let devices = RTCCameraVideoCapturer.captureDevices()
        guard let frontCamera = devices.first(where: { $0.position == .front }) else { return }
        
        let formats = RTCCameraVideoCapturer.supportedFormats(for: frontCamera)
        guard let format = formats.first(where: {
            let dimensions = CMVideoFormatDescriptionGetDimensions($0.formatDescription)
            return dimensions.width == 1280 && dimensions.height == 720
        }) ?? formats.last else { return }
        
        let fps = format.videoSupportedFrameRateRanges.first?.maxFrameRate ?? 30
        
        capturer.startCapture(
            with: frontCamera,
            format: format,
            fps: Int(fps)
        )
    }
    
    // 添加轨道
    func addTracksToConnection() {
        if let videoTrack = localVideoTrack {
            peerConnection?.add(videoTrack, streamIds: ["stream0"])
        }
        if let audioTrack = localAudioTrack {
            peerConnection?.add(audioTrack, streamIds: ["stream0"])
        }
    }
    
    // 创建 Offer
    func createOffer(completion: @escaping (RTCSessionDescription?) -> Void) {
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: [
                "OfferToReceiveVideo": "true",
                "OfferToReceiveAudio": "true"
            ],
            optionalConstraints: nil
        )
        
        peerConnection?.offer(for: constraints) { [weak self] sdp, error in
            guard let sdp = sdp else {
                completion(nil)
                return
            }
            
            self?.peerConnection?.setLocalDescription(sdp) { error in
                completion(error == nil ? sdp : nil)
            }
        }
    }
    
    // 创建 Answer
    func createAnswer(completion: @escaping (RTCSessionDescription?) -> Void) {
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: [
                "OfferToReceiveVideo": "true",
                "OfferToReceiveAudio": "true"
            ],
            optionalConstraints: nil
        )
        
        peerConnection?.answer(for: constraints) { [weak self] sdp, error in
            guard let sdp = sdp else {
                completion(nil)
                return
            }
            
            self?.peerConnection?.setLocalDescription(sdp) { error in
                completion(error == nil ? sdp : nil)
            }
        }
    }
    
    // 设置远程描述
    func setRemoteDescription(_ sdp: RTCSessionDescription, completion: @escaping () -> Void) {
        peerConnection?.setRemoteDescription(sdp) { error in
            if error == nil {
                completion()
            }
        }
    }
    
    // 添加 ICE Candidate
    func addIceCandidate(_ candidate: RTCIceCandidate) {
        peerConnection?.add(candidate)
    }
    
    // 切换摄像头
    func switchCamera() {
        guard let capturer = videoCapturer else { return }
        
        let devices = RTCCameraVideoCapturer.captureDevices()
        let currentPosition = capturer.captureSession.inputs
            .compactMap { ($0 as? AVCaptureDeviceInput)?.device.position }
            .first ?? .front
        
        let newPosition: AVCaptureDevice.Position = currentPosition == .front ? .back : .front
        
        guard let newCamera = devices.first(where: { $0.position == newPosition }) else { return }
        
        let formats = RTCCameraVideoCapturer.supportedFormats(for: newCamera)
        guard let format = formats.last else { return }
        
        let fps = format.videoSupportedFrameRateRanges.first?.maxFrameRate ?? 30
        
        capturer.startCapture(with: newCamera, format: format, fps: Int(fps))
    }
    
    // 静音
    func setAudioEnabled(_ enabled: Bool) {
        localAudioTrack?.isEnabled = enabled
    }
    
    // 关闭视频
    func setVideoEnabled(_ enabled: Bool) {
        localVideoTrack?.isEnabled = enabled
    }
    
    // 释放资源
    func release() {
        videoCapturer?.stopCapture()
        localVideoTrack = nil
        localAudioTrack = nil
        peerConnection?.close()
        peerConnection = nil
    }
}

// MARK: - RTCPeerConnectionDelegate
extension WebRTCManager: RTCPeerConnectionDelegate {
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        print("Signaling state: \(stateChanged)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        print("Stream added")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        print("Stream removed")
    }
    
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        print("Negotiation needed")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        print("ICE connection state: \(newState)")
        delegate?.webRTCManager(self, didChangeIceConnectionState: newState)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        print("ICE gathering state: \(newState)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        delegate?.webRTCManager(self, didGenerateCandidate: candidate)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        print("Candidates removed")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        print("Data channel opened")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd rtpReceiver: RTCRtpReceiver, streams mediaStreams: [RTCMediaStream]) {
        if let videoTrack = rtpReceiver.track as? RTCVideoTrack {
            delegate?.webRTCManager(self, didReceiveRemoteVideoTrack: videoTrack)
        }
    }
}

// MARK: - Delegate Protocol
protocol WebRTCManagerDelegate: AnyObject {
    func webRTCManager(_ manager: WebRTCManager, didGenerateCandidate candidate: RTCIceCandidate)
    func webRTCManager(_ manager: WebRTCManager, didChangeIceConnectionState state: RTCIceConnectionState)
    func webRTCManager(_ manager: WebRTCManager, didReceiveRemoteVideoTrack track: RTCVideoTrack)
}
```

---

## 4. 跨平台方案

### 4.1 Flutter WebRTC

```yaml
# pubspec.yaml
dependencies:
  flutter_webrtc: ^0.9.0
```

```dart
// video_call_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class VideoCallPage extends StatefulWidget {
  @override
  _VideoCallPageState createState() => _VideoCallPageState();
}

class _VideoCallPageState extends State<VideoCallPage> {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  
  @override
  void initState() {
    super.initState();
    _initRenderers();
    _initWebRTC();
  }
  
  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }
  
  Future<void> _initWebRTC() async {
    // 获取本地媒体
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {
        'facingMode': 'user',
        'width': 1280,
        'height': 720,
      }
    });
    
    _localRenderer.srcObject = _localStream;
    
    // 创建 PeerConnection
    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'}
      ]
    };
    
    _peerConnection = await createPeerConnection(config);
    
    // 添加本地轨道
    _localStream?.getTracks().forEach((track) {
      _peerConnection?.addTrack(track, _localStream!);
    });
    
    // 监听远程轨道
    _peerConnection?.onTrack = (event) {
      if (event.track.kind == 'video') {
        _remoteRenderer.srcObject = event.streams[0];
        setState(() {});
      }
    };
    
    // 监听 ICE Candidate
    _peerConnection?.onIceCandidate = (candidate) {
      // 发送给对端
      _sendCandidate(candidate);
    };
  }
  
  Future<void> _createOffer() async {
    final offer = await _peerConnection?.createOffer();
    await _peerConnection?.setLocalDescription(offer!);
    // 发送 offer 给对端
    _sendOffer(offer!);
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Video Call')),
      body: Column(
        children: [
          Expanded(
            child: RTCVideoView(_remoteRenderer),
          ),
          Container(
            height: 150,
            child: RTCVideoView(
              _localRenderer,
              mirror: true,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: Icon(Icons.call),
                onPressed: _createOffer,
              ),
              IconButton(
                icon: Icon(Icons.call_end),
                onPressed: _hangUp,
              ),
              IconButton(
                icon: Icon(Icons.switch_camera),
                onPressed: _switchCamera,
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  void _switchCamera() {
    _localStream?.getVideoTracks().forEach((track) {
      Helper.switchCamera(track);
    });
  }
  
  void _hangUp() {
    _localStream?.dispose();
    _peerConnection?.close();
    Navigator.pop(context);
  }
  
  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }
}
```

### 4.2 React Native WebRTC

```javascript
// VideoCall.js
import React, { useEffect, useRef, useState } from 'react';
import { View, Button, StyleSheet } from 'react-native';
import {
  RTCPeerConnection,
  RTCView,
  mediaDevices,
} from 'react-native-webrtc';

const VideoCall = () => {
  const [localStream, setLocalStream] = useState(null);
  const [remoteStream, setRemoteStream] = useState(null);
  const pc = useRef(null);
  
  useEffect(() => {
    initWebRTC();
    return () => {
      cleanup();
    };
  }, []);
  
  const initWebRTC = async () => {
    // 获取本地媒体
    const stream = await mediaDevices.getUserMedia({
      audio: true,
      video: {
        facingMode: 'user',
        width: 1280,
        height: 720,
      },
    });
    setLocalStream(stream);
    
    // 创建 PeerConnection
    const config = {
      iceServers: [
        { urls: 'stun:stun.l.google.com:19302' },
      ],
    };
    
    pc.current = new RTCPeerConnection(config);
    
    // 添加本地轨道
    stream.getTracks().forEach(track => {
      pc.current.addTrack(track, stream);
    });
    
    // 监听远程轨道
    pc.current.ontrack = (event) => {
      setRemoteStream(event.streams[0]);
    };
    
    // 监听 ICE Candidate
    pc.current.onicecandidate = (event) => {
      if (event.candidate) {
        sendCandidate(event.candidate);
      }
    };
  };
  
  const createOffer = async () => {
    const offer = await pc.current.createOffer();
    await pc.current.setLocalDescription(offer);
    sendOffer(offer);
  };
  
  const switchCamera = () => {
    localStream?.getVideoTracks().forEach(track => {
      track._switchCamera();
    });
  };
  
  const cleanup = () => {
    localStream?.getTracks().forEach(track => track.stop());
    pc.current?.close();
  };
  
  return (
    <View style={styles.container}>
      {remoteStream && (
        <RTCView
          streamURL={remoteStream.toURL()}
          style={styles.remoteVideo}
        />
      )}
      {localStream && (
        <RTCView
          streamURL={localStream.toURL()}
          style={styles.localVideo}
          mirror={true}
        />
      )}
      <View style={styles.controls}>
        <Button title="Call" onPress={createOffer} />
        <Button title="Switch Camera" onPress={switchCamera} />
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  remoteVideo: {
    flex: 1,
  },
  localVideo: {
    position: 'absolute',
    bottom: 100,
    right: 20,
    width: 120,
    height: 160,
  },
  controls: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    padding: 20,
  },
});

export default VideoCall;
```

---

## 5. 性能优化

### 5.1 硬件加速

```kotlin
// Android: 启用硬件编解码
val encoderFactory = DefaultVideoEncoderFactory(
    eglBase.eglBaseContext,
    true,  // enableIntelVp8Encoder
    true   // enableH264HighProfile
)

// 检查硬件编码器支持
val supportedCodecs = encoderFactory.supportedCodecs
for (codec in supportedCodecs) {
    Log.d("WebRTC", "Supported encoder: ${codec.name}")
}
```

### 5.2 分辨率自适应

```kotlin
// 根据网络状况调整分辨率
class AdaptiveVideoManager {
    private var currentWidth = 1280
    private var currentHeight = 720
    
    fun onNetworkQualityChanged(quality: NetworkQuality) {
        when (quality) {
            NetworkQuality.EXCELLENT -> setResolution(1280, 720)
            NetworkQuality.GOOD -> setResolution(960, 540)
            NetworkQuality.FAIR -> setResolution(640, 360)
            NetworkQuality.POOR -> setResolution(320, 240)
        }
    }
    
    private fun setResolution(width: Int, height: Int) {
        if (width != currentWidth || height != currentHeight) {
            currentWidth = width
            currentHeight = height
            videoCapturer?.changeCaptureFormat(width, height, 30)
        }
    }
}
```

### 5.3 电量优化

```swift
// iOS: 后台音频保持
func configureAudioSession() {
    let session = AVAudioSession.sharedInstance()
    
    do {
        try session.setCategory(
            .playAndRecord,
            mode: .voiceChat,
            options: [.allowBluetooth, .defaultToSpeaker]
        )
        try session.setActive(true)
    } catch {
        print("Audio session error: \(error)")
    }
}

// 进入后台时降低帧率
func applicationDidEnterBackground() {
    videoCapturer?.stopCapture()
    // 或降低帧率
    // videoCapturer?.changeCaptureFormat(640, 480, 15)
}
```

---

## 6. 常见问题

### 6.1 权限处理

```kotlin
// Android 权限请求
private fun checkPermissions(): Boolean {
    val permissions = arrayOf(
        Manifest.permission.CAMERA,
        Manifest.permission.RECORD_AUDIO
    )
    
    return permissions.all {
        ContextCompat.checkSelfPermission(this, it) == PackageManager.PERMISSION_GRANTED
    }
}

private fun requestPermissions() {
    ActivityCompat.requestPermissions(
        this,
        arrayOf(Manifest.permission.CAMERA, Manifest.permission.RECORD_AUDIO),
        PERMISSION_REQUEST_CODE
    )
}
```

### 6.2 网络切换

```kotlin
// 监听网络变化
class NetworkMonitor(context: Context) {
    private val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    
    fun startMonitoring(callback: (Boolean) -> Unit) {
        val networkCallback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                callback(true)
            }
            
            override fun onLost(network: Network) {
                callback(false)
            }
        }
        
        val request = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()
        
        connectivityManager.registerNetworkCallback(request, networkCallback)
    }
}
```

### 6.3 设备兼容性

```kotlin
// 检查设备能力
fun checkDeviceCapabilities(): DeviceCapabilities {
    val cameraEnumerator = Camera2Enumerator(context)
    
    return DeviceCapabilities(
        hasFrontCamera = cameraEnumerator.deviceNames.any { 
            cameraEnumerator.isFrontFacing(it) 
        },
        hasBackCamera = cameraEnumerator.deviceNames.any { 
            cameraEnumerator.isBackFacing(it) 
        },
        supportsHardwareEncoding = checkHardwareEncodingSupport()
    )
}
```

---

## 7. 总结

### 7.1 核心要点

| 平台 | SDK | 特点 |
|------|-----|------|
| Android | google-webrtc | 原生性能好 |
| iOS | GoogleWebRTC | 原生性能好 |
| Flutter | flutter_webrtc | 跨平台 |
| React Native | react-native-webrtc | 跨平台 |

### 7.2 最佳实践

```
移动端 WebRTC 最佳实践:

1. 权限管理
   - 提前请求权限
   - 处理权限拒绝

2. 生命周期
   - 正确释放资源
   - 处理后台切换

3. 性能优化
   - 启用硬件加速
   - 自适应分辨率
   - 电量优化

4. 网络处理
   - 监听网络变化
   - ICE 重启
   - 断线重连
```

### 7.3 系列总结

恭喜你完成了 WebRTC 技术专栏的全部学习!

本系列共 25 篇文章,涵盖了:
- **Part 1**: WebRTC 基础与快速入门 (5 篇)
- **Part 2**: 信令与会话管理 (6 篇)
- **Part 3**: 媒体传输深入讲解 (6 篇)
- **Part 4**: 音视频编码与媒体处理 (3 篇)
- **Part 5**: 工程实践 (5 篇)

希望这个系列能帮助你深入理解 WebRTC 技术,构建出色的实时通信应用!

---

## 参考资料

1. [WebRTC Native Code](https://webrtc.googlesource.com/src/)
2. [Flutter WebRTC](https://pub.dev/packages/flutter_webrtc)
3. [React Native WebRTC](https://github.com/react-native-webrtc/react-native-webrtc)

---

> 作者: WebRTC 技术专栏  
> 系列: 工程实践 (5/5)  
> 上一篇: [WebRTC 数据通道](./24-data-channel.md)

---

感谢阅读 WebRTC 技术专栏!
