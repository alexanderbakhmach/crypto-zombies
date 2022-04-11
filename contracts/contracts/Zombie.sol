// SPDX-License-Identifier: MIT
// Oleksandr Bakhmach Contracts

pragma solidity ^0.8.0;

import "./Uint.sol";
import "../interfaces/IERC721Enumerable.sol";
import "../interfaces/IERC721Metadata.sol";
import "../interfaces/IERC721Receiver.sol";
import "./Utils.sol";
import "./Address.sol";

contract Zombie is Utils , IERC721Metadata, IERC721Enumerable {
    using Uint for uint256;
    using Address for address;

    string private _zombieTokenName;
    string private _zombieTokenSymbol;
    string private _zombieTokenBaseLink;

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

    constructor (string memory zombieTokenName, string memory zombieTokenSymbol, string memory zombieTokenBaseLink) {
        _zombieTokenName = zombieTokenName;
        _zombieTokenSymbol = zombieTokenSymbol;
        _zombieTokenBaseLink = zombieTokenBaseLink;
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

        uint256 zombieDna = _zombies[tokenId].dna;
        uint256 zombieDnaSliced = zombieDna / (10 ** 12); // Crutch
        string memory stringifiedZombieDna = Utils.toString(zombieDnaSliced);
        string memory zombieTokenUri = string(abi.encodePacked(_zombieTokenBaseLink, "0000", stringifiedZombieDna, "-zombie.json"));

        return zombieTokenUri;
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
        uint256 zombieTokenId = _ownerAddressToOwnedZombies2Indexes[owner][index];

        require(owner != address(0), "Zombie: Owner must not be 0 address.");
        require(_zombieIdToOwnerAddress[zombieTokenId] == owner, "The token id on idex must be owned by owner.");

        return zombieTokenId;
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