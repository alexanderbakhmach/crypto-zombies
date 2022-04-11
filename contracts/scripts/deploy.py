from brownie import accounts, config, Zombie


def main():
    # Add here private metamask keyxw
    account = accounts.add(config["wallets"]["from_key"])
    zombie_token_name = "Zombie Token"
    zombie_token_symbol = "ZTK"

    zombie = Zombie.deploy(
    	zombie_token_name, 
    	zombie_token_symbol, 
    	{"from": account}, 
    	publish_source=True
    )

