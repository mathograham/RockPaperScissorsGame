from brownie import RpsGame, accounts, reverts
import pytest

#deploy instance of contract
@pytest.fixture
def contract(scope = "function"):
    return RpsGame.deploy(10000, {"from": accounts[0]})

# check _betAmount set at deployment
def test_betAmount_getter(contract):
    assert contract._betAmount() == 10000
 
    
# check _p1 starts as address(0)
def test_p1_getter(contract):
    assert contract._p1() == "0x0000000000000000000000000000000000000000"
    
# check _p2 starts as address(0)
def test_p2_getter(contract):
    assert contract._p2() == "0x0000000000000000000000000000000000000000"

# check _p1EncChoice starts as 0
def test_p1EncChoice_getter(contract):
    assert contract._p1EncChoice() == "0x00"

# check _p1Key starts as 0
def test_p1Key_getter(contract):
    assert contract._p1Key() == "0x00"

# check _p1DecChoice starts as 0
def test_p1DecChoice_getter(contract):
    assert contract._p1DecChoice() == "0x00"

# check _p2DecChoice starts as 0
def test_p2DecChoice_getter(contract):
    assert contract._p2DecChoice() == "0x00"

# check startGame reverts when incorrect _betAmount input
def test_startGame_incorrectEth_revert(contract):
    with reverts("Place required bet amount"):
        contract.startGame("0x90",{"from": accounts[0]})

    with reverts("Place required bet amount"):
        contract.startGame("0x90", {"from": accounts[0], "amount": 1000})

    with reverts("Place required bet amount"):
        contract.startGame("0x90", {"from": accounts[0], "amount": 100000})
       
# check after startGame, p1 info recorded and contract has new balance
def test_startGame_p1Set(contract):
   #contract.startGame("0x92", {"from": accounts[0], "value": "1000 wei"})
   contract.startGame("0x90", {"from": accounts[0], "amount": 10000})
   assert contract._p1() == accounts[0]
   assert contract._p1EncChoice() == "0x90"
   assert contract.balance() == 10000

# check startGame reverts when p1 already set
def test_startGame_p1set_revert(contract):
    contract.startGame("0x90", {"from": accounts[0], "amount": 10000})
    with reverts("Game started, try joinGame"):
        contract.startGame("0x91", {"from": accounts[1], "amount": 10000})
        
# check joinGame reverts when incorrect _betAmount input
def test_joinGame_incorrectEth_revert(contract):
    contract.startGame("0x90", {"from": accounts[0], "amount": 10000})

    with reverts("Place required bet amount"):
        contract.joinGame("0x01",{"from": accounts[1]})

    with reverts("Place required bet amount"):
        contract.joinGame("0x01", {"from": accounts[1], "amount": 1000})

    with reverts("Place required bet amount"):
        contract.joinGame("0x01", {"from": accounts[1], "amount": 100000})

# check joinGame reverts when no _p1 set first
def test_joinGame_nop1_revert(contract):
    with reverts("Game locked, try startGame"):
        contract.joinGame("0x01", {"from": accounts[1], "amount": 10000})

# check after joinGame, p2 info recorded and contract has new balance
def test_joinGame_p2Set(contract):
    contract.startGame("0x90", {"from": accounts[0], "amount": 10000})
    contract.joinGame("0x01", {"from": accounts[1], "amount": 10000})
    assert contract._p2() == accounts[1]
    assert contract._p2DecChoice() == "0x01"
    assert contract.balance() == 20000


# check joinGame reverts is p2 already set
def test_joinGame_p2set_revert(contract):
    contract.startGame("0x90", {"from": accounts[0], "amount": 10000})
    contract.joinGame("0x01", {"from": accounts[1], "amount": 10000})
    with reverts("Game locked, try startGame"):
        contract.joinGame("0x02", {"from": accounts[2], "amount": 10000})

# check revealChoice reverts is address other than _p1 executes
def test_revealChoice_p1Only_revert(contract):
    contract.startGame("0x90", {"from": accounts[0], "amount": 10000})
    contract.joinGame("0x01", {"from": accounts[1], "amount": 10000})
    with reverts("player1 only"):
        contract.revealChoice("0xaf", {"from": accounts[1]})

# check revealChoice reverts if p2 not yet set
def test_revealChoice_nop2_revert(contract):
    contract.startGame("0x90", {"from": accounts[0], "amount": 10000})
    with reverts("Waiting for player2 to join"):
        contract.revealChoice("0x92", {"from": accounts[0]})

# check revealChoice awards winner and resets game when p1 has paper, p2 has rock
def test_revealChoice_p1Wins(contract):
    p1BalBefore = accounts[0].balance()
    contract.startGame("0x90", {"from": accounts[0], "amount": 10000})
    contract.joinGame("0x01", {"from": accounts[1], "amount": 10000})
    contractBal = contract.balance()
    contract.revealChoice("0x92", {"from": accounts[0]})
    #gas is offsetting result. Think how to check reward transferred to correct player
    assert accounts[0].balance() > p1BalBefore
    assert contract.balance() == 0
    assert contract._p1() == "0x0000000000000000000000000000000000000000"
    assert contract._p2() == "0x0000000000000000000000000000000000000000"
    assert contract._p1EncChoice() == "0x00"
    assert contract._p1Key() == "0x00"
    assert contract._p1DecChoice() == "0x00"
    assert contract._p2DecChoice() == "0x00"


# check revealChoice results in draw and resets game when p1 has paper, p2 has paper
def test_revealChoice_drawAnd2ndRound(contract):
    p1BalBefore = accounts[0].balance()
    p2BalBefore = accounts[1].balance()
    contract.startGame("0x90", {"from": accounts[0], "amount": 10000})
    contract.joinGame("0x02", {"from": accounts[1], "amount": 10000})
    contractBal = contract.balance()
    contract.revealChoice("0x92", {"from": accounts[0]})
    assert accounts[0].balance() <= p1BalBefore
    assert accounts[1].balance() <= p2BalBefore
    assert contract.balance() == 10000
    assert contract._p1() == "0x0000000000000000000000000000000000000000"
    assert contract._p2() == "0x0000000000000000000000000000000000000000"
    assert contract._p1EncChoice() == "0x00"
    assert contract._p1Key() == "0x00"
    assert contract._p1DecChoice() == "0x00"
    assert contract._p2DecChoice() == "0x00"




