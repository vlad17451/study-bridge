// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.4;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./AcademyToken.sol";
import "hardhat/console.sol";

contract Bridge is AccessControl {
    using SafeERC20 for IERC20;
    using SafeERC20 for AcademyToken;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");

    enum SwapState {
        SWAPPED,
        REDEEMED
    }

    struct Swap {
        uint256 nonce;
        SwapState state;
    }

    enum TokenState {
        ACTIVE,
        INACTIVE
    }

    struct TokenInfo {
        address token;
        string symbol;
        TokenState state;
    }

    mapping(string => TokenInfo) public tokenBySymbol;
    string[] tokenSymbols;
    mapping(bytes32 => Swap) public swapByHash;

    event SwapInitialized(
        uint256 indexed initTimestamp,
        address indexed initiator,
        address indexed recipient,
        uint256 amount,
        string symbol,
        uint256 chainFrom,
        uint256 chainTo,
        uint256 txId
    );

    event TokenStateChanged(
        address indexed initiator,
        address indexed token,
        string indexed symbol,
        TokenState newState
    );

    constructor () {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
    }

    function getTokenList() external view returns (TokenInfo[] memory) {
        TokenInfo[] memory tokens = new TokenInfo[](tokenSymbols.length);
        for (uint i = 0; i < tokenSymbols.length; i++) {
            tokens[i] = tokenBySymbol[tokenSymbols[i]];
        }
        return tokens;
    }

    function addToken(string memory symbol, address tokenAddress) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "You should have a admin role");
        tokenBySymbol[symbol] = TokenInfo({
            token: tokenAddress,
            symbol: symbol,
            state: TokenState.ACTIVE
        });
        tokenSymbols.push(symbol);
    }

    function deactivateTokenBySymbol(string memory symbol) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "You should have a admin role");
        TokenInfo storage token = tokenBySymbol[symbol];
        token.state = TokenState.INACTIVE;
        emit TokenStateChanged(msg.sender, token.token, symbol, token.state);
    }

    function activateTokenBySymbol(string memory symbol) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "You should have a admin role");
        TokenInfo storage token = tokenBySymbol[symbol];
        token.state = TokenState.ACTIVE;
        emit TokenStateChanged(msg.sender, token.token, symbol, token.state);
    }

    function swap(
        address recipient,
        string memory symbol,
        uint256 amount,
        uint256 chainFrom,
        uint256 chainTo,
        uint256 txId
    ) external {
        TokenInfo memory token = tokenBySymbol[symbol];
        require(token.state == TokenState.ACTIVE, 'Token is inactive');
        AcademyToken(token.token).burn(msg.sender, amount);
        bytes32 hashedMsg = keccak256(abi.encodePacked(
            msg.sender,
            recipient,
            amount,
            symbol,
            chainFrom,
            chainTo,
            txId
        ));
        swapByHash[hashedMsg] = Swap({
            nonce: txId,
            state: SwapState.SWAPPED
        });
        emit SwapInitialized(
            block.timestamp,
            msg.sender,
            recipient,
            amount,
            symbol,
            chainFrom,
            chainTo,
            txId
        );
    }

    function redeem(
        address recipient,
        string memory symbol,
        uint256 amount,
        uint256 chainFrom,
        uint256 chainTo,
        uint256 txId,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public view {

        bytes32 hashStruct = keccak256(
            abi.encode(
                recipient,
                symbol,
                amount,
                chainFrom,
                chainTo,
                txId
            )
        );
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 prefixedHash = keccak256(abi.encodePacked(prefix, hashStruct));
        address validatorAddress = ecrecover(prefixedHash, v, r, s);
        console.log('address1: ', validatorAddress);
    }
}
