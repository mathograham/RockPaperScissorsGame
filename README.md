# RockPaperScissorsGame
A smart contract that lets two players join a game of rock-paper-scissors for a bet of predetermined amount of ether

# Rinkeby Contract Address

[0x2F6bdc26D48135885041A7165f78161c5EaDaC9b](https://rinkeby.etherscan.io/address/0x2f6bdc26d48135885041a7165f78161c5eadac9b)

* Bet Amount for testnet deployment: 1000 wei

# Contract Summary
This contract keeps track of an unbounded number of Rock Paper Scissors (RPS) games. At deployment, contract deployer chooses the amount each player must bet to join a game. Each game is identifiable by a unique ID. The difficulty of playing RPS over a smart contract comes from the ability of a user to read any change in state due to the contract. In a typical game of RPS, both players issue their choice at the same time so that it is a game of chance for both players. In this contract, one player initiates a game and waits for another player to join. While waiting, player1's choice is vulnerable because all information about the EVM state change is available for anyone to view. One solution to this is to encrypt the first player's information using a simple one-time pad. After both players have input their choices, the first player can input their encryption/decryption key to reveal their choice. Note, in this set up, player2 does not need to encrypt their choice since, as soon as player2 enters their choice, all game play ceases.


# User Instructions

1. To play, each player must enter a 1 byte hexadecimal input representing their choice of rock, paper, or scissors. Rock is represented by 0x01, paper is represented by 0x02, and scissors is represented by 0x03. See further instructions for exact input based on which player you are in the game.
2. You can input the game ID of the last game into the gameInfo[] array to get the status of the most recent game. At any time, the status of a game can be checked using this array. The satus gets updated when waiting for a second player, waiting for player1 to decrypt answer, when a time out occurs, when a draw occurs, and when a win occurs.
3. If the last game concluded, use startGame to initiate another game. You are player1. Include the required betAmount in your function call. You must enter an encrypted version of your hexadecimal choice. Encrypt using a 1 byte hexadecimal one-time pad. Keep the encryption/decryption key handy.
4. If the game is waiting on a second player, use joinGame to become player2 for the game. Include the required betAmount in your function call. You must enter 0x01, 0x02, or 0x03 as your choice, without encryption. Player2 must join within 48 hours of player1 starting a game or else on the next game update, player1 receives a refund.
5. After a second player joins the game, player1 must enter their decryption key into revealChoice within 48 hours of player2 joining. If player1 does not reveal their choice in this time limit, player2 automatically wins to keep player1 from prolonging the game if they don't like the outcome. The revealChoice function reveals the outcome of the game. If either player wins, they receive all ether in the contract. If there is a draw, each player only receives half of their initial bet. The rest is kept in the contract for the winner of the next game that finishes.
6. If, at any time, a player is waiting on the other player to finish the game, they can use the updateCurrentGame function which will check the two timers specified above to see if the game has timed out yet.
7. Once a game times out, or concludes through a win or draw, the game is reset and ready for the next game initiation.


# Example Run-Through
Say there are currently 5 games that have been concluded. The betAmount to enter the game is 1 ether.

* User inputs gameInfo[4] and sees the following information: <br>
   0: uint256: gameStartTime 1652667891 <br>
   1: uint256: gameLockTime 1652667951 <br>
   2: address: player1 0x622651b08EB2Fca00930f4a6a1A78dE5EAE035a7 <br>
   3: address: player2 0x6d655C92cc8Bf7664f0e06ab28f481E9EBb4d934 <br>
   4: string: status Player 1 chose scissors; player 2 chose rock. Player 2 wins! <br>
* This means the last game has concluded and that they must start a new game. Since this user is player1, they encrypt their choice before they start the game. Say player1 wants to choose paper, 0x02. This player gets an encryption key of the same size, say 0x92, and uses it to encrypt their choice: 0x90. The encrypted choice is what they input into startGame.
* Another player shows up within 10 minutes. Say they want to check if they can still join. They can execute updateCurrentGame and then gameInfo[4]. This time they see status "Game in progress. Waiting for player2 to join". Then player2 enters their choice of scissors by inputting 0x03 into the joinGame function. Alternatively, the player can read the gameStartTime from the gameInfo[] array for the game, and calculate the time since the start of the game themselves.
* At the time player2 inputs their choice, player1 then has 48 hours to enter their decryption key of 0x92 into the revealChoice function. Once this is done, the winner is calculated (the contract XORs player1's encrypted choice with the decryption key and compares their decrypted answer to player2's choice), which in this case would be player2. Player2 is rewarded the entire balance of the contract and the storage variables are reset for the next game.


# Limitations

* This set up for the RPS games has one glaring vulnerability: player1 has the advantage. Once player2 inputs their choice, it is not difficult for player1 to have three different decryption keys to use to get the best outcome based on player2's choice. For example, in the run-through above, player1 enters their decryption key of 0x92 to say their choice was paper, but they could have easily made their decryption key 0x93 to get 0x01 (rock) or 0x91 to get 0x03 (scissors). <br>
<b> Suggested Fix: </b> When player1 enters their encrypted choice in startGame, they must also enter an extra input of a hash composed from their encrypted choice and their encryption key. Then, when they enter their encryption key in the revealChoice function, the contract uses the encrypted choice and encryption key to make a hash and check against player1's hash. Since hashes are deterministic, they should match. If the hashes are not the same, player1 automatically loses.
* No safety checks are in place to verify that each player adds the correct hexadecimal input. At the time of writing this, if a player incorrectly inputs their choice or if player1 incorrectly inputs their decryption key, the game will effectively break since no winner will be able to be determined, and the game will not be able to reset. This is an easy fix: an extra case can be added to the if-else lines in which the contract can specify what to do if an unexpected hexadecimal answer occurs for either player.
* This contract was manually tested, as can be seen at the above address link to etherscan. In the deployed contract, several cases were tested including a winning case, a draw case, and a timeout case. Requirements were checked for each function as well. Update: Unit testing has been added in the RpsGamewTest folder. The test is made through pytest in Brownie. The test script, test_RpsGame.py, performs basic checks to make showcase the functions work as expected. The contract passed all tests included.


