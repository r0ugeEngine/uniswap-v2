//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// UniswapV2
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/lib/contracts/libraries/FixedPoint.sol";
import "@uniswap/v2-periphery/contracts/libraries/UniswapV2OracleLibrary.sol";

import "./interfaces/IUniswapV2TWAP.sol";

/// @title An UniswapV2 TWAP contract
/// @author r0ugeEngine
/// @notice TWAP(time-weighted average price) is an oracle that can get
/// @dev Imported the UniswapV2 Pair interface, FixedPoint, OracleLibrary libraries implentation
contract UniswapV2TWAP is IUniswapV2TWAP {
    using FixedPoint for *;

    ///@notice Min period 10 seconds period
    uint256 public constant PERIOD = 10;

    ///@notice Address of token pair contract
    IUniswapV2Pair public immutable pair;
    ///@notice Token0 address
    IERC20 public immutable token0;
    ///@notice Token1 address
    IERC20 public immutable token1;

    ///@notice Last cumulative price for token0
    uint256 public price0CumulativeLast;
    ///@notice Last cumulative price for token1
    uint256 public price1CumulativeLast;

    ///@notice Last timestamp
    uint32 public blockTimestampLast;

    ///@notice Average price for token0
    ///@dev Used FixedPoint library because solidity don't have floating variables
    FixedPoint.uq112x112 public price0Average;
    ///@notice Average price for token1
    ///@dev Used FixedPoint library because solidity don't have floating variables
    FixedPoint.uq112x112 public price1Average;

    /**
     * @dev Using pair contract for finding token0, token1,
     * price0CumulativeLast, price1CumulativeLast, blockTimestampLast
     */
    constructor(IUniswapV2Pair _pair) {
        pair = _pair;

        token0 = IERC20(_pair.token0());
        token1 = IERC20(_pair.token1());

        price0CumulativeLast = _pair.price0CumulativeLast();
        price1CumulativeLast = _pair.price1CumulativeLast();

        (, , blockTimestampLast) = _pair.getReserves();
    }

    /// @dev Updates the current price for token pair that pasted to constructor
    function update() external {
        (
            uint256 price0Cumulative,
            uint256 price1Cumulative,
            uint32 blockTimestamp
        ) = UniswapV2OracleLibrary.currentCumulativePrices(address(pair));

        uint256 timeElapsed = blockTimestamp - blockTimestampLast;

        require(timeElapsed >= PERIOD, "Time elapsed < min PERIOD");

        price0Average = FixedPoint.uq112x112(
            uint224((price0Cumulative - price0CumulativeLast) / timeElapsed)
        );
        price1Average = FixedPoint.uq112x112(
            uint224((price1Cumulative - price1CumulativeLast) / timeElapsed)
        );

        price0CumulativeLast = price0Cumulative;
        price1CumulativeLast = price1Cumulative;
        blockTimestampLast = blockTimestamp;
    }

    /// @dev Consult for `token` what `amountOut` can be taken
    ///@param token token that user needs to swap
    ///@param amountIn amount that user needs to calculate amountOut
    ///@return amountOut calculated amount that user needs to get
    function consult(IERC20 token, uint256 amountIn)
        external
        view
        returns (uint256 amountOut)
    {
        require(token == token0 || token == token1, "Incorrect token");

        if (token == token0) {
            amountOut = price0Average.mul(amountIn).decode144();
        } else {
            amountOut = price1Average.mul(amountIn).decode144();
        }
    }
}
