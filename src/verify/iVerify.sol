// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/// @notice A struct representing a single attestation.
struct Attestation {
    bytes32 uid; // A unique identifier of the attestation.
    bytes32 schema; // The unique identifier of the schema.
    uint64 time; // The time when the attestation was created (Unix timestamp).
    uint64 expirationTime; // The time when the attestation expires (Unix timestamp).
    uint64 revocationTime; // The time when the attestation was revoked (Unix timestamp).
    bytes32 refUID; // The UID of the related attestation.
    address recipient; // The recipient of the attestation.
    address attester; // The attester/sender of the attestation.
    bool revocable; // Whether the attestation is revocable.
    bytes data; // Custom attestation data.
}

/// @title IVeilVerifiedOnchain
/// @notice Interface for VeilVerifiedOnchain contract
interface IVeilVerifiedOnchain {
    /// @notice Gets full attestation details for an address
    /// @param _address Address to query attestation for
    /// @return Attestation struct with full attestation details
    function getAttestationDetails(address _address) external view returns (Attestation memory);

    /// @notice Checks if an address has a valid, non-revoked attestation
    /// @param _address Address to check verification status
    /// @return bool True if address has valid verification, false otherwise
    function isVerified(address _address) external view returns (bool);
} 