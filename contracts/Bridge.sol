// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.4;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./AcademyToken.sol";
import "hardhat/console.sol";

/// @notice Bridge to swap tokens between several blockchain by create vrs by validator
/// @dev instance of this bridge must exist on all networks between which you want to swap
contract Bridge is AccessControl {
    using SafeERC20 for IERC20;
    using SafeERC20 for AcademyToken;

    enum SwapState {
        EMPTY,
        SWAPPED,
        REDEEMED
    }

    enum TokenState {
        ACTIVE,
        INACTIVE
    }

    struct Swap {
        uint256 nonce;
        SwapState state;
    }

    struct TokenInfo {
        address tokenAddress;
        string symbol;
        TokenState state;
    }

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");

    uint256 public immutable currentBridgeChainId;

    mapping(string => TokenInfo) public tokenBySymbol;
    mapping(uint256 => bool) public isChainActiveById;
    mapping(bytes32 => Swap) public swapByHash;
    string[] tokenSymbols;

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

    event SwapRedeemed(
        uint256 indexed initTimestamp,
        address indexed initiator,
        uint256 indexed txId
    );

    event TokenStateChanged(
        address indexed initiator,
        address indexed token,
        string indexed symbol,
        TokenState newState
    );


    /**
      * @notice constructor
      * @dev use real id of blockchain, for example 4 for rinkeby, 97 for bsc testnet etc
      * @param bridgeChainId - id current blockchain
      */
    constructor (uint256 bridgeChainId) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        currentBridgeChainId = bridgeChainId;
    }

    /**
      * @notice add or update chain to chain map, activate or deactivate chain by id
      * @dev use real id of blockchain in map, for example 4 for rinkeby, 97 for bsc testnet etc
      * @param chainId - id of blockchain to update
      * @param isActive - new state of chain
      */
    function updateChainById(uint256 chainId, bool isActive) external {
        require(
            hasRole(ADMIN_ROLE, msg.sender),
            "Bridge: You should have a admin role"
        );
        isChainActiveById[chainId] = isActive;
    }

    /**
      * @notice get token list, which have addresses, symbols and state of all tokens
      * @return TokenInfo[] - array of structs of tokens, which have tokenAddress, symbol and state
      */
    function getTokenList() external view returns (TokenInfo[] memory) {
        TokenInfo[] memory tokens = new TokenInfo[](tokenSymbols.length);
        for (uint i = 0; i < tokenSymbols.length; i++) {
            tokens[i] = tokenBySymbol[tokenSymbols[i]];
        }
        return tokens;
    }

    /**
      * @notice add token which can be swapped
      * @dev you should have admin role to execute this method
      * @param symbol - symbol of token which you want to add
      * @param tokenAddress - address of token which you want to add
      */
    function addToken(string memory symbol, address tokenAddress) external {
        require(
            hasRole(ADMIN_ROLE, msg.sender),
            "Bridge: You should have a admin role"
        );
        tokenBySymbol[symbol] = TokenInfo({
            tokenAddress: tokenAddress,
            symbol: symbol,
            state: TokenState.ACTIVE
        });
        tokenSymbols.push(symbol);
    }

    /**
      * @notice deactivate token to swap, you can swap only tokens which active
      * @dev you should have admin role to execute this method
      * @param symbol - symbol of token which you want to deactivate
      */
    function deactivateTokenBySymbol(string memory symbol) external {
        require(
            hasRole(ADMIN_ROLE, msg.sender),
            "Bridge: You should have a admin role"
        );
        TokenInfo storage token = tokenBySymbol[symbol];
        token.state = TokenState.INACTIVE;
        emit TokenStateChanged(msg.sender, token.tokenAddress, symbol, token.state);
    }

    /**
      * @notice activate token to swap, you can swap only tokens which active
      * @dev you should have admin role to execute this method
      * @param symbol - symbol of token which you want to activate
      */
    function activateTokenBySymbol(string memory symbol) external {
        require(
            hasRole(ADMIN_ROLE, msg.sender),
            "Bridge: You should have a admin role"
        );
        TokenInfo storage token = tokenBySymbol[symbol];
        token.state = TokenState.ACTIVE;
        emit TokenStateChanged(msg.sender, token.tokenAddress, symbol, token.state);
    }

    /**
      * @notice init swap and create event
      * @dev you can get arguments for redeem from event of swap
      * @param recipient - The address of recipient of tokens in target chain
      * @param symbol - The symbol of swap token
      * @param amount - amount of tokens
      * @param chainFrom - chain id where tokens swap from
      * @param chainTo - chain id where tokens swap to
      * @param txId - unique id of swap
      */
    function swap(
        address recipient,
        string memory symbol,
        uint256 amount,
        uint256 chainFrom,
        uint256 chainTo,
        uint256 txId
    ) external {

        require(
            chainFrom == currentBridgeChainId,
            "Bridge: Invalid chainFrom"
        );
        require(
            chainTo != currentBridgeChainId,
            "Bridge: Invalid chainTo is same with current bridge chain"
        );
        require(
            isChainActiveById[chainTo],
            "Bridge: chainTo does not exist/is not active"
        );


        TokenInfo memory token = tokenBySymbol[symbol];
        require(
            token.state == TokenState.ACTIVE,
            "Bridge: Token is inactive"
        );
        AcademyToken(token.tokenAddress).burn(msg.sender, amount);
        bytes32 hash = keccak256(abi.encodePacked(
                recipient,
                amount,
                symbol,
                chainFrom,
                chainTo,
                txId
            ));

        require(
          swapByHash[hash].state == SwapState.EMPTY,
          "Bridge: Swap with given params already exists"
        );

        swapByHash[hash] = Swap({
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


    /**
      * @notice you get tokens if you have vrs
      * @dev all arguments except v, r and s, comes from swap event
      * @param recipient - The address of recipient of tokens in target chain
      * @param symbol - The symbol of swap token
      * @param amount - amount of tokens
      * @param chainFrom - chain id where tokens swap from
      * @param chainTo - chain id where tokens swap to
      * @param txId - unique id of swap
      * @param v - v of signature
      * @param r - r of signature
      * @param s - s of signature
      */
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
    ) external {
        bytes32 hash = keccak256(
            abi.encodePacked(
                recipient,
                symbol,
                amount,
                chainFrom,
                chainTo,
                txId
            )
        );
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 prefixedHash = keccak256(abi.encodePacked(prefix, hash));
        address validatorAddress = ecrecover(prefixedHash, v, r, s);
        require(
            hasRole(VALIDATOR_ROLE, validatorAddress),
            "Bridge: Validator address is not correct"
        );

        TokenInfo memory token = tokenBySymbol[symbol];
        require(
            token.state == TokenState.ACTIVE,
            "Bridge: Token is inactive"
        );
        AcademyToken(token.tokenAddress).mint(recipient, amount);

        require(
          swapByHash[hash].state == SwapState.EMPTY,
          "Bridge: Redeem with given params already exists"
        );

        swapByHash[hash] = Swap({
            nonce: txId,
            state: SwapState.REDEEMED
        });

        emit SwapRedeemed(
            block.timestamp,
            msg.sender,
            txId
        );
    }
}
