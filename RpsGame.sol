// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.6.0;

/** Write a solidity smart contract that does the following:
* - Keeps track of an unbounded number of rock-paper-scissors games;
* - Each game should be identifiable by a unique ID;
* - Once two players commit their move to the same game ID,
*   the game is now resolved, and no further moves can be played;
* - Each game, once started, needs both moves to be played within 48h.
*   If that doesn't happen, the first player can get a full refund;
* - To play, both users have to commit a predetermined amount of ETH
*   (to be decided by the contract deployer);
* - It should be impossible for the second player to figure out what
*   the first player's move was before both moves are committed;
* - When a game is finished, the winner gets to take the full pot;
* - In the event of a draw, each player can recover only 50% of their
*   locked amount. The other 50% are to be distributed to the next game
*   that finishes;
* - The repo should include some unit tests to simulate and test the 
*   main behaviors of the game. Extra love will be given if you showcase
*   security skills (fuzzing, mutation testing, etcetera).
*/

// NOTES:
// -Game made with assumption that player2 will always input 0x01, 0x02, 0x03 and player1 will always
//  input a properly encrypted version of this. No safeties are put in place for the event of either 
//  player not adhering to this, or if player1 accidentally puts in the wrong encryption/decryption key. 
//  With more time, I would add in a check for this. 
// -The onus is on player1 to come up with their own one-time pad encryption key and use it to correctly
//  encode their choice.

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.4.0/contracts/math/SafeMath.sol";

contract RpsGame {
    using SafeMath for uint;

    uint public _betAmount;
    address payable public _p1;
    address payable public _p2;
    bytes1 public _p1EncChoice;
    bytes1 public _p1Key;
    bytes1 public _p1DecChoice;
    bytes1 public _p2DecChoice;




    // Info for each game. Keeps track of game start time, game lock time, players, and status of game
    struct GameInfo {
        uint gameStartTime;
        uint gameLockTime;
        address payable player1;
        address payable player2;
        string status;

    }

    // Holds GameInfo in array according to unique id. Can keep track of unbounded number of games
    GameInfo[] public gameInfo;

    // At deployment, bet amount is decided for each rps game
    constructor(uint betAmount) public {
        _betAmount = betAmount;
    }

    // player1 starts game by inputting ENCRYPTED choice and meeting bet amount
    // At time the game is started, a timer starts. If timer exceeds 48 hours without a second player, player1 gets a refund.
    function startGame(bytes1 _p1Choice) external payable {
        require(_p1 == address(0), "Game started, try joinGame");
        require(msg.value == _betAmount, "Place required bet amount");
        _p1 = msg.sender;
        _p1EncChoice = _p1Choice;
        gameInfo.push(GameInfo({
            gameStartTime: now,
            gameLockTime: now,
            player1: _p1,
            player2: address(0),
            status: "Game in progress. Waiting for player2 to join"
        }));

    }

    // player2 enters DECRYPTED choice. No need for encryption at this stage because immediate next stage is to reveal choice
    // timer is checked when a second player joins to make sure time has not exceeded 48hrs from iniating game.
    // At time player2 joins game, a second timer starts. If timer exceeds 48 hours without player1 revealing choice, player2
    // automatically wins. This is to prevent player1 from holding player2 hostage because they did not like the outcome of the game.
    function joinGame(bytes1 _p2Choice) external payable {
        require(_p1 != address(0) && _p2 == address(0), "Game locked, try startGame");
        require(msg.value == _betAmount, "Place required bet amount");
        GameInfo storage game = gameInfo[(gameInfo.length).sub(1)];
        address payable p1 = game.player1;
        if ((now).sub(game.gameStartTime) <= 48 hours) {
            _p2 = msg.sender;
            _p2DecChoice = _p2Choice;
            game.gameLockTime = now;
            game.player2 = _p2;
            game.status = "Game in progress. Waiting for player1 to reveal choice";

        } else {
            game.status = "Game timed out. No player2 joined. Refund to player1.";
            resetGame();
            p1.transfer(_betAmount);
        }

    }

    // player1 enters encryption/decryption key so outcome of game can be decided
    // second timer is checked to make sure time has not exceeded 48 hours without player1 revealing choice
    // If player1 tries to reveal choice after time limit exceeded, player2 automatically wins
    function revealChoice(bytes1 _pKey) external {
        require(_p2 != address(0), "Waiting for player2 to join");
        require(msg.sender == _p1, "player1 only");
        GameInfo storage game = gameInfo[(gameInfo.length).sub(1)];
        address payable p2 = game.player2;
        if ((now).sub(game.gameLockTime) <= 48 hours) {
            require(_pKey.length == _p1EncChoice.length);
            _p1Key = _pKey;
            _p1DecChoice = _p1EncChoice^(_p1Key);
            concludeGame();
        } else {
            game.status = "Game timed out after lock. Player2 wins by default.";
            resetGame();
            payWinner(p2);
        }
    }

    // called by revealChoice. Compares decrypted choices of each player and decides whether someone wins or if there is a draw. 
    function concludeGame() internal returns (string memory) {
        require(_p1DecChoice != bytes1(uint8(0)) && _p2DecChoice != bytes1(uint8(0)), "reveal Choice for both players first");
        GameInfo storage game = gameInfo[(gameInfo.length).sub(1)];
        address payable p1 = game.player1;
        address payable p2 = game.player2;
        if (_p1DecChoice == bytes1(uint8(1))) {
            if (_p2DecChoice == bytes1(uint8(1))) {
                game.status = "Both players chose rock. Draw; no one wins.";
                resetGame();
                draw(p1,p2);
            } else if (_p2DecChoice == bytes1(uint8(2))) {
                game.status = "Player 1 chose rock; player 2 chose paper. Player 2 wins!";
                resetGame();
                payWinner(p2);

            } else if (_p2DecChoice == bytes1(uint8(3))) {
                game.status = "Player 1 chose rock; player 2 chose scissors. Player 1 wins!";
                resetGame();
                payWinner(p1);

            }

        } else if (_p1DecChoice == bytes1(uint8(2))) {
            if (_p2DecChoice == bytes1(uint8(1))) {
                game.status = "Player 1 chose paper; player 2 chose rock. Player 1 wins!";
                resetGame();
                payWinner(p1);

            } else if (_p2DecChoice == bytes1(uint8(2))) {
                game.status = "Both players chose paper. Draw; no one wins.";
                resetGame();
                draw(p1,p2);

            } else if (_p2DecChoice == bytes1(uint8(3))) {
                game.status = "Player 1 chose paper; player 2 chose scissors. Player 2 wins!";
                resetGame();
                payWinner(p2);
                
            }

        } else if (_p1DecChoice == bytes1(uint8(3))) {
            if (_p2DecChoice == bytes1(uint8(1))) {
                game.status = "Player 1 chose scissors; player 2 chose rock. Player 2 wins!";
                resetGame();
                payWinner(p2);

            } else if (_p2DecChoice == bytes1(uint8(2))) {
                game.status = "Player 1 chose scissors; player 2 chose paper. Player 1 wins!";
                resetGame();
                payWinner(p1);

            } else if (_p2DecChoice == bytes1(uint8(3))) {
                game.status = "Both players chose scissors. Draw; no one wins.";
                resetGame();
                draw(p1,p2);
                
            }

        }


    }

    // called when a game finishes, if there is a draw, or if a time limit exceeded
    function resetGame() internal {
        _p1 = address(0);
        _p2 = address(0);
        _p1EncChoice = bytes1(0);
        _p1Key = bytes1(0);
        _p1DecChoice = bytes1(0);
        _p2DecChoice = bytes1(0);

    }

    // in the case of a draw, each player only gets back half of their initial bet. The rest is paid out to the winner of the
    // next finished game
    function draw(address payable p1, address payable p2) internal {
        p1.transfer((_betAmount).div(2));
        p2.transfer((_betAmount).div(2));
    }

    // given more time, I would add a reentrancy guard to any function paying ether as an extra precaution
    function payWinner(address payable player) internal {
        player.transfer(address(this).balance);
    }


    // updates timer and checks for reset. Anyone can call on current game in case players stop calling other functions
    function updateCurrentGame() external {
        GameInfo storage game = gameInfo[(gameInfo.length).sub(1)];
        address payable p1 = game.player1;
        address payable p2 = game.player2;
        if (_p1 != address(0) && _p2 == address(0)) {
            if ((now).sub(game.gameStartTime) > 48 hours) {
                game.status = "Game timed out. No player2 joined. Refund to player1.";
                resetGame();
                p1.transfer(_betAmount);
            }
        }
        if (_p2 != address(0) && _p1DecChoice == bytes1(0)) {
            if ((now).sub(game.gameLockTime) > 48 hours) {
                game.status = "Game timed out after lock. Player2 wins by default.";
                resetGame();
                payWinner(p2);
            }
        }

    }


}

