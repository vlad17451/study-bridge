// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.4;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./AcademyToken.sol";

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

    mapping(string => address) public tokenBySymbol;
    string[] tokenSymbols;
    mapping(bytes32 => Swap) public swapByHash;

    event SwapInitialized(
        uint256 indexed initTimestamp,
        address indexed initiator,
        address indexed recipient,
        uint256 amount,
        string symbol,
        uint256 txId
    );

    constructor () {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
//        _setupRole(VALIDATOR_ROLE, msg.sender);
    }

    struct TokenInfo {
        address token;
        string symbol;
    }

    function getTokenList() external view returns (TokenInfo[] memory) {
        TokenInfo[] memory tokens = new TokenInfo[](tokenSymbols.length);
        for (uint i = 0; i < tokenSymbols.length; i++) {
            string memory symbol = tokenSymbols[i];
            tokens[i] = TokenInfo({
                symbol: symbol,
                token: tokenBySymbol[symbol]
            });
        }
        return tokens;
    }

    function addToken(string memory symbol, address tokenAddress) external {
        tokenBySymbol[symbol] = tokenAddress;
        tokenSymbols.push(symbol);
    }

    function swap(address recipient, string memory tokenSymbol, uint256 amount, uint256 txId) external {
        address tokenAddress = tokenBySymbol[tokenSymbol];
//        AcademyToken(tokenAddress).safeTransferFrom(msg.sender, address(this), amount);
        AcademyToken(tokenAddress).burn(msg.sender, amount);
        bytes32 hashedMsg = keccak256(abi.encodePacked(
            recipient,
            tokenSymbol,
            amount,
            txId
        ));
        swapByHash[hashedMsg] = Swap({
            nonce: txId,
            state: SwapState.SWAPPED
        });
        emit SwapInitialized(block.timestamp, msg.sender, recipient, amount, tokenSymbol, txId);
    }
}
