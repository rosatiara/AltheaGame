//
//  RealTimeGame.swift
//  Althea
//
//  Created by Theresa Tiffany on 21/06/23.
//

import Foundation
import GameKit
import SwiftUI

/// - Tag:RealTimeGame
@MainActor
class RealTimeGame: NSObject, GKGameCenterControllerDelegate, ObservableObject {
    // The local player's friends, if they grant access.
    @Published var friends: [Friend] = []
    
    // The game interface state.
    @Published var matchAvailable = false
    @Published var playingGame = false
    @Published var myMatch: GKMatch? = nil
//    @Published var automatch = false
    
    // Outcomes of the game for notifing players.
    @Published var youForfeit = false
    @Published var opponentForfeit = false
    @Published var youWon = false
    @Published var opponentWon = false
    
    // The match information.
    @Published var myAvatar = Image(systemName: "person.crop.circle")
    @Published var opponentAvatar = Image(systemName: "person.crop.circle")
    @Published var opponentAvatar1 = Image(systemName: "person.crop.circle")
    @Published var opponent  : GKPlayer? = nil
    @Published var opponent1 : GKPlayer? = nil
    @Published var messages: [Message] = []
    @Published var myScore = 0
    @Published var opponentScore = 0
    @Published var opponentScore1 = 0
    
    // The voice chat properties.
    @Published var voiceChat: GKVoiceChat? = nil
    @Published var opponentSpeaking = false
    
    @Published var navigatorName = ""
    @Published var supplyName = ""
    @Published var cookName = ""
    
    /// The name of the match.
    var matchName: String {
        "\(opponentName) Match"
    }
    
    /// The local player's name.
    var myName: String {
        GKLocalPlayer.local.displayName
    }
    
    /// The opponent's name.
    var opponentName: String {
        opponent?.displayName ?? "Invitation Pending"
    }
    var opponentName1: String {
        opponent1?.displayName ?? "Invitation Pending"
    }
    
    /// The root view controller of the window.
    var rootViewController: UIViewController? {
        let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        return windowScene?.windows.first?.rootViewController
    }

    /// Authenticates the local player, initiates a multiplayer game, and adds the access point.
    /// - Tag:authenticatePlayer
    func authenticatePlayer() {
        // Set the authentication handler that GameKit invokes.
        GKLocalPlayer.local.authenticateHandler = { viewController, error in
            if let viewController = viewController {
                // If the view controller is non-nil, present it to the player so they can
                // perform some necessary action to complete authentication.
                self.rootViewController?.present(viewController, animated: true) { }
                return
            }
            if let error {
                // If you can’t authenticate the player, disable Game Center features in your game.
                print("Error: \(error.localizedDescription).")
                return
            }
            
            // A value of nil for viewController indicates successful authentication, and you can access
            // local player properties.
            
            // Load the local player's avatar.
            GKLocalPlayer.local.loadPhoto(for: GKPlayer.PhotoSize.small) { image, error in
                if let image {
                    self.myAvatar = Image(uiImage: image)
                }
                if let error {
                    // Handle an error if it occurs.
                    print("Error: \(error.localizedDescription).")
                }
            }

            // Register for real-time invitations from other players.
            GKLocalPlayer.local.register(self)
            
            // Add an access point to the interface.
            GKAccessPoint.shared.location = .topLeading
            GKAccessPoint.shared.showHighlights = true
            GKAccessPoint.shared.isActive = true
            
            // Enable the Start Game button.
            self.matchAvailable = true
        }
    }
    
    /// Starts the matchmaking process where GameKit finds a player for the match.
    /// - Tag:findPlayer
//    func findPlayer() async {
//        let request = GKMatchRequest()
//        request.minPlayers = 3
//        request.maxPlayers = 3
//        let match: GKMatch
//
//        // Start automatch.
//        do {
//            match = try await GKMatchmaker.shared().findMatch(for: request)
//        } catch {
//            print("Error: \(error.localizedDescription).")
//            return
//        }
//
//        // Start the game, although the automatch player hasn't connected yet.
//        if !playingGame {
//            startMyMatchWith(match: match)
//        }
//
//        // Stop automatch.
//        GKMatchmaker.shared().finishMatchmaking(for: match)
//        automatch = false
//    }
    
    /// Presents the matchmaker interface where the local player selects and sends an invitation to another player.
    /// - Tag:choosePlayer
    func choosePlayer() {
        // Create a match request.
        let request = GKMatchRequest()
        request.minPlayers = 3
        request.maxPlayers = 3
        
        // Present the interface where the player selects opponents and starts the game.
        if let viewController = GKMatchmakerViewController(matchRequest: request) {
            viewController.matchmakerDelegate = self
            rootViewController?.present(viewController, animated: true) { }
        }
    }
    
    // Starting and stopping the game.
    
    /// Starts a match.
    /// - Parameter match: The object that represents the real-time match.
    /// - Tag:startMyMatchWith
    func startMyMatchWith(match: GKMatch) {
        GKAccessPoint.shared.isActive = false
        playingGame = true
        myMatch = match
        myMatch?.delegate = self
        
        // For automatch, check whether the opponent connected to the match before loading the avatar.
        if myMatch?.expectedPlayerCount == 0 {
            opponent = myMatch?.players[0]
            opponent1 = myMatch?.players[1]
            
            // Load the opponent's avatar.
            opponent?.loadPhoto(for: GKPlayer.PhotoSize.small) { (image, error) in
                if let image {
                    self.opponentAvatar = Image(uiImage: image)
                }
                if let error {
                    print("Error: \(error.localizedDescription).")
                }
            }
            
            opponent1?.loadPhoto(for: GKPlayer.PhotoSize.small) { (image, error) in
                if let image {
                    self.opponentAvatar1 = Image(uiImage: image)
                }
                if let error {
                    print("Error: \(error.localizedDescription).")
                }
            }
        }
            
        // Increment the achievement to play 10 games.
//        reportProgress()
    }
    
    /// Takes the player's turn.
    /// - Tag:takeAction
    func roleNavigator() {
        // Take your turn by incrementing the counter.
        myScore = 1
        navigatorName = myName
        
//        // If your score is 10 points higher or reaches the maximum, you win the match.
//        if (myScore - opponentScore == 10) || (myScore == 100) {
//            endMatch()
//            return
//        }
        
        // Otherwise, send the game data to the other player.
        do {
            let data = encode(score: myScore)
            try myMatch?.sendData(toAllPlayers: data!, with: GKMatch.SendDataMode.unreliable)
            let roleName = encode(roleName: navigatorName)
            try myMatch?.sendData(toAllPlayers: roleName!, with: GKMatch.SendDataMode.unreliable)
        } catch {
            print("Error: \(error.localizedDescription).")
        }
    }
    func roleSupply() {
        // Take your turn by incrementing the counter.
        myScore = 2
        supplyName = myName
//        // If your score is 10 points higher or reaches the maximum, you win the match.
//        if (myScore - opponentScore == 10) || (myScore == 100) {
//            endMatch()
//            return
//        }
        
        // Otherwise, send the game data to the other player.
        do {
            let data = encode(score: myScore)
            try myMatch?.sendData(toAllPlayers: data!, with: GKMatch.SendDataMode.unreliable)
            let roleName = encode(roleName: supplyName)
            try myMatch?.sendData(toAllPlayers: roleName!, with: GKMatch.SendDataMode.unreliable)
        } catch {
            print("Error: \(error.localizedDescription).")
        }
    }
    func roleCook() {
        // Take your turn by incrementing the counter.
        myScore = 3
        cookName = myName
//        // If your score is 10 points higher or reaches the maximum, you win the match.
//        if (myScore - opponentScore == 10) || (myScore == 100) {
//            endMatch()
//            return
//        }
        
        // Otherwise, send the game data to the other player.
        do {
            let data = encode(score: myScore)
            try myMatch?.sendData(toAllPlayers: data!, with: GKMatch.SendDataMode.unreliable)
            let roleName = encode(roleName: cookName)
            try myMatch?.sendData(toAllPlayers: roleName!, with: GKMatch.SendDataMode.unreliable)
        } catch {
            print("Error: \(error.localizedDescription).")
        }
    }
    
    /// Quits a match and saves the game data.
    /// - Tag:endMatch
    func endMatch() {
        let myOutcome = myScore >= opponentScore ? "won" : "lost"
        let opponentOutcome = opponentScore > myScore ? "won" : "lost"
        
        // Notify the opponent that they won or lost, depending on the score.
        do {
            let data = encode(outcome: opponentOutcome)
            try myMatch?.sendData(toAllPlayers: data!, with: GKMatch.SendDataMode.unreliable)
        } catch {
            print("Error: \(error.localizedDescription).")
        }
        
        // Notify the local player that they won or lost.
        if myOutcome == "won" {
            youWon = true
        } else {
            opponentWon = true
        }
    }
    
    /// Forfeits a match without saving the score.
    /// - Tag:forfeitMatch
    func forfeitMatch() {
        // Notify the opponent that you forfeit the game.
        do {
            let data = encode(outcome: "forfeit")
            try myMatch?.sendData(toAllPlayers: data!, with: GKMatch.SendDataMode.unreliable)
        } catch {
            print("Error: \(error.localizedDescription).")
        }

        youForfeit = true
    }
    
    /// Saves the local player's score.
    /// - Tag:saveScore
//    func saveScore() {
//        GKLeaderboard.submitScore(myScore, context: 0, player: GKLocalPlayer.local,
//            leaderboardIDs: ["123"]) { error in
//            if let error {
//                print("Error: \(error.localizedDescription).")
//            }
//        }
//    }
    
    /// Resets a match after players reach an outcome or cancel the game.
    func resetMatch() {
        // Reset the game data.
        playingGame = false
        myMatch?.disconnect()
        myMatch?.delegate = nil
        myMatch = nil
        voiceChat = nil
        opponent = nil
        opponent1 = nil
        opponentAvatar = Image(systemName: "person.crop.circle")
        opponentAvatar1 = Image(systemName: "person.crop.circle")
        messages = []
        GKAccessPoint.shared.isActive = true
        youForfeit = false
        opponentForfeit = false
        youWon = false
        opponentWon = false
        
        // Reset the score.
        myScore = 0
        opponentScore = 0
        opponentScore1 = 0
    }
    
    // Rewarding players with achievements.
    
    /// Reports the local player's progress toward an achievement.
//    func reportProgress() {
//        GKAchievement.loadAchievements(completionHandler: { (achievements: [GKAchievement]?, error: Error?) in
//            let achievementID = "1234"
//            var achievement: GKAchievement? = nil
//
//            // Find an existing achievement.
//            achievement = achievements?.first(where: { $0.identifier == achievementID })
//
//            // Otherwise, create a new achievement.
//            if achievement == nil {
//                achievement = GKAchievement(identifier: achievementID)
//            }
//
//            // Create an array containing the achievement.
//            let achievementsToReport: [GKAchievement] = [achievement!]
//
//            // Set the progress for the achievement.
//            achievement?.percentComplete = achievement!.percentComplete + 10.0
//
//            // Report the progress to Game Center.
//            GKAchievement.report(achievementsToReport, withCompletionHandler: {(error: Error?) in
//                if let error {
//                    print("Error: \(error.localizedDescription).")
//                }
//            })
//
//            if let error {
//                print("Error: \(error.localizedDescription).")
//            }
//        })
//    }
}
