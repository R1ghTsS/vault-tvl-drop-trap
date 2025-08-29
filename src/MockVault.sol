// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MockVault {
    uint256 private _assets;
    event AssetsSet(uint256 value);

    constructor(uint256 initialAssets) {
        _assets = initialAssets;
    }

    function totalAssets() external view returns (uint256) {
        return _assets;
    }

    // Testing helper to simulate deposits/withdrawals
    function setTotalAssets(uint256 newAssets) external {
        _assets = newAssets;
        emit AssetsSet(newAssets);
    }
}
