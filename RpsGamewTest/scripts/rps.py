from brownie import RpsGame, accounts

def main():
    account = accounts[0]
    return RpsGame.deploy(10000, {'from': account})