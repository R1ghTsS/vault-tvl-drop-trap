// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ITrap} from "drosera-contracts/interfaces/ITrap.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

// Define an interface for the vault contract you want to monitor
interface IVault {
    function totalAssets() external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

contract VaultTVLDropTrap is ITrap {
    // Hardcode the vault address you want to monitor
    // Replace this with your actual Mock Vault address
    address public constant VAULT_ADDRESS = 0x8cD9E6B7B4472e3d89abeBB902843BaC8f9b7b78;

    // collect() is called by Drosera Operators to get current data
    function collect() external view returns (bytes memory) {
        IVault vault = IVault(VAULT_ADDRESS);
        uint256 currentTVL;
        try vault.totalAssets() returns (uint256 assets) {
            currentTVL = assets;
        } catch {
            try IVault(VAULT_ADDRESS).totalSupply() returns (uint256 supply) {
                currentTVL = supply;
            } catch {
                currentTVL = 0;
            }
        }
        // Return current TVL and current block number
        return abi.encode(currentTVL, block.number);
    }

    // shouldRespond() must be pure as per ITrap interface
    // It will analyze the 'data' array which contains historical 'collect' outputs
    function shouldRespond(bytes[] calldata data) external pure returns (bool, bytes memory) {
        // Ensure we have enough data points (at least 3 for current, 1 block ago, 2 blocks ago)
        // data[0] is the most recent collect() output
        // data[1] is the collect() output from 1 block_sample_size ago
        // data[2] is the collect() output from 2 block_sample_size ago
        if (data.length < 3) {
            return (false, bytes("Not enough historical data points collected."));
        }

        // Decode the most recent TVL and block number
        (uint256 currentTVL, uint256 currentBlock) = abi.decode(data[0], (uint256, uint256));

        // Decode the TVL and block number from 2 block_sample_size ago
        (uint256 twoBlocksAgoTVL, uint256 twoBlocksAgoBlock) = abi.decode(data[2], (uint256, uint256));

        // Basic validation: ensure blocks are sequential and not zero
        if (currentTVL == 0 || twoBlocksAgoTVL == 0 || currentBlock == 0 || twoBlocksAgoBlock == 0) {
            return (false, bytes("Invalid TVL or block data."));
        }

        // Calculate the percentage drop
        uint256 dropPercentage;
        if (currentTVL < twoBlocksAgoTVL) {
            dropPercentage = ((twoBlocksAgoTVL - currentTVL) * 100) / twoBlocksAgoTVL;
        } else {
            dropPercentage = 0; // No drop or TVL increased
        }

        // Check if the drop is more than 20%
        if (dropPercentage > 20) {
            string memory message = string.concat(
                "Vault TVL dropped by ",
                Strings.toString(dropPercentage),
                "% in ",
                Strings.toString(currentBlock - twoBlocksAgoBlock), // Actual block difference
                " blocks. Current TVL: ",
                Strings.toString(currentTVL),
                ", TVL at block ",
                Strings.toString(twoBlocksAgoBlock),
                ": ",
                Strings.toString(twoBlocksAgoTVL)
            );
            return (true, abi.encode(message));
        }

        return (false, bytes("Vault TVL drop not significant enough."));
    }
}
