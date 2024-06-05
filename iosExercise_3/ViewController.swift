//
//  ViewController.swift
//  iosExercise_3
//
//  Created by 莊善傑 on 2024/6/6.
//

import UIKit
import AVKit

struct VideoRequest: Codable {
    let guestKey: String
    let videoID: String
    let mode: Int
}

struct VideoResponse: Codable {
    let status: Int
    let errMsgs: [String]
    let result: VideoResult
}

struct VideoResult: Codable {
    let videoInfo: VideoInfo
}

struct VideoInfo: Codable {
    let videourl: String
    let captionResult: CaptionResult
}

struct CaptionResult: Codable {
    let state: Int
    let results: [CaptionResultDetail]
}

struct CaptionResultDetail: Codable {
    let captions: [Caption]
}

struct Caption: Codable {
    let miniSecond: Double
    let content: String
}

class ViewController: UIViewController {

    @IBOutlet weak var tableView1: UITableView!
    @IBOutlet weak var videoContainerView: UIView!
    @IBOutlet weak var playImage: UIImageView!
    
    var player: AVPlayer!
    var playerViewController: AVPlayerViewController!
    var subtitles: [Caption] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView1.dataSource = self
        tableView1.delegate = self
        let nib = UINib(nibName: "contentTableViewCell", bundle: nil)
        tableView1.register(nib, forCellReuseIdentifier: "Cell")
        
        fetchVideoDetails { [weak self] videoResponse in
            guard let self = self, let videoResponse = videoResponse else { return }
            DispatchQueue.main.async {
                self.setupPlayer(with: "https://itutbox.s3.amazonaws.com/youtubeMP4/Online/5ee07d2e4486bc1b20c535bf%5bFriday%20Joke%5d%20A%20Woman%20Gets%20On%20A%20Bus%20-%20YouTube.mp4.mp4")
                self.subtitles = videoResponse.result.videoInfo.captionResult.results.first?.captions ?? []
                self.tableView1.reloadData()
                self.player.addObserver(self, forKeyPath: "rate", options: .new, context: nil)
            }
        }
    
    }
    
    func fetchVideoDetails(completion: @escaping (VideoResponse?) -> Void) {
        let url = URL(string: "https://api.italkutalk.com/api/video/detail")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = VideoRequest(guestKey: "44f6cfed-b251-4952-b6ab-34de1a599ae4", videoID: "5edfb3b04486bc1b20c2851a", mode: 0)
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            print("Failed to encode request body: \(error)")
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("Failed to fetch data: \(error?.localizedDescription ?? "No error description")")
                completion(nil)
                return
            }
            
            do {
                let videoResponse = try JSONDecoder().decode(VideoResponse.self, from: data)
                if videoResponse.status == 0 {
                    completion(videoResponse)
                } else {
                    print("Error: \(videoResponse.errMsgs.joined(separator: ", "))")
                    completion(nil)
                }
            } catch {
                print("Failed to decode response: \(error)")
                completion(nil)
            }
        }.resume()
    }
    
    func setupPlayer(with videoUrl: String) {
        
        guard let url = URL(string: videoUrl) else {
            print("Invalid URL")
            return
        }
        
        player = AVPlayer(url: url)
        playerViewController = AVPlayerViewController()
        playerViewController.player = player
        
        addChild(playerViewController)
        videoContainerView.addSubview(playerViewController.view)
        playerViewController.didMove(toParent: self)
        
        // playerViewController 受 videoContainerView 約束
        playerViewController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playerViewController.view.leadingAnchor.constraint(equalTo: videoContainerView.leadingAnchor),
            playerViewController.view.trailingAnchor.constraint(equalTo: videoContainerView.trailingAnchor),
            playerViewController.view.topAnchor.constraint(equalTo: videoContainerView.topAnchor),
            playerViewController.view.bottomAnchor.constraint(equalTo: videoContainerView.bottomAnchor)
        ])
        
        //相關影片進度監聽
        player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 600), queue: .main) { [weak self] time in
            self?.highlightCurrentSubtitle()
            if let currentItem = self?.player.currentItem, currentItem.duration.isValid {
                let currentTime = currentItem.currentTime()
                let duration = currentItem.duration
                if currentTime >= duration {
                    self?.playerDidFinishPlaying()
                }
            }
        }
        

    }
    
    func playerPause() {
        player.pause()
        playImage.image = UIImage(systemName: "play.circle.fill")
    }
    
    func  playerPlay() {
        player.play()
        playImage.image = UIImage(systemName: "pause.circle.fill")
    }
    
    @IBAction func playPauseTapped(_ sender: UIButton) {
        if player.timeControlStatus == .playing {
            playerPause()
        } else {
            playerPlay()
        }
    }
    
    //高亮當前影片進度字幕
    func highlightCurrentSubtitle() {
        let currentTime = CMTimeGetSeconds(player.currentTime())
        for (index, subtitle) in subtitles.enumerated() {
            if currentTime >= subtitle.miniSecond && (index == subtitles.count - 1 || currentTime < subtitles[index + 1].miniSecond) {
                tableView1.selectRow(at: IndexPath(row: index, section: 0), animated: true, scrollPosition: .middle)
                break
            }
        }
    }
    
    func playerDidFinishPlaying() {
        player.seek(to: .zero)
        playerPause()
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "rate" {
            DispatchQueue.main.async {
                if self.player.rate == 0 {
                    self.playImage.image = UIImage(systemName: "play.circle.fill")
                } else {
                    self.playImage.image = UIImage(systemName: "pause.circle.fill")
                }
            }
        }
    }
}

extension ViewController: UITableViewDelegate,UITableViewDataSource{
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int{
        return subtitles.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell{
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! contentTableViewCell
        let subtitle = subtitles[indexPath.row]
        cell.contentLabel?.text = subtitle.content
        cell.contentRowLabel?.text = "\(indexPath.row + 1)"
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let timestamp = subtitles[indexPath.row].miniSecond
        let cmTime = CMTime(seconds: timestamp, preferredTimescale: 600)
        let tolerance = CMTime(seconds: 0.01, preferredTimescale: 600)
        player.seek(to: cmTime, toleranceBefore: tolerance, toleranceAfter: tolerance) { completed in
            if completed {
                self.playerPlay()
            }
        }

    }
}
