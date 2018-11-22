//
//  OverviewModel.swift
//  groupstage-simulator
//
//  Created by Niels Beeuwkes on 21-11-18.
//  Copyright © 2018 Niels Beeuwkes. All rights reserved.
//

import Foundation

final class OverviewModel: NSObject {
    
    static let shared = OverviewModel()
    
    var games: [Game] = []
    var currentGame: Game?
    
    let numberOfTurns: Int = 40
    
    let gameWasSimulatedEvent = Event<Void>()
    
    public func generateGames() {
        let teamsModel = TeamsModel.shared
        
        // If there are no teams generated yet, generate teams
        if teamsModel.teams.count == 0 {
            teamsModel.generateTeams()
        }
        
        guard games.count == 0 else {
            return
        }
        
        // Plan all games
        // Planning:
        // A vs C
        // D vs B
        // B vs A
        // C vs D
        // A vs D
        // B vs C
        games.append(Game(id: 0, isSimulated: false, homeTeam: teamsModel.teams[0], awayTeam: teamsModel.teams[2], goalsHome: 0, goalsAway: 0, turns: [], holdingTeam: .home, ballHolder: teamsModel.teams[0].players.last!))
        games.append(Game(id: 1, isSimulated: false, homeTeam: teamsModel.teams[3], awayTeam: teamsModel.teams[1], goalsHome: 0, goalsAway: 0, turns: [], holdingTeam: .home, ballHolder: teamsModel.teams[3].players.last!))
        games.append(Game(id: 2, isSimulated: false, homeTeam: teamsModel.teams[1], awayTeam: teamsModel.teams[0], goalsHome: 0, goalsAway: 0, turns: [], holdingTeam: .home, ballHolder: teamsModel.teams[1].players.last!))
        games.append(Game(id: 3, isSimulated: false, homeTeam: teamsModel.teams[2], awayTeam: teamsModel.teams[3], goalsHome: 0, goalsAway: 0, turns: [], holdingTeam: .home, ballHolder: teamsModel.teams[2].players.last!))
        games.append(Game(id: 4, isSimulated: false, homeTeam: teamsModel.teams[0], awayTeam: teamsModel.teams[3], goalsHome: 0, goalsAway: 0, turns: [], holdingTeam: .home, ballHolder: teamsModel.teams[0].players.last!))
        games.append(Game(id: 5, isSimulated: false, homeTeam: teamsModel.teams[1], awayTeam: teamsModel.teams[2], goalsHome: 0, goalsAway: 0, turns: [], holdingTeam: .home, ballHolder: teamsModel.teams[1].players.last!))
        
        // All teams should play home/away atleast once against each contestant, so we reverse the previous
        /* [TURNED OFF] - This is not part of the instructions because it is the group stage
        for game in games {
            games.append(reverseTeamsFor(game: game))
        }*/
    }
    
    public func simulateGameWith(id: Int) {
        nextTurnForGameWith(id: id)
    }
    
    
    private func nextTurnForGameWith(id: Int) {
        //TODO: - Simulate a turn
        var game = games[id]
        
        // First move of the second half, the goalkeeper should start with the ball (might create actual kick-off later on
        if game.turns.count == (numberOfTurns / 2) {
            print("First half finished! Away's keeper is now ball holder")
            game.ballHolder = game.awayTeam.players.last!
        }
        
        // Player is a forwarder, should shoot on goal
        if game.ballHolder.position.1 == 3 {
            var goalChance: Double = 60
            
            // The higher difference between the forwarder and the keeper, the higher the chance to score.
            let playerPower = game.ballHolder.power
            let enemyPower = game.holdingTeam == .home ? game.awayTeam.players.last!.power : game.homeTeam.players.last!.power
            let difference: Double = Double(playerPower - enemyPower)
            
            goalChance = max(min(goalChance + (difference*1.5), 95), 10) // 1.5% goal chance +- per power level difference, with a maximum of 95% chance, and a minimum of 10% chance.
            
            let randomValue = Int.random(in: 0...100)
            
            var goal = false
            if randomValue < Int(goalChance) {
                // GOAL
                if game.holdingTeam == .home {
                    game.goalsHome += 1
                } else {
                    game.goalsAway += 1
                }
                goal = true
                
                print("\(game.ballHolder.firstName) \(game.ballHolder.lastName) scored! The score now stands \(game.goalsHome)-\(game.goalsAway)")
            } else {
                print("\(game.ballHolder.firstName) \(game.ballHolder.lastName) misses!")
            }
            
            let keeper = game.holdingTeam == .home ? game.awayTeam.players.last! : game.homeTeam.players.last!
            
            // Either after scroring or missing, the ball should return to the others goalkeeper (might add chance for rebound?)
            game.turns.append(Turn(fromPlayer: game.ballHolder, toPlayer: keeper, goal: goal))
            game.ballHolder = keeper
            game.holdingTeam = game.holdingTeam == .home ? .away : .home
        } else {
            // Player is either a goalkeeper, defender or midfielder. He should try passing.
            // Player should make a decision who to pass to:
            //   - Every player starts with 100 'chance points'
            //   - Stronger teammates get bonus chance (+2.5 per power)
            //   - Further teammates get decreased chance (-7.5 per grid)
            //
            let yPosCurrentGrid = game.ballHolder.position.1
            let teamMates = game.holdingTeam == .home ? game.homeTeam.players : game.awayTeam.players
            
            // Posible teammates, all players the current ball holder is currently able to pass to
            // .0 = PlayerModel
            // .1 = Double, represents the amount of chance points someone has
            var posibleTeammates = teamMates.compactMap { player -> (PlayerModel, Double)? in
                if player.position.1 == yPosCurrentGrid + 1 {
                    return (player, 100)
                }
                return nil
            }
            
            guard posibleTeammates.count > 0 else {
                games[id] = game
                nextTurnForGameWith(id: id)
                return
            }
            
            // We should know the weakest posible teammate, the other teammates should get extra chance points
            let lowestPower = posibleTeammates.compactMap { teammate -> Int in
                return teammate.0.power
            }.min() ?? 50
            
            for (index, teammate) in posibleTeammates.enumerated() {
                // Add the +2.5 for each point stronger than the weakest player
                let powerDifference = teammate.0.power - lowestPower
                posibleTeammates[index].1 += Double(powerDifference) * 2.5
                
                // Decrease the -5 for each grid further away from the current ball holder
                var gridDifference = yPosCurrentGrid - teammate.0.position.1
                if gridDifference < 0 {
                    gridDifference = -gridDifference
                }
                posibleTeammates[index].1 -= Double(gridDifference) * 7.5
            }
            
            // Now that we calculated the chances, lets see to what player the current ball holder will pass to.
            // First we need to know what the total amount of 'chance points' they have.
            var totalTeammatesChance: Double = 0
            for teammate in posibleTeammates {
                totalTeammatesChance += teammate.1
            }
            
            let randomTeammatesChanceValue = Double.random(in: 0 ..< totalTeammatesChance)
            var checkedTeammatesChance: Double = 0
            var chosenTeammate: PlayerModel = posibleTeammates.first!.0
            for teammate in posibleTeammates {
                if randomTeammatesChanceValue < checkedTeammatesChance + teammate.1 {
                    chosenTeammate = teammate.0
                } else {
                    checkedTeammatesChance += teammate.1
                }
            }
            
            // Now we know what player the current holder is passing to, we can now calculate how much chance the player has in succeeding this pass.
            // A pass starts with a chance based on the players power (5-10), bases on the following conditions, this can go up/down.
            //   - Enemy teammates close to the player you are passing to. (Lowers the chance (1-5). The further away, the less effective.)
            //   - Friendly teammates close to the player you are passing to. (Increases the chance (1-7.5). The further away, the less effective.)
            let baseChance = max(min(5 + ((10 / 50) * (game.ballHolder.power - 50)), 10), 5)
            var chances = [Double(baseChance)]
            
            // We have to know what enemies are able to intercept the pass.
            let yPosEnemies = 4 - chosenTeammate.position.1
            let enemies = (game.holdingTeam == .home ? game.awayTeam : game.homeTeam).players.compactMap { player -> PlayerModel? in
                if player.position.1 == yPosEnemies {
                    return player
                }
                return nil
            }
            
            // Removing itself from posible teammates to only keep the players capable of supporting him
            let supportTeammates = posibleTeammates.compactMap { player -> (PlayerModel, Double)? in
                if player.0 != chosenTeammate {
                    return player
                }
                return nil
            }
            
            // When there are no enemies, pass succesion should be 100% (this should not be possible right now).
            if enemies.count == 0 {
                chances[0] = 100
                print("ERROR")
            } else {
                // Calculate the chances for each supporting teammate (1-5)
                for teammate in supportTeammates {
                    var gridDifference = chosenTeammate.position.0 - teammate.0.position.0
                    if gridDifference < 0 {
                        gridDifference = -gridDifference
                    }
                    let chance = max(1, 6 - gridDifference) // 6 instead of 5 because a teammate could never be on the same x-pos on the grid
                    chances.append(Double(chance))
                }
                
                // Calculate the chances for each enemy (1-7.5)
                for enemy in enemies {
                    var gridDifference = chosenTeammate.position.0 - enemy.position.0
                    if gridDifference < 0 {
                        gridDifference = -gridDifference
                    }
                    let chance = max(1.0, 7.5 - Double(gridDifference))
                    chances.append(chance)
                }
            }
            
            var totalChances: Double = 0
            for chance in chances {
                totalChances += chance
            }
            
            let randomChanceValue = Double.random(in: 0 ..< totalChances)
            var checkedChance: Double = 0
            var passSucceeded = false
            
            if randomChanceValue < chances[0] {
                passSucceeded = true
            } else {
                if supportTeammates.count > 0 {
                    for i in 1 ... supportTeammates.count { // -1 for the person who is receiving the ball (can't acces supportedTeammates from here)
                        if randomChanceValue < checkedChance + chances[i] {
                            passSucceeded = true
                        } else {
                            checkedChance += chances[i]
                        }
                    }
                }
            }
            
            if passSucceeded {
                print("\(game.ballHolder.firstName) \(game.ballHolder.lastName) passed to \(chosenTeammate.firstName) \(chosenTeammate.lastName)!")
                game.turns.append(Turn(fromPlayer: game.ballHolder, toPlayer: chosenTeammate, goal: false))
                game.ballHolder = chosenTeammate
            } else {
                let receivingEnemy = enemies.randomElement() ?? enemies[0]
                
                print("\(receivingEnemy.firstName) \(receivingEnemy.lastName) intercepts the pass!")
                game.turns.append(Turn(fromPlayer: game.ballHolder, toPlayer: receivingEnemy, goal: false))
                game.ballHolder = receivingEnemy
                game.holdingTeam = game.holdingTeam == .home ? .away : .home
            }
        }
        
        games[id] = game
        
        // If game still has turns left, simulate next turn!
        if game.turns.count != numberOfTurns {
            nextTurnForGameWith(id: id)
        } else {
            //TODO: - Game finished simulating, show results/turns
            games[id].isSimulated = true
            print("Game finished! Total score is \(game.goalsHome)-\(game.goalsAway)")
            gameWasSimulatedEvent.emit()
        }
    }
    
    private func teamForPlayer(player: PlayerModel, inGame: Game) -> Teams {
        var team: Teams = .home
        
        for awayPlayer in inGame.awayTeam.players {
            if player == awayPlayer {
                team = .away
            }
        }
        
        return team
    }
}

struct Game {
    var id: Int
    var isSimulated: Bool = false
    let homeTeam: TeamModel
    let awayTeam: TeamModel
    var goalsHome: Int
    var goalsAway: Int
    var turns: [Turn]
    var holdingTeam: Teams
    var ballHolder: PlayerModel
}

struct Turn {
    let fromPlayer: PlayerModel
    let toPlayer: PlayerModel
    let goal: Bool
}

enum Teams {
    case home
    case away
}
