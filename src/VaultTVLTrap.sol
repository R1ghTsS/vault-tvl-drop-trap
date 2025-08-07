// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IVault {
    function totalAssets() external view returns (uint256);
}

contract VaultTVLTrap {
    IVault public vault;

    constructor(address _vault) {
        vault = IVault(_vault);
    }

    function collect() external view returns (uint256) {
        return vault.totalAssets();
    }

    function shouldRespond(uint256[] memory data) external pure returns (bool) {
        if (data.length < 3) return false;

        uint256 past = data[data.length - 3];
        uint256 current = data[data.length - 1];
        if (past == 0) return false;

        uint256 drop = ((past - current) * 100) / past;
        return drop > 20;
    }
}
