// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Minimal interface of the Binance Agent ID registry (SPACE ID Agent ID, ERC-721, non-transferable).
///         Registry on BNB Smart Chain: 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F
interface IAgentIdRegistry {
    function balanceOf(address owner) external view returns (uint256);
}

/// @title NoisGate — an Agent ID gate: soulbound badge + daily check-in for Binance Agent ID holders.
/// @notice Only wallets holding a Binance Agent ID (.ai) can claim the badge (one per wallet, non-transferable).
///         Badge holders can check in once per UTC day; streaks and totals are stored on-chain.
///         The contract never takes custody of user assets, never asks for approvals, and has no
///         mint/transfer/pause/treasury powers. The owner may only update the metadata URI and may
///         renounce ownership; both facts are disclosed in the project submission.
contract NoisGate {
    // ---------- ERC-721 metadata ----------
    string public constant name = "Nois Gate Badge";
    string public constant symbol = "NGB";

    // ---------- Agent ID gate ----------
    IAgentIdRegistry public immutable agentIdRegistry;

    // ---------- Ownership (metadata pointer only) ----------
    address public owner;
    string public metadataURI;

    // ---------- Badge state (soulbound ERC-721 subset) ----------
    uint256 public totalClaimed;
    mapping(address => uint256) private _badgeIdOf; // 0 = no badge
    mapping(uint256 => address) private _ownerOf;

    // ---------- Check-in state ----------
    mapping(address => uint256) public checkInCount;
    mapping(address => uint256) public currentStreak;
    mapping(address => uint256) public bestStreak;
    mapping(address => uint256) private _lastCheckInDay;

    // ---------- Events ----------
    event BadgeClaimed(address indexed user, uint256 indexed tokenId);
    event CheckIn(address indexed user, uint256 day, uint256 totalCheckIns, uint256 streak);
    event MetadataURIUpdated(string newURI);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address registry_, string memory metadataURI_) {
        require(registry_ != address(0), "registry is zero address");
        agentIdRegistry = IAgentIdRegistry(registry_);
        owner = msg.sender;
        metadataURI = metadataURI_;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    // ---------- Core: claim ----------
    /// @notice Claim the soulbound Nois Gate Badge. Requires holding a Binance Agent ID. One per wallet.
    function claim() external returns (uint256 tokenId) {
        require(agentIdRegistry.balanceOf(msg.sender) > 0, "Agent ID required");
        require(_badgeIdOf[msg.sender] == 0, "badge already claimed");
        tokenId = ++totalClaimed;
        _badgeIdOf[msg.sender] = tokenId;
        _ownerOf[tokenId] = msg.sender;
        emit BadgeClaimed(msg.sender, tokenId);
    }

    // ---------- Core: daily check-in ----------
    /// @notice Check in once per UTC day. Requires the badge. Tracks totals and day streaks.
    function checkIn() external {
        require(_badgeIdOf[msg.sender] != 0, "badge required");
        uint256 today = block.timestamp / 1 days;
        uint256 last = _lastCheckInDay[msg.sender];
        require(last != today, "already checked in today");
        if (last == today - 1) {
            currentStreak[msg.sender] += 1;
        } else {
            currentStreak[msg.sender] = 1;
        }
        if (currentStreak[msg.sender] > bestStreak[msg.sender]) {
            bestStreak[msg.sender] = currentStreak[msg.sender];
        }
        _lastCheckInDay[msg.sender] = today;
        uint256 total = ++checkInCount[msg.sender];
        emit CheckIn(msg.sender, today, total, currentStreak[msg.sender]);
    }

    // ---------- Views ----------
    function hasBadge(address user) external view returns (bool) {
        return _badgeIdOf[user] != 0;
    }

    function badgeOf(address user) external view returns (uint256) {
        return _badgeIdOf[user];
    }

    function lastCheckInDay(address user) external view returns (uint256) {
        return _lastCheckInDay[user];
    }

    function canCheckIn(address user) external view returns (bool) {
        return _badgeIdOf[user] != 0 && _lastCheckInDay[user] != block.timestamp / 1 days;
    }

    // ---------- ERC-721 read surface (soulbound: every transfer/approval path reverts) ----------
    function balanceOf(address user) external view returns (uint256) {
        require(user != address(0), "zero address");
        return _badgeIdOf[user] == 0 ? 0 : 1;
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        address holder = _ownerOf[tokenId];
        require(holder != address(0), "nonexistent token");
        return holder;
    }

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        require(_ownerOf[tokenId] != address(0), "nonexistent token");
        return metadataURI;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        // ERC165 (0x01ffc9a7) and ERC721 (0x80ac58cd)
        return interfaceId == 0x01ffc9a7 || interfaceId == 0x80ac58cd;
    }

    function approve(address, uint256) external pure {
        revert("soulbound: approvals disabled");
    }

    function getApproved(uint256) external pure returns (address) {
        return address(0);
    }

    function setApprovalForAll(address, bool) external pure {
        revert("soulbound: approvals disabled");
    }

    function isApprovedForAll(address, address) external pure returns (bool) {
        return false;
    }

    function transferFrom(address, address, uint256) external pure {
        revert("soulbound: non-transferable");
    }

    function safeTransferFrom(address, address, uint256) external pure {
        revert("soulbound: non-transferable");
    }

    function safeTransferFrom(address, address, uint256, bytes calldata) external pure {
        revert("soulbound: non-transferable");
    }

    // ---------- Owner: metadata pointer only, renounceable ----------
    function setMetadataURI(string calldata newURI) external onlyOwner {
        metadataURI = newURI;
        emit MetadataURIUpdated(newURI);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function renounceOwnership() external onlyOwner {
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
    }
}
