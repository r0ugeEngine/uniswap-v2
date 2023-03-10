//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@uniswap/lib/contracts/libraries/Babylonian.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

import "./interfaces/IUniswapV2OptimalAmount.sol";
import "./UniswapV2.sol";

/// @title An UniswapV2 Optimal Amount contract
/// @author r0ugeEngine
/// @notice Optimized swaps for full exchange of tokens
/// @dev Inherits the UniswapV2 implementation
/// @dev the UniswapV2 Babylonian library and Pair interface implentation
contract UniswapV2OptimalAmount is UniswapV2, IUniswapV2OptimalAmount {
    ///@notice WETH token address
    IERC20 private constant WETH =
        IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    /// @dev Calculate the optimal amount of swap
    /// @param _tokenA token that user needs to swap
    /// @param _tokenB token that user needs to get
    /// @param _amountA amount of `_tokenA` that user needs to swap
    function optimalSwap(
        IERC20 _tokenA,
        IERC20 _tokenB,
        uint256 _amountA
    ) external {
        require(
            _tokenA == WETH || _tokenB == WETH,
            "One of tokens must be WETH"
        );

        address tokenPair = UNISWAP_V2_FACTORY.getPair(
            address(_tokenA),
            address(_tokenB)
        );
        (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(tokenPair)
            .getReserves();

        uint256 swapAmount;

        if (IUniswapV2Pair(tokenPair).token0() == address(_tokenA)) {
            // swap from token0 to token1
            swapAmount = getSwapAmount(reserve0, _amountA);
        } else {
            swapAmount = getSwapAmount(reserve1, _amountA);
        }

        _tokenA.transferFrom(msg.sender, address(this), _amountA);

        _swap(_tokenA, _tokenB, swapAmount);
        _addLiquidity(_tokenA, _tokenB);
    }

    /// @dev Without calculating the optimal amount of swap
    /// @param _tokenA token that user needs to swap
    /// @param _tokenB token that user needs to get
    /// @param _amountA amount of `_tokenA` that user needs to swap
    function nonOptimalSwap(
        IERC20 _tokenA,
        IERC20 _tokenB,
        uint256 _amountA
    ) external {
        _tokenA.transferFrom(msg.sender, address(this), _amountA);

        _swap(_tokenA, _tokenB, _amountA / 2);
        _addLiquidity(_tokenA, _tokenB);
    }

    /**
     * s = optimal swap amount
     * r = amount of reserve for a token a
     * a = amount of token a the user currently has (not added to reserve yet)
     * f = swap percent
     * s = (sqrt(((2 - f)r)^2 + 4(1 - f)ar) - (2 - f)r) / (2(1 - f))
     */
    function getSwapAmount(uint256 r, uint256 a) public pure returns (uint256) {
        return
            (Babylonian.sqrt(r * (r * 3988009 + a * 3988000)) - r * 1997) /
            1994;
    }
}
