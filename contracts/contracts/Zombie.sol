// SPDX-License-Identifier: MIT
// Oleksandr Bakhmach Contracts

pragma solidity ^0.8.0;

import "./Uint.sol";
import "./Utils.sol";
import "./Address.sol";
import "./Base64.sol";
import "../interfaces/IERC721Enumerable.sol";
import "../interfaces/IERC721Metadata.sol";
import "../interfaces/IERC721Receiver.sol";

contract Zombie is Utils , IERC721Metadata, IERC721Enumerable {
    using Uint for uint256;
    using Uint for uint16;
    using Uint for uint32;
    using Address for address;

    string private _zombieTokenName;
    string private _zombieTokenSymbol;

    uint private _dnaDigits = 15;
    uint private _dnaModulus = 10 ** _dnaDigits;
    uint private _cooldownTime = 1 days;

    //The main structure describing a zombie
    struct Zombie {
        string name;
        uint256 dna;
        uint32 level;
        uint256 readyTime;
        uint16 winCount;
        uint16 lossCount;
    }

    // Store here all zombies ids as a list
    uint256[] private _allZombieIds;

    // Mapping from token ID to owner address
    mapping(uint256 => address) private _zombieIdToOwnerAddress;
    // Mapping owner address to token count
    mapping(address => uint256) private _zombieOwnerAddressToZombiesCount;
    // Mapping from token ID to approved address
    mapping(uint256 => address) private _zombieIdToApprovedAddress;
    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _ownerAddressToOperatorApprovals;
    // Mapping from the owner to the mapping of the zombie token index on the zombie token id
    mapping(address => mapping(uint256 => uint256)) private _ownerAddressToOwnedZombies2Indexes;
    // Mapping from the zombieId to the actual zombie
    mapping(uint256 => Zombie) private _zombies;

    // Event will be fired when a new zombie will be created
    event ZombieGenerated(uint zombieId, string zombieName);

    constructor (string memory zombieTokenName, string memory zombieTokenSymbol) {
        _zombieTokenName = zombieTokenName;
        _zombieTokenSymbol = zombieTokenSymbol;
	}

    /**
     * @dev Function returns 16 digits number for a corresponding given string.
     */
    function _generateRandomDna(string memory str) private view returns (uint) {
        bytes memory binarizedStr = abi.encodePacked(str); // We encode given string and
                                                           // receive encoded bytes
        bytes32 hashedStr = keccak256(binarizedStr); // We hash the bytes representation of the given string
                                                     // to receive a hash in bytes
        uint rand = uint(hashedStr); // We cast bytes hash to integer thus achive psevdo randomness.

        return rand % _dnaModulus;
    }

    /**
     * @dev Proceed the transdering from one account to another with a token
     * optionally with the data. Emit an event.
     */
    function _transferZombieToken(
        address from,
        address to,
        uint256 zombieTokenId
    ) private {
        _zombieIdToOwnerAddress[zombieTokenId] = to;
        _zombieOwnerAddressToZombiesCount[from] = _zombieOwnerAddressToZombiesCount[from].sub(1);
        _zombieOwnerAddressToZombiesCount[to] = _zombieOwnerAddressToZombiesCount[to].add(1);

        emit Transfer(from, to, zombieTokenId);
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (to.isContract()) {
            address sender = msg.sender;

            try IERC721Receiver(to).onERC721Received(sender, from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("Zombie: Transfer to non ERC721Receiver implementer.");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    /**
     * @dev Function which create the svg based on the zombie data with given zombieId
     */
    function _getZombieSvg(uint zombieId) private view returns (string memory) {
        string memory svg;
        
        svg = "<svg width='350px' height='350px' viewBox='0 0 24 24' fill='none' xmlns='http://www.w3.org/2000/svg'> <path d='M11.55 18.46C11.3516 18.4577 11.1617 18.3789 11.02 18.24L5.32001 12.53C5.19492 12.3935 5.12553 12.2151 5.12553 12.03C5.12553 11.8449 5.19492 11.6665 5.32001 11.53L13.71 3C13.8505 2.85931 14.0412 2.78017 14.24 2.78H19.99C20.1863 2.78 20.3745 2.85796 20.5133 2.99674C20.652 3.13552 20.73 3.32374 20.73 3.52L20.8 9.2C20.8003 9.40188 20.7213 9.5958 20.58 9.74L12.07 18.25C11.9282 18.3812 11.7432 18.4559 11.55 18.46ZM6.90001 12L11.55 16.64L19.3 8.89L19.25 4.27H14.56L6.90001 12Z' fill='red'/> <path d='M14.35 21.25C14.2512 21.2522 14.153 21.2338 14.0618 21.1959C13.9705 21.158 13.8882 21.1015 13.82 21.03L2.52 9.73999C2.38752 9.59782 2.3154 9.40977 2.31883 9.21547C2.32226 9.02117 2.40097 8.83578 2.53838 8.69837C2.67579 8.56096 2.86118 8.48224 3.05548 8.47882C3.24978 8.47539 3.43783 8.54751 3.58 8.67999L14.88 20C15.0205 20.1406 15.0993 20.3312 15.0993 20.53C15.0993 20.7287 15.0205 20.9194 14.88 21.06C14.7353 21.1907 14.5448 21.259 14.35 21.25Z' fill='red'/> <path d='M6.5 21.19C6.31632 21.1867 6.13951 21.1195 6 21L2.55 17.55C2.47884 17.4774 2.42276 17.3914 2.385 17.297C2.34724 17.2026 2.32855 17.1017 2.33 17C2.33 16.59 2.33 16.58 6.45 12.58C6.59063 12.4395 6.78125 12.3607 6.98 12.3607C7.17876 12.3607 7.36938 12.4395 7.51 12.58C7.65046 12.7206 7.72934 12.9112 7.72934 13.11C7.72934 13.3087 7.65046 13.4994 7.51 13.64C6.22001 14.91 4.82 16.29 4.12 17L6.5 19.38L9.86 16C9.92895 15.9292 10.0114 15.873 10.1024 15.8346C10.1934 15.7962 10.2912 15.7764 10.39 15.7764C10.4888 15.7764 10.5866 15.7962 10.6776 15.8346C10.7686 15.873 10.8511 15.9292 10.92 16C11.0605 16.1406 11.1393 16.3312 11.1393 16.53C11.1393 16.7287 11.0605 16.9194 10.92 17.06L7 21C6.8614 21.121 6.68402 21.1884 6.5 21.19Z' fill='red'/> </svg>";
        
        return svg;
    }  

    /**
     * @dev Function to create new zombie by a given name for caller.
     */
    function generateRandomZombie(string memory zombieName) public returns (uint) {
        address zombieOwner = msg.sender;

        require(zombieOwner != address(0), "Zombie: Sender must not be zero address.");
        require(_zombieOwnerAddressToZombiesCount[zombieOwner] == 0, "Zombie: Sender must not have any zombies.");
        require(bytes(zombieName).length > 0, "Zombie: Name must be not an empty string.");
        require(_zombieOwnerAddressToZombiesCount[zombieOwner] == 0, "Zombie: No previous zombies must be owned.");

        uint256 zombieDna = _generateRandomDna(zombieName);

        require(_zombies[zombieDna].dna == 0, "Zombie: Zombie with such name exists.");
        
        _zombies[zombieDna] = Zombie(zombieName, zombieDna, 0, block.timestamp, 0, 0);
        _zombieOwnerAddressToZombiesCount[zombieOwner] = _zombieOwnerAddressToZombiesCount[zombieOwner].add(1);
        _zombieIdToOwnerAddress[zombieDna] = zombieOwner;
        _ownerAddressToOwnedZombies2Indexes[zombieOwner][_allZombieIds.length] = zombieDna;
        _allZombieIds.push(zombieDna);

        emit ZombieGenerated(zombieDna, zombieName);
        emit Transfer(address(0), zombieOwner, zombieDna);

        return zombieDna;
    }

    /**
     * @dev Getter for a zombie.
     */
    function getZombieByToken(uint256 tokenId) public view returns (Zombie memory) {
        return _zombies[tokenId];
    }

    /**
     * @dev Implementation to receive name to support the token metadata functionality
     */
    function name() external view override returns (string memory _name) {
        return _zombieTokenName;
	}

    /**
     * @dev Implementation to receive symbol to support the token metadata functionality
     */
    function symbol() external view override returns (string memory _symbol) {
        return _zombieTokenSymbol;
    }
    
    /**
     * @dev Implementation to receive tokenURI to support the token metadata functionality
     */
    function tokenURI(uint256 tokenId) external view override returns (string memory) {
    	require(_zombieIdToOwnerAddress[tokenId] != address(0), "Zombie: Token is not owned and does not exist.");

        // uint256 zombieDna = _zombies[tokenId].dna;
        // uint256 zombieDnaSliced = zombieDna / (10 ** 12); // Crutch
        // string memory stringifiedZombieDna = Utils.toString(zombieDnaSliced);

        string memory zombieName = _zombies[tokenId].name;
        string memory zombieSvg = _getZombieSvg(tokenId);
        string memory zombieDna = this.toString(_zombies[tokenId].dna);
        string memory zombieLevel = this.toString(_zombies[tokenId].level);
        string memory zombieWinCount = this.toString(_zombies[tokenId].winCount);
        string memory zombieLossCount = this.toString(_zombies[tokenId].lossCount);

        bytes memory encodedJsonPart1 = abi.encodePacked(
            '{"name": "', zombieName, '",',
            '"image_data": "', zombieSvg, '",'
        );
        bytes memory encodedJsonPart2 = abi.encodePacked(
            '"attributes": [{"trait_type": "Dna", "value": ', zombieDna, '},',
            '{"trait_type": "Level", "value": ', zombieLevel, '},'
        );
        bytes memory encodedJsonPart3 = abi.encodePacked(
            '{"trait_type": "Won battles", "value": ', zombieWinCount, '},',
            '{"trait_type": "Loss battles", "value": "', zombieLossCount, '"}',
            ']}'
        );

        bytes memory encodedJsonFull = bytes.concat(encodedJsonPart1, encodedJsonPart2, encodedJsonPart3);
        string memory json = Base64.encode(bytes(string(encodedJsonFull)));

        return string(abi.encodePacked('data:application/json;base64,', json));
    }

    /**
     * @dev Implementation to receive the total balance to support the token metadata functionality
     */
    function balanceOf(address zombieOwner) external view override returns (uint256 balance) {
        require(zombieOwner != address(0), "Zombie: The owner must be valid owner.");

        return _zombieOwnerAddressToZombiesCount[zombieOwner];
    }

    /**
     * @dev Implementation to receive the owner address to support the token metadata functionality.
     */
    function ownerOf(uint256 tokenId) external view override returns (address owner) {
        require(_zombieIdToOwnerAddress[tokenId] != address(0), "Zombie: The zombie must have owner and must exists.");

        return _zombieIdToOwnerAddress[tokenId];
    }

    /**
     * @dev Implementation to receive the owner approval for the operator to support the nft functionality.
     */
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _ownerAddressToOperatorApprovals[owner][operator];
    }

    /**
     * @dev Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller
     * to support the nft functionality.
     */
    function setApprovalForAll(address operator, bool approved) external override {
        require(operator != address(0), "Zombie: Operator must be not zero address.");

        address owner = msg.sender;

        _ownerAddressToOperatorApprovals[owner][operator] = approved;

        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @dev Returns the account approved for `tokenId` token to support the nft functionality.
     */
    function getApproved(uint256 tokenId) external view override returns (address operator) {
        require(_zombies[tokenId].dna != 0, "Zombie: Token must exist.");

        return _zombieIdToApprovedAddress[tokenId];
    }

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account to support the nft functionality.
     */
    function approve(address to, uint256 tokenId) external override {
        address approver = msg.sender;
        address zombieOwner = _zombieIdToOwnerAddress[tokenId];

        require(zombieOwner != to, "Zombie: Can not be approved for the owner of the token.");
        require(
            zombieOwner == approver || isApprovedForAll(zombieOwner, approver), 
            "Zombie: Token can be approved only by a holder of the token or approver must be validated by the owner."
        );

        _zombieIdToApprovedAddress[tokenId] = to;

        emit Approval(zombieOwner, to, tokenId);
    }

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external override {
        address zombieOwner = _zombieIdToOwnerAddress[tokenId];
        require(_zombies[tokenId].dna != 0, "Token must exist.");
        require(from != address(0), "Zombie: From must be not a zero address.");
        require(to != address(0), "Zombie: To must be not a zero address.");
        require(
            zombieOwner == from || this.getApproved(tokenId) == from || this.isApprovedForAll(zombieOwner, from),
            "Zombie: From must be an token owner or approved to perform that action."
        );

        _transferZombieToken(from, to, tokenId);
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external override{
        this.transferFrom(from, to, tokenId);

        require(_checkOnERC721Received(from, to, tokenId, ""), "Zombie: Transfer to non ERC721Receiver implementer.");
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external override{
        this.transferFrom(from, to, tokenId);

        require(_checkOnERC721Received(from, to, tokenId, data), "Zombie: Transfer to non ERC721Receiver implementer.");
    }

    /**
     * @dev Returns the total amount of tokens stored by the contract.
     */
    function totalSupply() external view override returns (uint256) {
        return _allZombieIds.length;
    }

    /**
     * @dev  Returns a token ID owned by `owner` at a given `index` of its token list.
     * Use along with {balanceOf} to enumerate all of ``owner``'s tokens.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) external view override returns (uint256) {
        require(_zombieOwnerAddressToZombiesCount[owner] > index, "Zombie: Owner zombies count must be bigger then index.");

        return _ownerAddressToOwnedZombies2Indexes[owner][index];
    }

    /**
     * @dev Returns a token ID at a given `index` of all the tokens stored by the contract.
     * Use along with {totalSupply} to enumerate all tokens.
     */
    function tokenByIndex(uint256 index) external view override returns (uint256) {
        require(index < this.totalSupply(), "Zombie: Global index out of bounds.");

        return _allZombieIds[index];
    }  

    /**
     * @dev Returns true if this contract implements the interface defined.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            interfaceId == type(IERC165).interfaceId ||
            interfaceId == type(IERC721Enumerable).interfaceId;
    }
}