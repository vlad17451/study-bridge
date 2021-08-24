// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.4;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./AcademyToken.sol";
import "hardhat/console.sol";

/**
  * @notice Bridge to swap tokens between several blockchain by create vrs by validator
  * @dev instance of this bridge must exist on all networks between which you want to swap
  */
contract Bridge is AccessControl {
    using SafeERC20 for IERC20;
    using SafeERC20 for AcademyToken;

    enum SwapState {
        EMPTY,
        SWAPPED,
        REDEEMED
    }

    enum TokenState {
        EMPTY,
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


    /**
      * @notice id of current chain
      */
    uint256 public immutable currentChainId;

    /**
      * @notice get token structure by symbol
      * @param symbol - symbol of token
      * @return TokenInfo - token structure
      */
    mapping(string => TokenInfo) public tokenBySymbol;

    /**
      * @notice get boolean of chain state by id
      * @param id - id of chain
      * @return state - state of chain
      */
    mapping(uint256 => bool) public isChainActiveById;

    /**
      * @notice get swap structure by hash
      * @param hash - hash of all params of swap
      * @return Swap - structure of swap
      */
    mapping(bytes32 => Swap) public swapByHash;

    /**
      * @notice array with all token symbols
      * @return array of symbols
      */
    string[] public tokenSymbols;

    /**
      * @notice event emitting with redeem
      * @param initTimestamp - timestamp of block when redeem was created
      * @param initiator - address of user who call redeem method
      * @param recipient - address of user who get tokens
      * @param amount - amount of tokens
      * @param symbol - symbol of token
      * @param chainFrom - chain id where tokens swap from
      * @param chainTo - chain id where tokens swap to
      * @param txId - id of swap
      */
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


    /**
      * @notice event emitting with redeem
      * @param initTimestamp - timestamp of block when redeem was created
      * @param initiator - address of user who call redeem method
      * @param txId - id of swap
      */
    event SwapRedeemed(
        uint256 indexed initTimestamp,
        address indexed initiator,
        uint256 indexed txId
    );

    /**
      * @notice event emitting when token state in changing
      * @param initiator - address of user who change token state
      * @param tokenAddress - address token
      * @param symbol - symbol token
      * @param newState - new value for state token
      */
    event TokenStateChanged(
        address indexed initiator,
        address indexed tokenAddress,
        string indexed symbol,
        TokenState newState
    );


    /**
      * @notice constructor
      * @dev use real id of blockchain, for example 4 for rinkeby, 97 for bsc testnet etc
      * @param bridgeChainId - id current blockchain
      */
    constructor (uint256 bridgeChainId) payable {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        currentChainId = bridgeChainId;
    }

    /**
      * @notice add or update chain to chain map, activate or deactivate chain by id
      * @dev use real id of blockchain in map, for example 4 for rinkeby, 97 for bsc testnet etc
      * @param chainId - id of blockchain to update
      * @param isActive - new state of chain
      */
    function updateChainById(uint256 chainId, bool isActive) external payable {
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
    function addToken(string memory symbol, address tokenAddress) external payable {
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
    function deactivateTokenBySymbol(string memory symbol) external payable {
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
    function activateTokenBySymbol(string memory symbol) external payable {
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
    ) external payable {

        require(
            chainFrom == currentChainId,
            "Bridge: Invalid chainFrom"
        );
        require(
            chainTo != currentChainId,
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
    ) external payable {
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
