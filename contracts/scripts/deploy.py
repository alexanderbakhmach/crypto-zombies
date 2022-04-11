from brownie import accounts, config, Zombie


def main():
    # Add here private metamask keyxw
    account = accounts.add(config["wallets"]["from_key"])
    zombie_token_name = "Zombie Token"
    zombie_token_symbol = "ZTK"
    zombie_ipfs_url = "https://gateway.pinata.cloud/ipfs/QmcsDmVCWiLDHKzAzC6No13SeJNyBXPzVPvaug5Q2NFJoX/"

    zombie = Zombie.deploy(
    	zombie_token_name, 
    	zombie_token_symbol, 
    	zombie_ipfs_url, 
    	{"from": account}, 
    	publish_source=True
    )

