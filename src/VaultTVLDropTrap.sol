// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IVault {
    function totalAssets() external view returns (uint256);
}

/// @title VaultTVLDropTrap
/// @notice Test-only Drosera Trap that flags a TVL drop vs the peak observed in the sample window.
contract VaultTVLDropTrap {
    struct CollectOutput {
        uint256 blockNumber;
        uint256 assets;
    }

    // ======= CONFIG (edit these before build) =======
    // Mock vault from the example README. Replace with your own for testing.
    address public constant VAULT = 0x9E6d5A38127304256bA1583ff78e4373c3c58DAb;

    // Drop threshold in basis points (1% = 100 bps). Default 5% (500 bps).
    uint256 public constant DROP_THRESHOLD_BPS = 500;

    // Optional absolute-drop floor in asset units; set to 0 to disable.
    // This prevents firing on tiny TVL values or very small noise.
    uint256 public constant MIN_ABSOLUTE_DROP = 0;

    uint256 private constant BPS_DENOMINATOR = 10_000;

    constructor() {}

    /// @notice Collect current TVL.
    /// @return Encoded CollectOutput {blockNumber, assets}
    function collect() external view returns (bytes memory) {
        uint256 assets = _readAssets(VAULT);
        return abi.encode(CollectOutput({blockNumber: block.number, assets: assets}));
    }

    /// @notice Decide if an incident should trigger.
    /// @dev data[0] is assumed to be the most recent sample; scans entire window for peak->current drop.
    /// @param data Encoded CollectOutput[] from latest N blocks
    /// @return triggered True if drop >= threshold
    /// @return details Encoded incident message (string bytes)
    function shouldRespond(bytes[] calldata data) external pure returns (bool triggered, bytes memory details) {
        uint256 n = data.length;
        if (n < 2) {
            return (false, bytes("insufficient samples"));
        }

        // Most recent sample
        CollectOutput memory newest = abi.decode(data[0], (CollectOutput));
        uint256 currentAssets = newest.assets;
        uint256 newestBlock = newest.blockNumber;
        uint256 oldestBlock = newestBlock;

        // Find peak assets across the whole window and min/max block numbers for context
        uint256 peakAssets = currentAssets;
        for (uint256 i = 0; i < n; i++) {
            CollectOutput memory s = abi.decode(data[i], (CollectOutput));
            if (s.assets > peakAssets) peakAssets = s.assets;
            if (s.blockNumber < oldestBlock) oldestBlock = s.blockNumber;
            if (s.blockNumber > newestBlock) newestBlock = s.blockNumber;
        }

        // Nothing to compare or no drop
        if (peakAssets == 0 || currentAssets >= peakAssets) {
            return (false, bytes(""));
        }

        uint256 absDrop = peakAssets - currentAssets;

        // Optional absolute floor to avoid noise on tiny numbers
        if (MIN_ABSOLUTE_DROP > 0 && absDrop < MIN_ABSOLUTE_DROP) {
            return (false, bytes(""));
        }

        uint256 dropBps = (absDrop * BPS_DENOMINATOR) / peakAssets;

        if (dropBps >= DROP_THRESHOLD_BPS) {
            // Human-readable message packed as bytes (string)
            bytes memory msgBytes = abi.encodePacked(
                "TVL drop detected: ",
                _u(dropBps), " bps (", _u(absDrop), " units) from ",
                _u(peakAssets), " to ", _u(currentAssets),
                " across blocks ", _u(oldestBlock), "->", _u(newestBlock),
                "; samples=", _u(n)
            );
            return (true, msgBytes);
        }

        return (false, bytes(""));
    }

    // ======= internals =======

    function _readAssets(address a) internal view returns (uint256) {
        // Try ERC-4626 totalAssets()
        (bool ok, bytes memory ret) = a.staticcall(abi.encodeWithSelector(IVault.totalAssets.selector));
        if (ok && ret.length >= 32) {
            return abi.decode(ret, (uint256));
        }
        // Fallback: ERC-20 totalSupply() if vault lacks totalAssets()
        (ok, ret) = a.staticcall(abi.encodeWithSignature("totalSupply()"));
        require(ok && ret.length >= 32, "Vault: no assets/supply");
        return abi.decode(ret, (uint256));
    }

    function _u(uint256 x) private pure returns (string memory) {
        if (x == 0) return "0";
        uint256 j = x;
        uint256 len;
        while (j != 0) { len++; j /= 10; }
        bytes memory b = new bytes(len);
        uint256 k = len;
        while (x != 0) {
            k--;
            b[k] = bytes1(uint8(48 + x % 10));
            x /= 10;
        }
        return string(b);
    }
}
