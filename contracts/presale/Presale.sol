// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./SaleBase.sol";
import "./SafeMath.sol";

contract Presale is SaleBase {
    using SafeMath for uint256;
    constructor(
        uint256 rateNumerator,
        uint256 rateDenominator,
        IERC20 token,
        IERC20 paymentToken,
        address tokenWallet,
        uint256 cap,
        uint256 openingTime,
        uint256 closingTime,
        uint256 holdPeriod
    ) public SaleBase(rateNumerator, rateDenominator, token, paymentToken, tokenWallet, cap, openingTime, closingTime, holdPeriod){

    }
}
