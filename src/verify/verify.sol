// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
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

interface IAttestationIndexer {
    function getAttestationUid(address recipient, bytes32 schemaUid) external view returns (bytes32);
}

interface IEAS {
    function getAttestation(bytes32 uid) external view returns (Attestation memory);
}

/// @title VeilVerifiedOnchain - Used by the Veil Validator contract
/// @notice Contract to verify attestations on Base network
contract VeilVerifiedOnchain {
    /// @notice Interface for querying attestation UIDs
    IAttestationIndexer public immutable attestationIndexer;
    
    /// @notice Interface for the Ethereum Attestation Service
    IEAS public immutable eas;
    
    /// @notice Schema UID for Coinbase Onchain Verification
    /// @dev This is the specific schema used for Coinbase Onchain Verification
    bytes32 public immutable verifiedSchemaUid = 0xf8b05c79f090979bf4a80270aba232dff11a10d9ca55c4f88de95317970f0de9;

    /// @notice Initializes contract with attestation service addresses
    constructor() {
        attestationIndexer = IAttestationIndexer(0x2c7eE1E5f416dfF40054c27A62f7B357C4E8619C);
        eas = IEAS(0x4200000000000000000000000000000000000021);
    }

    /// @dev Internal function to get the attestation UID for a recipient
    /// @param recipient Address to query attestation for
    /// @param schemaUid Schema identifier
    /// @return bytes32 The attestation UID
    function _getAttestationUid(address recipient, bytes32 schemaUid) internal view returns (bytes32) {
        return attestationIndexer.getAttestationUid(recipient, schemaUid);
    }

    /// @dev Internal function to get attestation details from UID
    /// @param uid The attestation unique identifier
    /// @return Attestation struct containing all attestation details
    function _getAttestation(bytes32 uid) internal view returns (Attestation memory) {
        return eas.getAttestation(uid);
    }

    /// @notice Gets full attestation details for an address
    /// @param _address Address to query attestation for
    /// @return Attestation struct with full attestation details
    function getAttestationDetails(address _address) external view returns (Attestation memory) {
        bytes32 uid = _getAttestationUid(_address, verifiedSchemaUid);
        return _getAttestation(uid);
    }

    /// @notice Checks if an address has a valid, non-revoked attestation
    /// @param _address Address to check verification status
    /// @return bool True if address has valid verification, false otherwise
    function isVerified(address _address) external view returns (bool) {

        // get the attestation uid
        bytes32 uid = _getAttestationUid(_address, verifiedSchemaUid);

        // if no attestation, return false
        if (uid == 0) return false;

        // get the attestation details
        Attestation memory attestation = _getAttestation(uid);

        // if attestation is revoked, return false
        if (attestation.revocationTime > 0) return false;

        // if recipient does not match, return false
        if (attestation.recipient != _address) return false;

        // if all checks pass, return true
        return true;
    }
}
