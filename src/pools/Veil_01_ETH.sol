// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {MerkleTreeWithHistory, IHasher} from "../utils/MerkleTreeWithHistory.sol";
import {ReentrancyGuard} from "../utils/ReentrancyGuard.sol";
import {Verifier} from "../utils/Verifier.sol";

contract Veil_01_ETH is MerkleTreeWithHistory, ReentrancyGuard {
    /// @dev The SNARK verifier contract used to verify zero-knowledge proofs
    Verifier public immutable verifier;
    /// @dev The fixed amount of ETH that can be deposited/withdrawn (0.1 ETH)
    uint256 public denomination = 0.1 ether;
    /// @dev The address that deployed this contract and has admin privileges
    address public veilDeployer;

    /// @dev Mapping to track spent nullifiers and prevent double-spending
    mapping(bytes32 => bool) public nullifierHashes;
    /// @dev Mapping to track valid commitments and prevent duplicate deposits
    mapping(bytes32 => bool) public validCommitment;
    /// @dev Array storing all commitments for merkle tree construction
    bytes32[] public commitmentsArray;

    /// @dev Address of the validator contract that's authorized to make deposits
    address public validatorContract;

    modifier onlyValidator() {
        require(msg.sender == validatorContract, "Deposits can only be made from the validator contract");
        _;
    }

    modifier onlyVeilDeployer() {
        require(msg.sender == veilDeployer, "Not allowed");
        _;
    }

    event Deposit(address indexed sender, bytes32 indexed commitment, uint32 leafIndex, uint256 timestamp);
    event Withdrawal(
        address indexed to, bytes32 nullifierHash, address indexed relayer, uint256 fee, uint256 timestamp
    );
    event UpdateVerifiedDepositor(address indexed oldVeilVerifier, address indexed newVeilVerifier);

    /**
     * @dev The constructor
     * @param _verifier the address of SNARK verifier for this contract
     * @param _hasher the address of MiMC hash contract
     * @param _merkleTreeHeight the height of deposits' Merkle Tree
     */
    constructor(Verifier _verifier, IHasher _hasher, uint32 _merkleTreeHeight)
        MerkleTreeWithHistory(_merkleTreeHeight, _hasher)
    {
        verifier = _verifier;
        veilDeployer = msg.sender;
    }

    /**
     * @dev Deposit funds into the contract. The caller must send (for ETH) or approve (for ERC20) value equal to or `denomination` of this instance.
     * @param _commitment the note commitment, which is PedersenHash(nullifier + secret)
     */
    function deposit(bytes32 _commitment) external payable nonReentrant onlyValidator {
        require(!validCommitment[_commitment], "The commitment has been submitted");

        uint32 insertedIndex = _insert(_commitment);
        validCommitment[_commitment] = true;
        commitmentsArray.push(_commitment);
        require(msg.value == denomination, "Please send `mixDenomination` ETH along with transaction");

        emit Deposit(tx.origin, _commitment, insertedIndex, block.timestamp);
    }

    /**
     * @dev Withdraw a deposit from the contract. `proof` is a zkSNARK proof data, and input is an array of circuit public inputs
     * `input` array consists of:
     *   - merkle root of all deposits in the contract
     *   - hash of unique deposit nullifier to prevent double spends
     *   - the recipient of funds
     *   - optional fee that goes to the transaction sender (usually a relay)
     */
    function withdraw(
        uint256[2] calldata _pA,
        uint256[2][2] calldata _pB,
        uint256[2] calldata _pC,
        bytes32 _root,
        bytes32 _nullifierHash,
        address _recipient,
        address _relayer,
        uint256 _fee,
        uint256 _refund
    ) external payable nonReentrant {
        require(_fee <= denomination, "Fee exceeds transfer value");
        require(!nullifierHashes[_nullifierHash], "The note has been already spent");
        require(isKnownRoot(_root), "Cannot find your merkle root"); // Make sure to use a recent one
        require(
            verifier.verifyProof(
                _pA,
                _pB,
                _pC,
                [
                    uint256(_root),
                    uint256(_nullifierHash),
                    uint256(uint160(_recipient)),
                    uint256(uint160(_relayer)),
                    _fee,
                    _refund
                ]
            ),
            "Invalid withdraw proof"
        );

        nullifierHashes[_nullifierHash] = true;
        _processWithdraw(_recipient, _relayer, _fee, _refund);
        emit Withdrawal(_recipient, _nullifierHash, _relayer, _fee, block.timestamp);
    }

    function _processWithdraw(address _recipient, address _relayer, uint256 _fee, uint256 _refund) internal {
        // sanity checks
        require(msg.value == 0, "Message value is supposed to be zero for ETH instance");
        require(_refund == 0, "Refund value is supposed to be zero for ETH instance");

        (bool success,) = _recipient.call{value: denomination - _fee}("");
        require(success, "payment to _recipient did not go thru");
        if (_fee > 0) {
            (success,) = _relayer.call{value: _fee}("");
            require(success, "payment to _relayer did not go thru");
        }
    }

    /**
     * @dev whether a note is already spent
     */
    function isSpent(bytes32 _nullifierHash) public view returns (bool) {
        return nullifierHashes[_nullifierHash];
    }

    /**
     * @dev whether an array of notes is already spent
     */
    function isSpentArray(bytes32[] calldata _nullifierHashes) external view returns (bool[] memory spent) {
        spent = new bool[](_nullifierHashes.length);
        for (uint256 i = 0; i < _nullifierHashes.length; i++) {
            if (isSpent(_nullifierHashes[i])) {
                spent[i] = true;
            }
        }
    }

    /**
     * @dev Returns the index of the last commitment in the commitments array.
     * @return The index of the last commitment (array length - 1), or reverts if array is empty.
     */
    function getLastCommitmentIndex() external view returns (uint256) {
        return commitmentsArray.length - 1;
    }

    /**
     * @dev Returns all commitments between the specified index range.
     * @param startIndex The starting index of the range.
     * @param endIndex The ending index of the range.
     * @return An array of commitments within the specified range.
     */
    function getCommitmentsInRange(uint256 startIndex, uint256 endIndex) external view returns (bytes32[] memory) {
        require(startIndex <= endIndex, "Invalid index range");
        require(endIndex < commitmentsArray.length, "End index out of bounds");

        bytes32[] memory commitmentsInRange = new bytes32[](endIndex - startIndex + 1);
        for (uint256 i = startIndex; i <= endIndex; i++) {
            commitmentsInRange[i - startIndex] = commitmentsArray[i];
        }
        return commitmentsInRange;
    }

    /**
     * @dev Updates the address of the validator contract that's authorized to make deposits
     * @param _newValidator The address of the new validator contract
     */
    function updateValidatorContract(address _newValidator) external onlyVeilDeployer {
        validatorContract = _newValidator;
    }
}
