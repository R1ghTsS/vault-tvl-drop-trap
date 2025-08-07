// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MockVault {
    uint256 public currentTotalAssets;

    constructor(uint256 initialAssets) {
        currentTotalAssets = initialAssets;
    }

    // Mimics the totalAssets() function for your Trap
    function totalAssets() external view returns (uint256) {
        return currentTotalAssets;
    }

    // Mimics the totalSupply() function (if your Trap uses it as fallback)
    function totalSupply() external view returns (uint256) {
        return currentTotalAssets;
    }

    // Function to manually set the total assets for testing
    function setTotalAssets(uint256 newAssets) external {
        currentTotalAssets = newAssets;
    }
}
