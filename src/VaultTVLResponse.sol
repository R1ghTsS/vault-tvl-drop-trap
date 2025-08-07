// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract VaultTVLResponse {
    event DiscordTag(string tag);

    function respondWithDiscordName(string memory tag) external {
        emit DiscordTag(tag);
    }
}
